const express = require('express');
const router = express.Router();
const llmService = require('../services/llmService');
const scanJobService = require('../services/scanJobService');
const Document = require('../models/Document');
const ScanJob = require('../models/ScanJob');
const crossReferenceService = require('../services/crossReferenceService');
const { requireAuth } = require('../middleware/authMiddleware');

// =========================================================================
// RESUMABLE SCAN JOB ENDPOINTS
// =========================================================================

// POST /api/scans/start - Initializes a persistent scan job
router.post('/scans/start', requireAuth, async (req, res) => {
    try {
        const { text, title: customTitle, sourceType, base64Data, mimeType } = req.body;
        if (!text && !base64Data) {
            return res.status(400).json({ error: 'Document text or base64Data is required' });
        }
        const userId = req.user.userId;

        const job = await scanJobService.createScanJob({
            userId,
            text,
            base64Data,
            mimeType: mimeType || 'application/pdf',
            title: customTitle,
            sourceType: sourceType || (base64Data ? 'PDF Document' : 'Text Description')
        });

        // Trigger background processing if not already completed from cache
        if (job.status !== 'COMPLETED') {
            scanJobService.executeJobPipeline(job.jobId).catch(err => {
                console.warn(`[Background Job ${job.jobId}] Pipeline error:`, err.message);
            });
        }

        res.status(201).json({
            jobId: job.jobId,
            status: job.status,
            currentStep: job.currentStep,
            completedSteps: job.completedSteps,
            documentId: job.documentId
        });
    } catch (error) {
        console.error('Error starting scan job:', error);
        res.status(500).json({ error: 'Failed to start scan job', details: error.message });
    }
});

// GET /api/scans/active - Retrieves the user's latest active / unfinished scan job
router.get('/scans/active', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const activeJob = await ScanJob.findOne({
            userId,
            status: { $in: ['QUEUED', 'UPLOADING', 'OCR_PROCESSING', 'TEXT_EXTRACTED', 'AI_ANALYSIS', 'REPORT_GENERATION', 'RETRYING', 'FAILED'] }
        }).sort({ updatedAt: -1 });

        if (!activeJob) {
            return res.json({ activeJob: null });
        }

        res.json({
            activeJob: {
                jobId: activeJob.jobId,
                title: activeJob.title,
                sourceType: activeJob.sourceType,
                status: activeJob.status,
                currentStep: activeJob.currentStep,
                completedSteps: activeJob.completedSteps,
                errorInfo: activeJob.errorInfo,
                retryCount: (activeJob.autoRetriesCount || 0) + (activeJob.manualRetriesCount || 0),
                updatedAt: activeJob.updatedAt
            }
        });
    } catch (error) {
        console.error('Error fetching active scan job:', error);
        res.status(500).json({ error: 'Failed to fetch active scan job', details: error.message });
    }
});

// GET /api/scans/:jobId - Polls / inspects the status of a specific scan job
router.get('/scans/:jobId', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const job = await ScanJob.findOne({ jobId: req.params.jobId, userId });
        if (!job) {
            return res.status(404).json({ error: 'Scan job not found' });
        }

        let document = null;
        if (job.documentId) {
            document = await Document.findById(job.documentId);
        }

        res.json({
            jobId: job.jobId,
            status: job.status,
            currentStep: job.currentStep,
            completedSteps: job.completedSteps,
            extractedText: job.extractedText,
            analysis: job.analysis,
            canonicalClauses: job.canonicalClauses,
            documentId: job.documentId,
            document: document,
            errorInfo: job.errorInfo,
            retryCount: (job.autoRetriesCount || 0) + (job.manualRetriesCount || 0),
            createdAt: job.createdAt,
            updatedAt: job.updatedAt,
            completedAt: job.completedAt
        });
    } catch (error) {
        console.error('Error fetching scan job status:', error);
        res.status(500).json({ error: 'Failed to fetch scan job status', details: error.message });
    }
});

// POST /api/scans/:jobId/retry - Resumes a failed or incomplete scan job from its last incomplete stage
router.post('/scans/:jobId/retry', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const job = await ScanJob.findOne({ jobId: req.params.jobId, userId });
        if (!job) {
            return res.status(404).json({ error: 'Scan job not found' });
        }

        if (job.status === 'COMPLETED') {
            const document = job.documentId ? await Document.findById(job.documentId) : null;
            return res.json({
                message: 'Job is already completed',
                jobId: job.jobId,
                status: 'COMPLETED',
                document
            });
        }

        const completedJob = await scanJobService.retryJob(job.jobId, true);
        const document = completedJob.documentId ? await Document.findById(completedJob.documentId) : null;

        res.json({
            jobId: completedJob.jobId,
            status: completedJob.status,
            currentStep: completedJob.currentStep,
            completedSteps: completedJob.completedSteps,
            documentId: completedJob.documentId,
            document: document,
            errorInfo: completedJob.errorInfo
        });
    } catch (error) {
        console.error('Error retrying scan job:', error);
        if (error.status === 429) {
            return res.status(429).json({ error: 'Rate limit reached. Please wait a moment before retrying.' });
        }
        res.status(500).json({ error: 'Failed to retry scan job', details: error.message });
    }
});

