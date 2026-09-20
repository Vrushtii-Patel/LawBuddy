const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const SharedAnalysis = require('../models/SharedAnalysis');
const Document = require('../models/Document');
const { optionalAuth } = require('../middleware/authMiddleware');

// Helper: Sanitize string
function cleanString(val, maxLen = 300) {
    if (val === undefined || val === null) return '';
    const str = String(val).trim();
    return str.slice(0, maxLen);
}

// Helper: Sanitize array of strings
function cleanStringArray(arr, maxItems = 20, maxLen = 300) {
    if (!Array.isArray(arr)) return [];
    return arr
        .slice(0, maxItems)
        .map(item => cleanString(item, maxLen))
        .filter(item => item.length > 0);
}

// Helper: Normalize Risk Level enum for document
function normalizeOverallRisk(risk) {
    const clean = cleanString(risk, 50).toLowerCase();
    if (clean.includes('high')) return 'High Risk';
    if (clean.includes('caution') || clean.includes('medium') || clean.includes('yellow')) return 'Medium Risk';
    return 'Low Risk';
}

// Helper: Normalize Clause Risk Level enum
function normalizeClauseRisk(riskLevel, category) {
    const r = (cleanString(riskLevel, 50) || cleanString(category, 50)).toUpperCase();
    if (r.includes('HIGH') || r.includes('RED')) return 'HIGH_RISK';
    if (r.includes('CAUTION') || r.includes('YELLOW') || r.includes('MEDIUM')) return 'CAUTION';
    return 'COMPLIANT';
}

// =========================================================================
// POST /api/shares - Create a secure, read-only share token for an analysis
// =========================================================================
router.post('/shares', optionalAuth, async (req, res) => {
    try {
        const {
            documentId,
            title,
            riskLevel,
            riskScore,
            highRiskCount,
            cautionCount,
            compliantCount,
            totalClauseCount,
            analysis
        } = req.body;

        const userId = req.user ? req.user.userId : null;
        let finalTitle = cleanString(title, 300) || 'Property Legal Risk Summary';
        let finalRiskLevel = normalizeOverallRisk(riskLevel);
        let finalAnalysis = [];
        let finalHighRisk = Number.isInteger(highRiskCount) && highRiskCount >= 0 ? highRiskCount : 0;
        let finalCaution = Number.isInteger(cautionCount) && cautionCount >= 0 ? cautionCount : 0;
        let finalCompliant = Number.isInteger(compliantCount) && compliantCount >= 0 ? compliantCount : 0;
        let finalTotal = Number.isInteger(totalClauseCount) && totalClauseCount >= 0 ? totalClauseCount : 0;
        let verifiedDocId = null;

        // If a documentId is provided, it must belong to the authenticated caller.
        // Without this check, anyone who knows or guesses another user's document
        // ID could generate a public share link exposing that user's private
        // analysis — regardless of whether the requester is even logged in.
        if (documentId && typeof documentId === 'string' && documentId.match(/^[0-9a-fA-F]{24}$/)) {
            if (!userId) {
                return res.status(401).json({ error: 'Authentication required to share a saved document.' });
            }
            try {
                const doc = await Document.findOne({ _id: documentId, userId });
                if (!doc) {
                    return res.status(403).json({ error: 'You do not have access to this document.' });
                }
                verifiedDocId = doc._id;
                if (!title) finalTitle = doc.title || finalTitle;
                if (!riskLevel) finalRiskLevel = doc.riskLevel || finalRiskLevel;
                if (doc.analysis && Array.isArray(doc.analysis) && (!analysis || !analysis.length)) {
                    finalAnalysis = doc.analysis;
                }
                if (doc.highRiskCount !== undefined) finalHighRisk = doc.highRiskCount;
                if (doc.cautionCount !== undefined) finalCaution = doc.cautionCount;
                if (doc.compliantCount !== undefined) finalCompliant = doc.compliantCount;
                if (doc.totalClauseCount !== undefined) finalTotal = doc.totalClauseCount;
            } catch (err) {
                console.warn('[Share] Document lookup non-fatal error:', err.message);
                return res.status(500).json({ error: 'Failed to verify document ownership.' });
            }
        }

        // If client provided analysis items directly, sanitize and validate them
        if (Array.isArray(analysis) && analysis.length > 0) {
            finalAnalysis = analysis.slice(0, 150).map(item => {
                const cRisk = normalizeClauseRisk(item.riskLevel, item.category);
                return {
                    clauseId: cleanString(item.clauseId, 100) || '',
                    title: cleanString(item.title, 300) || '',
                    text: cleanString(item.text, 4000) || '',
                    category: cleanString(item.category, 50) || (cRisk === 'HIGH_RISK' ? 'Red' : cRisk === 'CAUTION' ? 'Yellow' : 'Green'),
                    riskLevel: cRisk,
                    findingCategory: cleanString(item.findingCategory, 200) || 'No material issue identified',
                    reason: cleanString(item.reason, 4000) || '',
                    legalFinding: cleanString(item.legalFinding, 4000) || '',
                    statutoryCitations: cleanStringArray(item.statutoryCitations, 20, 300),
                    reraReferences: cleanStringArray(item.reraReferences, 20, 300),
                    buyerImpact: cleanString(item.buyerImpact, 4000) || '',
                    recommendation: cleanString(item.recommendation, 4000) || '',
                    sourcePages: Array.isArray(item.sourcePages)
                        ? item.sourcePages.filter(p => Number.isInteger(p)).slice(0, 20)
                        : []
                };
            });

            // Recalculate counts if not set
            if (finalTotal === 0) {
                finalHighRisk = finalAnalysis.filter(c => c.riskLevel === 'HIGH_RISK').length;
                finalCaution = finalAnalysis.filter(c => c.riskLevel === 'CAUTION').length;
                finalCompliant = finalAnalysis.filter(c => c.riskLevel === 'COMPLIANT').length;
                finalTotal = finalAnalysis.length;
            }
        }

        // Generate 32-character cryptographically secure hex token
        const shareToken = crypto.randomBytes(16).toString('hex');

        // Create SharedAnalysis record
        const sharedRecord = await SharedAnalysis.create({
            shareToken,
            userId,
            documentId: verifiedDocId,
            title: finalTitle,
            riskLevel: finalRiskLevel,
            riskScore: typeof riskScore === 'number' ? riskScore : null,
            highRiskCount: finalHighRisk,
            cautionCount: finalCaution,
            compliantCount: finalCompliant,
            totalClauseCount: finalTotal,
            analysis: finalAnalysis,
            createdAt: new Date(),
            expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
        });

        res.status(201).json({
            success: true,
            shareToken: sharedRecord.shareToken,
            expiresAt: sharedRecord.expiresAt
        });
    } catch (error) {
        console.error('Error creating shared analysis:', error);
        res.status(500).json({ error: 'Failed to generate share link' });
    }
});

