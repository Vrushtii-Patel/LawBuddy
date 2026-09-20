const mongoose = require('mongoose');

const sharedClauseItemSchema = new mongoose.Schema({
    clauseId: { type: String, default: '' },
    title: { type: String, default: '', maxlength: 300 },
    text: { type: String, default: '', maxlength: 4000 },
    category: { type: String, default: 'Green' },
    riskLevel: { 
        type: String, 
        enum: ['HIGH_RISK', 'CAUTION', 'COMPLIANT'], 
        default: 'COMPLIANT' 
    },
    findingCategory: { 
        type: String, 
        default: 'No material issue identified',
        maxlength: 200
    },
    reason: { type: String, default: '', maxlength: 4000 },
    legalFinding: { type: String, default: '', maxlength: 4000 },
    statutoryCitations: [{ type: String, maxlength: 300 }],
    reraReferences: [{ type: String, maxlength: 300 }],
    buyerImpact: { type: String, default: '', maxlength: 4000 },
    recommendation: { type: String, default: '', maxlength: 4000 },
    sourcePages: [{ type: Number }]
}, { _id: false });

const sharedAnalysisSchema = new mongoose.Schema({
    shareToken: { 
        type: String, 
        required: true, 
        unique: true, 
        index: true,
        trim: true
    },
    userId: { 
        type: String, 
        default: null,
        index: true 
    },
    documentId: { 
        type: mongoose.Schema.Types.ObjectId, 
        ref: 'Document',
        default: null 
    },
    title: { 
        type: String, 
        required: true, 
        trim: true, 
        maxlength: 300,
        default: 'Property Legal Risk Summary' 
    },
    riskLevel: { 
        type: String, 
        enum: ['High Risk', 'Medium Risk', 'Low Risk'], 
        default: 'Low Risk' 
    },
    highRiskCount: { type: Number, default: 0, min: 0 },
    cautionCount: { type: Number, default: 0, min: 0 },
    compliantCount: { type: Number, default: 0, min: 0 },
    totalClauseCount: { type: Number, default: 0, min: 0 },
    riskScore: { type: Number, default: null },
    
    // Sanitized analysis items (max 150 items)
    analysis: [sharedClauseItemSchema],
    
    createdAt: { 
        type: Date, 
        default: Date.now,
        index: true 
    },
    expiresAt: { 
        type: Date, 
        default: () => new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
    },
    viewCount: { 
        type: Number, 
        default: 0 
    }
});

// TTL index to automatically purge expired records if desired
sharedAnalysisSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('SharedAnalysis', sharedAnalysisSchema);
