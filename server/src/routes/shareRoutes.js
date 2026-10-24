const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const SharedAnalysis = require('../models/SharedAnalysis');
const Document = require('../models/Document');
const { requireAuth } = require('../middleware/authMiddleware');
const { createShareLimiter } = require('../middleware/rateLimitMiddleware');

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

// Helper: Sanitize one analysis item (used for both client-supplied and stored analysis)
function sanitizeAnalysisItem(item) {
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
}

const MAX_SHARED_CLAUSES = 150;
const MAX_TOTAL_TEXT_BYTES = 200 * 1024; // 200 KB max text across all clauses

// =========================================================================
// POST /api/shares - Create a secure, read-only share token for an analysis
// Strictly requires authentication and rate limiting.
// =========================================================================
router.post('/shares', requireAuth, createShareLimiter, async (req, res) => {
    try {
        const {
            documentId,
            title,
            riskLevel,
            riskScore,
            analysis
        } = req.body || {};

        const userId = req.user.userId;
        let finalTitle = cleanString(title, 300) || 'Property Legal Risk Summary';
        let finalRiskLevel = normalizeOverallRisk(riskLevel);
        let finalAnalysis = [];
        let verifiedDocId = null;

        // Cap clause count
        if (Array.isArray(analysis) && analysis.length > MAX_SHARED_CLAUSES) {
            return res.status(400).json({
                error: `Too many clauses provided. Maximum allowed is ${MAX_SHARED_CLAUSES}.`
            });
        }

        // If a documentId is provided, it must belong to the authenticated caller.
        if (documentId) {
            if (typeof documentId !== 'string' || !documentId.match(/^[0-9a-fA-F]{24}$/)) {
                return res.status(400).json({ error: 'Invalid document ID format.' });
            }
            try {
                const doc = await Document.findOne({ _id: documentId, userId, isDeleted: { $ne: true } });
                if (!doc) {
                    return res.status(404).json({ error: 'Document not found or access denied.' });
                }
                verifiedDocId = doc._id;
                if (!title) finalTitle = doc.title || finalTitle;
                if (!riskLevel) finalRiskLevel = doc.riskLevel || finalRiskLevel;
                if (doc.analysis && Array.isArray(doc.analysis) && (!analysis || !analysis.length)) {
                    finalAnalysis = doc.analysis.slice(0, MAX_SHARED_CLAUSES).map(sanitizeAnalysisItem);
                }
            } catch (err) {
                console.warn('[Share] Document lookup non-fatal error:', err.message);
                return res.status(500).json({ error: 'Failed to verify document ownership.' });
            }
        }

        // If client provided analysis items directly, sanitize and validate them
        if (Array.isArray(analysis) && analysis.length > 0) {
            finalAnalysis = analysis.slice(0, MAX_SHARED_CLAUSES).map(sanitizeAnalysisItem);
        }

        // Cap total content size across clauses to protect storage
        let totalTextLength = 0;
        for (const item of finalAnalysis) {
            totalTextLength += (item.text || '').length + (item.reason || '').length + (item.legalFinding || '').length;
        }
        if (totalTextLength > MAX_TOTAL_TEXT_BYTES) {
            return res.status(400).json({ error: 'Analysis content exceeds the maximum allowed size.' });
        }

        // One source for the counts: the clauses that are actually stored in the share.
        const finalHighRisk = finalAnalysis.filter(c => c.riskLevel === 'HIGH_RISK').length;
        const finalCaution = finalAnalysis.filter(c => c.riskLevel === 'CAUTION').length;
        const finalCompliant = finalAnalysis.filter(c => c.riskLevel === 'COMPLIANT').length;
        const finalTotal = finalAnalysis.length;

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
            isRevoked: false,
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
// GET /api/shares - List active shares created by the authenticated user
// =========================================================================
router.get('/shares', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const shares = await SharedAnalysis.find({
            userId,
            isRevoked: { $ne: true },
            expiresAt: { $gt: new Date() }
        })
        .select('shareToken documentId title riskLevel riskScore highRiskCount cautionCount compliantCount totalClauseCount viewCount createdAt expiresAt')
        .sort({ createdAt: -1 });

        res.json(shares);
    } catch (error) {
        console.error('Error listing shares:', error);
        res.status(500).json({ error: 'Failed to retrieve your shared links' });
    }
});

// =========================================================================
// DELETE /api/shares/:token - Revoke a shared analysis link
// =========================================================================
router.delete('/shares/:token', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const token = cleanString(req.params.token, 64);

        if (!/^[a-f0-9]{32}$/i.test(token)) {
            return res.status(404).json({ error: 'Share link not found' });
        }

        const share = await SharedAnalysis.findOne({ shareToken: token, userId });
        if (!share) {
            return res.status(404).json({ error: 'Share link not found or unauthorized' });
        }

        await SharedAnalysis.deleteOne({ _id: share._id });
        res.json({ message: 'Share link revoked successfully', shareToken: token });
    } catch (error) {
        console.error('Error revoking share link:', error);
        res.status(500).json({ error: 'Failed to revoke share link' });
    }
});

// POST /api/shares/:token/revoke - Alternative revocation route
router.post('/shares/:token/revoke', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const token = cleanString(req.params.token, 64);

        if (!/^[a-f0-9]{32}$/i.test(token)) {
            return res.status(404).json({ error: 'Share link not found' });
        }

        const share = await SharedAnalysis.findOne({ shareToken: token, userId });
        if (!share) {
            return res.status(404).json({ error: 'Share link not found or unauthorized' });
        }

        await SharedAnalysis.deleteOne({ _id: share._id });
        res.json({ message: 'Share link revoked successfully', shareToken: token });
    } catch (error) {
        console.error('Error revoking share link:', error);
        res.status(500).json({ error: 'Failed to revoke share link' });
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

        const sharedDoc = await SharedAnalysis.findOne({
            shareToken: token,
            isRevoked: { $ne: true }
        });
        if (!sharedDoc) {
            return res.status(404).json({ error: 'Share link not found or has expired' });
        }

        // Check expiration
        if (sharedDoc.expiresAt && new Date(sharedDoc.expiresAt) < new Date()) {
            return res.status(404).json({ error: 'Share link not found or has expired' });
        }

        // If this share is linked to a document, verify that the document was not soft-deleted or deleted
        if (sharedDoc.documentId) {
            const parentDoc = await Document.findById(sharedDoc.documentId);
            if (!parentDoc || parentDoc.isDeleted) {
                // Asynchronously delete the orphaned share
                SharedAnalysis.deleteOne({ _id: sharedDoc._id }).catch(() => {});
                return res.status(404).json({ error: 'Share link not found or has expired' });
            }
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