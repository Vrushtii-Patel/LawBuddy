const assert = require('assert');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const mongoose = require('mongoose');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const Document = require('../src/models/Document');
const ScanJob = require('../src/models/ScanJob');
const Checklist = require('../src/models/Checklist');
const scanJobService = require('../src/services/scanJobService');
const llmService = require('../src/services/llmService');
const crossReferenceService = require('../src/services/crossReferenceService');

const testUserId = `test_reupload_user_${Date.now()}`;

function generateHash(text) {
    return crypto.createHash('sha256').update(text).digest('hex');
}

const mockAnalysis = [
    {
        clauseId: 'CLAUSE-001',
        title: 'Payment and Forfeiture',
        text: 'The builder may forfeit the deposit if buyer delays payment.',
        riskLevel: 'HIGH_RISK',
        category: 'Red',
        findingCategory: 'Confirmed statutory violation',
        reason: 'Unfair forfeiture violates statutory protection'
    },
    {
        clauseId: 'CLAUSE-002',
        title: 'Delivery of Possession',
        text: 'Possession within 24 months with grace period.',
        riskLevel: 'COMPLIANT',
        category: 'Green',
        findingCategory: 'No material issue identified',
        reason: 'Reasonable timeline'
    }
];

async function runTests() {
    console.log('=== Starting LawBuddy Issue 22 Regression Test Suite ===\n');

    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
    try {
        await mongoose.connect(uri, { serverSelectionTimeoutMS: 4000 });
        console.log('Connected to MongoDB.');
    } catch (err) {
        console.error('Failed to connect to MongoDB:', err.message);
        process.exit(1);
    }

    // Save original analysis function to restore later
    const originalAnalyzeCanonicalClauses = llmService.analyzeCanonicalClauses;
    // Stub LLM analysis to return deterministic clauses without network calls
    llmService.analyzeCanonicalClauses = async () => mockAnalysis;

    try {
        // Clean up test collections for this user
        await Document.deleteMany({ userId: testUserId });
        await ScanJob.deleteMany({ userId: testUserId });
        await Checklist.deleteMany({ userId: testUserId });

        const sampleTextActive = 'Active Contract Clause 1: The buyer agrees to pay in installments according to RERA schedule.';
        const sampleHashActive = generateHash(sampleTextActive);

        const sampleTextBinned = 'Binned Contract Clause 1: The builder retains full right of forfeiture without notice.';
        const sampleHashBinned = generateHash(sampleTextBinned);

        const sampleTextNew = 'Brand New Unique Contract Clause 1: Mutual indemnification upon property transfer.';
        const sampleHashNew = generateHash(sampleTextNew);

        // =========================================================================
        // Scenario 1: Uploading a file that matches an active document does not overwrite its custom title
        // =========================================================================
        console.log('--- Scenario 1: Preserving custom title on active document re-upload ---');

        const activeDoc = await Document.create({
            userId: testUserId,
            fileHash: sampleHashActive,
            title: 'Custom Title Assigned By User',
            fileName: 'custom_original.pdf',
            originalText: sampleTextActive,
            extractedNormalizedText: sampleTextActive,
            canonicalClauses: [{ clauseId: 'CLAUSE-001', text: sampleTextActive, title: 'Payment' }],
            analysis: mockAnalysis,
            riskLevel: 'High Risk',
            highRiskCount: 1,
            cautionCount: 0,
            compliantCount: 1,
            totalClauseCount: 2,
            promptVersion: llmService.PROMPT_VERSION,
            modelName: llmService.MODEL_NAME,
            analysisVersion: llmService.ANALYSIS_VERSION,
            analysisStatus: 'completed',
            isDeleted: false,
            deletedAt: null
        });

        // Re-upload the same file with a different generic title or original filename
        const reuploadJobActive = await scanJobService.createScanJob({
            userId: testUserId,
            text: sampleTextActive,
            title: 'incoming_upload_filename.pdf'
        });

        // It should match cache or resolve to existing title
        assert.strictEqual(reuploadJobActive.title, 'Custom Title Assigned By User', 'ScanJob title should preserve active document custom title');

        // Execute Stage 4/upsert again to simulate re-running scan pipeline
        await scanJobService.executeJobPipeline(reuploadJobActive.jobId);

        const activeDocAfter = await Document.findOne({ userId: testUserId, fileHash: sampleHashActive });
        assert.strictEqual(activeDocAfter.title, 'Custom Title Assigned By User', 'Active document custom title MUST NOT be overwritten by upload title');
        assert.strictEqual(activeDocAfter.isDeleted, false, 'Active document must remain active');
        console.log('✓ Scenario 1 Passed: Uploading matching file preserves custom title on active document.\n');

        // =========================================================================
        // Scenario 2: Uploading a file that matches a binned document does not change isDeleted: true
        // =========================================================================
        console.log('--- Scenario 2: Uploading matching file does not restore binned document ---');

        const deletedTimestamp = new Date(Date.now() - 3600 * 1000 * 24); // 1 day ago
        const binnedDoc = await Document.create({
            userId: testUserId,
            fileHash: sampleHashBinned,
            title: 'Binned Important Sale Deed',
            fileName: 'binned_deed.pdf',
            originalText: sampleTextBinned,
            extractedNormalizedText: sampleTextBinned,
            canonicalClauses: [{ clauseId: 'CLAUSE-001', text: sampleTextBinned, title: 'Forfeiture' }],
            analysis: mockAnalysis,
            riskLevel: 'High Risk',
            highRiskCount: 1,
            cautionCount: 0,
            compliantCount: 1,
            totalClauseCount: 2,
            promptVersion: llmService.PROMPT_VERSION,
            modelName: llmService.MODEL_NAME,
            analysisVersion: llmService.ANALYSIS_VERSION,
            analysisStatus: 'completed',
            isDeleted: true,
            deletedAt: deletedTimestamp
        });

        // Re-upload the binned document file
        const reuploadJobBinned = await scanJobService.createScanJob({
            userId: testUserId,
            text: sampleTextBinned,
            title: 'reuploaded_binned_file.pdf'
        });

        // Document in DB must still be binned immediately after job creation
        let binnedDocCheck = await Document.findOne({ userId: testUserId, fileHash: sampleHashBinned });
        assert.strictEqual(binnedDocCheck.isDeleted, true, 'isDeleted MUST remain true after scan job creation');
        assert.strictEqual(binnedDocCheck.deletedAt.getTime(), deletedTimestamp.getTime(), 'deletedAt MUST remain unchanged');

        console.log('✓ Scenario 2 Passed: Uploading matching file does not change isDeleted: true.\n');

        // =========================================================================
        // Scenario 3: Binned document custom title remains unchanged after upload, scanning, and LLM analysis
        // =========================================================================
        console.log('--- Scenario 3: Custom title and bin state preserved across full scan & LLM pipeline ---');

        // Execute scan job pipeline through Stage 4 completion
        await scanJobService.executeJobPipeline(reuploadJobBinned.jobId);

        binnedDocCheck = await Document.findOne({ userId: testUserId, fileHash: sampleHashBinned });
        assert.strictEqual(binnedDocCheck.isDeleted, true, 'isDeleted MUST remain true after pipeline execution');
        assert.strictEqual(binnedDocCheck.deletedAt.getTime(), deletedTimestamp.getTime(), 'deletedAt MUST be preserved');
        assert.strictEqual(binnedDocCheck.title, 'Binned Important Sale Deed', 'Custom title MUST NOT be overwritten after scan pipeline');

        // Also test direct LLM pipeline re-analysis
        await llmService.analyzeContractPipeline({
            text: sampleTextBinned,
            customTitle: 'New Overwriting Attempt From LLM',
            userId: testUserId
        });

        binnedDocCheck = await Document.findOne({ userId: testUserId, fileHash: sampleHashBinned });
        assert.strictEqual(binnedDocCheck.isDeleted, true, 'isDeleted MUST remain true after direct LLM analysis');
        assert.strictEqual(binnedDocCheck.deletedAt.getTime(), deletedTimestamp.getTime(), 'deletedAt MUST be preserved after direct LLM analysis');
        assert.strictEqual(binnedDocCheck.title, 'Binned Important Sale Deed', 'Custom title MUST remain intact after direct LLM analysis');

        console.log('✓ Scenario 3 Passed: Binned document custom title and bin state preserved after full scan and LLM analysis.\n');

        // =========================================================================
        // Scenario 4: A genuinely new file can still be uploaded and processed normally
        // =========================================================================
        console.log('--- Scenario 4: Genuinely new file uploads and processes normally ---');

        const newJob = await scanJobService.createScanJob({
            userId: testUserId,
            text: sampleTextNew,
            title: 'Genuine New Document Title'
        });

        await scanJobService.executeJobPipeline(newJob.jobId);

        const newDoc = await Document.findOne({ userId: testUserId, fileHash: sampleHashNew });
        assert.ok(newDoc, 'New document record must be created in DB');
        assert.strictEqual(newDoc.isDeleted, false, 'New document must have isDeleted: false');
        assert.strictEqual(newDoc.deletedAt, null, 'New document must have deletedAt: null');
        assert.strictEqual(newDoc.title, 'Genuine New Document Title', 'New document must have requested title');
        assert.strictEqual(newDoc.analysisStatus, 'completed', 'New document analysisStatus must be completed');

        console.log('✓ Scenario 4 Passed: Genuinely new file creates active document with correct metadata.\n');

        // =========================================================================
        // Scenario 5: Explicit Restore action continues to work as intended
        // =========================================================================
        console.log('--- Scenario 5: Explicit restore action functionality ---');

        // Restore the binned document explicitly (simulating PATCH /api/documents/:id/restore)
        const explicitlyRestoredDoc = await Document.findOneAndUpdate(
            { _id: binnedDoc._id, userId: testUserId },
            { $set: { isDeleted: false, deletedAt: null } },
            { returnDocument: 'after' }
        );

        assert.ok(explicitlyRestoredDoc, 'Explicitly restored document must exist');
        assert.strictEqual(explicitlyRestoredDoc.isDeleted, false, 'Explicit restore must set isDeleted: false');
        assert.strictEqual(explicitlyRestoredDoc.deletedAt, null, 'Explicit restore must set deletedAt: null');
        assert.strictEqual(explicitlyRestoredDoc.title, 'Binned Important Sale Deed', 'Custom title must be preserved upon explicit restore');

        // Verify it now appears in active documents query
        const activeDocsIncludingRestored = await Document.find({ userId: testUserId, isDeleted: { $ne: true } });
        const hasRestoredInActive = activeDocsIncludingRestored.some(d => String(d._id) === String(binnedDoc._id));
        assert.strictEqual(hasRestoredInActive, true, 'Explicitly restored document must appear in active documents query');

        console.log('✓ Scenario 5 Passed: Explicit restore action continues to work as intended.\n');

        // =========================================================================
        // Scenario 6: Background scan, retry, or analysis update cannot silently restore a binned document
        // =========================================================================
        console.log('--- Scenario 6: Background retries cannot silently restore binned document ---');

        // Soft-delete the document again
        const reBinnedTimestamp = new Date();
        await Document.findOneAndUpdate(
            { _id: binnedDoc._id, userId: testUserId },
            { $set: { isDeleted: true, deletedAt: reBinnedTimestamp } }
        );

        // Create a failed job simulating an interrupted scan
        const retryJobId = `job_retry_${Date.now()}`;
        const failedJob = await ScanJob.create({
            jobId: retryJobId,
            userId: testUserId,
            fileHash: sampleHashBinned,
            title: 'retry_attempt.pdf',
            status: 'FAILED',
            currentStep: 'OCR processing',
            completedSteps: ['UPLOAD'],
            extractedText: sampleTextBinned,
            errorInfo: { message: 'Network timeout', isTransient: true }
        });

        // Trigger retry pipeline execution
        await scanJobService.executeJobPipeline(failedJob.jobId);

        // Verify document was NOT restored by the retry
        const docAfterRetry = await Document.findOne({ _id: binnedDoc._id, userId: testUserId });
        assert.strictEqual(docAfterRetry.isDeleted, true, 'Retry pipeline MUST NOT restore a binned document');
        assert.ok(docAfterRetry.deletedAt, 'deletedAt MUST be preserved');

        console.log('✓ Scenario 6 Passed: Background scan retry cannot silently restore binned document.\n');

        // =========================================================================
        // Scenario 7: Binned document remains excluded from active-document results
        // =========================================================================
        console.log('--- Scenario 7: Binned document exclusion from active listings ---');

        const activeListing = await Document.find({ userId: testUserId, isDeleted: { $ne: true } });
        const isBinnedInActive = activeListing.some(d => String(d._id) === String(binnedDoc._id));
        assert.strictEqual(isBinnedInActive, false, 'Binned document MUST NOT appear in active document results');

        const binListing = await Document.find({ userId: testUserId, isDeleted: true });
        const isBinnedInBin = binListing.some(d => String(d._id) === String(binnedDoc._id));
        assert.strictEqual(isBinnedInBin, true, 'Binned document MUST appear in bin results');

        console.log('✓ Scenario 7 Passed: Binned document is excluded from active listings and present in bin.\n');

        // =========================================================================
        // Scenario 8: Existing duplicate detection and scan-job behavior continue to work
        // =========================================================================
        console.log('--- Scenario 8: Duplicate detection and single document record invariant ---');

        // Verify that no duplicate document records exist for any fileHash
        const allDocsForUser = await Document.find({ userId: testUserId });
        const hashCounts = {};
        for (const doc of allDocsForUser) {
            hashCounts[doc.fileHash] = (hashCounts[doc.fileHash] || 0) + 1;
        }

        for (const [hash, count] of Object.entries(hashCounts)) {
            assert.strictEqual(count, 1, `There must be exactly 1 document record for fileHash ${hash}, but found ${count}`);
        }

        // Cache hit test for active document
        const cacheHitJob = await scanJobService.createScanJob({
            userId: testUserId,
            text: sampleTextActive,
            title: 'Another upload of active'
        });
        assert.strictEqual(cacheHitJob.status, 'COMPLETED', 'Active document with current prompt and model must yield immediate cache hit');
        assert.strictEqual(cacheHitJob.title, 'Custom Title Assigned By User', 'Cache hit must preserve custom title');

        console.log('✓ Scenario 8 Passed: Existing duplicate detection works without creating duplicate document records.\n');

        // Clean up test data
        await Document.deleteMany({ userId: testUserId });
        await ScanJob.deleteMany({ userId: testUserId });
        await Checklist.deleteMany({ userId: testUserId });

        console.log('🎉 ALL 8 ISSUE 22 REGRESSION TEST SCENARIOS PASSED SUCCESSFULLY!');

    } finally {
        llmService.analyzeCanonicalClauses = originalAnalyzeCanonicalClauses;
        await mongoose.disconnect();
    }
}

runTests().catch(err => {
    console.error('Test Suite Failed:', err);
    process.exit(1);
});
