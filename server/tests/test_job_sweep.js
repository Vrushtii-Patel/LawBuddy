const assert = require('assert');
const path = require('path');
const fs = require('fs');
const mongoose = require('mongoose');
const Document = require('../src/models/Document');
const ScanJob = require('../src/models/ScanJob');
const DocumentComparison = require('../src/models/DocumentComparison');
const cleanup = require('../src/services/documentCleanupService');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const stamp = Date.now();
const userA = `sweep_user_a_${stamp}`;
const userB = `sweep_user_b_${stamp}`;
const DAY = 24 * 60 * 60 * 1000;
const OLD = new Date(Date.now() - 10 * DAY); // older than the 7-day default
const uploadsDir = cleanup.UPLOADS_DIR;

function filePath(hash) { return path.join(uploadsDir, `${hash}.dat`); }
function makeFile(hash) {
    if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
    fs.writeFileSync(filePath(hash), Buffer.from('sweep test'));
}

// ScanJob/DocumentComparison pre-save hooks overwrite updatedAt, so age rows via the raw collection.
async function age(Model, filter, date) {
    await Model.collection.updateMany(filter, { $set: { updatedAt: date } });
}

async function run() {
    console.log('=== LawBuddy Abandoned Job Sweep Test Suite ===\n');
    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
    if (mongoose.connection.readyState !== 1) await mongoose.connect(uri);

    const h = {
        failed: `sweep_failed_${stamp}`,
        shared: `sweep_shared_${stamp}`,
        docBacked: `sweep_docbacked_${stamp}`,
        orphanDone: `sweep_orphandone_${stamp}`,
        recent: `sweep_recent_${stamp}`,
    };
    const cleanAll = async () => {
        await ScanJob.deleteMany({ userId: { $in: [userA, userB] } });
        await Document.deleteMany({ userId: { $in: [userA, userB] } });
        await DocumentComparison.deleteMany({ userId: { $in: [userA, userB] } });
        Object.values(h).forEach(x => { if (fs.existsSync(filePath(x))) fs.unlinkSync(filePath(x)); });
    };

    try {
        await cleanAll();
        Object.values(h).forEach(makeFile);

        // Old FAILED job, file referenced by nobody else -> job and file removed
        await ScanJob.create({ jobId: `j_failed_${stamp}`, userId: userA, fileHash: h.failed, status: 'FAILED', storagePath: `uploads/scan_files/${h.failed}.dat` });

        // Old FAILED job whose hash is shared with another user's active job -> job removed, file kept
        await ScanJob.create({ jobId: `j_shared_old_${stamp}`, userId: userA, fileHash: h.shared, status: 'FAILED' });
        await ScanJob.create({ jobId: `j_shared_new_${stamp}`, userId: userB, fileHash: h.shared, status: 'AI_ANALYSIS' });

        // Old FAILED job whose hash belongs to a saved Document -> job removed, file kept
        await Document.create({ userId: userA, fileHash: h.docBacked, title: 'Kept doc', originalText: 'x', sourceType: 'PDF Document', mimeType: 'application/pdf', analysisStatus: 'completed' });
        await ScanJob.create({ jobId: `j_docbacked_${stamp}`, userId: userA, fileHash: h.docBacked, status: 'FAILED' });

        // Old COMPLETED job pointing at a Document that no longer exists -> removed with its file
        await ScanJob.create({ jobId: `j_orphandone_${stamp}`, userId: userA, fileHash: h.orphanDone, status: 'COMPLETED', documentId: new mongoose.Types.ObjectId() });

        // Recent FAILED job -> must survive
        await ScanJob.create({ jobId: `j_recent_${stamp}`, userId: userA, fileHash: h.recent, status: 'FAILED' });

        // Comparisons: old failed removed; old completed and recent failed kept
        const cmp = (id, status, n) => DocumentComparison.create({
            comparisonId: `c_${id}_${stamp}`, userId: userA, fileHashA: `a${n}_${stamp}`, titleA: 'A', fileHashB: `b${n}_${stamp}`, titleB: 'B',
            comparisonHash: `ch_${id}_${stamp}`, status
        });
        await cmp('old_failed', 'FAILED', 1);
        await cmp('old_done', 'COMPLETED', 2);
        await cmp('recent_failed', 'FAILED', 3);

        // Age everything except the "recent" rows
        await age(ScanJob, { userId: { $in: [userA, userB] }, jobId: { $nin: [`j_recent_${stamp}`, `j_shared_new_${stamp}`] } }, OLD);
        await age(DocumentComparison, { userId: userA, comparisonId: { $in: [`c_old_failed_${stamp}`, `c_old_done_${stamp}`] } }, OLD);

        const res = await cleanup.sweepAbandonedJobs(7);
        console.log('sweep result:', res);

        const jobExists = id => ScanJob.exists({ jobId: `${id}_${stamp}` });
        assert.ok(!(await jobExists('j_failed')), 'old failed job removed');
        assert.ok(!fs.existsSync(filePath(h.failed)), 'its unreferenced file removed');
        console.log('✓ Old failed job and its unreferenced file are removed.');

        assert.ok(!(await jobExists('j_shared_old')), 'old shared-hash job removed');
        assert.ok(await jobExists('j_shared_new'), 'other user active job kept');
        assert.ok(fs.existsSync(filePath(h.shared)), 'shared file kept while another job uses it');
        console.log('✓ A file still used by another job is kept.');

        assert.ok(!(await jobExists('j_docbacked')), 'old failed job removed');
        assert.ok(fs.existsSync(filePath(h.docBacked)), 'file kept because a Document references it');
        console.log('✓ A file referenced by a saved Document is kept.');

        assert.ok(!(await jobExists('j_orphandone')), 'orphaned completed job removed');
        assert.ok(!fs.existsSync(filePath(h.orphanDone)), 'orphaned completed job file removed');
        console.log('✓ Completed job whose Document is gone is removed with its file.');

        assert.ok(await jobExists('j_recent'), 'recent failed job kept');
        assert.ok(fs.existsSync(filePath(h.recent)), 'recent job file kept');
        console.log('✓ Recent failed jobs are not touched.');

        assert.ok(!(await DocumentComparison.exists({ comparisonId: `c_old_failed_${stamp}` })), 'old failed comparison removed');
        assert.ok(await DocumentComparison.exists({ comparisonId: `c_old_done_${stamp}` }), 'old completed comparison kept');
        assert.ok(await DocumentComparison.exists({ comparisonId: `c_recent_failed_${stamp}` }), 'recent failed comparison kept');
        console.log('✓ Only old non-completed comparisons are removed.');

        // Path-traversal guard
        assert.strictEqual(await cleanup.removeFileIfUnreferenced('../../package'), false);
        console.log('✓ Unsafe hash values are rejected.');

        console.log('\n=== All job sweep tests passed ===');
    } finally {
        await cleanAll();
        await mongoose.disconnect();
    }
}

run().catch(err => { console.error('✗ Job sweep test failed:', err); process.exit(1); });