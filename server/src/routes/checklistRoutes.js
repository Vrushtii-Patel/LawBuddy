const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Checklist = require('../models/Checklist');
const Document = require('../models/Document');
const { requireAuth } = require('../middleware/authMiddleware');
const llmService = require('../services/llmService');
const crossReferenceService = require('../services/crossReferenceService');
const documentCleanupService = require('../services/documentCleanupService');

// Helper to query checklist by either MongoDB _id or type
function getChecklistQuery(idOrType, userId, activeOnly = false) {
    let query = { userId };
    if (mongoose.Types.ObjectId.isValid(idOrType)) {
        query.$or = [{ _id: idOrType }, { type: idOrType }];
    } else {
        query.type = idOrType;
    }
    if (activeOnly) {
        query.isDeleted = { $ne: true };
    }
    return query;
}

// 1. Fetch all active checklists for logged-in user
router.get('/checklists', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;

        // Auto-clean any stale/orphaned issues for deleted documents
        try {
            await crossReferenceService.cleanOrphanChecklistIssues(userId);
        } catch (_) {}

        let checklists = await Checklist.find({ userId, isDeleted: { $ne: true } }).sort({ _id: -1 });

        // If user has no active checklists, check if they have analyzed documents and auto-sync
        if (!checklists || checklists.length === 0) {
            const hasDocs = await Document.exists({ userId, isDeleted: { $ne: true }, analysisStatus: 'completed' });
            if (hasDocs) {
                await crossReferenceService.syncAllUserDocuments(userId);
                checklists = await Checklist.find({ userId, isDeleted: { $ne: true } }).sort({ _id: -1 });
            }
        }

        res.json(checklists);
    } catch (error) {
        console.error('Error fetching checklists:', error);
        res.status(500).json({ error: 'Failed to fetch checklists. Please try again.' });
    }
});

// 2. Fetch soft-deleted checklists in Recycle Bin (sorted by deletedAt descending)
// Note: Placed before /checklists/:type so 'bin' is not captured as :type
router.get('/checklists/bin', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;

        // Opportunistically purge any checklists binned > 30 days ago
        try {
            await documentCleanupService.purgeExpiredBinnedChecklists(userId);
        } catch (purgeErr) {
            console.warn('[GetChecklistBin] Warning: Opportunistic purge note:', purgeErr.message);
        }

        const binnedChecklists = await Checklist.find({
            userId,
            isDeleted: true
        }).sort({ deletedAt: -1 });

        res.json(binnedChecklists);
    } catch (error) {
        console.error('Error fetching Recycle Bin checklists:', error);
        res.status(500).json({ error: 'Failed to fetch Recycle Bin checklists' });
    }
});

// 3. Restore soft-deleted checklist from Recycle Bin
router.patch('/checklists/:id/restore', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const query = getChecklistQuery(req.params.id, userId);
        const checklist = await Checklist.findOne(query);

        if (!checklist) {
            return res.status(404).json({ error: 'Checklist not found or unauthorized' });
        }
        if (!checklist.isDeleted) {
            return res.status(400).json({ error: 'Checklist is not in the Recycle Bin' });
        }

        checklist.isDeleted = false;
        checklist.deletedAt = null;
        checklist.updatedAt = new Date();
        await checklist.save();

        // Cross-reference any active documents to refresh issues
        try {
            await crossReferenceService.syncAllUserDocuments(userId);
        } catch (syncErr) {
            console.warn('[RestoreChecklist] Warning: Cross-reference sync note:', syncErr.message);
        }

        res.json({ message: 'Checklist restored successfully', checklist });
    } catch (error) {
        console.error('Error restoring checklist:', error);
        res.status(500).json({ error: 'Failed to restore checklist. Please try again.' });
    }
});

// 4. Permanent deletion of a binned checklist
router.delete('/checklists/:id/permanent', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const result = await documentCleanupService.permanentlyDeleteChecklist(req.params.id, userId);
        res.json({ message: 'Checklist permanently deleted', id: result.id, type: result.type });
    } catch (error) {
        console.error('Error permanently deleting checklist:', error);
        const status = error.message.includes('not found') ? 404 : (error.message.includes('must be in the bin') ? 400 : 500);
        res.status(status).json({ error: error.message || 'Failed to permanently delete checklist' });
    }
});

