require('dotenv').config();
const mongoose = require('mongoose');
const LawSnippet = require('../src/models/LawSnippet');
const ChatCache = require('../src/models/ChatCache');
const llmService = require('../src/services/llmService');

async function testQuery(queryDescription, userMessage) {
    console.log(`\n======================================================================`);
    console.log(`TEST: ${queryDescription}`);
    console.log(`QUERY: "${userMessage}"`);
    console.log(`======================================================================`);

    const history = [{ role: 'user', text: userMessage }];
    const response = await llmService.chat(history);

    console.log(`\n--- RETRIEVED SOURCES (${response.sources ? response.sources.length : 0}) ---`);
    if (response.sources && response.sources.length > 0) {
        response.sources.forEach((s, idx) => {
            console.log(`[Source ${idx + 1}]`);
            console.log(`  Document: ${s.document}`);
            console.log(`  Section/Rule: ${s.section ? 'Section ' + s.section : s.rule || 'N/A'}`);
            console.log(`  Title: ${s.title}`);
            console.log(`  Jurisdiction: ${s.jurisdiction}`);
            console.log(`  Authority: ${s.authority}`);
            console.log(`  Score: ${s.score}`);
            console.log(`  URL: ${s.sourceUrl}`);
        });
    } else {
        console.log(`  [No sources passed threshold or out-of-domain]`);
    }

    console.log(`\n--- FINAL ANSWER ---`);
    console.log(response.reply);

    console.log(`\n--- SUGGESTIONS ---`);
    console.log(response.suggestions);

    return response;
}

async function run() {
    try {
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('Connected to MongoDB for RAG verification.');

        // Clear chat cache to ensure live AI evaluation
        await ChatCache.deleteMany({});
        console.log('Cleared ChatCache for clean testing.');

        // 1. Check LawSnippet collection
        const totalSnippets = await LawSnippet.countDocuments();
        console.log(`Total LawSnippet documents in DB: ${totalSnippets}`);
        const sampleSnippets = await LawSnippet.find().limit(3);
        console.log('\n--- 3 Sample Records in MongoDB ---');
        sampleSnippets.forEach((s, i) => {
            console.log(`\nSample ${i+1}:`);
            console.log(`  Document: ${s.document}`);
            console.log(`  Section: ${s.section}`);
            console.log(`  Rule: ${s.rule}`);
            console.log(`  Jurisdiction: ${s.jurisdiction}`);
            console.log(`  Authority: ${s.authority}`);
            console.log(`  SourceUrl: ${s.sourceUrl}`);
            console.log(`  Vector Length: ${s.embedding ? s.embedding.length : 0}`);
            console.log(`  Text: ${s.text.substring(0, 100)}...`);
        });

        // 2. Run Test Queries
        const testCases = [
            {
                title: "RERA Overview",
                query: "What is RERA?"
            },
            {
                title: "Rights of an Allottee",
                query: "What are the rights of an allottee?"
            },
            {
                title: "Possession Delay & Remedies",
                query: "What happens when possession is delayed?"
            },
            {
                title: "Specific RERA Section 18 Analysis",
                query: "What does Section 18 of RERA provide?"
            },
            {
                title: "Promoter Obligations",
                query: "What obligations does a promoter have?"
            },
            {
                title: "Maharashtra-specific RERA Rules",
                query: "What Maharashtra-specific RERA rules apply?"
            },
            {
                title: "Out-of-Domain / Insufficient Context Test",
                query: "How do I make a chocolate cake with vanilla frosting?"
            }
        ];

        for (const tc of testCases) {
            await testQuery(tc.title, tc.query);
        }

        console.log('\n======================================================================');
        console.log('All Legal RAG Tests Completed Successfully!');
        console.log('======================================================================');

    } catch (e) {
        console.error('Error in verification:', e);
    } finally {
        await mongoose.disconnect();
    }
}

run();
