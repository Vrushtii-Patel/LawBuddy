const mongoose = require('mongoose');

const clauseSchema = new mongoose.Schema({
    clauseId: { type: String, required: true },
    text: { type: String, required: true },
    title: { type: String, default: '' },
    sourcePages: [{ type: Number }],
    categoryHint: { type: String, default: '' }
}, { _id: false });

const analysisItemSchema = new mongoose.Schema({
    clauseId: { type: String, required: true },
    title: { type: String, default: '' },
    text: { type: String, required: true },
    category: { type: String, enum: ['Red', 'Yellow', 'Green'], default: 'Green' }, // Backward-compatible
    riskLevel: { type: String, enum: ['HIGH_RISK', 'CAUTION', 'COMPLIANT'], default: 'COMPLIANT' },
    findingCategory: { 
        type: String, 
        enum: [
            'Confirmed statutory violation',
            'Potential legal concern',
            'Contractual risk',
            'Documentation/title concern',
            'Applicability uncertain',
            'No material issue identified'
        ],
        default: 'No material issue identified'
    },
    reason: { type: String, default: '' },
    legalFinding: { type: String, default: '' },
    statutoryCitations: [{ type: String }],
    reraReferences: [{ type: String }],
    buyerImpact: { type: String, default: '' },
    recommendation: { type: String, default: '' },
    sourcePages: [{ type: Number }]
}, { _id: false });

const pageClassificationSchema = new mongoose.Schema({
    page: { type: Number, required: true },
    classification: { 
        type: String, 
        enum: ['substantive legal content', 'administrative/supporting document', 'annexure', 'irrelevant/non-legal'],
        default: 'substantive legal content'
    },
    hasContent: { type: Boolean, default: false }
}, { _id: false });

const documentSchema = new mongoose.Schema({
    userId: { type: String, required: true, index: true },
    fileHash: { type: String, required: true, index: true }, // SHA-256 hex string
    title: { type: String, required: true },
    originalText: { type: String, required: true },
    sourceType: { type: String, default: 'PDF Document' }, // 'PDF Document', 'Photo Scan', 'Text Description'
    mimeType: { type: String, default: 'text/plain' },
    fileData: { type: String, default: null }, // Base64 string of original uploaded file/photo
    fileName: { type: String, default: '' },
    docSize: { type: String, default: '1.2 MB' },
    
    // Page Coverage & Classification Metadata
    totalPages: { type: Number, default: 1 },
    pagesProcessed: { type: Number, default: 1 },
    pageClassifications: [pageClassificationSchema],

    // Extraction and Canonical Segmentation metadata
    extractionMethod: { 
        type: String, 
        enum: ['digital_pdf_text', 'direct_ocr', 'scanned_pdf_vision', 'raw_text'],
        default: 'digital_pdf_text' 
    },
    extractedNormalizedText: { type: String, default: '' },
    canonicalClauses: [clauseSchema],
    
    // Risk Analysis & Breakdown
    analysis: [analysisItemSchema],
    riskLevel: { 
        type: String, 
        enum: ['Low Risk', 'Medium Risk', 'High Risk'], 
        default: 'Low Risk' 
    },
    highRiskCount: { type: Number, default: 0 },
    cautionCount: { type: Number, default: 0 },
    compliantCount: { type: Number, default: 0 },
    totalClauseCount: { type: Number, default: 0 },
    
    // Pipeline Model & Execution Metadata
    modelName: { type: String, default: 'gemini-3.6-flash' },
    modelVersion: { type: String, default: 'latest' },
    promptVersion: { type: String, default: 'v1.0.0' },
    analysisVersion: { type: String, default: 'v1.0.0' },
    temperature: { type: Number, default: 0.0 },
    
    // Analysis Processing Status
    analysisStatus: { 
        type: String, 
        enum: ['processing', 'completed', 'failed'], 
        default: 'completed',
        index: true
    },
    
    // Soft-Delete / Recycle Bin Metadata
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: { type: Date, default: null, index: true },

    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now }
});

// Compound index for active document queries and user-isolated SHA-256 caching
documentSchema.index({ userId: 1, isDeleted: 1, createdAt: -1 });
documentSchema.index({ userId: 1, fileHash: 1, isDeleted: 1 });

module.exports = mongoose.model('Document', documentSchema);
