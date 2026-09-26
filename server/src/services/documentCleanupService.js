const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const Document = require('../models/Document');
const ScanJob = require('../models/ScanJob');
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

module.exports = {
    permanentlyDeleteDocument,
    permanentlyDeleteChecklist,
    purgeExpiredBinnedDocuments,
    purgeExpiredBinnedChecklists,
    UPLOADS_DIR
};
