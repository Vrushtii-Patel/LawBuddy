const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const Document = require('../models/Document');
const ScanJob = require('../models/ScanJob');
const DocumentComparison = require('../models/DocumentComparison');
const Checklist = require('../models/Checklist');
const crossReferenceService = require('./crossReferenceService');

const UPLOADS_DIR = path.join(__dirname, '../../uploads/scan_files');

/**
 * Permanently deletes a single document and cleans up all associated resources:
 * - Physical file on disk (uploads/scan_files/<hash>.dat) if no other document references this fileHash
 * - Associated ScanJob record(s)
 * - Associated Checklist cross-reference links
 * - The Document record itself
 */
async function permanentlyDeleteDocument(docId, userId) {
    const doc = await Document.findOne({ _id: docId, userId });
    if (!doc) {
        throw new Error('Document not found or unauthorized');
    }
    if (!doc.isDeleted) {
        throw new Error('Document must be in the bin before it can be permanently deleted');
    }

    // 1. File on disk cleanup with error tolerance
    if (doc.fileHash) {
        try {
            const otherReferences = await Document.countDocuments({
                _id: { $ne: doc._id },
                fileHash: doc.fileHash
            });

            if (otherReferences === 0) {
                const filePath = path.join(UPLOADS_DIR, `${doc.fileHash}.dat`);
                if (fs.existsSync(filePath)) {
                    fs.unlinkSync(filePath);
                }
            }
        } catch (fsErr) {
            console.warn(`[PermanentDelete] Warning: File deletion failed for hash ${doc.fileHash}:`, fsErr.message);
        }
    }

    // 2. Delete associated ScanJob records
    try {
        await ScanJob.deleteMany({
            $or: [
                { documentId: doc._id },
                { userId: doc.userId, fileHash: doc.fileHash }
            ]
        });
    } catch (jobErr) {
        console.warn(`[PermanentDelete] Warning: ScanJob deletion error:`, jobErr.message);
    }

    // 3. Clean up linked checklist issues
    try {
        await crossReferenceService.removeDocumentIssuesFromChecklists(userId, doc._id);
    } catch (syncErr) {
        console.warn(`[PermanentDelete] Warning: Checklist cleanup error:`, syncErr.message);
    }

    // 4. Delete the Document row itself
    await Document.findByIdAndDelete(doc._id);

    return { id: doc._id, fileHash: doc.fileHash };
}

/**
 * Permanently deletes a single binned checklist.
 */
async function permanentlyDeleteChecklist(checklistIdOrType, userId) {
    let query = { userId };
    if (mongoose.Types.ObjectId.isValid(checklistIdOrType)) {
        query.$or = [{ _id: checklistIdOrType }, { type: checklistIdOrType }];
    } else {
        query.type = checklistIdOrType;
    }

    const checklist = await Checklist.findOne(query);
    if (!checklist) {
        throw new Error('Checklist not found or unauthorized');
    }
    if (!checklist.isDeleted) {
        throw new Error('Checklist must be in the bin before it can be permanently deleted');
    }

    await Checklist.findByIdAndDelete(checklist._id);
    return { id: checklist._id, type: checklist.type };
}

/**
 * Automatically purges all binned documents older than 30 days (default retention).
 * Can be run opportunistically for a specific user or globally for all expired binned documents.
 * 
 * @param {string|null} userId - Optional userId to scope the purge to a specific user
 * @param {number} retentionDays - Retention window in days (default: 30)
 * @returns {Promise<number>} Number of documents permanently purged
 */
async function purgeExpiredBinnedDocuments(userId = null, retentionDays = 30) {
    const expirationThreshold = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);
    const query = {
        isDeleted: true,
        deletedAt: { $lt: expirationThreshold }
    };
    if (userId) {
        query.userId = userId;
    }

    const expiredDocs = await Document.find(query);
    let purgedCount = 0;

    for (const doc of expiredDocs) {
        try {
            await permanentlyDeleteDocument(doc._id, doc.userId);
            purgedCount++;
        } catch (err) {
            console.warn(`[AutoPurge] Warning: Failed to purge expired document ${doc._id}:`, err.message);
        }
    }

    return purgedCount;
}

/**
 * Automatically purges all binned checklists older than 30 days (default retention).
 * 
 * @param {string|null} userId - Optional userId to scope the purge to a specific user
 * @param {number} retentionDays - Retention window in days (default: 30)
 * @returns {Promise<number>} Number of checklists permanently purged
 */
async function purgeExpiredBinnedChecklists(userId = null, retentionDays = 30) {
    const expirationThreshold = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);
    const query = {
        isDeleted: true,
        deletedAt: { $lt: expirationThreshold }
    };
    if (userId) {
        query.userId = userId;
    }

    const expiredChecklists = await Checklist.find(query);
    let purgedCount = 0;

    for (const checklist of expiredChecklists) {
        try {
            await permanentlyDeleteChecklist(checklist._id.toString(), checklist.userId);
            purgedCount++;
        } catch (err) {
            console.warn(`[AutoPurge] Warning: Failed to purge expired checklist ${checklist._id}:`, err.message);
        }
    }

    return purgedCount;
}

// =========================================================================
// ORPHANED / ABANDONED JOB SWEEP
// =========================================================================

const DEFAULT_ABANDONED_JOB_RETENTION_DAYS = (() => {
    const fromEnv = parseInt(process.env.ABANDONED_JOB_RETENTION_DAYS || '', 10);
    return Number.isFinite(fromEnv) && fromEnv > 0 ? fromEnv : 7;
})();

