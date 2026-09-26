const assert = require('assert');
const path = require('path');
const fs = require('fs');
const mongoose = require('mongoose');
const Document = require('../src/models/Document');
const ScanJob = require('../src/models/ScanJob');
const documentCleanupService = require('../src/services/documentCleanupService');
const scanJobService = require('../src/services/scanJobService');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const testUserId = `test_bin_user_${Date.now()}`;
const testFileHash = `bin_hash_${Date.now()}`;

async function runBinTests() {
    console.log('=== Starting LawBuddy Document Bin & Soft-Delete Test Suite ===\n');

    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
    if (mongoose.connection.readyState !== 1) {
        await mongoose.connect(uri);
    }

    try {
        // Clean up any test state
        await Document.deleteMany({ userId: testUserId });
        await ScanJob.deleteMany({ userId: testUserId });

        // Ensure disk file exists for testing
        const uploadsDir = path.join(__dirname, '../uploads/scan_files');
        if (!fs.existsSync(uploadsDir)) {
            fs.mkdirSync(uploadsDir, { recursive: true });
        }
        const testFilePath = path.join(uploadsDir, `${testFileHash}.dat`);
        fs.writeFileSync(testFilePath, Buffer.from('Mock PDF Content for Bin Test'));

        // Create sample document
        const doc = await Document.create({
            userId: testUserId,
            fileHash: testFileHash,
            title: 'Sample Sale Deed for Bin Test',
            originalText: 'Agreement between buyer and seller...',
            sourceType: 'PDF Document',
            mimeType: 'application/pdf',
            analysisStatus: 'completed',
            riskLevel: 'High Risk',
            highRiskCount: 1,
            analysis: [{ clauseId: '1', title: 'Penalty', text: 'Clause text', riskLevel: 'HIGH_RISK' }]
        });

        // Create associated ScanJob
        const job = await ScanJob.create({
            jobId: `job_bin_${Date.now()}`,
            userId: testUserId,
            fileHash: testFileHash,
            documentId: doc._id,
            status: 'COMPLETED',
            title: doc.title,
            storagePath: `uploads/scan_files/${testFileHash}.dat`
        });

        console.log('✓ Initial setup: Document, ScanJob, and disk file created.');

        // Test 1: Active listing query filters out isDeleted: true
        const initialActiveDocs = await Document.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(initialActiveDocs.length, 1, 'Initial active query must return 1 document');
        console.log('✓ Test 1: Active query initially returns the document.');

        // Test 2: Soft-delete sets isDeleted: true and deletedAt, while leaving file & ScanJob intact
        doc.isDeleted = true;
        doc.deletedAt = new Date();
        await doc.save();

        const activeDocsAfterSoftDelete = await Document.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(activeDocsAfterSoftDelete.length, 0, 'Active query must return 0 documents after soft delete');

        const binnedDocs = await Document.find({ userId: testUserId, isDeleted: true });
        assert.strictEqual(binnedDocs.length, 1, 'Bin query must return the soft-deleted document');
        assert.strictEqual(fs.existsSync(testFilePath), true, 'File on disk MUST NOT be deleted during soft delete');
        const existingJob = await ScanJob.findOne({ jobId: job.jobId });
        assert.ok(existingJob, 'ScanJob MUST NOT be deleted during soft delete');
        console.log('✓ Test 2: Soft-delete moves document to bin without touching file on disk or ScanJob.');

        // Test 3: Restore document resets isDeleted and deletedAt
        doc.isDeleted = false;
        doc.deletedAt = null;
        await doc.save();

        const activeDocsAfterRestore = await Document.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(activeDocsAfterRestore.length, 1, 'Active query must return 1 document after restoration');
        const binnedDocsAfterRestore = await Document.find({ userId: testUserId, isDeleted: true });
        assert.strictEqual(binnedDocsAfterRestore.length, 0, 'Bin query must return 0 documents after restoration');
        console.log('✓ Test 3: Document restore successfully reactivates document into library.');

        // Test 4: Reject permanent delete on active (non-binned) document
        let rejected = false;
        try {
            await documentCleanupService.permanentlyDeleteDocument(doc._id, testUserId);
        } catch (err) {
            rejected = true;
            assert.ok(err.message.includes('must be in the bin'), 'Should reject permanent deletion of non-binned doc');
        }
        assert.strictEqual(rejected, true, 'Permanent delete must be rejected on active document');
        console.log('✓ Test 4: Permanent deletion correctly rejected for non-binned active document.');

        // Test 5: Permanent delete on soft-deleted document cleans up file, ScanJob, and Document row
        doc.isDeleted = true;
        doc.deletedAt = new Date();
        await doc.save();

        await documentCleanupService.permanentlyDeleteDocument(doc._id, testUserId);

        const docAfterPermDelete = await Document.findById(doc._id);
        assert.strictEqual(docAfterPermDelete, null, 'Document row must be deleted from MongoDB');
        const jobAfterPermDelete = await ScanJob.findOne({ jobId: job.jobId });
        assert.strictEqual(jobAfterPermDelete, null, 'Associated ScanJob must be deleted from MongoDB');
        assert.strictEqual(fs.existsSync(testFilePath), false, 'File on disk must be removed from disk');
        console.log('✓ Test 5: Permanent deletion cleanly deletes file on disk, ScanJob, and Document row.');

        // Test 6: Auto-purge documents older than 30 days
        const expiredHash = `expired_hash_${Date.now()}`;
        const expiredFilePath = path.join(uploadsDir, `${expiredHash}.dat`);
        fs.writeFileSync(expiredFilePath, Buffer.from('Expired file'));

        const thirtyOneDaysAgo = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
        const expiredDoc = await Document.create({
            userId: testUserId,
            fileHash: expiredHash,
            title: 'Expired Old Document',
            originalText: 'Old agreement...',
            analysisStatus: 'completed',
            isDeleted: true,
            deletedAt: thirtyOneDaysAgo
        });

        const recentHash = `recent_hash_${Date.now()}`;
        const recentFilePath = path.join(uploadsDir, `${recentHash}.dat`);
        fs.writeFileSync(recentFilePath, Buffer.from('Recent file'));

        const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000);
        const recentBinnedDoc = await Document.create({
            userId: testUserId,
            fileHash: recentHash,
            title: 'Recent Binned Document',
            originalText: 'Recent agreement...',
            analysisStatus: 'completed',
            isDeleted: true,
            deletedAt: twoDaysAgo
        });

        const purgedCount = await documentCleanupService.purgeExpiredBinnedDocuments(testUserId, 30);
        assert.strictEqual(purgedCount, 1, 'Auto-purge must only purge documents older than 30 days');

        const remainingBinned = await Document.find({ userId: testUserId, isDeleted: true });
        assert.strictEqual(remainingBinned.length, 1, 'Recent binned document must remain in bin');
        assert.strictEqual(remainingBinned[0]._id.toString(), recentBinnedDoc._id.toString());
        assert.strictEqual(fs.existsSync(expiredFilePath), false, 'Expired file must be deleted from disk');
        assert.strictEqual(fs.existsSync(recentFilePath), true, 'Recent binned file must be preserved');
        console.log('✓ Test 6: 30-day auto-purge cleanly purges expired items while preserving recent binned items.');

        // Clean up remaining test records
        await documentCleanupService.permanentlyDeleteDocument(recentBinnedDoc._id, testUserId);

        console.log('\n🎉 ALL 6 DOCUMENT BIN & AUTO-PURGE TESTS PASSED SUCCESSFULLY!');
    } finally {
        await Document.deleteMany({ userId: testUserId });
        await ScanJob.deleteMany({ userId: testUserId });
    }
}

if (require.main === module) {
    runBinTests()
        .then(() => process.exit(0))
        .catch(err => {
            console.error('Test failure:', err);
            process.exit(1);
        });
}

module.exports = { runBinTests };
