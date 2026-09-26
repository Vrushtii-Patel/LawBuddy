const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const pdfParse = require('pdf-parse');
const ScanJob = require('../models/ScanJob');
const Document = require('../models/Document');
const llmService = require('./llmService');
const crossReferenceService = require('./crossReferenceService');

const UPLOADS_DIR = path.join(__dirname, '../../uploads/scan_files');

// In-memory set of currently processing "userId:fileHash" keys to prevent redundant concurrent pipeline executions
const activeProcessingKeys = new Set();

function ensureUploadsDirectory() {
    if (!fs.existsSync(UPLOADS_DIR)) {
        fs.mkdirSync(UPLOADS_DIR, { recursive: true });
    }
}

/**
 * Saves file buffer to disk under uploads/scan_files/${fileHash}.dat
 * Returns the relative storage path.
 */
function saveFileToStorage(buffer, fileHash) {
    ensureUploadsDirectory();
    const relativePath = path.join('uploads/scan_files', `${fileHash}.dat`).replace(/\\/g, '/');
    const absolutePath = path.join(UPLOADS_DIR, `${fileHash}.dat`);
    if (!fs.existsSync(absolutePath)) {
        fs.writeFileSync(absolutePath, buffer);
    }
    return relativePath;
}

/**
 * Reads file buffer from storage path.
 */
function readFileFromStorage(storagePath) {
    if (!storagePath) return null;
    const absolutePath = path.isAbsolute(storagePath)
        ? storagePath
        : path.join(__dirname, '../../', storagePath);
    if (fs.existsSync(absolutePath)) {
        return fs.readFileSync(absolutePath);
    }
    return null;
}

/**
 * Determines if an error is transient (eligible for automatic retry).
 */
function isTransientError(error) {
    if (!error) return false;
    const msg = (error.message || '').toLowerCase();
    const status = error.status || error.statusCode || 0;
    return (
        status === 429 ||
        status === 503 ||
        status === 504 ||
        msg.includes('429') ||
        msg.includes('503') ||
        msg.includes('504') ||
        msg.includes('rate limit') ||
        msg.includes('resource exhausted') ||
        msg.includes('quota') ||
        msg.includes('timeout') ||
        msg.includes('econnreset') ||
        msg.includes('etimedout') ||
        msg.includes('network')
    );
}

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * Validates whether a cached Document record is strictly up-to-date.
 * A cached record is valid ONLY when:
 * 1. It belongs to the requested user and fileHash.
 * 2. Its analysis status is 'completed' with non-empty findings.
 * 3. Its promptVersion strictly matches current llmService.PROMPT_VERSION.
 * 4. Its modelName strictly matches current llmService.MODEL_NAME.
 * 5. Its analysisVersion matches llmService.ANALYSIS_VERSION (if defined).
 * Legacy records lacking version metadata are safely treated as outdated.
 */
function isDocumentCacheValid(doc) {
    if (!doc) return false;
    if (doc.analysisStatus !== 'completed') return false;
    if (!Array.isArray(doc.analysis) || doc.analysis.length === 0) return false;
    if (!doc.promptVersion || doc.promptVersion !== llmService.PROMPT_VERSION) return false;
    if (!doc.modelName || doc.modelName !== llmService.MODEL_NAME) return false;
    if (llmService.ANALYSIS_VERSION && (!doc.analysisVersion || doc.analysisVersion !== llmService.ANALYSIS_VERSION)) {
        return false;
    }
    return true;
}

/**
 * Creates and initializes a persistent ScanJob record with version-aware caching
 * and duplicate concurrent job safeguards.
 */