const SWEEP_BATCH_LIMIT = 500;

// Hashes are used to build a path on disk, so only accept plain file-name characters.
const SAFE_HASH_RE = /^[A-Za-z0-9_-]+$/;

/**
 * Deletes uploads/scan_files/<hash>.dat only when nothing references it any more:
 * no Document (including binned ones) and no remaining ScanJob with the same fileHash.
 * Files are content-addressed, so the same upload by different users shares one file.
 * Call this AFTER the ScanJob rows being removed have been deleted.
 * Returns true if a file was removed.
 */
async function removeFileIfUnreferenced(fileHash) {
    if (!fileHash || !SAFE_HASH_RE.test(fileHash)) return false;

    const [docRefs, jobRefs] = await Promise.all([
        Document.countDocuments({ fileHash }),
        ScanJob.countDocuments({ fileHash })
    ]);
    if (docRefs > 0 || jobRefs > 0) return false;

    const filePath = path.resolve(UPLOADS_DIR, `${fileHash}.dat`);
    if (!filePath.startsWith(path.resolve(UPLOADS_DIR) + path.sep)) return false;
    if (!fs.existsSync(filePath)) return false;

    fs.unlinkSync(filePath);
    return true;
}

/**
 * Sweeps scan/comparison jobs that will never produce (or no longer have) a document:
 *
 *  1. ScanJobs that are not COMPLETED (FAILED, or stuck in a pending status) and have not
 *     been touched for `retentionDays`.
 *  2. COMPLETED ScanJobs older than `retentionDays` whose Document no longer exists.
 *  3. DocumentComparisons that are not COMPLETED and have not been touched for `retentionDays`.
 *
 * For scan jobs, the uploaded file is removed too, but only if no Document or other ScanJob
 * still references the same hash. Comparisons own no files (they point at Documents' files).
 * Works in bounded batches so a large backlog cannot stall the server; the next run continues.
 *
 * @param {number} retentionDays - Age (by updatedAt) before a job is considered abandoned
 * @returns {Promise<{scanJobs:number, orphanedCompletedJobs:number, comparisons:number, files:number}>}
 */
async function sweepAbandonedJobs(retentionDays = DEFAULT_ABANDONED_JOB_RETENTION_DAYS) {
    const threshold = new Date(Date.now() - retentionDays * 24 * 60 * 60 * 1000);
    const result = { scanJobs: 0, orphanedCompletedJobs: 0, comparisons: 0, files: 0 };
    const affectedHashes = new Set();

    // 1. Failed / stuck scan jobs
    try {
        const stale = await ScanJob.find({
            status: { $ne: 'COMPLETED' },
            updatedAt: { $lt: threshold }
        }).select('_id fileHash').limit(SWEEP_BATCH_LIMIT).lean();

        if (stale.length > 0) {
            const del = await ScanJob.deleteMany({ _id: { $in: stale.map(j => j._id) } });
            result.scanJobs = del.deletedCount || 0;
            stale.forEach(j => j.fileHash && affectedHashes.add(j.fileHash));
        }
    } catch (err) {
        console.warn('[JobSweep] Warning: failed/stuck ScanJob sweep error:', err.message);
    }

    // 2. Completed scan jobs whose Document has been deleted
    try {
        const completed = await ScanJob.find({
            status: 'COMPLETED',
            documentId: { $ne: null },
            updatedAt: { $lt: threshold }
        }).select('_id fileHash documentId').limit(SWEEP_BATCH_LIMIT).lean();

        if (completed.length > 0) {
            const existing = await Document.find({
                _id: { $in: completed.map(j => j.documentId) }
            }).select('_id').lean();
            const existingIds = new Set(existing.map(d => String(d._id)));

            const orphans = completed.filter(j => !existingIds.has(String(j.documentId)));
            if (orphans.length > 0) {
                const del = await ScanJob.deleteMany({ _id: { $in: orphans.map(j => j._id) } });
                result.orphanedCompletedJobs = del.deletedCount || 0;
                orphans.forEach(j => j.fileHash && affectedHashes.add(j.fileHash));
            }
        }
    } catch (err) {
        console.warn('[JobSweep] Warning: orphaned completed ScanJob sweep error:', err.message);
    }

    // 3. Failed / stuck comparisons (no files of their own)
    try {
        const staleCmp = await DocumentComparison.find({
            status: { $ne: 'COMPLETED' },
            updatedAt: { $lt: threshold }
        }).select('_id').limit(SWEEP_BATCH_LIMIT).lean();

        if (staleCmp.length > 0) {
            const del = await DocumentComparison.deleteMany({ _id: { $in: staleCmp.map(c => c._id) } });
            result.comparisons = del.deletedCount || 0;
        }
    } catch (err) {
        console.warn('[JobSweep] Warning: DocumentComparison sweep error:', err.message);
    }

    // 4. Files left without any reference (checked after the rows above are gone)
    for (const hash of affectedHashes) {
        try {
            if (await removeFileIfUnreferenced(hash)) result.files++;
        } catch (err) {
            console.warn(`[JobSweep] Warning: file cleanup failed for hash ${hash}:`, err.message);
        }
    }

    return result;
}

module.exports = {
    permanentlyDeleteDocument,
    permanentlyDeleteChecklist,
    purgeExpiredBinnedDocuments,
    purgeExpiredBinnedChecklists,
    sweepAbandonedJobs,
    removeFileIfUnreferenced,
    UPLOADS_DIR
};