// =========================================================================
// SYNCHRONOUS / LEGACY SCAN ENDPOINTS (BACKED BY PERSISTENT SCAN JOB)
// =========================================================================

// POST /api/scan
router.post('/scan', requireAuth, async (req, res) => {
    try {
        const { text, title: customTitle, sourceType = 'Text Description', base64Data = null, mimeType = 'text/plain' } = req.body;
        if (!text && !base64Data) {
            return res.status(400).json({ error: 'Document text or base64Data is required' });
        }
        const userId = req.user.userId;

        // Create persistent job
        const job = await scanJobService.createScanJob({
            userId,
            text,
            base64Data,
            mimeType,
            title: customTitle,
            sourceType
        });

        // Execute pipeline synchronously
        const completedJob = await scanJobService.executeJobPipeline(job.jobId);
        const doc = completedJob.documentId ? await Document.findById(completedJob.documentId) : null;

        res.json({
            jobId: completedJob.jobId,
            cacheHit: completedJob.currentStep.includes('cache'),
            fileHash: completedJob.fileHash,
            extractedText: completedJob.extractedText,
            analysis: completedJob.analysis,
            canonicalClauses: completedJob.canonicalClauses,
            highRiskCount: doc ? doc.highRiskCount : completedJob.analysis.filter(c => c.riskLevel === 'HIGH_RISK').length,
            cautionCount: doc ? doc.cautionCount : completedJob.analysis.filter(c => c.riskLevel === 'CAUTION').length,
            compliantCount: doc ? doc.compliantCount : completedJob.analysis.filter(c => c.riskLevel === 'COMPLIANT').length,
            totalClauseCount: completedJob.analysis.length,
            riskLevel: doc ? doc.riskLevel : 'Low Risk',
            sourceType: completedJob.sourceType,
            fileData: base64Data,
            mimeType: completedJob.mimeType,
            document: doc,
            documentId: completedJob.documentId
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

        const job = await scanJobService.createScanJob({
            userId,
            base64Data,
            mimeType: mimeType || (computedSourceType === 'PDF Document' ? 'application/pdf' : 'image/jpeg'),
            title: customTitle,
            sourceType: computedSourceType
        });

        const completedJob = await scanJobService.executeJobPipeline(job.jobId);
        const doc = completedJob.documentId ? await Document.findById(completedJob.documentId) : null;

        res.json({
            jobId: completedJob.jobId,
            cacheHit: completedJob.currentStep.includes('cache'),
            fileHash: completedJob.fileHash,
            extractedText: completedJob.extractedText,
            analysis: completedJob.analysis,
            canonicalClauses: completedJob.canonicalClauses,
            highRiskCount: doc ? doc.highRiskCount : completedJob.analysis.filter(c => c.riskLevel === 'HIGH_RISK').length,
            cautionCount: doc ? doc.cautionCount : completedJob.analysis.filter(c => c.riskLevel === 'CAUTION').length,
            compliantCount: doc ? doc.compliantCount : completedJob.analysis.filter(c => c.riskLevel === 'COMPLIANT').length,
            totalClauseCount: completedJob.analysis.length,
            riskLevel: doc ? doc.riskLevel : 'Low Risk',
            sourceType: completedJob.sourceType,
            fileData: base64Data,
            mimeType: completedJob.mimeType,
            document: doc,
            documentId: completedJob.documentId
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

        // Clean up linked checklist issues and auto-created checklists
        try {
            await crossReferenceService.removeDocumentIssuesFromChecklists(userId, req.params.id);
        } catch (syncErr) {
            console.warn(`[DeleteDocument] Warning: Checklist cleanup error:`, syncErr.message);
        }

        res.json({ message: 'Document deleted successfully', id: req.params.id });
    } catch (error) {
        console.error('Error deleting document:', error);
        res.status(500).json({ error: 'Failed to delete document', details: error.message });
    }
});

// POST /api/explain
router.post('/explain', requireAuth, async (req, res) => {
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