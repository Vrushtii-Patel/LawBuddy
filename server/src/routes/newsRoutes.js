const express = require('express');
const router = express.Router();

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

router.get('/legal-updates', async (req, res) => {
    try {
        const rssUrl = "https://news.google.com/rss/search?q=RERA+real+estate+law+India&hl=en-IN&gl=IN&ceid=IN:en";
        const response = await fetch(rssUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
        });
        
        if (!response.ok) {
            throw new Error(`Failed to fetch Google News RSS: ${response.status}`);
        }
        
        const xmlText = await response.text();
        let articles = parseRssItems(xmlText);
        
        if (articles.length === 0) {
            return res.json(fallbackNews);
        }
        
        articles = articles.slice(0, 4);
        
        res.json(articles);
    } catch (error) {
        console.warn('Error fetching live legal news, serving fallback:', error.message);
        res.json(fallbackNews);
    }
});

module.exports = router;
