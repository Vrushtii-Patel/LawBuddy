const mongoose = require('mongoose');

const materialChangeSchema = new mongoose.Schema({
    category: { 
        type: String, 
        enum: [
            'Duration / Deadline',
            'Monetary / Payment Schedule',
            'Obligation / Permission (shall/may)',
            'Liability / Indemnity / Penalty',
            'Condition / Disclaimer',
            'Party Role / Rights',
            'Statutory / Jurisdiction Reference',
            'General Text'
        ],
        required: true 
    },
    changeDescription: { type: String, required: true },
    fromText: { type: String, default: '' },
    toText: { type: String, default: '' }
}, { _id: false });

const structuredCitationSchema = new mongoose.Schema({
    lawSnippetId: { type: mongoose.Schema.Types.ObjectId, ref: 'LawSnippet', default: null },
    actName: { type: String, required: true },
    sectionOrRule: { type: String, required: true },
    provisionTitle: { type: String, default: '' },
    sourceUrl: { type: String, default: '' },
    similarityScore: { type: Number, default: 0.0 }
}, { _id: false });

const clauseComparisonSchema = new mongoose.Schema({
    clausePairId: { type: String, required: true },
    
    // Version A
    clauseIdA: { type: String, default: null },
    titleA: { type: String, default: '' },
    textA: { type: String, default: '' },
    sourcePagesA: [{ type: Number }],
    riskLevelA: { type: String, enum: ['HIGH_RISK', 'CAUTION', 'COMPLIANT', 'UNASSESSED', null], default: null },
    
    // Version B
    clauseIdB: { type: String, default: null },
    titleB: { type: String, default: '' },
    textB: { type: String, default: '' },
    sourcePagesB: [{ type: Number }],
    riskLevelB: { type: String, enum: ['HIGH_RISK', 'CAUTION', 'COMPLIANT', 'UNASSESSED', null], default: null },
    
    // Matching & Classification
    matchConfidence: { type: String, enum: ['EXACT', 'HIGH', 'MEDIUM', 'LOW', 'NONE'], required: true },
    changeStatus: { type: String, enum: ['UNCHANGED', 'MODIFIED', 'ADDED', 'REMOVED', 'SPLIT', 'MERGED'], required: true },
    similarityScore: { type: Number, default: 1.0 },
    
    // Findings & Analysis
    materialChangesDetected: [materialChangeSchema],
    buyerImpact: { type: String, default: '' },
    legalFinding: { type: String, default: '' },
    riskMigration: { 
        type: String, 
        enum: ['ESCALATED_RISK', 'REDUCED_RISK', 'UNCHANGED_RISK', 'NEW_RISK_ADDED', 'RISK_REMOVED', 'NO_ADVERSE_RISK_IDENTIFIED'], 
        default: 'UNCHANGED_RISK' 
    },
    statutoryCitations: [structuredCitationSchema],
    buyerConsiderations: { type: String, default: '' }
}, { _id: false });

const documentComparisonSchema = new mongoose.Schema({
    comparisonId: { type: String, required: true, unique: true, index: true },
    userId: { type: String, required: true, index: true },
    
    docAId: { type: mongoose.Schema.Types.ObjectId, ref: 'Document', default: null },
    fileHashA: { type: String, required: true },
    titleA: { type: String, required: true },
    
    docBId: { type: mongoose.Schema.Types.ObjectId, ref: 'Document', default: null },
    fileHashB: { type: String, required: true },
    titleB: { type: String, required: true },
    
    comparisonHash: { type: String, required: true, index: true },
    
    status: { 
        type: String, 
        enum: ['QUEUED', 'RESOLVING_DOCUMENTS', 'MATCHING_CLAUSES', 'DIFFING_CHANGES', 'AI_ANALYSIS', 'REPORT_GENERATION', 'COMPLETED', 'FAILED', 'RETRYING'], 
        default: 'QUEUED',
        index: true
    },
    currentStep: { type: String, default: 'Comparison queued' },
    completedSteps: [{ type: String }],
    
    totalClausesA: { type: Number, default: 0 },
    totalClausesB: { type: Number, default: 0 },
    unchangedCount: { type: Number, default: 0 },
    modifiedCount: { type: Number, default: 0 },
    addedCount: { type: Number, default: 0 },
    removedCount: { type: Number, default: 0 },
    escalatedRiskCount: { type: Number, default: 0 },
    reducedRiskCount: { type: Number, default: 0 },
    
    overallSummary: { type: String, default: '' },
    clauseComparisons: [clauseComparisonSchema],
    
    errorInfo: {
        message: { type: String, default: null },
        stage: { type: String, default: null },
        code: { type: String, default: null },
        isTransient: { type: Boolean, default: false },
        timestamp: { type: Date, default: null }
    },
    
    autoRetriesCount: { type: Number, default: 0 },
    manualRetriesCount: { type: Number, default: 0 },
    lastRetryAt: { type: Date, default: null },
    
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now },
    completedAt: { type: Date, default: null }
});

documentComparisonSchema.index({ userId: 1, comparisonHash: 1 }, { unique: true });

documentComparisonSchema.pre('save', function() {
    this.updatedAt = new Date();
});

module.exports = mongoose.model('DocumentComparison', documentComparisonSchema);
