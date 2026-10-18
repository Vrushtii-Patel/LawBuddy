/**
 * Regression tests: every successfully scanned document must update the user's
 * due-diligence checklists, including scanned PDFs and photos (these finish early,
 * inside the text-extraction stage, and used to skip the checklist step).
 * No network or database is needed: models and AI calls are replaced with stubs.
 */
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const mongoose = require('mongoose');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lawbuddy-sync-'));
process.env.SCAN_FILES_DIR = tempDir;
process.env.NODE_ENV = 'test';

const llm = require('../src/services/llmService');
const ScanJob = require('../src/models/ScanJob');
const Document = require('../src/models/Document');
const crossReferenceService = require('../src/services/crossReferenceService');
const scanJobService = require('../src/services/scanJobService');

const oid = () => new mongoose.Types.ObjectId();
const analysis = [
    { clauseId: 'CLAUSE-001', title: 'Forfeiture', riskLevel: 'HIGH_RISK', category: 'Red', text: 't1', reason: 'r' },
    { clauseId: 'CLAUSE-002', title: 'Notice', riskLevel: 'COMPLIANT', category: 'Green', text: 't2', reason: 'r' }
];

// ---- stubs ---------------------------------------------------------------
let syncCalls = [];
let syncShouldThrow = false;
crossReferenceService.syncDocumentIssuesWithChecklists = async (userId, doc) => {
    syncCalls.push({ userId, doc });
    if (syncShouldThrow) throw new Error('checklist database is down');
    return [];
};
const storedDocs = new Map();
Document.findOne = async () => null;
Document.findById = async (id) => storedDocs.get(String(id)) || null;
let upsertDocId = null;
Document.findOneAndUpdate = async (_q, update) => {
    upsertDocId = oid();
    return { _id: upsertDocId, title: update.$set.title, analysis: update.$set.analysis };
};
llm.analyzeCanonicalClauses = async () => analysis;

let counter = 0;
function makeJob({ mimeType, bytes, extractedText = '' }) {
    counter++;
    let storagePath = null;
    if (bytes) {
        storagePath = path.join(tempDir, `f${counter}.dat`);
        fs.writeFileSync(storagePath, bytes);
    }
    const job = new ScanJob({
        jobId: `job_${counter}`, userId: 'user_1', fileHash: `hash_${counter}`,
        mimeType, storagePath, extractedText, title: 'Sale Agreement'
    });
    job.save = async () => job;
    ScanJob.findOne = async () => job;
    return job;
}
const unreadablePdf = Buffer.from('%PDF-1.4 not a real pdf');   // forces the "scanned PDF" route
const jpeg = Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

function scannedResult(documentId) {
    return {
        analysis, documentId,
        extractedText: 'Clause 1. The developer may forfeit the full amount paid by the buyer.',
        canonicalClauses: [{ clauseId: 'CLAUSE-001', text: 't1', title: 'Forfeiture' }]
    };
}
function reset() { syncCalls = []; syncShouldThrow = false; storedDocs.clear(); }

async function run() {
    console.log('--- Checklist sync after scan tests ---');

    // 1. Scanned PDF
    reset();
    let docId = oid();
    storedDocs.set(String(docId), { _id: docId, title: 'Sale Agreement', analysis });
    llm.analyzeContractPipeline = async () => scannedResult(docId);
    let job = makeJob({ mimeType: 'application/pdf', bytes: unreadablePdf });
    await scanJobService.executeJobPipeline(job.jobId);
    assert.strictEqual(job.status, 'COMPLETED');
    assert.strictEqual(syncCalls.length, 1, 'scanned PDF must update the checklist exactly once');
    assert.strictEqual(syncCalls[0].userId, 'user_1');
    assert.strictEqual(String(syncCalls[0].doc._id), String(docId));
    assert.strictEqual(syncCalls[0].doc.analysis.length, 2);
    console.log('✓ 1. Scanned PDF updates the checklist');

    // 2. Photo
    reset();
    docId = oid();
    storedDocs.set(String(docId), { _id: docId, title: 'Photo', analysis });
    llm.analyzeContractPipeline = async () => scannedResult(docId);
    job = makeJob({ mimeType: 'image/jpeg', bytes: jpeg });
    await scanJobService.executeJobPipeline(job.jobId);
    assert.strictEqual(job.status, 'COMPLETED');
    assert.strictEqual(syncCalls.length, 1, 'photo scan must update the checklist exactly once');
    console.log('✓ 2. Photo scan updates the checklist');

    // 3. A checklist problem never fails a finished analysis
    reset(); syncShouldThrow = true;
    docId = oid();
    storedDocs.set(String(docId), { _id: docId, title: 'Sale Agreement', analysis });
    llm.analyzeContractPipeline = async () => scannedResult(docId);
    job = makeJob({ mimeType: 'application/pdf', bytes: unreadablePdf });
    await scanJobService.executeJobPipeline(job.jobId);
    assert.strictEqual(job.status, 'COMPLETED');
    assert.strictEqual(syncCalls.length, 1);
    console.log('✓ 3. A checklist error does not fail the completed scan');

    // 4. Saved document cannot be re-read: use the analysed result instead
    reset();
    docId = oid();                       // not in storedDocs -> findById returns null
    llm.analyzeContractPipeline = async () => scannedResult(docId);
    job = makeJob({ mimeType: 'application/pdf', bytes: unreadablePdf });
    await scanJobService.executeJobPipeline(job.jobId);
    assert.strictEqual(syncCalls.length, 1);
    assert.strictEqual(String(syncCalls[0].doc._id), String(docId));
    assert.strictEqual(syncCalls[0].doc.analysis.length, 2);
    console.log('✓ 4. If the saved document cannot be re-read, the analysed result is used');

    // 5. No document id returned: nothing to link, scan still completes
    reset();
    llm.analyzeContractPipeline = async () => scannedResult(undefined);
    job = makeJob({ mimeType: 'application/pdf', bytes: unreadablePdf });
    await scanJobService.executeJobPipeline(job.jobId);
    assert.strictEqual(job.status, 'COMPLETED');
    assert.strictEqual(syncCalls.length, 0);
    console.log('✓ 5. No document id: no sync, scan still completes');

    // 6. Normal (text) path still syncs exactly once
    reset();
    job = makeJob({
        mimeType: 'text/plain', bytes: null,
        extractedText: 'Clause 1. The developer may forfeit the full amount paid by the buyer on any delay.\n\nClause 2. Notice shall be given in writing.'
    });
    await scanJobService.executeJobPipeline(job.jobId);
    assert.strictEqual(job.status, 'COMPLETED');
    assert.strictEqual(syncCalls.length, 1, 'text path must still sync exactly once (no double sync)');
    assert.strictEqual(String(syncCalls[0].doc._id), String(upsertDocId));
    console.log('✓ 6. Normal text scan still updates the checklist once');

    console.log('\nALL CHECKLIST SYNC TESTS PASSED (6/6)');
}

run().then(() => { fs.rmSync(tempDir, { recursive: true, force: true }); process.exit(0); })
    .catch(err => { console.error('\nTEST FAILED:', err.message); process.exit(1); });