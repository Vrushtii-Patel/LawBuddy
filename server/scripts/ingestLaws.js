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

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function ingest() {
    try {
        console.log('--- Starting Authoritative Legal Corpus Ingestion ---');
        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('Connected to MongoDB for ingestion.');

        // 1. Remove all old/dummy law snippets
        const deleteResult = await LawSnippet.deleteMany({});
        console.log(`Cleared ${deleteResult.deletedCount} old/dummy law snippets from LawSnippet collection.`);

        // 2. Load authoritative_laws.json
        const filePath = path.join(__dirname, '../data/authoritative_laws.json');
        if (!fs.existsSync(filePath)) {
            throw new Error(`Authoritative laws file not found at: ${filePath}`);
        }
        const legalData = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        console.log(`Loaded ${legalData.length} authoritative statutory provisions.`);

        let count = 0;
        for (const item of legalData) {
            // Validate required fields
            if (!item.text || !item.document) {
                console.warn(`Skipping invalid item at index ${count}: missing text or document`);
                continue;
            }

            const citationLabel = item.section
                ? `${item.document} - Section ${item.section}`
                : `${item.document} - ${item.rule || item.title}`;
            
            console.log(`[${count + 1}/${legalData.length}] Embedding: ${citationLabel}...`);

            // Generate embedding for the legal text + context
            // Embedding text includes title and text for maximal semantic retrieval
            const textToEmbed = `${item.document} ${item.section ? 'Section ' + item.section : ''} ${item.title || ''}: ${item.text}`.trim();
            
            let embeddingValues = null;
            let attempts = 0;
            while (attempts < 3 && !embeddingValues) {
                try {
                    attempts++;
                    const result = await embeddingModel.embedContent(textToEmbed);
                    embeddingValues = result.embedding.values;
                } catch (embErr) {
                    console.warn(`Embedding attempt ${attempts} failed for "${citationLabel}": ${embErr.message}. Retrying in 2s...`);
                    await sleep(2000);
                }
            }

            if (!embeddingValues) {
                throw new Error(`Failed to generate embedding for "${citationLabel}" after 3 attempts.`);
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
                embedding: embeddingValues
            });

            await snippet.save();
            count++;

            // Brief pause to adhere to Gemini API rate limits
            await sleep(350);
        }

        console.log('\n=============================================');
        console.log(`✅ Ingestion Complete!`);
        console.log(`Total authoritative legal snippets ingested: ${count}`);
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