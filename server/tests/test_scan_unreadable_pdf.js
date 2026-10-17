/**
 * Regression tests: a PDF or photo that cannot be read must FAIL the scan with a clear
 * message. It must never be "analyzed" from its raw bytes or from an empty text.
 * No network or database is needed: models and AI calls are replaced with stubs.
 */
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lawbuddy-unreadable-'));
process.env.SCAN_FILES_DIR = tempDir;
process.env.NODE_ENV = 'test';

const llm = require('../src/services/llmService');
const ScanJob = require('../src/models/ScanJob');
const Document = require('../src/models/Document');
const scanJobService = require('../src/services/scanJobService');

// ---- stubs ---------------------------------------------------------------
Document.findOne = async () => null;
let analyzeCalls = 0;
llm.analyzeCanonicalClauses = async () => { analyzeCalls++; throw new Error('STOP_AT_STAGE_3'); };

let jobCounter = 0;
function makeJob({ mimeType, bytes, extractedText = '' }) {
    jobCounter++;
    let storagePath = null;
    if (bytes) {
        storagePath = path.join(tempDir, `file-${jobCounter}.dat`);
        fs.writeFileSync(storagePath, bytes);
    }
    const job = new ScanJob({
        jobId: `job_${jobCounter}`,
        userId: 'user_1',
        fileHash: `hash_${jobCounter}`,
        mimeType,
        storagePath,
        extractedText,
        title: 'Test'
    });
    job.save = async () => job;               // no database
    ScanJob.findOne = async () => job;
    return job;
}

// A buffer that pdf-parse cannot read, but that contains readable-looking bytes.
const notARealPdf = Buffer.from('%PDF-1.4\n\u0000\u0001\u0002 binary garbage that is not a valid pdf \u0003\u0004');

async function expectFailure(label, job, expectedCode) {
    analyzeCalls = 0;
    let thrown = null;
    try {
        await scanJobService.executeJobPipeline(job.jobId);
    } catch (err) {
        thrown = err;
    }
    assert.ok(thrown, `${label}: pipeline should have failed`);
    assert.notStrictEqual(thrown.message, 'STOP_AT_STAGE_3', `${label}: the AI was asked to analyze unreadable content`);
    assert.strictEqual(analyzeCalls, 0, `${label}: AI analysis must not run`);
    assert.strictEqual(thrown.code, expectedCode, `${label}: expected code ${expectedCode}, got ${thrown.code}`);
    assert.strictEqual(job.status, 'FAILED');
    assert.strictEqual((job.extractedText || '').trim(), '', `${label}: no garbage text should be stored`);
    console.log(`✓ ${label}`);
    return thrown;
}

async function run() {
    console.log('--- Unreadable PDF / image tests ---');

    // 1. Scanned-PDF reading fails -> job FAILS, raw bytes are never analyzed
    llm.analyzeContractPipeline = async () => { throw new Error('Vision extraction exploded'); };
    const err1 = await expectFailure('1. PDF cannot be read -> job fails (raw bytes never analyzed)',
        makeJob({ mimeType: 'application/pdf', bytes: notARealPdf }), 'PDF_READ_FAILED');
    assert.ok(/Could not read this scanned PDF/.test(err1.message) && /Vision extraction exploded/.test(err1.message));

    // 2. An AI outage keeps its own, clearer error
    llm.analyzeContractPipeline = async () => { throw new llm.AiAnalysisError('AI legal analysis unavailable: 429', { code: 'AI_ANALYSIS_UNAVAILABLE' }); };
    await expectFailure('2. AI outage while reading a scanned PDF keeps AI_ANALYSIS_UNAVAILABLE',
        makeJob({ mimeType: 'application/pdf', bytes: notARealPdf }), 'AI_ANALYSIS_UNAVAILABLE');

    // 3. Reading "succeeds" but finds no text -> clear message
    llm.analyzeContractPipeline = async () => ({ analysis: [], extractedText: '   ', canonicalClauses: [] });
    const err3 = await expectFailure('3. Scanned PDF with no readable text -> NO_READABLE_TEXT',
        makeJob({ mimeType: 'application/pdf', bytes: notARealPdf }), 'NO_READABLE_TEXT');
    assert.ok(/No readable text/.test(err3.message));

    // 4. Same for a photo
    llm.analyzeContractPipeline = async () => ({ analysis: [], extractedText: '', canonicalClauses: [] });
    await expectFailure('4. Photo with no readable text -> NO_READABLE_TEXT',
        makeJob({ mimeType: 'image/jpeg', bytes: Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]) }), 'NO_READABLE_TEXT');

    // 5. Reading works -> job completes as before
    llm.analyzeContractPipeline = async () => ({
        analysis: [{ clauseId: 'CLAUSE-001', riskLevel: 'CAUTION', category: 'Yellow', text: 't', title: 't' }],
        extractedText: 'Clause 1. The seller shall hand over possession within sixty months.',
        canonicalClauses: [{ clauseId: 'CLAUSE-001', text: 't', title: 't' }],
        documentId: undefined
    });
    const okJob = makeJob({ mimeType: 'application/pdf', bytes: notARealPdf });
    analyzeCalls = 0;
    await scanJobService.executeJobPipeline(okJob.jobId);
    assert.strictEqual(okJob.status, 'COMPLETED');
    assert.strictEqual(analyzeCalls, 0);
    console.log('✓ 5. A scanned PDF that can be read still completes normally');

    // 6. Text pasted by the user (no file) is not affected, even when short
    analyzeCalls = 0;
    const textJob = makeJob({ mimeType: 'text/plain', bytes: null, extractedText: 'Short note' });
    let stopped = null;
    try { await scanJobService.executeJobPipeline(textJob.jobId); } catch (e) { stopped = e; }
    assert.ok(stopped && stopped.message === 'STOP_AT_STAGE_3', 'text jobs must still reach the AI analysis stage');
    assert.strictEqual(analyzeCalls, 1);
    console.log('✓ 6. Typed/pasted text jobs are unaffected (still reach AI analysis)');

    console.log('\nALL UNREADABLE PDF TESTS PASSED (6/6)');
}

run().then(() => { fs.rmSync(tempDir, { recursive: true, force: true }); process.exit(0); })
    .catch(err => { console.error('\nTEST FAILED:', err.message); process.exit(1); });