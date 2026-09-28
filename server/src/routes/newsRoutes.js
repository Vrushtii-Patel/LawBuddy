const express = require('express');
const router = express.Router();

const RSS_URL = "https://news.google.com/rss/search?q=RERA+real+estate+law+India&hl=en-IN&gl=IN&ceid=IN:en";
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes cache TTL
const RSS_TIMEOUT_MS = 7000; // 7 seconds timeout on external RSS fetch

// Process-local in-memory cache
let newsCache = {
    data: null,
    timestamp: 0
};

// In-flight refresh promise to coalesce concurrent requests and prevent cache stampedes
let inFlightRefresh = null;

const WARNING_PATTERNS = [
    /\b(?:warning|warns?|alert|alerts|caution|cautionary|beware)\b/i,
    /\b(?:penalt(?:y|ies)|penaliz(?:e|ed|ing)|fines?|fined|violat(?:ion|ions|ing|ed?)|breach(?:ed|ing)?)\b/i,
    /\b(?:arrest(?:ed|ing)?|bans?|banned|banning|cancel(?:led|ling|lation)?|revok(?:ed|ing|ation)|stay(?:ed)?)\b/i,
    /\b(?:probe|investigat(?:ion|ing|ed)|notices?|summons?|blacklist(?:ed)?|evict(?:ion|ed)?|demolit(?:ion|ed))\b/i,
    /\b(?:fraud|scams?|illegal(?:ly)?|defaulters?|defaults?|non-complian(?:ce|t)|unauthori[sz]ed|unregistered|forg(?:ery|ed))\b/i,
    /\b(?:stuck|delayed?|delays?|aggrieved|disputes?|crisis|losses?|strict|mandat(?:ory|es?))\b/i
];

function isWarningArticle(title = '', source = '') {
    const text = `${title} ${source}`;
    return WARNING_PATTERNS.some(regex => regex.test(text));
}

function parseRssItems(xmlText) {
    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/gi;
    let match;
    
    while ((match = itemRegex.exec(xmlText)) !== null) {
        const itemContent = match[1];
        
        const titleMatch = /<title>([\s\S]*?)<\/title>/i.exec(itemContent);
        const linkMatch = /<link>([\s\S]*?)<\/link>/i.exec(itemContent);
        const pubDateMatch = /<pubDate>([\s\S]*?)<\/pubDate>/i.exec(itemContent);
        const sourceMatch = /<source[^>]*>([\s\S]*?)<\/source>/i.exec(itemContent);
        
        let title = titleMatch ? titleMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';
        const link = linkMatch ? linkMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : '';
        const pubDate = pubDateMatch ? pubDateMatch[1].trim() : '';
        const source = sourceMatch ? sourceMatch[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : 'Legal News';
        
        if (title.includes(' - ')) {
            const parts = title.split(' - ');
            if (parts.length > 1) {
                parts.pop();
                title = parts.join(' - ');
            }
        }
        
        if (title && link) {
            items.push({
                title,
                link,
                pubDate,
                source,
                isWarning: isWarningArticle(title, source)
            });
        }
    }
    return items;
}

const fallbackNews = [
    {
        title: "Supreme Court Clarifies RERA Applicability to Ongoing Real Estate Projects",
        link: "https://www.livelaw.in",
        pubDate: new Date().toUTCString(),
        source: "Supreme Court Update",
        isWarning: false
    },
    {
        title: "State RERA Authority Mandates Registration Before Property Marketing",
        link: "https://www.barandbench.com",
        pubDate: new Date().toUTCString(),
        source: "RERA Alerts",
        isWarning: true
    },
    {
        title: "Homebuyers Granted Status as Financial Creditors Under IBC Framework",
        link: "https://economictimes.indiatimes.com",
        pubDate: new Date().toUTCString(),
        source: "Legal Update",
        isWarning: false
    }
];

/**
 * Performs network fetch with an AbortController timeout.
 */
async function fetchRssFeed(url, timeoutMs = RSS_TIMEOUT_MS) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
    try {
        const response = await fetch(url, {
            signal: controller.signal,
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
        });
        if (!response.ok) {
            throw new Error(`Failed to fetch Google News RSS: ${response.status}`);
        }
        const xmlText = await response.text();
        return xmlText;
    } finally {
        clearTimeout(timeoutId);
    }
}

/**
 * Fetches and parses RSS articles, updating the in-memory cache on success.
 */
async function refreshLegalNews(rssUrl = RSS_URL, timeoutMs = RSS_TIMEOUT_MS) {
    const xmlText = await fetchRssFeed(rssUrl, timeoutMs);
    let articles = parseRssItems(xmlText);
    
    if (articles.length === 0) {
        throw new Error('No articles parsed from Google News RSS');
    }
    
    articles = articles.slice(0, 4);
    
    newsCache = {
        data: articles,
        timestamp: Date.now()
    };
    
    return articles;
}

/**
 * Retrieves legal updates using:
 * 1. Fresh cache if within TTL
 * 2. Shared in-flight RSS refresh to prevent stampedes
 * 3. Stale cache fallback if RSS fetch fails/times out
 * 4. Fallback static news if cache is completely empty and RSS fails
 */
async function getLegalUpdates({ rssUrl = RSS_URL, timeoutMs = RSS_TIMEOUT_MS, ttlMs = CACHE_TTL_MS, forceRefresh = false, fetcher = refreshLegalNews } = {}) {
    const now = Date.now();
    const isFresh = newsCache.data && (now - newsCache.timestamp < ttlMs);

    if (!forceRefresh && isFresh) {
        return newsCache.data;
    }

    // Single in-flight refresh to prevent cache stampede
    if (!inFlightRefresh) {
        inFlightRefresh = fetcher(rssUrl, timeoutMs)
            .finally(() => {
                inFlightRefresh = null;
            });
    }

    try {
        const freshArticles = await inFlightRefresh;
        return freshArticles;
    } catch (error) {
        // Stale-cache fallback
        if (newsCache.data && newsCache.data.length > 0) {
            console.warn('RSS fetch failed, serving stale cached legal news:', error.message);
            return newsCache.data;
        }

        // Empty cache fallback
        console.warn('Error fetching live legal news, serving fallback:', error.message);
        return fallbackNews;
    }
}

router.get('/legal-updates', async (req, res) => {
    try {
        const articles = await getLegalUpdates();
        res.json(articles);
    } catch (error) {
        console.warn('Unhandled error in /legal-updates, serving fallback:', error.message);
        res.json(fallbackNews);
    }
});

// Exposed helpers for testing and verification
router.getLegalUpdates = getLegalUpdates;
router.getCache = () => newsCache;
router.setCache = (data, timestamp) => { newsCache = { data, timestamp }; };
router.resetCache = () => { newsCache = { data: null, timestamp: 0 }; inFlightRefresh = null; };
router.CACHE_TTL_MS = CACHE_TTL_MS;
router.RSS_TIMEOUT_MS = RSS_TIMEOUT_MS;
router.fallbackNews = fallbackNews;
router.parseRssItems = parseRssItems;
router.isWarningArticle = isWarningArticle;

module.exports = router;
