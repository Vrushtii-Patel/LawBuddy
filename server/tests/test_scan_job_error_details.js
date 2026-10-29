const assert = require('assert');
const { getUserFriendlyErrorMessage } = require('../src/services/scanJobService');
const ScanJob = require('../src/models/ScanJob');
const scanJobService = require('../src/services/scanJobService');
const llmService = require('../src/services/llmService');

async function runTests() {
    console.log('=== Starting Scan Job Error Details & Stage Preservation Test Suite ===\n');

    // --- Section 1: getUserFriendlyErrorMessage unit tests ---
    console.log('--- Section 1: Error Message Sanitization ---');

    // 1.1 Technical stack traces and internal SDK errors are masked
    const sdkError = new Error('[GoogleGenerativeAI Error]: Error fetching from https://generativelanguage.googleapis.com: 500 Internal Error at /app/node_modules/foo.js:12');
    const sdkFriendly = getUserFriendlyErrorMessage(sdkError);
    assert.strictEqual(sdkFriendly.includes('GoogleGenerativeAI'), false, 'SDK name should not leak');
    assert.strictEqual(sdkFriendly.includes('https://'), false, 'API URLs should not leak');
    assert.strictEqual(sdkFriendly.includes('node_modules'), false, 'Stack traces should not leak');
    assert.strictEqual(sdkFriendly, 'Document analysis could not be completed. Please retry.');
    console.log('✓ Test 1.1 Passed: Technical SDK and stack trace errors are masked with friendly messages.');

    // 1.2 Rate limits and quota errors
    const rateLimitError = new Error('ResourceExhausted: 429 Quota exceeded');
    rateLimitError.status = 429;
    const rateLimitFriendly = getUserFriendlyErrorMessage(rateLimitError);
    assert.match(rateLimitFriendly, /busy|retry/i);
    assert.strictEqual(rateLimitFriendly.includes('ResourceExhausted'), false);
    console.log('✓ Test 1.2 Passed: 429 Rate limit errors mapped to friendly advice.');

    // 1.3 Service outages / 503
    const outageError = new Error('503 Service Unavailable');
    outageError.status = 503;
    const outageFriendly = getUserFriendlyErrorMessage(outageError);
    assert.match(outageFriendly, /temporarily unavailable/i);
    console.log('✓ Test 1.3 Passed: 503 Outage errors mapped to friendly unavailable message.');

    // 1.4 PDF read failure
    const pdfErr = new Error('Could not read this scanned PDF: Vision extraction exploded at line 42');
    pdfErr.code = 'PDF_READ_FAILED';
    const pdfFriendly = getUserFriendlyErrorMessage(pdfErr);
    assert.strictEqual(pdfFriendly.includes('exploded'), false);
    assert.match(pdfFriendly, /clear and undamaged/i);
    console.log('✓ Test 1.4 Passed: PDF read failure does not leak raw internal explosion text.');

    // 1.5 Missing storage file
    const missingFileErr = new Error('Uploaded source file is missing from storage (uploads/scan_files/123.dat)');
    const missingFileFriendly = getUserFriendlyErrorMessage(missingFileErr);
    assert.strictEqual(missingFileFriendly, 'Uploaded source file is missing from storage. Please upload the document again.');
    console.log('✓ Test 1.5 Passed: Storage missing file error mapped cleanly.');

    // --- Section 2: Pipeline Stage Preservation and errorInfo.stage check ---
    console.log('\n--- Section 2: Stage Preservation on Pipeline Failure ---');

    // Create a mock ScanJob in memory
    const mockJob = new ScanJob({
        jobId: `test_stage_${Date.now()}`,
        userId: 'test_user_1',
        fileHash: 'test_hash_1',
        status: 'AI_ANALYSIS',
        currentStep: 'Analyzing legal clauses...',
        completedSteps: ['UPLOAD', 'TEXT_EXTRACTION'],
        extractedText: 'Clause 1: Sample legal contract clause for testing.',
        canonicalClauses: [{ clauseId: 'CLAUSE-1', text: 'Sample text' }]
    });

    // Mock ScanJob.findOne and Document.findOne to return immediately without DB connection
    const Document = require('../src/models/Document');
    Document.findOne = async () => null;
    ScanJob.findOne = async () => mockJob;
    mockJob.save = async () => mockJob;

    // Force stage 3 (analyzeCanonicalClauses) to fail with a raw technical error
    const originalAnalyze = llmService.analyzeCanonicalClauses;
    llmService.analyzeCanonicalClauses = async () => {
        throw new Error('TypeError: Cannot read properties of undefined (reading "findings") at Object.eval (/server/llmService.js:89:12)');
    };

    let thrown = null;
    try {
        await scanJobService.executeJobPipeline(mockJob.jobId);
    } catch (err) {
        thrown = err;
    }

    assert.ok(thrown, 'Pipeline should have thrown the error');
    assert.strictEqual(mockJob.status, 'FAILED', 'Job status must be FAILED');

    // CRITICAL: errorInfo.stage must be the original stage BEFORE replacement
    assert.strictEqual(
        mockJob.errorInfo.stage,
        'Analyzing legal clauses...',
        'errorInfo.stage must be the original stage name, NOT "Failed at ...: raw message"'
    );

    // CRITICAL: errorInfo.message must be friendly, not the raw TypeError
    assert.strictEqual(
        mockJob.errorInfo.message.includes('TypeError'),
        false,
        'errorInfo.message must not contain raw TypeError'
    );
    assert.strictEqual(
        mockJob.errorInfo.message.includes('/server/llmService.js'),
        false,
        'errorInfo.message must not contain file paths or line numbers'
    );

    // currentStep should be "Failed at Analyzing legal clauses..."
    assert.strictEqual(
        mockJob.currentStep,
        'Failed at Analyzing legal clauses...',
        'currentStep should record Failed at <stage>'
    );

    console.log('✓ Test 2.1 Passed: errorInfo.stage correctly preserves original stage name.');
    console.log('✓ Test 2.2 Passed: errorInfo.message is sanitized and friendly.');
    console.log('✓ Test 2.3 Passed: currentStep is cleanly formatted without raw technical trace.');

    // Restore original method
    llmService.analyzeCanonicalClauses = originalAnalyze;

    console.log('\n🎉 ALL SCAN JOB ERROR DETAILS TESTS PASSED (100%)!\n');
}

runTests().catch(err => {
    console.error('Test suite failed:', err);
    process.exit(1);
});
