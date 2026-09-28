const assert = require('assert');
const newsRoutes = require('../src/routes/newsRoutes');

async function runTests() {
    console.log('--- Running Legal Updates Caching & Timeout Unit Tests ---');

    // 1. Verify Constants
    assert.strictEqual(newsRoutes.CACHE_TTL_MS, 10 * 60 * 1000, 'CACHE_TTL_MS should be 10 minutes (600,000 ms)');
    assert.strictEqual(newsRoutes.RSS_TIMEOUT_MS, 7000, 'RSS_TIMEOUT_MS should be 7000 ms (7s)');
    console.log('✓ Test 1 Passed: Cache TTL (10m) and RSS timeout (7s) correctly configured');

    // 2. Test initial request fetches and populates cache
    newsRoutes.resetCache();
    let fetchCount = 0;
    const mockFetcher = async () => {
        fetchCount++;
        const sampleArticles = [
            {
                title: 'High Court Issues Warning On Real Estate Defaulters',
                link: 'https://example.com/article1',
                pubDate: 'Mon, 28 Sep 2026 12:00:00 GMT',
                source: 'High Court',
                isWarning: true
            },
            {
                title: 'New RERA Guidelines Released for Homebuyers',
                link: 'https://example.com/article2',
                pubDate: 'Mon, 28 Sep 2026 11:00:00 GMT',
                source: 'RERA Authority',
                isWarning: false
            }
        ];
        newsRoutes.setCache(sampleArticles, Date.now());
        return sampleArticles;
    };

    const firstResult = await newsRoutes.getLegalUpdates({ fetcher: mockFetcher });
    assert.strictEqual(fetchCount, 1, 'First request should invoke fetcher');
    assert.strictEqual(firstResult.length, 2, 'Result should have 2 articles');
    assert.strictEqual(firstResult[0].title, 'High Court Issues Warning On Real Estate Defaulters');
    console.log('✓ Test 2 Passed: Initial request fetches news and populates cache');

    // 3. Test subsequent request within TTL uses cache without invoking fetcher
    const secondResult = await newsRoutes.getLegalUpdates({ fetcher: mockFetcher });
    assert.strictEqual(fetchCount, 1, 'Subsequent request within TTL must NOT invoke fetcher');
    assert.strictEqual(secondResult, firstResult, 'Subsequent request should return identical cached array');
    console.log('✓ Test 3 Passed: Fresh cache served immediately without network fetch');

    // 4. Test expired cache triggers a refresh
    const expiredTimestamp = Date.now() - (11 * 60 * 1000); // 11 mins ago
    newsRoutes.setCache(firstResult, expiredTimestamp);
    
    let refreshedFetchCount = 0;
    const refreshedArticles = [
        {
            title: 'Updated Real Estate Legal News',
            link: 'https://example.com/article-fresh',
            pubDate: 'Mon, 28 Sep 2026 14:00:00 GMT',
            source: 'Legal Desk',
            isWarning: false
        }
    ];
    const refreshFetcher = async () => {
        refreshedFetchCount++;
        newsRoutes.setCache(refreshedArticles, Date.now());
        return refreshedArticles;
    };

    const expiredResult = await newsRoutes.getLegalUpdates({ fetcher: refreshFetcher });
    assert.strictEqual(refreshedFetchCount, 1, 'Expired cache must trigger refresh fetcher');
    assert.strictEqual(expiredResult[0].title, 'Updated Real Estate Legal News');
    console.log('✓ Test 4 Passed: Expired cache triggers refresh fetch and updates cache');

    // 5. Test stale cache fallback on RSS timeout/failure
    const staleArticles = [
        {
            title: 'Stale Cached Real Estate Article',
            link: 'https://example.com/stale',
            pubDate: 'Mon, 28 Sep 2026 10:00:00 GMT',
            source: 'Archive News',
            isWarning: false
        }
    ];
    // Cache is expired
    newsRoutes.setCache(staleArticles, Date.now() - (15 * 60 * 1000));
    
    const failingFetcher = async () => {
        throw new Error('Simulated network timeout after 7000ms');
    };

    const staleResult = await newsRoutes.getLegalUpdates({ fetcher: failingFetcher });
    assert.strictEqual(staleResult.length, 1);
    assert.strictEqual(staleResult[0].title, 'Stale Cached Real Estate Article');
    console.log('✓ Test 5 Passed: RSS failure/timeout falls back to stale cache safely');

    // 6. Test cold-start RSS failure (no cached data) falls back to static fallbackNews
    newsRoutes.resetCache();
    const fallbackResult = await newsRoutes.getLegalUpdates({ fetcher: failingFetcher });
    assert.strictEqual(fallbackResult, newsRoutes.fallbackNews, 'Empty cache + RSS failure returns fallbackNews');
    assert.strictEqual(fallbackResult.length, 3);
    console.log('✓ Test 6 Passed: Empty cache with RSS failure returns fallback news without throwing');

    // 7. Test cache stampede prevention (concurrent requests coalesce into 1 in-flight fetch)
    newsRoutes.resetCache();
    let stampedeFetchCount = 0;
    const slowFetcher = async () => {
        stampedeFetchCount++;
        await new Promise(resolve => setTimeout(resolve, 50));
        const data = [
            {
                title: 'Coalesced RSS Article',
                link: 'https://example.com/coalesced',
                pubDate: 'Mon, 28 Sep 2026 15:00:00 GMT',
                source: 'Legal Daily',
                isWarning: false
            }
        ];
        newsRoutes.setCache(data, Date.now());
        return data;
    };

    const [res1, res2, res3, res4, res5] = await Promise.all([
        newsRoutes.getLegalUpdates({ fetcher: slowFetcher }),
        newsRoutes.getLegalUpdates({ fetcher: slowFetcher }),
        newsRoutes.getLegalUpdates({ fetcher: slowFetcher }),
        newsRoutes.getLegalUpdates({ fetcher: slowFetcher }),
        newsRoutes.getLegalUpdates({ fetcher: slowFetcher })
    ]);

    assert.strictEqual(stampedeFetchCount, 1, 'All 5 concurrent requests must coalesce into exactly 1 in-flight fetch');
    assert.strictEqual(res1[0].title, 'Coalesced RSS Article');
    assert.strictEqual(res2[0].title, 'Coalesced RSS Article');
    assert.strictEqual(res3[0].title, 'Coalesced RSS Article');
    assert.strictEqual(res4[0].title, 'Coalesced RSS Article');
    assert.strictEqual(res5[0].title, 'Coalesced RSS Article');
    console.log('✓ Test 7 Passed: Concurrent requests coalesced, preventing cache stampedes');

    // 8. Test XML parsing & isWarning flag logic
    const sampleXml = `
        <rss version="2.0">
            <channel>
                <item>
                    <title><![CDATA[State RERA Authority warns builders over illegal sales - Economic Times]]></title>
                    <link>https://news.google.com/rss/articles/123</link>
                    <pubDate>Mon, 28 Sep 2026 09:30:00 GMT</pubDate>
                    <source url="https://economictimes.indiatimes.com">Economic Times</source>
                </item>
                <item>
                    <title>Supreme Court upholds homebuyer rights in insolvency - LiveLaw</title>
                    <link>https://news.google.com/rss/articles/456</link>
                    <pubDate>Mon, 28 Sep 2026 08:00:00 GMT</pubDate>
                    <source url="https://livelaw.in">LiveLaw</source>
                </item>
            </channel>
        </rss>
    `;
    const parsed = newsRoutes.parseRssItems(sampleXml);
    assert.strictEqual(parsed.length, 2);
    assert.strictEqual(parsed[0].title, 'State RERA Authority warns builders over illegal sales');
    assert.strictEqual(parsed[0].isWarning, true, 'Warning keywords should set isWarning = true');
    assert.strictEqual(parsed[1].title, 'Supreme Court upholds homebuyer rights in insolvency');
    assert.strictEqual(parsed[1].isWarning, false, 'Non-warning titles should set isWarning = false');
    console.log('✓ Test 8 Passed: XML parsing strips source suffix and computes isWarning accurately');

    console.log('\nALL LEGAL UPDATES CACHING & TIMEOUT TESTS PASSED (8/8)!');
}

runTests().catch(err => {
    console.error('Test failed:', err);
    process.exit(1);
});
