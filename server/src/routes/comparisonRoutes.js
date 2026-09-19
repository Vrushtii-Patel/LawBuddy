const express = require('express');
const router = express.Router();
const DocumentComparison = require('../models/DocumentComparison');
const comparisonService = require('../services/comparisonService');
const { requireAuth } = require('../middleware/authMiddleware');

// POST /api/comparisons/start - Starts a document comparison
router.post('/comparisons/start', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const { docAId, docBId, fileA, fileB, titleA, titleB } = req.body;

        if (!docAId && !fileA) {
            return res.status(400).json({ error: 'Document A (docAId or fileA) is required.' });
        }
        if (!docBId && !fileB) {
            return res.status(400).json({ error: 'Document B (docBId or fileB) is required.' });
        }

        const comp = await comparisonService.startComparison({
            userId,
            docAId,
            docBId,
            fileA,
            fileB,
            titleA,
            titleB
        });

        // Trigger background processing if not completed
        if (comp.status !== 'COMPLETED') {
            comparisonService.executeComparisonPipeline(comp.comparisonId).catch(err => {
                console.warn(`[Background Comparison ${comp.comparisonId}] Error:`, err.message);
            });
        }

        res.status(201).json({
            comparisonId: comp.comparisonId,
            status: comp.status,
            currentStep: comp.currentStep,
            completedSteps: comp.completedSteps
        });
    } catch (error) {
        console.error('Error starting comparison:', error);
        res.status(500).json({ error: 'Failed to start comparison', details: error.message });
    }
});

// GET /api/comparisons/active - Get latest active comparison
router.get('/comparisons/active', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const activeComp = await DocumentComparison.findOne({
            userId,
            status: { $in: ['QUEUED', 'RESOLVING_DOCUMENTS', 'MATCHING_CLAUSES', 'DIFFING_CHANGES', 'AI_ANALYSIS', 'REPORT_GENERATION', 'RETRYING', 'FAILED'] }
        }).sort({ updatedAt: -1 });

        if (!activeComp) {
            return res.status(200).json({ activeComparison: null });
        }

        res.status(200).json({
            activeComparison: {
                comparisonId: activeComp.comparisonId,
                status: activeComp.status,
                currentStep: activeComp.currentStep,
                completedSteps: activeComp.completedSteps,
                titleA: activeComp.titleA,
                titleB: activeComp.titleB,
                errorInfo: activeComp.errorInfo,
                updatedAt: activeComp.updatedAt
            }
        });
    } catch (error) {
        console.error('Error fetching active comparison:', error);
        res.status(500).json({ error: 'Failed to fetch active comparison' });
    }
});

// GET /api/comparisons/:comparisonId - Get comparison status / report
router.get('/comparisons/:comparisonId', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const comp = await DocumentComparison.findOne({
            comparisonId: req.params.comparisonId,
            userId
        });

        if (!comp) {
            return res.status(404).json({ error: 'Comparison record not found or unauthorized' });
        }

        res.status(200).json(comp);
    } catch (error) {
        console.error('Error fetching comparison:', error);
        res.status(500).json({ error: 'Failed to fetch comparison details' });
    }
});

// POST /api/comparisons/:comparisonId/retry - Retry / Resume comparison
router.post('/comparisons/:comparisonId/retry', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const comp = await DocumentComparison.findOne({
            comparisonId: req.params.comparisonId,
            userId
        });

        if (!comp) {
            return res.status(404).json({ error: 'Comparison record not found or unauthorized' });
        }

        comp.manualRetriesCount = (comp.manualRetriesCount || 0) + 1;
        comp.lastRetryAt = new Date();
        comp.status = 'RETRYING';
        comp.currentStep = 'Resuming comparison...';
        await comp.save();

        comparisonService.executeComparisonPipeline(comp.comparisonId).catch(err => {
            console.warn(`[Background Retry Comparison ${comp.comparisonId}] Error:`, err.message);
        });

        res.status(200).json({
            comparisonId: comp.comparisonId,
            status: comp.status,
            currentStep: comp.currentStep
        });
    } catch (error) {
        console.error('Error retrying comparison:', error);
        res.status(500).json({ error: 'Failed to retry comparison' });
    }
});

// GET /api/comparisons - List user's past comparisons
router.get('/comparisons', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const comparisons = await DocumentComparison.find({ userId })
            .select('comparisonId titleA titleB status unchangedCount modifiedCount addedCount removedCount escalatedRiskCount reducedRiskCount createdAt completedAt')
            .sort({ createdAt: -1 });

        res.status(200).json(comparisons);
    } catch (error) {
        console.error('Error listing comparisons:', error);
        res.status(500).json({ error: 'Failed to list comparisons' });
    }
});

// DELETE /api/comparisons/:comparisonId - Delete a comparison record
router.delete('/comparisons/:comparisonId', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const result = await DocumentComparison.findOneAndDelete({
            comparisonId: req.params.comparisonId,
            userId
        });

        if (!result) {
            return res.status(404).json({ error: 'Comparison not found or unauthorized' });
        }

        res.status(200).json({ success: true, message: 'Comparison deleted successfully' });
    } catch (error) {
        console.error('Error deleting comparison:', error);
        res.status(500).json({ error: 'Failed to delete comparison' });
    }
});

module.exports = router;
