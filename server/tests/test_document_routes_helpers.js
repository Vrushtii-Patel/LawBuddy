const assert = require('assert');

// Test the helper logic extracted for documentRoutes
function inferScanJobParams(req, { requireFile = false } = {}) {
    const file = req.file;
    const { text, title: customTitle, sourceType, base64Data, mimeType } = req.body || {};

    if (requireFile ? (!file && !base64Data) : (!text && !file && !base64Data)) {
        return { error: requireFile ? 'Document file is required.' : 'Document file or text description is required.' };
    }

    const computedMimeType = file 
        ? file.mimetype 
        : (mimeType || (base64Data ? 'application/pdf' : 'text/plain'));
    
    const isPdf = (computedMimeType || '').toLowerCase().includes('pdf');
    const defaultSourceType = file 
        ? (isPdf ? 'PDF Document' : 'Photo Scan') 
        : (base64Data ? 'PDF Document' : 'Text Description');

    return {
        params: {
            userId: req.user.userId,
            text,
            fileBuffer: file ? file.buffer : null,
            fileName: file ? file.originalname : (customTitle || ''),
            base64Data: base64Data || null,
            mimeType: computedMimeType,
            title: customTitle || (file ? file.originalname : ''),
            sourceType: sourceType || defaultSourceType
        }
    };
}

function formatScanResult(completedJob, doc, base64Data = null) {
    const analysis = completedJob.analysis || [];
    return {
        jobId: completedJob.jobId,
        cacheHit: completedJob.currentStep ? completedJob.currentStep.includes('cache') : false,
        fileHash: completedJob.fileHash,
        extractedText: completedJob.extractedText,
        analysis: analysis,
        canonicalClauses: completedJob.canonicalClauses,
        highRiskCount: doc ? doc.highRiskCount : analysis.filter(c => c.riskLevel === 'HIGH_RISK').length,
        cautionCount: doc ? doc.cautionCount : analysis.filter(c => c.riskLevel === 'CAUTION').length,
        compliantCount: doc ? doc.compliantCount : analysis.filter(c => c.riskLevel === 'COMPLIANT').length,
        totalClauseCount: analysis.length,
        riskLevel: doc ? doc.riskLevel : 'Low Risk',
        sourceType: completedJob.sourceType,
        fileData: base64Data,
        mimeType: completedJob.mimeType,
        document: doc,
        documentId: completedJob.documentId
    };
}

function runTests() {
    console.log('Testing documentRoutes helpers...');

    // Test 1: Validation error when empty
    const res1 = inferScanJobParams({ user: { userId: 'u1' }, body: {} });
    assert.strictEqual(res1.error, 'Document file or text description is required.');

    // Test 2: Text description inference
    const res2 = inferScanJobParams({ user: { userId: 'u1' }, body: { text: 'Some legal contract text' } });
    assert.strictEqual(res2.error, undefined);
    assert.strictEqual(res2.params.mimeType, 'text/plain');
    assert.strictEqual(res2.params.sourceType, 'Text Description');

    // Test 3: PDF File upload inference
    const res3 = inferScanJobParams({
        user: { userId: 'u1' },
        file: { originalname: 'contract.pdf', mimetype: 'application/pdf', buffer: Buffer.from('test') },
        body: {}
    });
    assert.strictEqual(res3.params.mimeType, 'application/pdf');
    assert.strictEqual(res3.params.sourceType, 'PDF Document');
    assert.strictEqual(res3.params.fileName, 'contract.pdf');

    // Test 4: Image scan upload inference
    const res4 = inferScanJobParams({
        user: { userId: 'u1' },
        file: { originalname: 'scan.png', mimetype: 'image/png', buffer: Buffer.from('test') },
        body: {}
    });
    assert.strictEqual(res4.params.mimeType, 'image/png');
    assert.strictEqual(res4.params.sourceType, 'Photo Scan');

    // Test 5: Response shaping
    const mockJob = {
        jobId: 'job_123',
        currentStep: 'Fetched from cache',
        fileHash: 'hash_abc',
        extractedText: 'sample text',
        analysis: [
            { clauseId: '1', riskLevel: 'HIGH_RISK' },
            { clauseId: '2', riskLevel: 'CAUTION' },
            { clauseId: '3', riskLevel: 'COMPLIANT' }
        ],
        canonicalClauses: [],
        sourceType: 'PDF Document',
        mimeType: 'application/pdf',
        documentId: 'doc_123'
    };
    const formatted = formatScanResult(mockJob, null, 'base64sample');
    assert.strictEqual(formatted.jobId, 'job_123');
    assert.strictEqual(formatted.cacheHit, true);
    assert.strictEqual(formatted.highRiskCount, 1);
    assert.strictEqual(formatted.cautionCount, 1);
    assert.strictEqual(formatted.compliantCount, 1);
    assert.strictEqual(formatted.totalClauseCount, 3);
    assert.strictEqual(formatted.fileData, 'base64sample');

    console.log('✓ All documentRoutes helper tests passed successfully!');
}

runTests();
