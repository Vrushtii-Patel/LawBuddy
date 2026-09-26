const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const llmService = require('../services/llmService');
const scanJobService = require('../services/scanJobService');
const Document = require('../models/Document');
const ScanJob = require('../models/ScanJob');
const crossReferenceService = require('../services/crossReferenceService');
const { requireAuth } = require('../middleware/authMiddleware');
const { uploadDocument } = require('../middleware/uploadMiddleware');

// =========================================================================
// RESUMABLE SCAN JOB ENDPOINTS
// =========================================================================

// POST /api/scans/start - Initializes a persistent scan job
router.post('/scans/start', requireAuth, uploadDocument, async (req, res) => {
    try {
        const file = req.file;
        const { text, title: customTitle, sourceType, base64Data, mimeType } = req.body || {};
        
        if (!text && !file && !base64Data) {
            return res.status(400).json({ error: 'Document file or text description is required.' });
        }
        const userId = req.user.userId;

        const computedMimeType = file ? file.mimetype : (mimeType || 'application/pdf');
        const defaultSourceType = file ? ((computedMimeType.includes('pdf')) ? 'PDF Document' : 'Photo Scan') : (base64Data ? 'PDF Document' : 'Text Description');

        const job = await scanJobService.createScanJob({
            userId,
            text,
            fileBuffer: file ? file.buffer : null,
            fileName: file ? file.originalname : (customTitle || ''),
            base64Data,
            mimeType: computedMimeType,
            title: customTitle || (file ? file.originalname : ''),
            sourceType: sourceType || defaultSourceType
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
        res.status(500).json({ error: 'Failed to start scan job. Please try again.' });
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
        res.status(500).json({ error: 'Failed to fetch active scan job.' });
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
        res.status(500).json({ error: 'Failed to fetch scan job status.' });
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

        job.manualRetriesCount = (job.manualRetriesCount || 0) + 1;
        job.lastRetryAt = new Date();
        job.status = 'RETRYING';
        job.currentStep = 'Resuming scan...';
        await job.save();

        // Launch pipeline in background so HTTP response returns immediately and client polling can track progress
        scanJobService.executeJobPipeline(job.jobId).catch(err => {
            console.warn(`[Background Retry Job ${job.jobId}] Pipeline error:`, err.message);
        });

        res.json({
            jobId: job.jobId,
            status: job.status,
            currentStep: job.currentStep,
            completedSteps: job.completedSteps,
            documentId: job.documentId,
            errorInfo: job.errorInfo
        });
    } catch (error) {
        console.error('Error retrying scan job:', error);
        if (error.status === 429) {
            return res.status(429).json({ error: 'Rate limit reached. Please wait a moment before retrying.' });
        }
        res.status(500).json({ error: 'Failed to retry scan job. Please try again.' });
    }
});

// =========================================================================
// SYNCHRONOUS / LEGACY SCAN ENDPOINTS (BACKED BY PERSISTENT SCAN JOB)
// =========================================================================

// POST /api/scan
router.post('/scan', requireAuth, uploadDocument, async (req, res) => {
    try {
        const file = req.file;
        const { text, title: customTitle, sourceType, base64Data = null, mimeType } = req.body || {};
        
        if (!text && !file && !base64Data) {
            return res.status(400).json({ error: 'Document file or text description is required.' });
        }
        const userId = req.user.userId;

        const computedMimeType = file ? file.mimetype : (mimeType || (base64Data ? 'application/pdf' : 'text/plain'));
        const defaultSourceType = file ? (computedMimeType.includes('pdf') ? 'PDF Document' : 'Photo Scan') : (base64Data ? 'PDF Document' : 'Text Description');

        // Create persistent job
        const job = await scanJobService.createScanJob({
            userId,
            text,
            fileBuffer: file ? file.buffer : null,
            fileName: file ? file.originalname : (customTitle || ''),
            base64Data,
            mimeType: computedMimeType,
            title: customTitle || (file ? file.originalname : ''),
            sourceType: sourceType || defaultSourceType
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
        res.status(500).json({ error: 'Failed to analyze document. Please try again.' });
    }
});

// POST /api/scan-file
router.post('/scan-file', requireAuth, uploadDocument, async (req, res) => {
    try {
        const file = req.file;
        const { base64Data, mimeType, title: customTitle, sourceType: reqSourceType } = req.body || {};
        
        if (!file && !base64Data) {
            return res.status(400).json({ error: 'Document file is required.' });
        }
        const userId = req.user.userId;

        const computedMimeType = file ? file.mimetype : (mimeType || 'application/pdf');
        let computedSourceType = reqSourceType;
        if (!computedSourceType) {
            if ((computedMimeType || '').toLowerCase().includes('pdf')) {
                computedSourceType = 'PDF Document';
            } else {
                computedSourceType = 'Photo Scan';
            }
        }

        const job = await scanJobService.createScanJob({
            userId,
            fileBuffer: file ? file.buffer : null,
            fileName: file ? file.originalname : (customTitle || ''),
            base64Data,
            mimeType: computedMimeType,
            title: customTitle || (file ? file.originalname : ''),
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
        res.status(500).json({ error: 'Failed to analyze file. Please try again.' });
    }
});

// Import cleanup service
const documentCleanupService = require('../services/documentCleanupService');

// GET /api/documents (Strictly scoped to authenticated user, excludes soft-deleted docs)
router.get('/documents', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const docs = await Document.find({ userId, isDeleted: { $ne: true } }).sort({ createdAt: -1 });
        res.json(docs);
    } catch (error) {
        console.error('Error fetching documents:', error);
        res.status(500).json({ error: 'Failed to fetch documents. Please try again.' });
    }
});

// GET /api/documents/bin (Returns soft-deleted documents, sorted by deletedAt descending)
// Note: Placed before /documents/:id so 'bin' is not matched as an :id parameter
router.get('/documents/bin', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        // Opportunistically purge any documents binned > 30 days ago
        try {
            await documentCleanupService.purgeExpiredBinnedDocuments(userId);
        } catch (purgeErr) {
            console.warn('[GetBin] Warning: Opportunistic purge note:', purgeErr.message);
        }

        const binnedDocs = await Document.find({
            userId,
            isDeleted: true
        }).sort({ deletedAt: -1 });

        res.json(binnedDocs);
    } catch (error) {
        console.error('Error fetching Recycle Bin documents:', error);
        res.status(500).json({ error: 'Failed to fetch Recycle Bin documents' });
    }
});

// GET /api/documents/:id (Strictly scoped to authenticated user, excludes soft-deleted docs)
router.get('/documents/:id', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const doc = await Document.findOne({ _id: req.params.id, userId, isDeleted: { $ne: true } });
        if (!doc) {
            return res.status(404).json({ error: 'Document not found' });
        }
        res.json(doc);
    } catch (error) {
        console.error('Error fetching document:', error);
        res.status(500).json({ error: 'Failed to fetch document. Please try again.' });
    }
});

