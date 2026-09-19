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

async function ingest() {
    try {
        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('Connected to MongoDB for ingestion');

        // Clear existing snippets to avoid duplicates during testing
        await LawSnippet.deleteMany({});
        console.log('Cleared existing law snippets.');

        // Read laws.txt
        const filePath = path.join(__dirname, '../data/laws.txt');
        const textData = fs.readFileSync(filePath, 'utf-8');

        // Very basic chunking: split by newlines and filter empty lines
        // A better approach for real production would be LangChain text splitters, 
        // but this works for our dummy data format.
        const chunks = textData.split('\n')
            .map(line => line.trim())
            .filter(line => line.length > 20); // ignore very short lines

        console.log(`Found ${chunks.length} chunks to process.`);

        let count = 0;
        for (const chunk of chunks) {
            // Generate embedding for the chunk
            const result = await embeddingModel.embedContent(chunk);
            const embedding = result.embedding.values;

            // Save to DB
            const snippet = new LawSnippet({
                text: chunk,
                source: 'Indian Property Laws & RERA (Curated Reference)',
                embedding: embedding
            });
            await snippet.save();

            count++;
            if (count % 10 === 0) {
                console.log(`Processed ${count}/${chunks.length} chunks...`);
            }
        }

        console.log(`Successfully ingested ${count} law snippets!`);
    } catch (error) {
        console.error('Error during ingestion:', error);
    } finally {
        mongoose.disconnect();
    }
}

ingest();