async function createScanJob({
    userId,
    text,
    fileBuffer: inputBuffer,
    base64Data,
    fileName = '',
    mimeType = 'application/pdf',
    title = '',
    sourceType = 'PDF Document'
}) {
    if (!userId) {
        throw new Error('userId is required to create a scan job.');
    }

    let fileHash = '';
    let fileBuffer = null;
    let storagePath = null;
    let fileSize = 0;

    if (Buffer.isBuffer(inputBuffer) && inputBuffer.length > 0) {
        fileBuffer = inputBuffer;
        fileSize = fileBuffer.length;
        fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
        storagePath = saveFileToStorage(fileBuffer, fileHash);
    } else if (base64Data && typeof base64Data === 'string' && base64Data.trim().length > 0) {
        let clean = base64Data.trim();
        if (clean.includes(',')) clean = clean.split(',').pop().trim();
        clean = clean.replace(/\s+/g, '');
        fileBuffer = Buffer.from(clean, 'base64');
        fileSize = fileBuffer.length;
        fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
        storagePath = saveFileToStorage(fileBuffer, fileHash);
    } else if (text && typeof text === 'string' && text.trim().length > 0) {
        const norm = llmService.normalizeDocumentText(text);
        fileSize = Buffer.byteLength(norm, 'utf8');
        fileHash = crypto.createHash('sha256').update(norm).digest('hex');
    } else {
        throw new Error('Either valid text or document file is required.');
    }

    // Version-aware cache query: match user, hash, completed status, prompt version, and model
    const existingDoc = await Document.findOne({
        userId,
        fileHash,
        analysisStatus: 'completed',
        promptVersion: llmService.PROMPT_VERSION,
        modelName: llmService.MODEL_NAME
    });

    const jobId = `job_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

    if (isDocumentCacheValid(existingDoc)) {
        // Immediate cache-hit completion without re-processing
        const completedJob = new ScanJob({
            jobId,
            userId,
            fileHash,
            title: title || existingDoc.title,
            fileName: title || existingDoc.fileName || '',
            sourceType: sourceType || existingDoc.sourceType,
            mimeType: mimeType || existingDoc.mimeType,
            storagePath,
            fileSize,
            modelName: existingDoc.modelName,
            modelVersion: existingDoc.modelVersion || 'latest',
            promptVersion: existingDoc.promptVersion,
            analysisVersion: existingDoc.analysisVersion,
            status: 'COMPLETED',
            currentStep: 'Analysis completed (from cache)',
            completedSteps: ['UPLOAD', 'TEXT_EXTRACTION', 'AI_ANALYSIS', 'REPORT'],
            extractedText: existingDoc.extractedNormalizedText || existingDoc.originalText,
            canonicalClauses: existingDoc.canonicalClauses,
            analysis: existingDoc.analysis,
            documentId: existingDoc._id,
            completedAt: new Date()
        });
        await completedJob.save();
        return completedJob;
    }

    // Prevent duplicate concurrent analysis jobs for the same user, file hash, and current analysis version
    const inFlightStatuses = [
        'QUEUED',
        'UPLOADING',
        'OCR_PROCESSING',
        'TEXT_EXTRACTED',
        'AI_ANALYSIS',
        'REPORT_GENERATION',
        'RETRYING'
    ];
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    const inFlightJob = await ScanJob.findOne({
        userId,
        fileHash,
        status: { $in: inFlightStatuses },
        updatedAt: { $gte: fiveMinutesAgo }
    }).sort({ updatedAt: -1 });

    if (inFlightJob) {
        console.log(`[createScanJob] Reusing active in-flight ScanJob ${inFlightJob.jobId} for user ${userId} / hash ${fileHash.substring(0, 8)}...`);
        return inFlightJob;
    }

    // Initialize new pending job with explicit version metadata
    const newJob = new ScanJob({
        jobId,
        userId,
        fileHash,
        title: title || 'Property Legal Agreement',
        fileName: title || '',
        sourceType,
        mimeType,
        storagePath,
        fileSize,
        modelName: llmService.MODEL_NAME,
        modelVersion: llmService.MODEL_VERSION || 'latest',
        promptVersion: llmService.PROMPT_VERSION,
        analysisVersion: llmService.ANALYSIS_VERSION,
        status: 'QUEUED',
        currentStep: 'Scan queued',
        completedSteps: ['UPLOAD'],
        extractedText: text ? llmService.normalizeDocumentText(text) : ''
    });

    await newJob.save();
    return newJob;
}

/**
 * Core Stage-by-Stage Resumable Pipeline Execution
 */
async function executeJobPipeline(jobId) {
    const job = await ScanJob.findOne({ jobId });
    if (!job) {
        throw new Error(`ScanJob ${jobId} not found.`);
    }

    if (job.status === 'COMPLETED') {
        return job;
    }

    const processKey = `${job.userId}:${job.fileHash}`;
    if (activeProcessingKeys.has(processKey)) {
        console.log(`[ScanJob ${job.jobId}] Pipeline already in-progress for ${processKey}. Skipping duplicate invocation.`);
        return job;
    }

    activeProcessingKeys.add(processKey);

    try {
        // Fast-check if another worker just completed an up-to-date document for this file
        const recentDoc = await Document.findOne({
            userId: job.userId,
            fileHash: job.fileHash,
            analysisStatus: 'completed',
            promptVersion: llmService.PROMPT_VERSION,
            modelName: llmService.MODEL_NAME
        });

        if (isDocumentCacheValid(recentDoc)) {
            job.extractedText = recentDoc.extractedNormalizedText || recentDoc.originalText;
            job.canonicalClauses = recentDoc.canonicalClauses;
            job.analysis = recentDoc.analysis;
            job.documentId = recentDoc._id;
            job.modelName = recentDoc.modelName;
            job.modelVersion = recentDoc.modelVersion || 'latest';
            job.promptVersion = recentDoc.promptVersion;
            job.analysisVersion = recentDoc.analysisVersion;
            job.completedSteps = ['UPLOAD', 'TEXT_EXTRACTION', 'AI_ANALYSIS', 'REPORT'];
            job.status = 'COMPLETED';
            job.currentStep = 'Analysis completed';
            job.completedAt = new Date();
            await job.save();
            return job;
        }

        // =====================================================================
        // STAGE 2: OCR & TEXT EXTRACTION
        // =====================================================================
        if (!job.completedSteps.includes('TEXT_EXTRACTION') || !job.extractedText || job.extractedText.length === 0) {
            console.log(`[ScanJob ${job.jobId}] Executing STAGE 2: Text Extraction & OCR...`);
            job.status = 'OCR_PROCESSING';
            job.currentStep = 'Extracting document...';
            await job.save();

            let extractedText = '';
            let canonicalClauses = [];
            const isPdf = (job.mimeType || '').toLowerCase().includes('pdf');
            const isImage = (job.mimeType || '').toLowerCase().startsWith('image/');
            const fileBuffer = readFileFromStorage(job.storagePath);

            if (fileBuffer && isPdf) {
                let pdfText = '';
                try {
                    const pdfData = await pdfParse(fileBuffer);
                    if (pdfData && pdfData.text) pdfText = pdfData.text;
                } catch (pdfErr) {
                    console.warn(`[ScanJob ${job.jobId}] pdf-parse warning:`, pdfErr.message);
                }

                const normalizedPdfText = llmService.normalizeDocumentText(pdfText);
                if (normalizedPdfText.length >= 50) {
                    extractedText = normalizedPdfText;
                    canonicalClauses = llmService.extractCanonicalClausesFromText(extractedText);
                } else {
                    try {
                        // Scanned PDF vision extraction fallback
                        const scannedResult = await llmService.analyzeContractPipeline({
                            base64Data: fileBuffer.toString('base64'),
                            mimeType: 'application/pdf',
                            customTitle: job.title,
                            sourceType: job.sourceType,
                            userId: job.userId
                        });
                        
                        if (scannedResult && scannedResult.analysis && scannedResult.analysis.length > 0) {
                            job.extractedText = scannedResult.extractedText;
                            job.canonicalClauses = scannedResult.canonicalClauses;
                            job.analysis = scannedResult.analysis;
                            job.documentId = scannedResult.documentId;
                            job.modelName = llmService.MODEL_NAME;
                            job.modelVersion = llmService.MODEL_VERSION || 'latest';
                            job.promptVersion = llmService.PROMPT_VERSION;
                            job.analysisVersion = llmService.ANALYSIS_VERSION;
                            job.completedSteps = ['UPLOAD', 'TEXT_EXTRACTION', 'AI_ANALYSIS', 'REPORT'];
                            job.status = 'COMPLETED';
                            job.currentStep = 'Analysis completed';
                            job.completedAt = new Date();
                            await job.save();
                            console.log(`[ScanJob ${job.jobId}] Scanned PDF pipeline completed holistically in Stage 2.`);
                            return job;
                        }
                        
                        extractedText = scannedResult ? scannedResult.extractedText : '';
                        canonicalClauses = scannedResult ? scannedResult.canonicalClauses : [];
                    } catch (scannedErr) {
                        console.warn(`[ScanJob ${job.jobId}] Scanned PDF vision fallback failed (${scannedErr.message}), using buffer text fallback.`);
                        extractedText = llmService.normalizeDocumentText(fileBuffer.toString('utf8'));
                        canonicalClauses = llmService.extractCanonicalClausesFromText(extractedText);
                    }
                }
            } else if (fileBuffer && isImage) {
                const imgResult = await llmService.analyzeContractPipeline({
                    base64Data: fileBuffer.toString('base64'),
                    mimeType: job.mimeType || 'image/jpeg',
                    customTitle: job.title,
                    sourceType: 'Photo Scan',
                    userId: job.userId
                });
                
                if (imgResult && imgResult.analysis && imgResult.analysis.length > 0) {
                    job.extractedText = imgResult.extractedText;
                    job.canonicalClauses = imgResult.canonicalClauses;
                    job.analysis = imgResult.analysis;
                    job.documentId = imgResult.documentId;
                    job.modelName = llmService.MODEL_NAME;
                    job.modelVersion = llmService.MODEL_VERSION || 'latest';
                    job.promptVersion = llmService.PROMPT_VERSION;
                    job.analysisVersion = llmService.ANALYSIS_VERSION;
                    job.completedSteps = ['UPLOAD', 'TEXT_EXTRACTION', 'AI_ANALYSIS', 'REPORT'];
                    job.status = 'COMPLETED';
                    job.currentStep = 'Analysis completed';
                    job.completedAt = new Date();
                    await job.save();
                    console.log(`[ScanJob ${job.jobId}] Image scan pipeline completed holistically in Stage 2.`);
                    return job;
                }
                
                extractedText = imgResult ? imgResult.extractedText : '';
                canonicalClauses = imgResult ? imgResult.canonicalClauses : [];
            } else if (job.extractedText && job.extractedText.length > 0) {
                extractedText = job.extractedText;
                canonicalClauses = llmService.extractCanonicalClausesFromText(extractedText);
            } else {
                extractedText = 'Property Agreement';
                canonicalClauses = llmService.extractCanonicalClausesFromText(extractedText);
            }

            if (!canonicalClauses || canonicalClauses.length === 0) {
                canonicalClauses = llmService.extractCanonicalClausesFromText(extractedText);
            }

            job.extractedText = extractedText;
            job.canonicalClauses = canonicalClauses;
            if (!job.completedSteps.includes('TEXT_EXTRACTION')) {
                job.completedSteps.push('TEXT_EXTRACTION');
            }
            job.status = 'TEXT_EXTRACTED';
            job.currentStep = 'Document extracted';
            await job.save();
            console.log(`[ScanJob ${job.jobId}] STAGE 2 COMPLETE: Extracted ${extractedText.length} chars.`);
        } else {
            console.log(`[ScanJob ${job.jobId}] SKIPPING STAGE 2: Already extracted (${job.extractedText.length} chars).`);
        }

        // =====================================================================
        // STAGE 3: AI LEGAL ANALYSIS (Stage B)
        // =====================================================================
        if (!job.completedSteps.includes('AI_ANALYSIS') || !job.analysis || job.analysis.length === 0) {
            console.log(`[ScanJob ${job.jobId}] Executing STAGE 3: AI Legal Analysis...`);
            job.status = 'AI_ANALYSIS';
            job.currentStep = 'Analyzing legal clauses...';
            await job.save();

            let analyzedClauses = null;
            let autoRetries = 0;
            const maxAutoRetries = job.maxAutoRetries || 3;

            while (!analyzedClauses && autoRetries <= maxAutoRetries) {
                try {
                    analyzedClauses = await llmService.analyzeCanonicalClauses(job.canonicalClauses);
                } catch (aiErr) {
                    const transient = isTransientError(aiErr);
                    if (transient && autoRetries < maxAutoRetries) {
                        autoRetries++;
                        job.autoRetriesCount = (job.autoRetriesCount || 0) + 1;
                        job.status = 'RETRYING';
                        job.currentStep = `Temporarily unavailable — retrying automatically (${autoRetries}/${maxAutoRetries})...`;
                        await job.save();

                        const backoffDelay = Math.pow(2, autoRetries) * 1500; // 3s, 6s, 12s
                        console.log(`[ScanJob ${job.jobId}] Transient AI failure (${aiErr.message}). Waiting ${backoffDelay / 1000}s...`);
                        await sleep(backoffDelay);
                    } else {
                        throw aiErr;
                    }
                }
            }

            if (!analyzedClauses || analyzedClauses.length === 0) {
                throw new Error('AI analysis produced empty clause findings.');
            }

            job.analysis = analyzedClauses;
            if (!job.completedSteps.includes('AI_ANALYSIS')) {
                job.completedSteps.push('AI_ANALYSIS');
            }
            job.status = 'AI_ANALYSIS';
            job.currentStep = 'Clauses analyzed';
            await job.save();
            console.log(`[ScanJob ${job.jobId}] STAGE 3 COMPLETE: Analyzed ${analyzedClauses.length} clauses.`);
        } else {
            console.log(`[ScanJob ${job.jobId}] SKIPPING STAGE 3: Already analyzed (${job.analysis.length} clauses).`);
        }

        // =====================================================================
        // STAGE 4: REPORT GENERATION & IDEMPOTENT DOCUMENT UPSERT
        // =====================================================================
        if (!job.completedSteps.includes('REPORT') || !job.documentId) {
            console.log(`[ScanJob ${job.jobId}] Executing STAGE 4: Report Generation & Document Upsert...`);
            job.status = 'REPORT_GENERATION';
            job.currentStep = 'Generating report...';
            await job.save();

            const analyzedClauses = job.analysis;
            const highRiskCount = analyzedClauses.filter(c => c.riskLevel === 'HIGH_RISK').length;
            const cautionCount = analyzedClauses.filter(c => c.riskLevel === 'CAUTION').length;
            const compliantCount = analyzedClauses.filter(c => c.riskLevel === 'COMPLIANT').length;
            const totalClauseCount = analyzedClauses.length;

            let riskLevel = 'Low Risk';
            if (highRiskCount > 0) riskLevel = 'High Risk';
            else if (cautionCount > 0) riskLevel = 'Medium Risk';

            let title = job.title;
            if (!title || !title.trim()) {
                const firstLine = (job.extractedText || '').trim().split('\n')[0].replace(/[#*_-]/g, '').trim();
                title = firstLine.length > 50 ? firstLine.substring(0, 47) + '...' : (firstLine || 'Property Legal Agreement');
            }

            const rawBytes = job.fileSize || Buffer.byteLength(job.extractedText || '', 'utf8');
            const docSize = rawBytes >= 1048576
                ? `${(rawBytes / 1048576).toFixed(1)} MB`
                : `${Math.max(1, Math.round(rawBytes / 1024))} KB`;

            const docData = {
                userId: job.userId,
                fileHash: job.fileHash,
                title,
                originalText: job.extractedText,
                sourceType: job.sourceType,
                mimeType: job.mimeType,
                fileData: null, // Preserved lightweight in Document schema
                fileName: title,
                riskLevel,
                docSize,
                totalPages: 1,
                pagesProcessed: 1,
                pageClassifications: [{ page: 1, classification: 'substantive legal content', hasContent: true }],
                extractionMethod: job.mimeType?.includes('pdf') ? 'digital_pdf_text' : 'raw_text',
                extractedNormalizedText: job.extractedText,
                canonicalClauses: job.canonicalClauses,
                analysis: analyzedClauses,
                highRiskCount,
                cautionCount,
                compliantCount,
                totalClauseCount,
                modelName: llmService.MODEL_NAME,
                modelVersion: llmService.MODEL_VERSION || 'latest',
                promptVersion: llmService.PROMPT_VERSION,
                analysisVersion: llmService.ANALYSIS_VERSION,
                temperature: llmService.TEMPERATURE,
                analysisStatus: 'completed',
                updatedAt: new Date()
            };

            // Atomic Idempotent Upsert (overwrites stale analysis with current version findings)
            const savedDoc = await Document.findOneAndUpdate(
                { userId: job.userId, fileHash: job.fileHash },
                { $set: docData, $setOnInsert: { createdAt: new Date() } },
                { upsert: true, returnDocument: 'after' }
            );

            job.documentId = savedDoc._id;
            job.modelName = llmService.MODEL_NAME;
            job.modelVersion = llmService.MODEL_VERSION || 'latest';
            job.promptVersion = llmService.PROMPT_VERSION;
            job.analysisVersion = llmService.ANALYSIS_VERSION;
            if (!job.completedSteps.includes('REPORT')) {
                job.completedSteps.push('REPORT');
            }
            job.status = 'COMPLETED';
            job.currentStep = 'Analysis completed';
            job.completedAt = new Date();
            job.errorInfo = { message: null, stage: null, code: null, isTransient: false, timestamp: null };
            await job.save();

            // Synchronize detected document issues with user's due diligence checklists
            try {
                await crossReferenceService.syncDocumentIssuesWithChecklists(job.userId, savedDoc);
                console.log(`[ScanJob ${job.jobId}] Cross-referencing checklist sync completed for user ${job.userId}`);
            } catch (syncErr) {
                console.warn(`[ScanJob ${job.jobId}] Warning: Checklist sync error:`, syncErr.message);
            }

            console.log(`[ScanJob ${job.jobId}] STAGE 4 COMPLETE: Linked to Document ${savedDoc._id}. Status: COMPLETED.`);
        } else {
            console.log(`[ScanJob ${job.jobId}] SKIPPING STAGE 4: Document already linked (${job.documentId}).`);
            job.status = 'COMPLETED';
            job.currentStep = 'Analysis completed';
            await job.save();
        }

        return job;

    } catch (err) {
        console.error(`[ScanJob ${job.jobId}] Error during stage execution:`, err.message);
        job.status = 'FAILED';
        job.currentStep = `Failed at ${job.currentStep}: ${err.message}`;
        job.errorInfo = {
            message: err.message,
            stage: job.currentStep,
            code: err.code || err.status || 'PIPELINE_ERROR',
            isTransient: isTransientError(err),
            timestamp: new Date()
        };
        await job.save();
        throw err;
    } finally {
        activeProcessingKeys.delete(processKey);
    }
}

/**
 * Resumes a failed or unfinished scan job from its last incomplete stage.
 */
async function retryJob(jobId, isManual = true) {
    const job = await ScanJob.findOne({ jobId });
    if (!job) {
        throw new Error(`ScanJob ${jobId} not found.`);
    }

    if (job.status === 'COMPLETED') {
        return job;
    }

    if (isManual) {
        job.manualRetriesCount = (job.manualRetriesCount || 0) + 1;
    }
    job.lastRetryAt = new Date();
    job.status = 'RETRYING';
    job.currentStep = 'Resuming scan...';
    await job.save();

    return executeJobPipeline(jobId);
}

/**
 * Startup Recovery Hook:
 * Discovers any ScanJobs that were left incomplete due to server shutdown/restart and safely resumes them.
 */
async function recoverUnfinishedScanJobs(awaitAll = false) {
    try {
        console.log('--- Checking for Unfinished ScanJobs (Startup Recovery) ---');
        const pendingStatuses = [
            'QUEUED',
            'UPLOADING',
            'OCR_PROCESSING',
            'TEXT_EXTRACTED',
            'AI_ANALYSIS',
            'REPORT_GENERATION',
            'RETRYING'
        ];

        // Find jobs that have not been updated for at least 5 seconds (stale server state)
        const staleThreshold = new Date(Date.now() - 5000);
        const unfinishedJobs = await ScanJob.find({
            status: { $in: pendingStatuses },
            updatedAt: { $lt: staleThreshold }
        });

        if (unfinishedJobs.length === 0) {
            console.log('✓ No unfinished ScanJobs found on startup. State is clean.');
            return 0;
        }

        console.log(`Found ${unfinishedJobs.length} unfinished ScanJob(s) to recover.`);

        const promises = unfinishedJobs.map(job => {
            console.log(`[Startup Recovery] Resuming ScanJob ${job.jobId} (Completed stages: [${job.completedSteps.join(', ')}])...`);
            return executeJobPipeline(job.jobId).catch(err => {
                console.error(`[Startup Recovery] Failed to recover ScanJob ${job.jobId}:`, err.message);
            });
        });

        if (awaitAll) {
            await Promise.all(promises);
        }

        return unfinishedJobs.length;
    } catch (e) {
        console.warn('Startup scan job recovery error:', e.message);
        return 0;
    }
}

module.exports = {
    createScanJob,
    executeJobPipeline,
    retryJob,
    recoverUnfinishedScanJobs,
    saveFileToStorage,
    readFileFromStorage,
    isDocumentCacheValid
};
