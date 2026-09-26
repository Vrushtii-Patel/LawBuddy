const mongoose = require('mongoose');

const linkedIssueSchema = new mongoose.Schema({
    documentId: { type: String, required: true },
    documentTitle: { type: String, default: 'Uploaded Document' },
    clauseId: { type: String, required: true },
    clauseTitle: { type: String, default: '' },
    riskLevel: { type: String, enum: ['HIGH_RISK', 'CAUTION', 'COMPLIANT'], default: 'HIGH_RISK' },
    findingCategory: { type: String, default: '' },
    reason: { type: String, default: '' },
    legalFinding: { type: String, default: '' },
    statutoryCitations: [{ type: String }],
    reraReferences: [{ type: String }],
    buyerImpact: { type: String, default: '' },
    recommendation: { type: String, default: '' },
    flaggedAt: { type: Date, default: Date.now }
}, { _id: true });

const checklistItemSchema = new mongoose.Schema({
    id: { type: String, required: true },
    title: { type: String, required: true },
    isCompleted: { type: Boolean, default: false },
    status: { 
        type: String, 
        enum: ['NOT_STARTED', 'FLAGGED', 'VERIFIED'], 
        default: 'NOT_STARTED' 
    },
    linkedIssues: [linkedIssueSchema]
}, { _id: true });

const checklistSchema = new mongoose.Schema({
    userId: { type: String, required: true, index: true },
    type: { type: String, required: true }, // e.g., 'buying-resale'
    title: { type: String, required: true },
    items: [checklistItemSchema],
    // Soft-Delete / Recycle Bin Metadata
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: { type: Date, default: null, index: true },

    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
});

// Ensure a user can only have one active checklist of each type, and index active checklist queries
checklistSchema.index({ userId: 1, type: 1 }, { unique: true, partialFilterExpression: { isDeleted: false } });
checklistSchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });
checklistSchema.index({ userId: 1, isDeleted: 1, updatedAt: -1 });

module.exports = mongoose.model('Checklist', checklistSchema);
