require('dotenv').config();
const mongoose = require('mongoose');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const LawSnippet = require('../src/models/LawSnippet');

async function testQuery(query) {
    console.log(`\n======================================================`);
    console.log(`QUERY: "${query}"`);
    console.log(`======================================================`);

    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const embeddingModel = genAI.getGenerativeModel({ model: "gemini-embedding-2" });
    const embeddingResult = await embeddingModel.embedContent(query);
    const queryVector = embeddingResult.embedding.values;

    const pipeline = [
        {
            $vectorSearch: {
                index: "vector_index",
                path: "embedding",
                queryVector: queryVector,
                numCandidates: 25,
                limit: 3
            }
        },
        {
            $project: {
                text: 1,
                document: 1,
                actOrRule: 1,
                section: 1,
                subsection: 1,
                rule: 1,
                title: 1,
                jurisdiction: 1,
                authority: 1,
                sourceUrl: 1,
                score: { $meta: "vectorSearchScore" }
            }
        }
    ];

    const results = await LawSnippet.aggregate(pipeline);
    console.log(`Found ${results.length} results:`);
    results.forEach((r, i) => {
        console.log(`\n[${i+1}] Score: ${r.score.toFixed(4)} | Doc: ${r.document} | Section: ${r.section || r.rule || 'N/A'}`);
        console.log(`    Title: ${r.title}`);
        console.log(`    Jurisdiction: ${r.jurisdiction} | Authority: ${r.authority}`);
        console.log(`    URL: ${r.sourceUrl}`);
        console.log(`    Snippet: ${r.text.substring(0, 140)}...`);
    });
    return results;
}

async function run() {
    try {
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('Connected to MongoDB.');

        const queries = [
            "What is RERA?",
            "What are the rights of an allottee?",
            "What happens when possession is delayed?",
            "What does Section 18 of RERA provide?",
            "What obligations does a promoter have?",
            "What Maharashtra-specific RERA rules apply?",
            "How do I cook Italian pasta with mushrooms?" // out of domain test
        ];

        for (const q of queries) {
            await testQuery(q);
        }

    } catch (e) {
        console.error('Error during test:', e);
    } finally {
        await mongoose.disconnect();
    }
}

run();
