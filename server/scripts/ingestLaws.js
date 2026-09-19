require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const LawSnippet = require('../src/models/LawSnippet');

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
// Note: We use 'gemini-embedding-2' as it is the stable embedding model
const embeddingModel = genAI.getGenerativeModel({ model: "gemini-embedding-2" });

const DELAY_BETWEEN_REQUESTS_MS = 1500; // stay well under free-tier rate limits
const MAX_RETRIES = 5;

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Embeds a chunk with exponential backoff on 429 (rate limit) errors.
async function embedWithRetry(chunk, attempt = 1) {
    try {
        const result = await embeddingModel.embedContent(chunk);
        return result.embedding.values;
    } catch (error) {
        const isRateLimit = error?.status === 429 || /429|Resource exhausted|Too Many Requests/i.test(error?.message || '');
        if (isRateLimit && attempt <= MAX_RETRIES) {
            const backoffMs = 5000 * Math.pow(2, attempt - 1); // 5s, 10s, 20s, 40s, 80s
            console.log(`  Rate limited, waiting ${backoffMs / 1000}s before retry ${attempt}/${MAX_RETRIES}...`);
            await sleep(backoffMs);
            return embedWithRetry(chunk, attempt + 1);
        }
        throw error;
    }
}

async function ingest() {
    let skipped = 0;
    let inserted = 0;
    let failed = 0;

    try {
        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('Connected to MongoDB for ingestion');

        // Read laws.txt
        const filePath = path.join(__dirname, '../data/laws.txt');
        const textData = fs.readFileSync(filePath, 'utf-8');

        // Very basic chunking: split by newlines and filter empty lines
        const chunks = textData.split('\n')
            .map(line => line.trim())
            .filter(line => line.length > 20); // ignore very short lines

        console.log(`Found ${chunks.length} chunks to process.`);

        // Resume support: skip chunks that are already ingested (matched by
        // exact text), so a rate-limit failure partway through doesn't force
        // re-embedding everything (and re-burning API quota) on the next run.
        const existingTexts = new Set(
            (await LawSnippet.find({ text: { $in: chunks } }, 'text')).map(doc => doc.text)
        );
        if (existingTexts.size > 0) {
            console.log(`${existingTexts.size} chunks already ingested — resuming, will skip those.`);
        }

        for (let i = 0; i < chunks.length; i++) {
            const chunk = chunks[i];

            if (existingTexts.has(chunk)) {
                skipped++;
                continue;
            }

            try {
                const embedding = await embedWithRetry(chunk);

                const snippet = new LawSnippet({
                    text: chunk,
                    source: 'Indian Property Laws & RERA (Curated Reference)',
                    embedding: embedding
                });
                await snippet.save();
                inserted++;
            } catch (error) {
                // Log and continue rather than letting one bad/rate-limited
                // chunk take down the whole ingestion run.
                console.error(`  Failed to ingest chunk ${i + 1}: ${error.message}`);
                failed++;
            }

            if ((inserted + skipped + failed) % 10 === 0) {
                console.log(`Progress: ${inserted + skipped + failed}/${chunks.length} (inserted: ${inserted}, skipped: ${skipped}, failed: ${failed})`);
            }

            // Pace requests to stay under free-tier rate limits.
            if (i < chunks.length - 1) {
                await sleep(DELAY_BETWEEN_REQUESTS_MS);
            }
        }

        console.log(`\nDone. Inserted: ${inserted}, already present: ${skipped}, failed: ${failed}, total: ${chunks.length}`);
        if (failed > 0) {
            console.log('Some chunks failed — re-run this script to retry just the missing ones.');
        }
    } catch (error) {
        console.error('Error during ingestion:', error);
    } finally {
        mongoose.disconnect();
    }
}

ingest();