// GET /api/documents/:id/file (Stream document file binary from disk storage or base64)
router.get('/documents/:id/file', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const doc = await Document.findOne({ _id: req.params.id, userId, isDeleted: { $ne: true } });
        if (!doc) {
            return res.status(404).json({ error: 'Document not found' });
        }

        // Check disk storage first
        if (doc.fileHash) {
            const diskBuffer = scanJobService.readFileFromStorage(path.join('uploads/scan_files', `${doc.fileHash}.dat`));
            if (diskBuffer && diskBuffer.length > 0) {
                res.setHeader('Content-Type', doc.mimeType || 'application/pdf');
                res.setHeader('Content-Length', diskBuffer.length);
                res.setHeader('Content-Disposition', `inline; filename="${encodeURIComponent(doc.fileName || doc.title || 'document.pdf')}"`);
                return res.send(diskBuffer);
            }
        }

        // Fallback to in-memory/in-database base64 if present
        if (doc.fileData) {
            let clean = doc.fileData.trim();
            if (clean.includes(',')) clean = clean.split(',').pop().trim();
            clean = clean.replace(/\s+/g, '');
            const buf = Buffer.from(clean, 'base64');
            res.setHeader('Content-Type', doc.mimeType || 'application/pdf');
            res.setHeader('Content-Length', buf.length);
            return res.send(buf);
        }

        return res.status(404).json({ error: 'Document file binary not found' });
    } catch (error) {
        console.error('Error fetching document file:', error);
        res.status(500).json({ error: 'Failed to fetch document file' });
    }
});

