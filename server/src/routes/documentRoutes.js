const express = require('express');
const router = express.Router();
const llmService = require('../services/llmService');
const Document = require('../models/Document');
const { requireAuth } = require('../middleware/authMiddleware');

// POST /api/scan
router.post('/scan', requireAuth, async (req, res) => {
    try {
        const { text, title: customTitle, sourceType = 'Text Description', base64Data = null, mimeType = 'text/plain' } = req.body;
        if (!text && !base64Data) {
            return res.status(400).json({ error: 'Document text or base64Data is required' });
        }
        const userId = req.user.userId;

        const result = await llmService.analyzeContractPipeline({
            text,
            base64Data,
            mimeType,
            customTitle,
            sourceType,
            userId
        });

        res.json({
            cacheHit: result.cacheHit,
            fileHash: result.fileHash,
            extractedText: result.extractedText,
            analysis: result.analysis,
            canonicalClauses: result.canonicalClauses,
            highRiskCount: result.highRiskCount,
            cautionCount: result.cautionCount,
            compliantCount: result.compliantCount,
            totalClauseCount: result.totalClauseCount,
            riskLevel: result.riskLevel,
            sourceType: result.sourceType,
            fileData: result.fileData,
            mimeType: result.mimeType,
            document: result.document,
            documentId: result.documentId
        });
    } catch (error) {
        console.error('Error analyzing document:', error);
        if (error.status === 429) {
            return res.status(429).json({ error: 'Rate limit reached. Please wait a moment before trying again.' });
        }
        res.status(500).json({ error: 'Failed to analyze document', details: error.message });
    }
});

// POST /api/scan-file
router.post('/scan-file', requireAuth, async (req, res) => {
    try {
        const { base64Data, mimeType, title: customTitle, sourceType: reqSourceType } = req.body;
        if (!base64Data) {
            return res.status(400).json({ error: 'base64Data is required' });
        }
        const userId = req.user.userId;

        let computedSourceType = reqSourceType;
        if (!computedSourceType) {
            if ((mimeType || '').toLowerCase().includes('pdf')) {
                computedSourceType = 'PDF Document';
            } else {
                computedSourceType = 'Photo Scan';
            }
        }

        const result = await llmService.analyzeContractPipeline({
            base64Data,
            mimeType: mimeType || (computedSourceType === 'PDF Document' ? 'application/pdf' : 'image/jpeg'),
            customTitle,
            sourceType: computedSourceType,
            userId
        });

        res.json({
            cacheHit: result.cacheHit,
            fileHash: result.fileHash,
            extractedText: result.extractedText,
            analysis: result.analysis,
            canonicalClauses: result.canonicalClauses,
            highRiskCount: result.highRiskCount,
            cautionCount: result.cautionCount,
            compliantCount: result.compliantCount,
            totalClauseCount: result.totalClauseCount,
            riskLevel: result.riskLevel,
            sourceType: result.sourceType,
            fileData: result.fileData,
            mimeType: result.mimeType,
            document: result.document,
            documentId: result.documentId
        });
    } catch (error) {
        console.error('Error analyzing file:', error);
        if (error.status === 429) {
            return res.status(429).json({ error: 'Rate limit reached. Please wait a moment before trying again.' });
        }
        res.status(500).json({ error: 'Failed to analyze file', details: error.message });
    }
});

// GET /api/documents (Strictly scoped to authenticated user)
router.get('/documents', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const docs = await Document.find({ userId }).sort({ createdAt: -1 });
        res.json(docs);
    } catch (error) {
        console.error('Error fetching documents:', error);
        res.status(500).json({ error: 'Failed to fetch documents', details: error.message });
    }
});

// GET /api/documents/:id (Strictly scoped to authenticated user)
router.get('/documents/:id', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const doc = await Document.findOne({ _id: req.params.id, userId });
        if (!doc) {
            return res.status(404).json({ error: 'Document not found' });
        }
        res.json(doc);
    } catch (error) {
        console.error('Error fetching document:', error);
        res.status(500).json({ error: 'Failed to fetch document', details: error.message });
    }
});

// PATCH /api/documents/:id (Rename or update document metadata)
router.patch('/documents/:id', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const { title } = req.body;
        if (!title || typeof title !== 'string' || !title.trim()) {
            return res.status(400).json({ error: 'A valid non-empty title is required' });
        }
        const doc = await Document.findOneAndUpdate(
            { _id: req.params.id, userId },
            { $set: { title: title.trim() } },
            { new: true }
        );
        if (!doc) {
            return res.status(404).json({ error: 'Document not found or unauthorized' });
        }
        res.json({ message: 'Document renamed successfully', document: doc });
    } catch (error) {
        console.error('Error renaming document:', error);
        res.status(500).json({ error: 'Failed to rename document', details: error.message });
    }
});

// DELETE /api/documents/:id (Strictly scoped to authenticated user)
router.delete('/documents/:id', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const result = await Document.findOneAndDelete({ _id: req.params.id, userId });
        if (!result) {
            return res.status(404).json({ error: 'Document not found or unauthorized' });
        }
        res.json({ message: 'Document deleted successfully', id: req.params.id });
    } catch (error) {
        console.error('Error deleting document:', error);
        res.status(500).json({ error: 'Failed to delete document', details: error.message });
    }
});

// POST /api/explain
router.post('/explain', async (req, res) => {
    try {
        const { context, snippet } = req.body;
        if (!context || !snippet) {
            return res.status(400).json({ error: 'Context and snippet are required' });
        }
        const explanation = await llmService.explainSnippet(context, snippet);
        res.json({ explanation });
    } catch (error) {
        console.error('Error explaining snippet:', error);
        if (error.status === 429) {
            return res.status(429).json({ error: 'Rate limit reached. Please wait a moment before trying again.' });
        }
        res.status(500).json({ error: 'Failed to explain snippet', details: error.message });
    }
});

module.exports = router;