// 5. Fetch single active checklist by type or id
router.get('/checklists/:type', requireAuth, async (req, res) => {
    try {
        const type = req.params.type;
        const userId = req.user.userId;
        const query = getChecklistQuery(type, userId, true);
        const checklist = await Checklist.findOne(query);
        
        if (!checklist) {
             return res.status(404).json({ error: 'Checklist not found' });
        }
        res.json(checklist);
    } catch (error) {
        console.error('Error fetching checklist:', error);
        res.status(500).json({ error: 'Failed to fetch checklist.' });
    }
});

// 6. Update single item completion status in active checklist
router.put('/checklists/:type/items/:itemId', requireAuth, async (req, res) => {
    try {
        const { type, itemId } = req.params;
        const { isCompleted } = req.body;
        const userId = req.user.userId;

        const query = getChecklistQuery(type, userId, true);
        const checklist = await Checklist.findOne(query);
        if (!checklist) {
            return res.status(404).json({ error: 'Checklist not found' });
        }

        const item = checklist.items.find(i => (i.id && i.id.toString() === itemId.toString()) || (i._id && i._id.toString() === itemId.toString()));
        if (!item) {
            return res.status(404).json({ error: 'Item not found in checklist' });
        }

        item.isCompleted = Boolean(isCompleted);
        if (item.isCompleted) {
            item.status = 'VERIFIED';
        } else {
            item.status = (item.linkedIssues && item.linkedIssues.length > 0) ? 'FLAGGED' : 'NOT_STARTED';
        }

        checklist.updatedAt = new Date();
        await checklist.save();

        res.json({ message: 'Checklist updated successfully', checklist });
    } catch (error) {
        console.error('Error updating checklist item:', error);
        res.status(500).json({ error: 'Failed to update checklist item. Please try again.' });
    }
});

// 7. Add new item to an active checklist
router.post('/checklists/:type/items', requireAuth, async (req, res) => {
    try {
        const { type } = req.params;
        const { title } = req.body;
        const userId = req.user.userId;

        if (!title || !title.trim()) {
            return res.status(400).json({ error: 'Title is required' });
        }

        const query = getChecklistQuery(type, userId, true);
        const checklist = await Checklist.findOne(query);
        if (!checklist) {
            return res.status(404).json({ error: 'Checklist not found' });
        }

        const newItem = {
            id: Date.now().toString(),
            title: title.trim(),
            isCompleted: false,
            status: 'NOT_STARTED',
            linkedIssues: []
        };

        checklist.items.push(newItem);
        checklist.updatedAt = new Date();
        await checklist.save();

        res.json({ message: 'Item added successfully', checklist, item: newItem });
    } catch (error) {
        console.error('Error adding checklist item:', error);
        res.status(500).json({ error: 'Failed to add checklist item. Please try again.' });
    }
});

// 8. Delete single item from an active checklist
router.delete('/checklists/:type/items/:itemId', requireAuth, async (req, res) => {
    try {
        const { type, itemId } = req.params;
        const userId = req.user.userId;

        const query = getChecklistQuery(type, userId, true);
        const checklist = await Checklist.findOne(query);
        if (!checklist) {
            return res.status(404).json({ error: 'Checklist not found' });
        }

        const initialLength = checklist.items.length;
        checklist.items = checklist.items.filter(
            i => !( (i.id && i.id.toString() === itemId.toString()) || (i._id && i._id.toString() === itemId.toString()) )
        );

        if (checklist.items.length === initialLength) {
            return res.status(404).json({ error: 'Item not found in checklist' });
        }

        checklist.updatedAt = new Date();
        await checklist.save();
        res.json({ message: 'Item deleted successfully', checklist });
    } catch (error) {
        console.error('Error deleting checklist item:', error);
        res.status(500).json({ error: 'Failed to delete checklist item. Please try again.' });
    }
});

// 9. Soft-delete entire checklist (moves to Recycle Bin)
router.delete('/checklists/:type', requireAuth, async (req, res) => {
    try {
        const { type } = req.params;
        const userId = req.user.userId;

        const query = getChecklistQuery(type, userId);
        const checklist = await Checklist.findOne(query);
        if (!checklist) {
            return res.status(404).json({ error: 'Checklist not found or unauthorized' });
        }
        if (checklist.isDeleted) {
            return res.status(400).json({ error: 'Checklist is already in the Recycle Bin' });
        }

        checklist.isDeleted = true;
        checklist.deletedAt = new Date();
        checklist.updatedAt = new Date();
        await checklist.save();

        res.json({
            message: 'Checklist moved to Recycle Bin',
            id: checklist._id,
            type: checklist.type,
            isDeleted: true,
            deletedAt: checklist.deletedAt
        });
    } catch (error) {
        console.error('Error deleting checklist:', error);
        res.status(500).json({ error: 'Failed to delete checklist. Please try again.' });
    }
});