// PATCH /api/documents/:id/restore (Restores soft-deleted document from Recycle Bin)
router.patch('/documents/:id/restore', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const doc = await Document.findOne({ _id: req.params.id, userId });
        if (!doc) {
            return res.status(404).json({ error: 'Document not found or unauthorized' });
        }
        if (!doc.isDeleted) {
            return res.status(400).json({ error: 'Document is not in the Recycle Bin' });
        }

        doc.isDeleted = false;
        doc.deletedAt = null;
        await doc.save();

        // Re-sync checklist issues if document has completed analysis
        if (doc.analysisStatus === 'completed' && doc.analysis && doc.analysis.length > 0) {
            try {
                await crossReferenceService.syncDocumentWithChecklists(userId, doc);
            } catch (syncErr) {
                console.warn(`[RestoreDocument] Warning: Checklist sync error:`, syncErr.message);
            }
        }

        res.json({ message: 'Document restored successfully', document: doc });
    } catch (error) {
        console.error('Error restoring document:', error);
        res.status(500).json({ error: 'Failed to restore document. Please try again.' });
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
            { _id: req.params.id, userId, isDeleted: { $ne: true } },
            { $set: { title: title.trim() } },
            { returnDocument: 'after' }
        );
        if (!doc) {
            return res.status(404).json({ error: 'Document not found or unauthorized' });
        }
        res.json({ message: 'Document renamed successfully', document: doc });
    } catch (error) {
        console.error('Error renaming document:', error);
        res.status(500).json({ error: 'Failed to rename document. Please try again.' });
    }
});

// DELETE /api/documents/:id/permanent (Permanent cleanup of file, ScanJob, and Document record)
router.delete('/documents/:id/permanent', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const result = await documentCleanupService.permanentlyDeleteDocument(req.params.id, userId);
        res.json({ message: 'Document permanently deleted', id: result.id });
    } catch (error) {
        console.error('Error permanently deleting document:', error);
        const status = error.message.includes('not found') ? 404 : (error.message.includes('must be in the bin') ? 400 : 500);
        res.status(status).json({ error: error.message || 'Failed to permanently delete document' });
    }
});

// DELETE /api/documents/:id (Soft-delete: moves document to Recycle Bin)
router.delete('/documents/:id', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const doc = await Document.findOne({ _id: req.params.id, userId });
        if (!doc) {
            return res.status(404).json({ error: 'Document not found or unauthorized' });
        }
        if (doc.isDeleted) {
            return res.status(400).json({ error: 'Document is already in the Recycle Bin' });
        }

        doc.isDeleted = true;
        doc.deletedAt = new Date();
        await doc.save();

        // Clean up linked checklist issues and auto-created checklists while soft-deleted
        try {
            await crossReferenceService.removeDocumentIssuesFromChecklists(userId, req.params.id);
        } catch (syncErr) {
            console.warn(`[SoftDeleteDocument] Warning: Checklist cleanup error:`, syncErr.message);
        }

        res.json({ message: 'Document moved to Recycle Bin', id: req.params.id, isDeleted: true, deletedAt: doc.deletedAt });
    } catch (error) {
        console.error('Error deleting document:', error);
        res.status(500).json({ error: 'Failed to delete document. Please try again.' });
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
        res.status(500).json({ error: 'Failed to explain snippet. Please try again.' });
    }
});

module.exports = router;