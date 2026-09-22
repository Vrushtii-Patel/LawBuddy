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
    category: { type: String, enum: ['Red', 'Yellow', 'Green'], default: 'Green' },
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

const scanJobSchema = new mongoose.Schema({
    jobId: { type: String, required: true, unique: true, index: true },
    userId: { type: String, required: true, index: true },
    fileHash: { type: String, required: true, index: true }, // SHA-256 hex string

    // Lightweight file reference metadata (NO large Base64 blobs stored in MongoDB)
    title: { type: String, default: 'Property Legal Agreement' },
    fileName: { type: String, default: '' },
    sourceType: { type: String, default: 'PDF Document' }, // 'PDF Document', 'Photo Scan', 'Text Description', 'Scanned Image'
    mimeType: { type: String, default: 'application/pdf' },
    storagePath: { type: String, default: null }, // Relative path on disk (e.g. uploads/scan_files/hash.dat)
    fileSize: { type: Number, default: 0 },

    // Explicit Pipeline Status & Step Tracking
    status: {
        type: String,
        enum: [
            'QUEUED',
            'UPLOADING',
            'OCR_PROCESSING',
            'TEXT_EXTRACTED',
            'AI_ANALYSIS',
            'REPORT_GENERATION',
            'COMPLETED',
            'FAILED',
            'RETRYING'
        ],
        default: 'QUEUED',
        index: true
    },
    currentStep: { type: String, default: 'Scan queued' },
    completedSteps: [{ 
        type: String, 
        enum: ['UPLOAD', 'TEXT_EXTRACTION', 'AI_ANALYSIS', 'REPORT'] 
    }],

    // Intermediate Persisted Outputs
    extractedText: { type: String, default: '' },
    canonicalClauses: [clauseSchema],
    analysis: [analysisItemSchema],

    // Final Document Reference (when COMPLETED)
    documentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Document', default: null },

    // Explicit Error & Retry Tracking
    errorInfo: {
        message: { type: String, default: null },
        stage: { type: String, default: null },
        code: { type: String, default: null },
        isTransient: { type: Boolean, default: false },
        timestamp: { type: Date, default: null }
    },
    autoRetriesCount: { type: Number, default: 0 },
    maxAutoRetries: { type: Number, default: 3 },
    manualRetriesCount: { type: Number, default: 0 },
    lastRetryAt: { type: Date, default: null },

    createdAt: { type: Date, default: Date.now, index: true },
    updatedAt: { type: Date, default: Date.now, index: true },
    completedAt: { type: Date, default: null }
}, { versionKey: false });

// Auto-update updatedAt on save
scanJobSchema.pre('save', function() {
    this.updatedAt = new Date();
});

module.exports = mongoose.model('ScanJob', scanJobSchema);