// 10. Rename active checklist title
router.put('/checklists/:type/rename', requireAuth, async (req, res) => {
    try {
        const { type } = req.params;
        const { title } = req.body;
        const userId = req.user.userId;

        if (!title || !title.trim()) {
            return res.status(400).json({ error: 'Title is required' });
        }

        const query = getChecklistQuery(type, userId, true);
        const checklist = await Checklist.findOne(query);
        if (!checklist) {
            return res.status(404).json({ error: 'Checklist not found' });
        }

        checklist.title = title.trim();
        checklist.updatedAt = new Date();
        await checklist.save();

        res.json({ message: 'Checklist renamed successfully', checklist });
    } catch (error) {
        console.error('Error renaming checklist:', error);
        res.status(500).json({ error: 'Failed to rename checklist. Please try again.' });
    }
});

// 11. Generate AI Checklist & Cross-reference existing issues
router.post('/checklists/generate', requireAuth, async (req, res) => {
    try {
        const { prompt } = req.body;
        const userId = req.user.userId;

        if (!prompt || !prompt.trim()) {
            return res.status(400).json({ error: 'Prompt is required' });
        }

        let items;
        try {
            items = await llmService.generateChecklist(prompt);
        } catch (llmErr) {
            console.error('LLM generation error, using fallback legal rules:', llmErr);
            items = [
                { id: "1", title: "Verify Title Deed & 30-Year Chain of Documents" },
                { id: "2", title: "Obtain Encumbrance Certificate (EC) from Sub-Registrar" },
                { id: "3", title: "Check RERA Registration & Approved Sanction Plan" },
                { id: "4", title: "Verify Occupancy Certificate (OC) & Completion Certificate (CC)" },
                { id: "5", title: "Inspect Society NOC & Share Certificate / Khata Transfer" },
                { id: "6", title: "Draft & Execute Registered Agreement for Sale / Conveyance Deed" }
            ];
        }

        const cleanItems = (items || []).map((item, idx) => ({
            id: (item.id || (idx + 1)).toString(),
            title: item.title || 'Legal Due Diligence Task',
            isCompleted: false,
            status: 'NOT_STARTED',
            linkedIssues: []
        }));

        const newType = 'custom_' + Date.now();
        const checklist = new Checklist({
            userId,
            type: newType,
            title: prompt.trim().substring(0, 45) + (prompt.trim().length > 45 ? '...' : ''),
            items: cleanItems
        });

        await checklist.save();

        // Cross-reference any existing user documents to immediately flag relevant tasks
        try {
            await crossReferenceService.syncAllUserDocuments(userId);
            const reloaded = await Checklist.findById(checklist._id);
            if (reloaded) return res.json(reloaded);
        } catch (syncErr) {
            console.warn('Post-generation checklist sync warning:', syncErr.message);
        }

        res.json(checklist);
    } catch (error) {
        console.error('Error generating checklist:', error);
        res.status(500).json({ error: 'Failed to generate checklist. Please try again.' });
    }
});

// 12. Synchronize specific document findings with checklists
router.post('/checklists/sync/:documentId', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const document = await Document.findOne({ _id: req.params.documentId, userId, isDeleted: { $ne: true } });
        if (!document) {
            return res.status(404).json({ error: 'Document not found' });
        }

        const modified = await crossReferenceService.syncDocumentIssuesWithChecklists(userId, document);
        res.json({ message: 'Checklist cross-referencing completed', modifiedCount: modified.length });
    } catch (error) {
        console.error('Error syncing checklist with document:', error);
        res.status(500).json({ error: 'Failed to sync checklist with document.' });
    }
});

// 13. Synchronize all user documents with checklists
router.post('/checklists/sync', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const modified = await crossReferenceService.syncAllUserDocuments(userId);
        res.json({ message: 'All documents cross-referenced with checklists', modifiedCount: modified.length });
    } catch (error) {
        console.error('Error syncing all checklists:', error);
        res.status(500).json({ error: 'Failed to sync checklists.' });
    }
});

module.exports = router;