// =========================================================================
// GET /api/shares/:token - Public read-only retrieval of shared analysis
// =========================================================================
router.get('/shares/:token', async (req, res) => {
    try {
        const token = cleanString(req.params.token, 64);

        // Ensure token format matches 32-character hex pattern
        if (!/^[a-f0-9]{32}$/i.test(token)) {
            return res.status(404).json({ error: 'Share link not found or has expired' });
        }

        const sharedDoc = await SharedAnalysis.findOne({ shareToken: token });
        if (!sharedDoc) {
            return res.status(404).json({ error: 'Share link not found or has expired' });
        }

        // Check expiration
        if (sharedDoc.expiresAt && new Date(sharedDoc.expiresAt) < new Date()) {
            return res.status(404).json({ error: 'Share link not found or has expired' });
        }

        // Increment view count asynchronously
        SharedAnalysis.updateOne({ _id: sharedDoc._id }, { $inc: { viewCount: 1 } }).catch(err => {
            console.warn('[Share] View count increment non-fatal error:', err.message);
        });

        // Return strictly sanitized read-only representation (no userId, no documentId, no internal IDs)
        res.json({
            title: sharedDoc.title,
            riskLevel: sharedDoc.riskLevel,
            riskScore: sharedDoc.riskScore,
            highRiskCount: sharedDoc.highRiskCount,
            cautionCount: sharedDoc.cautionCount,
            compliantCount: sharedDoc.compliantCount,
            totalClauseCount: sharedDoc.totalClauseCount,
            analysis: sharedDoc.analysis,
            createdAt: sharedDoc.createdAt,
            expiresAt: sharedDoc.expiresAt
        });
    } catch (error) {
        console.error('Error retrieving shared analysis:', error);
        res.status(500).json({ error: 'Failed to retrieve shared summary' });
    }
});

module.exports = router;