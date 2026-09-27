require('dotenv').config();
const mongoose = require('mongoose');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const LawSnippet = require('../src/models/LawSnippet');
const { EMBEDDING_MODEL_NAME } = require('../src/config/modelConfig');

async function run() {
    try {
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('MongoDB connected.');
        
        // Try embedding
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const embeddingModel = genAI.getGenerativeModel({ model: EMBEDDING_MODEL_NAME });
        const embeddingResult = await embeddingModel.embedContent("Hello world");
        const queryVector = embeddingResult.embedding.values;
        console.log('Embedding created successfully, vector length:', queryVector.length);

        // Try searching
        const searchResults = await LawSnippet.aggregate([
            {
                "$vectorSearch": {
                    "index": "vector_index",
                    "path": "embedding",
                    "queryVector": queryVector,
                    "numCandidates": 10,
                    "limit": 3
                }
            },
            {
                "$project": {
                    "text": 1,
                    "score": { "$meta": "vectorSearchScore" }
                }
            }
        ]);
        console.log('Search successful, results found:', searchResults.length);

    } catch (e) {
        console.error('Error during test:', e);
    } finally {
        await mongoose.disconnect();
    }
}
run();
