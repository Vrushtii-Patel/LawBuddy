const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mongoose = require('mongoose');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const LawSnippet = require('../src/models/LawSnippet');

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
// Note: We use 'gemini-embedding-2' which produces 3072-dimensional embeddings
const embeddingModel = genAI.getGenerativeModel({ model: "gemini-embedding-2" });

const DELAY_BETWEEN_REQUESTS_MS = 400;
const MAX_RETRIES = 5;

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Embeds legal text with exponential backoff on 429 / rate limits
async function embedWithRetry(textToEmbed, attempt = 1) {
    try {
        const result = await embeddingModel.embedContent(textToEmbed);
        return result.embedding.values;
    } catch (error) {
        const isRateLimit = error?.status === 429 || /429|Resource exhausted|Too Many Requests/i.test(error?.message || '');
        if (isRateLimit && attempt <= MAX_RETRIES) {
            const backoffMs = 2000 * Math.pow(2, attempt - 1); // 2s, 4s, 8s, 16s, 32s
            console.log(`  Rate limited, waiting ${backoffMs / 1000}s before retry ${attempt}/${MAX_RETRIES}...`);
            await sleep(backoffMs);
            return embedWithRetry(textToEmbed, attempt + 1);
        }
        throw error;
    }
}

const crypto = require('crypto');

function computeSourceKey(item) {
    // Stable identity independent of embedding content, so re-running the
    // script doesn't treat an already-ingested provision as "new" just
    // because whitespace or embedding values differ.
    const parts = [item.document, item.actOrRule, item.section, item.subsection, item.rule, item.title]
        .map(p => (p === undefined || p === null ? '' : String(p).trim().toLowerCase()));
    return crypto.createHash('sha256').update(parts.join('|')).digest('hex');
}

async function ingest() {
    try {
        console.log('--- Starting Authoritative Legal Corpus Ingestion (sync mode) ---');
        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('Connected to MongoDB for ingestion.');

        // Load authoritative_laws.json
        const filePath = path.join(__dirname, '../data/authoritative_laws.json');
        if (!fs.existsSync(filePath)) {
            throw new Error(`Authoritative laws file not found at: ${filePath}`);
        }
        const legalData = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        console.log(`Loaded ${legalData.length} authoritative statutory provisions from source file.`);

        // Build the target state: sourceKey -> item, catching duplicate keys
        // within the source file itself before touching the database.
        const targetByKey = new Map();
        for (const item of legalData) {
            if (!item.text || !item.document) {
                console.warn(`Skipping invalid item (missing text or document): ${JSON.stringify(item).slice(0, 80)}...`);
                continue;
            }
            const key = computeSourceKey(item);
            if (targetByKey.has(key)) {
                console.warn(`Duplicate entry in source file for "${item.document} ${item.section || item.rule || ''}" — keeping the first occurrence only.`);
                continue;
            }
            targetByKey.set(key, item);
        }

        // One-time migration cleanup: records saved by the old (pre-sync)
        // version of this script have no sourceKey and would otherwise sit
        // alongside the new sync-tracked set as untracked duplicates. Since
        // authoritative_laws.json is the single source of truth going
        // forward, clear those out so the collection only ever reflects
        // what's in this file.
        const legacyResult = await LawSnippet.deleteMany({ sourceKey: null });
        if (legacyResult.deletedCount > 0) {
            console.log(`Removed ${legacyResult.deletedCount} legacy record(s) with no sourceKey (from a pre-sync ingestion run).`);
        }

        // Sync instead of wipe-and-reload: only add what's missing, and only
        // remove records that used to come from this file but no longer do.
        // This means two people can each run this script against the same
        // shared database without racing to delete each other's work — both
        // runs converge to the same end state instead of whoever-ran-last winning.
        const existing = await LawSnippet.find({ sourceKey: { $ne: null } }, 'sourceKey');
        const existingKeys = new Set(existing.map(e => e.sourceKey));

        const toInsert = [...targetByKey.entries()].filter(([key]) => !existingKeys.has(key));
        const toRemove = existing.filter(e => !targetByKey.has(e.sourceKey)).map(e => e._id);

        console.log(`Already ingested: ${existingKeys.size} | New to embed: ${toInsert.length} | Stale (removed from source file): ${toRemove.length}`);

        if (toRemove.length > 0) {
            await LawSnippet.deleteMany({ _id: { $in: toRemove } });
            console.log(`Removed ${toRemove.length} stale record(s) no longer present in authoritative_laws.json.`);
        }

        let count = 0;
        for (const [key, item] of toInsert) {
            const citationLabel = item.section
                ? `${item.document} - Section ${item.section}`
                : `${item.document} - ${item.rule || item.title}`;

            console.log(`[${count + 1}/${toInsert.length}] Embedding: ${citationLabel}...`);

            // Generate embedding for the legal text + context
            const textToEmbed = `${item.document} ${item.section ? 'Section ' + item.section : ''} ${item.title || ''}: ${item.text}`.trim();
            const embeddingValues = await embedWithRetry(textToEmbed);

            if (!embeddingValues) {
                throw new Error(`Failed to generate embedding for "${citationLabel}".`);
            }

            // Save structured LawSnippet with all metadata
            const snippet = new LawSnippet({
                text: item.text,
                document: item.document,
                actOrRule: item.actOrRule || 'Act',
                section: item.section || null,
                subsection: item.subsection || null,
                rule: item.rule || null,
                title: item.title || null,
                jurisdiction: item.jurisdiction || 'India',
                authority: item.authority || 'India Code',
                sourceUrl: item.sourceUrl || null,
                source: `${item.document}${item.section ? ' (Sec ' + item.section + ')' : ''}`,
                sourceKey: key,
                embedding: embeddingValues
            });

            await snippet.save();
            count++;

            if (count < toInsert.length) {
                await sleep(DELAY_BETWEEN_REQUESTS_MS);
            }
        }

        console.log('\n=============================================');
        console.log(`✅ Ingestion Complete!`);
        console.log(`Newly embedded: ${count} | Already present: ${existingKeys.size - toRemove.length} | Removed: ${toRemove.length} | Total now in DB: ${existingKeys.size - toRemove.length + count}`);
        console.log('=============================================\n');

    } catch (error) {
        console.error('❌ Error during legal corpus ingestion:', error);
    } finally {
        await mongoose.disconnect();
        console.log('Disconnected from MongoDB.');
    }
}

if (require.main === module) {
    ingest();
}

module.exports = { ingest };