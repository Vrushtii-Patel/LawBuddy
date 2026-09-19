const express = require('express');
const router = express.Router();
const Document = require('../models/Document');
const User = require('../models/User');
const ChatSession = require('../models/ChatSession');
const Checklist = require('../models/Checklist');
const { requireAdmin } = require('../middleware/authMiddleware');

// GET /api/admin/analytics - Aggregated system metrics from real MongoDB records
router.get('/analytics', requireAdmin, async (req, res) => {
    try {
        // 1. Overview KPIs (executed concurrently)
        const [
            totalUsers,
            totalDocumentsAnalyzed,
            totalChatSessions,
            totalChecklists,
            docTotalsAgg,
            docRiskAgg,
            clauseRiskAgg,
            findingCategoriesAgg,
            sourceTypesAgg,
            extractionMethodsAgg,
            recentScansDocs
        ] = await Promise.all([
            User.countDocuments(),
            Document.countDocuments({ analysisStatus: 'completed' }),
            ChatSession.countDocuments(),
            Checklist.countDocuments(),
            
            // Total clauses evaluated and average pages per completed document
            Document.aggregate([
                { $match: { analysisStatus: 'completed' } },
                {
                    $group: {
                        _id: null,
                        totalClauses: { $sum: '$totalClauseCount' },
                        avgPages: { $avg: '$totalPages' }
                    }
                }
            ]),

            // Document-level risk distribution
            Document.aggregate([
                { $match: { analysisStatus: 'completed' } },
                {
                    $group: {
                        _id: '$riskLevel',
                        count: { $sum: 1 }
                    }
                }
            ]),

            // Clause-level risk distribution
            Document.aggregate([
                { $match: { analysisStatus: 'completed' } },
                {
                    $group: {
                        _id: null,
                        highRisk: { $sum: '$highRiskCount' },
                        caution: { $sum: '$cautionCount' },
                        compliant: { $sum: '$compliantCount' }
                    }
                }
            ]),

            // Clause finding category breakdown
            Document.aggregate([
                { $match: { analysisStatus: 'completed' } },
                { $unwind: '$analysis' },
                {
                    $group: {
                        _id: '$analysis.findingCategory',
                        count: { $sum: 1 }
                    }
                },
                { $sort: { count: -1 } }
            ]),

            // Document input source distribution
            Document.aggregate([
                { $match: { analysisStatus: 'completed' } },
                {
                    $group: {
                        _id: '$sourceType',
                        count: { $sum: 1 }
                    }
                },
                { $sort: { count: -1 } }
            ]),

            // Extraction method pipeline distribution
            Document.aggregate([
                { $match: { analysisStatus: 'completed' } },
                {
                    $group: {
                        _id: '$extractionMethod',
                        count: { $sum: 1 }
                    }
                },
                { $sort: { count: -1 } }
            ]),

            // Recent 10 completed analyses (sanitized, excluding private text / credentials)
            Document.find({ analysisStatus: 'completed' })
                .sort({ createdAt: -1 })
                .limit(10)
                .select('_id title riskLevel highRiskCount cautionCount compliantCount totalPages sourceType extractionMethod createdAt')
                .lean()
        ]);

        // Process Overview KPIs
        const docTotals = docTotalsAgg.length > 0 ? docTotalsAgg[0] : { totalClauses: 0, avgPages: 0 };
        const totalClausesEvaluated = docTotals.totalClauses || 0;
        const averagePagesPerDoc = docTotals.avgPages ? Number(docTotals.avgPages.toFixed(1)) : 0;

        // Process Document-Level Risk Breakdown
        const documentLevelRisk = {
            highRisk: 0,
            mediumRisk: 0,
            lowRisk: 0
        };
        docRiskAgg.forEach(item => {
            if (item._id === 'High Risk') documentLevelRisk.highRisk = item.count;
            else if (item._id === 'Medium Risk') documentLevelRisk.mediumRisk = item.count;
            else if (item._id === 'Low Risk') documentLevelRisk.lowRisk = item.count;
        });

        // Process Clause-Level Risk Breakdown
        const clauseRiskTotals = clauseRiskAgg.length > 0 ? clauseRiskAgg[0] : { highRisk: 0, caution: 0, compliant: 0 };
        const clauseLevelRisk = {
            highRisk: clauseRiskTotals.highRisk || 0,
            caution: clauseRiskTotals.caution || 0,
            compliant: clauseRiskTotals.compliant || 0
        };

        // Process Finding Categories
        const findingCategories = findingCategoriesAgg
            .filter(item => item._id) // filter out null/empty categories if any
            .map(item => ({
                category: String(item._id),
                count: item.count
            }));

        // Process Source Types
        const sourceDistribution = sourceTypesAgg
            .filter(item => item._id)
            .map(item => ({
                sourceType: String(item._id),
                count: item.count
            }));

        // Process Extraction Methods
        const extractionMethods = extractionMethodsAgg
            .filter(item => item._id)
            .map(item => ({
                method: String(item._id),
                count: item.count
            }));

        // Process Recent Scans
        const recentScans = recentScansDocs.map(doc => ({
            id: doc._id.toString(),
            title: doc.title || 'Untitled Document',
            riskLevel: doc.riskLevel || 'Low Risk',
            highRiskCount: doc.highRiskCount || 0,
            cautionCount: doc.cautionCount || 0,
            compliantCount: doc.compliantCount || 0,
            totalPages: doc.totalPages || 1,
            sourceType: doc.sourceType || 'PDF Document',
            extractionMethod: doc.extractionMethod || 'digital_pdf_text',
            createdAt: doc.createdAt
        }));

        res.status(200).json({
            overview: {
                totalUsers,
                totalDocumentsAnalyzed,
                totalClausesEvaluated,
                averagePagesPerDoc,
                totalChatSessions,
                totalChecklists
            },
            riskDistribution: {
                documentLevel: documentLevelRisk,
                clauseLevel: clauseLevelRisk
            },
            findingCategories,
            sourceDistribution,
            extractionMethods,
            recentScans
        });
    } catch (error) {
        console.error('Error computing admin analytics:', error);
        res.status(500).json({ error: 'Failed to compute admin analytics', details: error.message });
    }
});

module.exports = router;
