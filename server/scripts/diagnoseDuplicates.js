const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mongoose = require('mongoose');
const LawSnippet = require('../src/models/LawSnippet');

async function diagnose() {
    console.log('======================================================================');
    console.log('SAFE READ-ONLY DIAGNOSIS OF LawSnippet COLLECTION IN MONGODB');
    console.log('======================================================================\n');

    try {
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('✓ Connected to MongoDB (Read-Only Analysis Mode).\n');

        // Fetch all documents from the collection
        const allSnippets = await LawSnippet.find({}).lean();
        const totalCount = allSnippets.length;

        console.log(`1. Total LawSnippet Document Count: ${totalCount}`);

        // Group by provision key: document + section/rule + title
        const byProvisionKey = new Map();
        const byExactText = new Map();

        allSnippets.forEach((snippet) => {
            const doc = snippet.document || 'Unknown';
            const sec = snippet.section || snippet.rule || 'NoSec';
            const title = snippet.title || 'NoTitle';
            const provisionKey = `${doc} | ${sec} | ${title}`.toLowerCase().trim();

            if (!byProvisionKey.has(provisionKey)) {
                byProvisionKey.set(provisionKey, []);
            }
            byProvisionKey.get(provisionKey).push(snippet);

            const textKey = (snippet.text || '').trim();
            if (!byExactText.has(textKey)) {
                byExactText.set(textKey, []);
            }
            byExactText.get(textKey).push(snippet);
        });

        const uniqueProvisionsCount = byProvisionKey.size;
        const uniqueTextCount = byExactText.size;

        // Find duplicates
        const duplicateProvisionGroups = [];
        for (const [key, records] of byProvisionKey.entries()) {
            if (records.length > 1) {
                duplicateProvisionGroups.push({ key, count: records.length, records });
            }
        }

        const duplicateTextGroups = [];
        for (const [key, records] of byExactText.entries()) {
            if (records.length > 1) {
                duplicateTextGroups.push({ key, count: records.length, records });
            }
        }

        const totalDuplicatesByProvision = allSnippets.length - uniqueProvisionsCount;
        const totalDuplicatesByText = allSnippets.length - uniqueTextCount;

        console.log(`2. Number of Unique Legal Provisions (by doc/sec/title): ${uniqueProvisionsCount}`);
        console.log(`3. Number of Unique Legal Provisions (by exact text): ${uniqueTextCount}`);
        console.log(`4. Number of Duplicate Records (by doc/sec/title): ${totalDuplicatesByProvision}`);
        console.log(`5. Number of Duplicate Records (by exact text): ${totalDuplicatesByText}\n`);

        if (duplicateProvisionGroups.length === 0 && duplicateTextGroups.length === 0) {
            console.log('✅ NO DUPLICATES FOUND! Every record in the database is unique.');
        } else {
            console.log('⚠️ DUPLICATE RECORDS IDENTIFIED:');
            duplicateProvisionGroups.forEach((group, idx) => {
                console.log(`\n--- Duplicate Group #${idx + 1} (${group.count} copies) ---`);
                console.log(`Key: ${group.key}`);
                
                const first = group.records[0];
                let allEmbeddingsIdentical = true;
                let allMetadataIdentical = true;

                group.records.forEach((r, rIdx) => {
                    console.log(`  [Record ID ${r._id}] Created: ${r.createdAt || 'N/A'}, EmbDims: ${r.embedding ? r.embedding.length : 0}`);
                    if (rIdx > 0) {
                        // Compare embedding values with first
                        if (!r.embedding || !first.embedding || r.embedding.length !== first.embedding.length) {
                            allEmbeddingsIdentical = false;
                        } else {
                            const match = r.embedding.every((val, i) => Math.abs(val - first.embedding[i]) < 0.000001);
                            if (!match) allEmbeddingsIdentical = false;
                        }

                        // Compare metadata
                        if (r.document !== first.document || r.section !== first.section || r.sourceUrl !== first.sourceUrl) {
                            allMetadataIdentical = false;
                        }
                    }
                });

                console.log(`  - Identical Embeddings across copies: ${allEmbeddingsIdentical ? 'YES' : 'NO'}`);
                console.log(`  - Identical Metadata across copies: ${allMetadataIdentical ? 'YES' : 'NO'}`);
            });
        }

        console.log('\n======================================================================');
        console.log('DIAGNOSIS COMPLETE (NO DATA MODIFIED)');
        console.log('======================================================================');

    } catch (err) {
        console.error('Error during diagnosis:', err);
    } finally {
        await mongoose.disconnect();
        console.log('\nDisconnected from MongoDB.');
    }
}

diagnose();
