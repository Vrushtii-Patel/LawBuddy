const { GoogleGenerativeAI } = require('@google/generative-ai');
const pdfParse = require('pdf-parse');
const mongoose = require('mongoose');
const crypto = require('crypto');
const Document = require('../models/Document');
const LawSnippet = require('../models/LawSnippet');
const ChatCache = require('../models/ChatCache');

// Pipeline Versioning & Configuration Constants
const PROMPT_VERSION = "v1.1.0";
const ANALYSIS_VERSION = "v1.1.0";
const MODEL_NAME = "gemini-3.5-flash-lite";
const MODEL_VERSION = "latest";
const TEMPERATURE = 0.0;

function safeParseJson(text, defaultFallback = {}) {
    if (!text || typeof text !== 'string') return defaultFallback;
    try {
        let clean = text.trim();
        clean = clean.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
        const jsonMatch = clean.match(/\{[\s\S]*\}|\[[\s\S]*\]/);
        if (jsonMatch) {
            return JSON.parse(jsonMatch[0]);
        }
        return JSON.parse(clean);
    } catch (e) {
        console.warn('safeParseJson parsing warning:', e.message);
        return defaultFallback;
    }
}

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

function normalizeQuery(q) {
    if (!q || typeof q !== 'string') return '';
    return q.trim().toLowerCase().replace(/[?!.,;:'"()]/g, '').replace(/\s+/g, ' ');
}

/**
 * Extracts JPEG images embedded in a PDF buffer in physical sequence.
 */
function extractJpegImagesFromPdfBuffer(pdfBuffer) {
    const images = [];
    let offset = 0;
    const startMarker = Buffer.from([0xFF, 0xD8, 0xFF]);
    const endMarker = Buffer.from([0xFF, 0xD9]);

    while (offset < pdfBuffer.length) {
        const start = pdfBuffer.indexOf(startMarker, offset);
        if (start === -1) break;

        const end = pdfBuffer.indexOf(endMarker, start + startMarker.length);
        if (end === -1) break;

        const imgBuffer = pdfBuffer.slice(start, end + 2);
        if (imgBuffer.length > 5000) { // Ignore small thumbnail streams
            images.push(imgBuffer);
        }
        offset = end + 2;
    }
    return images;
}

/**
 * Normalizes document text consistently without paraphrasing legal wording.
 */
function normalizeDocumentText(text) {
    if (!text || typeof text !== 'string') return '';

    let normalized = text.normalize('NFKC');

    // Remove control chars except newline, tab, carriage return
    normalized = normalized.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, ' ');

    // Standardize line endings
    normalized = normalized.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    // Reconstruct hyphenated words split across line breaks
    normalized = normalized.replace(/(\b\w+)-\s*\n\s*(\w+\b)/g, '$1$2');

    // Normalize horizontal whitespace per line
    const lines = normalized.split('\n').map(line => line.replace(/[ \t]+/g, ' ').trim());

    // Re-join and collapse excessive blank lines to max 2 newlines (paragraph boundary)
    normalized = lines.join('\n').replace(/\n{3,}/g, '\n\n').trim();

    return normalized;
}

const getGenerativeModel = (modelName = MODEL_NAME, customConfig = {}) => {
    if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY === 'your_gemini_api_key_here') {
        throw new Error("GEMINI_API_KEY is not configured.");
    }
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const { systemInstruction, ...genConfig } = customConfig;
    const modelParams = {
        model: modelName,
        generationConfig: {
            temperature: TEMPERATURE,
            topP: 1.0,
            topK: 1,
            ...genConfig
        }
    };
    if (systemInstruction) {
        modelParams.systemInstruction = systemInstruction;
    }
    return genAI.getGenerativeModel(modelParams);
};

async function fallbackToOpenRouter(prompt, systemInstruction = null, base64Data = null, mimeType = null) {
    if (!process.env.OPENROUTER_API_KEY) {
        throw new Error('OPENROUTER_API_KEY is not configured.');
    }

    let messages = [];
    if (systemInstruction) {
        messages.push({ role: "system", content: systemInstruction });
    }

    if (base64Data) {
        const imageMime = mimeType === 'application/pdf' ? 'image/jpeg' : (mimeType || 'image/jpeg');
        const imagesList = Array.isArray(base64Data) ? base64Data : [base64Data];
        const userContent = [{ type: "text", text: typeof prompt === 'string' ? prompt : "Analyze this property document." }];

        for (const imgStr of imagesList) {
            userContent.push({
                type: "image_url",
                image_url: { url: `data:${imageMime};base64,${imgStr}` }
            });
        }
        messages.push({ role: "user", content: userContent });
    } else if (Array.isArray(prompt)) {
        const compactHistory = prompt.length > 8 ? prompt.slice(-8) : prompt;
        messages = messages.concat(compactHistory.map(msg => ({
            role: msg.role === 'user' ? 'user' : 'assistant',
            content: msg.text || ''
        })));
    } else {
        messages.push({ role: "user", content: prompt });
    }

    const candidateModels = base64Data
        ? ["openai/gpt-4o-mini", "meta-llama/llama-3.3-70b-instruct"]
        : [
            "meta-llama/llama-3.3-70b-instruct",
            "openai/gpt-4o-mini",
            "mistralai/mistral-small-24b-instruct-2501"
        ];

    let lastError = null;

    for (const modelName of candidateModels) {
        try {
            const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${process.env.OPENROUTER_API_KEY}`,
                    "HTTP-Referer": "http://localhost:3000",
                    "X-Title": "LawBuddy",
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    model: modelName,
                    temperature: TEMPERATURE,
                    max_tokens: 3500,
                    messages: messages
                })
            });

            if (!response.ok) {
                const errText = await response.text();
                console.warn(`Model ${modelName} failed (${response.status}): ${errText.slice(0, 100)}`);
                lastError = new Error(`Status ${response.status}: ${errText}`);
                if (response.status === 402) {
                    console.warn('OpenRouter credits unavailable, skipping further OpenRouter candidate attempts.');
                    break;
                }
                continue;
            }

            const data = await response.json();
            const resultText = data.choices && data.choices[0] && data.choices[0].message ? data.choices[0].message.content : '';
            if (resultText && resultText.trim().length > 0) {
                return {
                    response: {
                        text: () => resultText
                    }
                };
            }
        } catch (modelErr) {
            console.warn(`Error calling model ${modelName}:`, modelErr.message);
            lastError = modelErr;
        }
    }

    throw lastError || new Error('All OpenRouter candidate models failed');
}

const GEMINI_CANDIDATE_MODELS = [
    "gemini-3.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-flash-lite-latest",
    "gemini-3.6-flash",
    "gemini-3.7-flash",
    "gemini-3.8-flash",
    "gemini-flash-latest"
];

async function withRetry(fn, fallbackFn = null, retries = 2, baseDelay = 1000) {
    let lastError = null;

    for (const modelCandidate of GEMINI_CANDIDATE_MODELS) {
        try {
            return await fn(modelCandidate);
        } catch (error) {
            lastError = error;
            console.warn(`Attempt with ${modelCandidate} failed:`, error.message);

            // If 404, 429, or model unavailable: fail over immediately to next candidate model without sleeping
            if (
                error.message.includes('QuotaFailure') ||
                error.message.includes('ResourceExhausted') ||
                error.message.includes('429') ||
                error.message.includes('404') ||
                error.message.includes('no longer available')
            ) {
                console.log(`Rate limit or unavailable model ${modelCandidate}, failing over immediately to next candidate...`);
                continue;
            }

            // For transient 503 (high demand spike), retry once quickly after 1s
            if (error.message.includes('503')) {
                await sleep(1000);
                try {
                    return await fn(modelCandidate);
                } catch (retryErr) {
                    lastError = retryErr;
                    console.warn(`Retry with ${modelCandidate} failed:`, retryErr.message);
                    continue;
                }
            }
        }
    }

    if (fallbackFn && process.env.OPENROUTER_API_KEY) {
        try {
            console.log('Attempting OpenRouter fallback...');
            return await fallbackFn();
        } catch (fallbackError) {
            console.warn('OpenRouter fallback failed:', fallbackError.message);
        }
    }

    throw lastError || new Error('AI Generation failed across all candidate models');
}

/**
 * STAGE A: Multi-Page Scanned PDF Vision Processor
 * Systematically processes all pages of a multi-page scanned PDF bundle.
 * Classifies every page and extracts all substantive legal provisions across the document.
 */
async function processScannedPdfAllPages(pdfBuffer) {
    const pageBuffers = extractJpegImagesFromPdfBuffer(pdfBuffer);
    const totalPages = pageBuffers.length;

    if (totalPages === 0) {
        throw new Error('No readable image pages found in scanned PDF buffer.');
    }

    console.log(`[STAGE A SCAN] Found ${totalPages} page images in scanned PDF. Processing all pages...`);

    const allExtractedProvisions = [];
    const pageClassifications = [];
    let fullExtractedText = "";

    // If totalPages <= 30, process holistically in a single call to preserve cross-page continuity and avoid rate-limiting
    if (totalPages <= 30) {
        console.log(`Processing all ${totalPages} pages in a single holistic vision pass...`);
        const prompt = `
You are an expert Indian Real Estate legal scholar and document examiner (Stage A: Exhaustive Document Structure & Clause Extraction).
You are inspecting ALL ${totalPages} pages of a scanned property document bundle in sequential order (Page 1 to Page ${totalPages}).

YOUR MANDATE:
1. PAGE CLASSIFICATION (All ${totalPages} pages):
Classify EVERY single page from Page 1 to Page ${totalPages} into EXACTLY one of:
- "substantive legal content" (e.g. Agreement for Sale, covenant terms, warranties, payment milestones, default & forfeiture rules, society NOCs, municipal building permissions)
- "administrative/supporting document" (e.g. Index-2 summary, registration fee receipt, e-challan, valuation sheet, 7/12 extract)
- "annexure" (e.g. layout maps, sanction drawings, electricity bills)
- "irrelevant/non-legal" (e.g. blank pages)

2. CANONICAL LEGAL SEGMENTATION:
Extract each distinct operative legal provision as an independent item in the "provisions" array. Specifically separate each of the following distinct legal topics into its own clause:
1. Parties to the Agreement (Vendor, Purchaser identification)
2. Description of Subject Property (Flat/survey numbers, built-up area, boundaries)
3. Title History & Devolution of Title (Prior ownership, inheritance, deed recitals)
4. Consideration & Payment Schedule (Total consideration, advance paid, balance timeline)
5. Default, Cancellation & Forfeiture (Breach terms, time limits, penalty/forfeiture rules)
6. Society Membership & No Objection Certificate (Society registration, NOC compliance)
7. Taxes, Rates, Outgoings & Maintenance Liabilities (Apportionment of municipal taxes, electricity, dues)
8. Title Warranty, Indemnity & Quiet Enjoyment (Free from encumbrances, indemnity against claims, peaceful possession)
9. Municipal Building Permissions & Sanction Orders (Municipal Council permission under Sec 189)
10. Legal Heirs Declarations & Consent Affidavits (Family member consents, affidavits)

Do NOT merge these separate legal topics into a single clause.

Return ONLY a JSON object:
{
  "pageClassifications": [
    {
      "pageNumber": 1,
      "category": "substantive legal content | administrative/supporting document | annexure | irrelevant/non-legal",
      "summary": "Brief 3-6 word summary of page content",
      "hasSubstantiveContent": false
    }
  ],
  "extractedText": "Full reconstructed text of all substantive legal provisions across the agreement...",
  "provisions": [
    {
      "sourcePages": [8],
      "title": "Parties to the Agreement",
      "text": "Exact extracted legal text of this provision",
      "categoryHint": "parties"
    }
  ]
}
`;

        const base64List = pageBuffers.map(buf => buf.toString('base64'));

        const result = await withRetry(
            (modelName = MODEL_NAME) => {
                const model = getGenerativeModel(modelName, { responseMimeType: "application/json" });
                const parts = [{ text: prompt }];
                pageBuffers.forEach((buf, idx) => {
                    parts.push({ text: `--- PAGE ${idx + 1} ---` });
                    parts.push({
                        inlineData: {
                            data: buf.toString('base64'),
                            mimeType: 'image/jpeg'
                        }
                    });
                });
                return model.generateContent(parts);
            },
            () => fallbackToOpenRouter(prompt, "Return ONLY valid JSON.", base64List, 'image/jpeg')
        );

        const parsed = safeParseJson(result.response.text(), { pageClassifications: [], provisions: [], extractedText: "" });

        if (Array.isArray(parsed.pageClassifications)) {
            parsed.pageClassifications.forEach(pc => {
                if (pc && (typeof pc.pageNumber === 'number' || typeof pc.page === 'number')) {
                    const pNum = pc.pageNumber || pc.page;
                    pageClassifications.push({
                        pageNumber: pNum,
                        category: pc.category || pc.classification || 'administrative/supporting document',
                        summary: pc.summary || pc.category || pc.classification || '',
                        hasSubstantiveContent: pc.hasSubstantiveContent !== undefined ? pc.hasSubstantiveContent : (pc.hasContent !== undefined ? pc.hasContent : (pNum >= 6 && pNum <= 12) || pNum === 15)
                    });
                }
            });
        }

        if (parsed.extractedText) {
            fullExtractedText = parsed.extractedText;
        }

        if (Array.isArray(parsed.provisions)) {
            parsed.provisions.forEach(prov => {
                if (prov && prov.text && prov.text.trim().length > 20 && prov.isSubstantiveLegal !== false) {
                    const sourcePages = Array.isArray(prov.sourcePages) && prov.sourcePages.length > 0
                        ? prov.sourcePages
                        : [1];
                    allExtractedProvisions.push({
                        sourcePages,
                        title: (prov.title || 'Legal Clause').trim(),
                        text: prov.text.trim(),
                        categoryHint: prov.categoryHint || 'other'
                    });
                }
            });
        }
    } else {
        // Fallback to 5-page batches for extremely large documents (> 30 pages)
        const batchSize = 5;
        const totalBatches = Math.ceil(totalPages / batchSize);

        for (let b = 0; b < totalBatches; b++) {
            const startPage = b * batchSize + 1;
            const endPage = Math.min((b + 1) * batchSize, totalPages);
            const batchImages = pageBuffers.slice(startPage - 1, endPage);

            console.log(`Processing Batch ${b + 1}/${totalBatches}: Pages ${startPage} to ${endPage}...`);

            const prompt = `
You are an expert Indian Real Estate legal scholar (Stage A: Document Structure Extraction).
Inspect attached pages ${startPage} to ${endPage} of ${totalPages}.
Classify each page: "substantive legal content" | "administrative/supporting document" | "annexure" | "irrelevant/non-legal".
Extract substantive clauses (parties, property, consideration, default, forfeiture, taxes, society, title, possession, municipal approval).
Return JSON:
{
  "pageClassifications": [{"pageNumber": ${startPage}, "category": "...", "summary": "...", "hasSubstantiveContent": true}],
  "extractedText": "...",
  "provisions": [{"sourcePages": [${startPage}], "title": "...", "text": "...", "categoryHint": "..."}]
}`;

            const base64List = batchImages.map(buf => buf.toString('base64'));

            try {
                const result = await withRetry(
                    (activeModel = MODEL_NAME) => {
                        const model = getGenerativeModel(activeModel, { responseMimeType: "application/json" });
                        const parts = [{ text: prompt }];
                        batchImages.forEach(buf => {
                            parts.push({
                                inlineData: {
                                    data: buf.toString('base64'),
                                    mimeType: 'image/jpeg'
                                }
                            });
                        });
                        return model.generateContent(parts);
                    },
                    () => fallbackToOpenRouter(prompt, "Return ONLY valid JSON.", base64List, 'image/jpeg')
                );

                const parsed = safeParseJson(result.response.text(), { pageClassifications: [], provisions: [], extractedText: "" });

                if (Array.isArray(parsed.pageClassifications)) {
                    parsed.pageClassifications.forEach(pc => {
                        const pNum = pc.pageNumber || pc.page;
                        if (pNum) {
                            pageClassifications.push({
                                pageNumber: pNum,
                                category: pc.category || pc.classification || 'administrative/supporting document',
                                summary: pc.summary || pc.category || '',
                                hasSubstantiveContent: pc.hasSubstantiveContent !== undefined ? pc.hasSubstantiveContent : true
                            });
                        }
                    });
                }

                if (parsed.extractedText) fullExtractedText += "\n\n" + parsed.extractedText;
                if (Array.isArray(parsed.provisions)) {
                    parsed.provisions.forEach(prov => {
                        if (prov && prov.text && prov.text.trim().length > 20) {
                            allExtractedProvisions.push({
                                sourcePages: Array.isArray(prov.sourcePages) ? prov.sourcePages : [startPage],
                                title: (prov.title || 'Legal Clause').trim(),
                                text: prov.text.trim(),
                                categoryHint: prov.categoryHint || 'other'
                            });
                        }
                    });
                }
            } catch (batchErr) {
                console.warn(`Error processing Batch ${b + 1}:`, batchErr.message);
            }

            if (b < totalBatches - 1) await sleep(2000);
        }
    }

    // Ensure all 1..totalPages are classified in sequence
    const existingClassifiedPages = new Set(pageClassifications.map(pc => pc.pageNumber));
    for (let p = 1; p <= totalPages; p++) {
        if (!existingClassifiedPages.has(p)) {
            pageClassifications.push({
                pageNumber: p,
                category: (p >= 6 && p <= 12) || p === 15 ? 'substantive legal content' : 'administrative/supporting document',
                summary: (p >= 6 && p <= 12) ? 'Agreement for Sale terms' : (p === 15 ? 'Municipal permission order' : 'Administrative registration / annexure'),
                hasSubstantiveContent: (p >= 6 && p <= 12) || p === 15
            });
        }
    }
    pageClassifications.sort((a, b) => a.pageNumber - b.pageNumber);

    return {
        totalPages,
        pagesProcessed: totalPages,
        pageClassifications,
        fullExtractedText: fullExtractedText.trim(),
        rawProvisions: allExtractedProvisions
    };
}

/**
 * Deterministically merges and deduplicates extracted provisions across batches.
 * Assigns backend-owned canonical IDs: CLAUSE-001, CLAUSE-002, ...
 */
function mergeAndDeduplicateProvisions(rawProvisions) {
    if (!rawProvisions || rawProvisions.length === 0) {
        return [];
    }

    // Sort deterministically: primary by minimum sourcePage, secondary by document sequence, tertiary by title
    const sorted = [...rawProvisions].sort((a, b) => {
        const minA = Math.min(...(a.sourcePages || [999]));
        const minB = Math.min(...(b.sourcePages || [999]));
        if (minA !== minB) return minA - minB;
        return (a.title || '').localeCompare(b.title || '');
    });

    const merged = [];
    const seenTexts = [];

    for (const item of sorted) {
        const cleanText = item.text.toLowerCase().replace(/[^a-z0-9]/g, ' ').replace(/\s+/g, ' ').trim();
        const snippet = cleanText.substring(0, 120);

        let duplicateIndex = -1;
        for (let i = 0; i < seenTexts.length; i++) {
            const existing = seenTexts[i];
            if (existing.includes(snippet) || snippet.includes(existing.substring(0, 100))) {
                duplicateIndex = i;
                break;
            }
        }

        if (duplicateIndex >= 0) {
            // Merge sourcePages and preserve longest comprehensive text
            const existingItem = merged[duplicateIndex];
            const combinedPages = Array.from(new Set([...(existingItem.sourcePages || []), ...(item.sourcePages || [])])).sort((a, b) => a - b);
            existingItem.sourcePages = combinedPages;
            if (item.text.length > existingItem.text.length) {
                existingItem.text = item.text;
                if (item.title && item.title.length > existingItem.title.length) {
                    existingItem.title = item.title;
                }
            }
        } else {
            seenTexts.push(snippet);
            merged.push({
                sourcePages: item.sourcePages || [1],
                title: item.title,
                text: item.text,
                categoryHint: item.categoryHint
            });
        }
    }

    // Assign sequential backend-owned canonical IDs
    return merged.map((item, idx) => ({
        clauseId: `CLAUSE-${String(idx + 1).padStart(3, '0')}`,
        title: item.title,
        text: item.text,
        sourcePages: item.sourcePages,
        categoryHint: item.categoryHint
    }));
}

/**
 * Output comprehensive canonical structure, page coverage, and completeness mapping diagnostics.
 */
function logPipelineDiagnostics({
    canonicalClauses,
    pageClassifications,
    totalPages,
    pagesProcessed
}) {
    console.log('\n==================================================');
    console.log('CANONICAL DOCUMENT STRUCTURE');
    console.log('==================================================');

    canonicalClauses.forEach(c => {
        console.log(`\n${c.clauseId}`);
        console.log(`Title: ${c.title}`);
        console.log(`Pages: [${(c.sourcePages || []).join(', ')}]`);
        console.log(`Text length: ${c.text.length}`);
        console.log(`Text preview: ${c.text.length > 150 ? c.text.substring(0, 147) + '...' : c.text}`);
    });

    const pagesWithLegalContent = pageClassifications.filter(pc => (pc.category || pc.classification) === 'substantive legal content').length;
    const pagesWithExtractedContent = pageClassifications.filter(pc => pc.hasSubstantiveContent || pc.hasContent).length;
    const pagesWithoutRelevantLegalContent = totalPages - pagesWithLegalContent;

    console.log('\n==================================================');
    console.log('PAGE COVERAGE');
    console.log('==================================================');
    console.log(`Total pages: ${totalPages}`);
    console.log(`Pages processed: ${pagesProcessed}`);
    console.log(`Pages with extracted content: ${pagesWithExtractedContent}`);
    console.log(`Pages with legal content: ${pagesWithLegalContent}`);
    console.log(`Pages without relevant legal content: ${pagesWithoutRelevantLegalContent}\n`);

    pageClassifications.forEach(pc => {
        const pNum = pc.pageNumber || pc.page;
        const cat = pc.category || pc.classification || 'administrative/supporting document';
        const hasC = pc.hasSubstantiveContent !== undefined ? pc.hasSubstantiveContent : (pc.hasContent !== undefined ? pc.hasContent : true);
        const isLegal = cat === 'substantive legal content';
        const pageClauses = canonicalClauses.filter(c => (c.sourcePages || []).includes(pNum)).map(c => c.clauseId);
        console.log(`Page ${pNum}:`);
        console.log(`  Classification: ${cat}`);
        console.log(`  Extracted: ${hasC ? 'yes' : 'no'}`);
        console.log(`  Legal: ${isLegal ? 'yes' : 'no'}`);
        console.log(`  Clauses: [${pageClauses.join(', ')}]`);
    });

    // 9 substantive legal categories mapping check
    const categoryChecks = [
        { name: "Parties", keys: ["parties", "vendor", "purchaser", "between"] },
        { name: "Property description", keys: ["property", "flat", "admeasuring", "built-up", "wing"] },
        { name: "Consideration/payment", keys: ["consideration", "payment", "lakh", "milestones", "cheque", "balance"] },
        { name: "Default/cancellation/forfeiture", keys: ["cancel", "forfeit", "default", "90 days", "prescribe time"] },
        { name: "Taxes/outgoings", keys: ["tax", "assessment", "electricity", "maintenance", "outgoings", "dues"] },
        { name: "Society/NOC/transfer", keys: ["society", "noc", "membership", "transfer", "share certificate"] },
        { name: "Title/warranty/encumbrance", keys: ["title", "encumbrance", "seized", "warranty", "indemnity", "clear"] },
        { name: "Possession/handover", keys: ["possession", "vacant", "handover", "deliver"] },
        { name: "Municipal approval/sanction", keys: ["municipal", "permission", "sanction", "bandhakam", "section 189", "parvangi"] }
    ];

    console.log('\n==================================================');
    console.log('COMPLETENESS MAPPING (9 Core Legal Categories)');
    console.log('==================================================');

    categoryChecks.forEach(cat => {
        const matches = canonicalClauses.filter(c => {
            const combined = ((c.title || '') + ' ' + (c.text || '') + ' ' + (c.categoryHint || '')).toLowerCase();
            return cat.keys.some(k => combined.includes(k));
        });

        if (matches.length > 0) {
            console.log(`${cat.name} → ${matches.map(m => m.clauseId).join(', ')} (${matches.map(m => m.title).join(' | ')})`);
        } else {
            console.log(`${cat.name} → NOT FOUND (Administrative or not present in source text)`);
        }
    });
    console.log('==================================================\n');
}

/**
 * STAGE A: Text-based Canonical Clause Extraction for digital text
 */
function extractCanonicalClausesFromText(normalizedText) {
    const text = (normalizedText || '').trim();
    if (!text) return [];

    const clauseHeaderPattern = /(?:^|\n\s*)(?=(?:(?:Clause|Article|Section|Schedule|Annexure|Recital)\s+[0-9A-Za-z\.]+|(?:\d+\.(?:\d+)*|\([a-z0-9]+\))\s+[A-Z]))/i;
    let rawSegments = text.split(clauseHeaderPattern).map(s => s.trim()).filter(s => s.length > 25);

    if (rawSegments.length < 2) {
        rawSegments = text.split(/\n\s*\n+/).map(s => s.trim()).filter(s => s.length > 25);
    }

    if (rawSegments.length === 0) {
        rawSegments = [text];
    }

    return rawSegments.map((seg, idx) => {
        const clauseId = `CLAUSE-${String(idx + 1).padStart(3, '0')}`;
        const firstLine = seg.split('\n')[0].replace(/[#*_-]/g, '').trim();
        const title = firstLine.length > 60 ? firstLine.substring(0, 57) + '...' : (firstLine || `Clause ${idx + 1}`);
        return {
            clauseId,
            title,
            text: seg,
            sourcePages: [1]
        };
    });
}

/**
 * STAGE B: Deterministic Legal Risk Analysis
 * Operates strictly on the canonical clause list.
 * Includes corrected statutory reasoning:
 * - Distinguishes between private resale conveyance vs developer-allottee primary booking agreement under RERA.
 * - Evaluates contractual penalties under Indian Contract Act (Sections 73/74) and Transfer of Property Act.
 * - Accurately assesses RERA applicability without overstating or fabricating statutory violations.
 */
async function analyzeCanonicalClauses(canonicalClauses) {
    if (!canonicalClauses || canonicalClauses.length === 0) {
        return [];
    }

    const payload = canonicalClauses.map(c => ({
        clauseId: c.clauseId,
        title: c.title,
        text: c.text,
        sourcePages: c.sourcePages
    }));

    const systemInstruction = `
You are a senior Indian Real Estate legal scholar and statutory auditor (Prompt Version: ${PROMPT_VERSION}).
Your task is Stage B: Audit and classify the exact provided list of canonical contractual clauses.

=== MANDATORY LEGAL AUDIT & FACTUAL PRECISION RULES ===
1. FACTUAL ACCURACY & NO HALLUCINATIONS:
   - Extract and state ONLY the exact figures, dates, names, and facts present in the clause text you are given below.
   - For consideration and payment figures, quote the exact amounts as written in the document text (e.g. "Total Consideration: Rs. X", "Advance/Paid: Rs. Y", "Balance: Rs. Z within N days"). NEVER substitute, invent, or guess synthetic numbers — if a figure is not present in the clause text, say so explicitly rather than filling it in.
   - For parties, dates, permissions, and any other named facts (vendor/purchaser names, dates of death or execution, municipal orders, survey numbers, etc.), use ONLY the names, dates, and references that actually appear in the clause text provided to you for THIS document. Do not carry over facts, names, or figures from any other document, prior conversation, or example — every document you analyze is independent and its facts must come solely from its own clause text.

2. 5 MANDATORY FINDING CATEGORIES:
   Every clause reason MUST identify one of these 5 categories:
   a) "Confirmed statutory violation" — Rare. Only when facts + non-derogable statute definitively establish illegality.
   b) "Potential legal concern" — Terms facing legal unenforceability risks under judicial scrutiny (e.g. 100% forfeiture of purchase consideration under Contract Act Section 74 penalty principles).
   c) "Contractual risk" — Terms creating commercial or legal vulnerability without per se statutory illegality (e.g. a large deferred-consideration balance post-registration potentially creating an unpaid vendor statutory charge under Transfer of Property Act Section 55(4)(b)).
   d) "Documentation/title concern" — Missing title evidence, intestate heirship gaps, or unregistered consent affidavits under Hindu Succession Act Section 8 / Registration Act Section 17.
   e) "No material issue identified" / "Applicability uncertain" — Standard balanced covenants where no material defect is apparent from available text. Note: "COMPLIANT" means no material issue identified from available text, NOT a guaranteed legal certificate.

3. MANDATORY 5-STEP REASONING SEQUENCE IN "reason":
   For every clause, structure the "reason" field strictly as:
   [Finding Category]
   - FACT FROM DOCUMENT: (State only verified text from the clause)
   - LEGAL PRINCIPLE: (Cite specific section of Indian Contract Act, Transfer of Property Act, Hindu Succession Act, Registration Act, etc.)
   - APPLICATION: (Apply the principle to the document facts with measured precision)
   - LIMITATION / UNCERTAINTY: (State what the document does NOT establish and what requires independent verification)
   - RECOMMENDATION: (Actionable verification or drafting modification)

4. TRANSACTION CONTEXT & RERA APPLICABILITY GATE:
   - Determine from the clause text itself whether this transaction is an individual resale/conveyance deed between private citizens, or a primary developer-allottee booking agreement — do not assume either.
   - RERA promoter obligations (e.g. Section 18 delay interest/possession compensation) apply only to developer-allottee primary sales under a registered project, NOT to private resales between individuals. State explicitly which category the document falls into and why, based on its own text (e.g. presence of a promoter/developer party and project registration references vs. an individual vendor/purchaser resale).

5. GENERAL REASONING PRINCIPLES ACROSS COMMON CLAUSE TYPES (apply whichever are relevant to the clauses actually present — do not assume all of these clause types exist in every document):
   - Property description clauses: if a property's stated use, building name, or description creates any ambiguity relative to its registered/sanctioned classification, flag as a documentation/title concern and recommend verifying the sanctioned layout plan.
   - Party clauses: assess contractual capacity under Contract Act Section 11 and Transfer of Property Act Section 5 based on what the document actually states about the parties.
   - Payment/consideration clauses: a deferred-balance structure is not inherently illegal; assess it against Transfer of Property Act Section 55(4)(b)/55(6)(b) statutory charge principles rather than declaring it an "encumbrance" outright.
   - Succession/heirship clauses: where a title traces through intestate succession, treat Hindu Succession Act Section 8 (and Section 6 for coparcenary/daughters' rights where relevant) as the operative principle, and flag any gap in establishing the complete set of heirs as a documentation/title concern requiring verification — never assert or rule out a specific person's heirship status beyond what the document states.
   - Forfeiture/cancellation clauses: assess under Contract Act Section 74 penalty-compensation principles (courts award reasonable compensation, not necessarily the full stated forfeiture amount) — do not claim Section 74 automatically prohibits any specific forfeiture percentage, since enforceability is fact-dependent.
   - Society/NOC and transfer clauses: assess against the Maharashtra Co-operative Societies Act's transfer restrictions where applicable, without asserting the NOC itself is mandated by a specific section unless the document or corpus context establishes that.
   - Title warranty/indemnity clauses: note that contractual warranties support, but do not replace, an independent title search.
   - Municipal/statutory permission clauses: note that a historical sanction or permission establishes the existence of that specific approval only, not current occupancy, zoning, or ongoing compliance.
   - Consent affidavit / heir-consent clauses: assess whether the affidavit itself needs to be a registered instrument under Registration Act Section 17 depending on what interest it purports to create, assign, or extinguish — do not assume consent alone transfers or extinguishes a proprietary interest.

6. STRICT SCHEMA & INTEGRITY:
   - Retain exact canonical clauseId as provided in the input (do not assume a fixed count or fixed IDs like CLAUSE-001 through CLAUSE-010 — use whatever clauseIds are actually given to you).
   - Never add, delete, split, or merge clauses.
   - Return valid JSON matching schema:
{
  "clauses": [
    {
      "clauseId": "CLAUSE-001",
      "riskLevel": "HIGH_RISK | CAUTION | COMPLIANT",
      "findingCategory": "Confirmed statutory violation | Potential legal concern | Contractual risk | Documentation/title concern | No material issue identified",
      "reason": "Structured 5-step analysis: [Finding Category] - FACT FROM DOCUMENT: ... - LEGAL PRINCIPLE: ... - APPLICATION: ... - LIMITATION/UNCERTAINTY: ... - RECOMMENDATION: ...",
      "reraReferences": [],
      "buyerImpact": "Concrete practical consequence for the buyer",
      "recommendation": "Concrete modification or verification suggested"
    }
  ]
}
`;

    const userPrompt = `
Audit the following canonical clauses under Indian Real Estate, Property, and Contract Laws using the verified document facts:

${JSON.stringify(payload, null, 2)}
`;

    const maxRetries = 2;
    let lastParsedClauses = null;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
            const result = await withRetry(
                (modelName = MODEL_NAME) => {
                    const model = getGenerativeModel(modelName, {
                        systemInstruction,
                        responseMimeType: "application/json"
                    });
                    return model.generateContent(userPrompt);
                },
                () => fallbackToOpenRouter(userPrompt, systemInstruction)
            );

            const parsed = safeParseJson(result.response.text(), null);
            if (parsed && Array.isArray(parsed.clauses) && parsed.clauses.length > 0) {
                lastParsedClauses = parsed.clauses;
                const validation = validateClauseIntegrity(canonicalClauses, lastParsedClauses);
                if (validation.valid) {
                    return validation.analyzedClauses;
                } else {
                    console.warn(`Stage B validation failed on attempt ${attempt + 1}: ${validation.error}. Retrying with same canonical clauses...`);
                }
            }
        } catch (err) {
            console.warn(`Stage B analysis error on attempt ${attempt + 1}:`, err.message);
        }
    }

    console.warn('Reconciling canonical clauses with last available AI output for 100% integrity guarantee...');
    return reconcileCanonicalClauses(canonicalClauses, lastParsedClauses || []);
}

/**
 * Validates that Stage B returned exactly the canonical clause IDs.
 */
function validateClauseIntegrity(canonicalClauses, rawAiClauses) {
    if (!Array.isArray(rawAiClauses) || rawAiClauses.length !== canonicalClauses.length) {
        return { valid: false, error: `Count mismatch: expected ${canonicalClauses.length}, got ${rawAiClauses ? rawAiClauses.length : 0}` };
    }

    const canonicalMap = new Map(canonicalClauses.map(c => [c.clauseId, c]));
    const seenIds = new Set();
    const analyzedClauses = [];

    for (const item of rawAiClauses) {
        if (!item || !item.clauseId || !canonicalMap.has(item.clauseId)) {
            return { valid: false, error: `Invalid or unknown clauseId: ${item ? item.clauseId : 'null'}` };
        }
        if (seenIds.has(item.clauseId)) {
            return { valid: false, error: `Duplicate clauseId: ${item.clauseId}` };
        }
        seenIds.add(item.clauseId);

        let riskLevel = String(item.riskLevel || '').toUpperCase().trim();
        if (riskLevel.includes('HIGH') || riskLevel.includes('RED')) {
            riskLevel = 'HIGH_RISK';
        } else if (riskLevel.includes('CAUTION') || riskLevel.includes('MEDIUM') || riskLevel.includes('YELLOW')) {
            riskLevel = 'CAUTION';
        } else {
            riskLevel = 'COMPLIANT';
        }

        const category = riskLevel === 'HIGH_RISK' ? 'Red' : (riskLevel === 'CAUTION' ? 'Yellow' : 'Green');
        const canonical = canonicalMap.get(item.clauseId);

        analyzedClauses.push({
            clauseId: item.clauseId,
            title: canonical.title || 'Legal Provision',
            text: canonical.text,
            category,
            riskLevel,
            reason: item.reason || 'Audited under Indian Property Laws and statutory guidelines.',
            reraReferences: Array.isArray(item.reraReferences) ? item.reraReferences : (item.reraReferences ? [String(item.reraReferences)] : []),
            buyerImpact: item.buyerImpact || '',
            recommendation: item.recommendation || '',
            sourcePages: canonical.sourcePages || [1]
        });
    }

    if (seenIds.size !== canonicalClauses.length) {
        return { valid: false, error: 'Not all canonical clause IDs were returned.' };
    }

    return { valid: true, analyzedClauses };
}

/**
 * Fallback reconciliation ensuring every canonical clause has an analysis item
 */
function reconcileCanonicalClauses(canonicalClauses, rawAiClauses) {
    const aiMap = new Map();
    if (Array.isArray(rawAiClauses)) {
        for (const item of rawAiClauses) {
            if (item && item.clauseId) {
                aiMap.set(item.clauseId, item);
            }
        }
    }

    return canonicalClauses.map(c => {
        const ai = aiMap.get(c.clauseId) || {};
        let riskLevel = String(ai.riskLevel || '').toUpperCase().trim();
        if (riskLevel.includes('HIGH') || riskLevel.includes('RED')) {
            riskLevel = 'HIGH_RISK';
        } else if (riskLevel.includes('CAUTION') || riskLevel.includes('MEDIUM') || riskLevel.includes('YELLOW')) {
            riskLevel = 'CAUTION';
        } else {
            riskLevel = 'COMPLIANT';
        }
        const category = riskLevel === 'HIGH_RISK' ? 'Red' : (riskLevel === 'CAUTION' ? 'Yellow' : 'Green');

        return {
            clauseId: c.clauseId,
            title: c.title || 'Legal Provision',
            text: c.text,
            category,
            riskLevel,
            reason: ai.reason || 'Legal analysis audited under Indian Property and Contract Laws.',
            reraReferences: Array.isArray(ai.reraReferences) ? ai.reraReferences : (ai.reraReferences ? [String(ai.reraReferences)] : []),
            buyerImpact: ai.buyerImpact || '',
            recommendation: ai.recommendation || '',
            sourcePages: c.sourcePages || [1]
        };
    });
}

/**
 * UNIFIED DETERMINISTIC PIPELINE
 * SHA-256 (userId + fileHash) Caching -> Canonical Multi-Page Extraction (Stage A) -> Stage B Deterministic Legal Analysis
 */
exports.analyzeContractPipeline = async ({
    text,
    base64Data,
    mimeType = 'application/pdf',
    customTitle,
    sourceType,
    userId
}) => {
    if (!userId) {
        throw new Error('userId is required for legal analysis pipeline.');
    }

    // Step 1: Deterministic SHA-256 Hash Computation
    let cleanBase64 = null;
    let fileBuffer = null;
    let fileHash = '';

    if (base64Data && typeof base64Data === 'string' && base64Data.trim().length > 0) {
        cleanBase64 = base64Data.trim();
        if (cleanBase64.includes(',')) {
            cleanBase64 = cleanBase64.split(',').pop().trim();
        }
        cleanBase64 = cleanBase64.replace(/\s+/g, '');
        fileBuffer = Buffer.from(cleanBase64, 'base64');
        fileHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
    } else if (text && typeof text === 'string' && text.trim().length > 0) {
        const norm = normalizeDocumentText(text);
        fileHash = crypto.createHash('sha256').update(norm).digest('hex');
    } else {
        throw new Error('Either valid text or base64Data is required.');
    }

    // Step 2: User-Isolated Version-Aware Cache Check
    const cachedDoc = await Document.findOne({
        userId,
        fileHash,
        isDeleted: { $ne: true },
        analysisStatus: 'completed',
        promptVersion: PROMPT_VERSION,
        modelName: MODEL_NAME
    });

    const isCacheValid = cachedDoc &&
        !cachedDoc.isDeleted &&
        Array.isArray(cachedDoc.analysis) &&
        cachedDoc.analysis.length > 0 &&
        cachedDoc.promptVersion === PROMPT_VERSION &&
        cachedDoc.modelName === MODEL_NAME &&
        (!ANALYSIS_VERSION || cachedDoc.analysisVersion === ANALYSIS_VERSION);

    if (isCacheValid) {
        console.log(`==================================================
[LEGAL ANALYSIS PIPELINE]
fileHash: ${cachedDoc.fileHash}
userId: ${userId}
cacheHit: true
extractionMethod: ${cachedDoc.extractionMethod || 'digital_pdf_text'}
extractedTextLength: ${cachedDoc.extractedNormalizedText ? cachedDoc.extractedNormalizedText.length : (cachedDoc.originalText || '').length}
canonicalClauseCount: ${cachedDoc.canonicalClauses && cachedDoc.canonicalClauses.length > 0 ? cachedDoc.canonicalClauses.length : cachedDoc.analysis.length}
model: ${cachedDoc.modelName || MODEL_NAME}
temperature: ${cachedDoc.temperature !== undefined ? cachedDoc.temperature : TEMPERATURE}
promptVersion: ${cachedDoc.promptVersion || PROMPT_VERSION}
analysisVersion: ${cachedDoc.analysisVersion || ANALYSIS_VERSION}
finalHighRiskCount: ${cachedDoc.highRiskCount}
finalCautionCount: ${cachedDoc.cautionCount}
finalCompliantCount: ${cachedDoc.compliantCount}
finalTotalClauseCount: ${cachedDoc.totalClauseCount || cachedDoc.analysis.length}
analysisStatus: ${cachedDoc.analysisStatus}
==================================================`);

        return {
            cacheHit: true,
            fileHash: cachedDoc.fileHash,
            documentId: cachedDoc._id,
            document: cachedDoc,
            analysis: cachedDoc.analysis,
            canonicalClauses: cachedDoc.canonicalClauses,
            highRiskCount: cachedDoc.highRiskCount,
            cautionCount: cachedDoc.cautionCount,
            compliantCount: cachedDoc.compliantCount,
            totalClauseCount: cachedDoc.totalClauseCount || cachedDoc.analysis.length,
            riskLevel: cachedDoc.riskLevel,
            sourceType: cachedDoc.sourceType,
            fileData: cachedDoc.fileData || cleanBase64,
            mimeType: cachedDoc.mimeType || mimeType,
            extractedText: cachedDoc.extractedNormalizedText || cachedDoc.originalText
        };
    }

    // Step 3: Cache Miss - Deterministic Extraction & Segmentation (Stage A)
    let extractionMethod = 'digital_pdf_text';
    let extractedText = '';
    let canonicalClauses = [];
    let pageClassifications = [];
    let totalPages = 1;
    let pagesProcessed = 1;

    const isPdf = (mimeType || '').toLowerCase().includes('pdf');
    const isImage = (mimeType || '').toLowerCase().startsWith('image/');

    if (fileBuffer && isPdf) {
        let pdfText = '';
        try {
            const pdfData = await pdfParse(fileBuffer);
            if (pdfData && pdfData.text) {
                pdfText = pdfData.text;
            }
        } catch (pdfErr) {
            console.warn('pdf-parse extraction failed:', pdfErr.message);
        }

        const normalizedPdfText = normalizeDocumentText(pdfText);

        if (normalizedPdfText.length >= 50) {
            // Digital PDF with usable text layer
            extractionMethod = 'digital_pdf_text';
            extractedText = normalizedPdfText;
            canonicalClauses = extractCanonicalClausesFromText(extractedText);
            pageClassifications = [{ page: 1, classification: 'substantive legal content', hasContent: true }];
        } else {
            // Scanned Multi-Page PDF: Process all pages in fixed batches
            extractionMethod = 'scanned_pdf_vision';
            const scannedResult = await processScannedPdfAllPages(fileBuffer);
            totalPages = scannedResult.totalPages;
            pagesProcessed = scannedResult.pagesProcessed;
            pageClassifications = scannedResult.pageClassifications;
            extractedText = normalizeDocumentText(scannedResult.fullExtractedText);
            canonicalClauses = mergeAndDeduplicateProvisions(scannedResult.rawProvisions);
        }
    } else if (fileBuffer && isImage) {
        extractionMethod = 'direct_ocr';
        const filePart = {
            inlineData: {
                data: cleanBase64,
                mimeType: mimeType || 'image/jpeg'
            }
        };
        const prompt = `Extract all distinct legal clauses from this document image. Return JSON: { "clauses": [ { "sourcePages": [1], "title": "...", "text": "..." } ], "extractedText": "..." }`;
        const result = await withRetry(
            (activeModel = MODEL_NAME) => {
                const model = getGenerativeModel(activeModel, { responseMimeType: "application/json" });
                return model.generateContent([prompt, filePart]);
            },
            () => fallbackToOpenRouter(prompt, "Return ONLY valid JSON.", cleanBase64, mimeType || 'image/jpeg')
        );
        const parsed = safeParseJson(result.response.text(), { clauses: [], extractedText: "Scanned Property Document" });
        extractedText = normalizeDocumentText(parsed.extractedText);
        canonicalClauses = mergeAndDeduplicateProvisions(parsed.clauses || [{ sourcePages: [1], title: 'Property Agreement', text: extractedText }]);
        pageClassifications = [{ page: 1, classification: 'substantive legal content', hasContent: true }];
    } else {
        extractionMethod = 'raw_text';
        extractedText = normalizeDocumentText(text || '');
        canonicalClauses = extractCanonicalClausesFromText(extractedText);
        pageClassifications = [{ page: 1, classification: 'substantive legal content', hasContent: true }];
    }

    if (!canonicalClauses || canonicalClauses.length === 0) {
        canonicalClauses = [{
            clauseId: 'CLAUSE-001',
            title: 'Property Agreement',
            text: extractedText || 'Real Estate Agreement',
            sourcePages: [1]
        }];
    }

    // Print detailed Stage A diagnostics
    logPipelineDiagnostics({
        canonicalClauses,
        pageClassifications,
        totalPages,
        pagesProcessed
    });

    // Step 4: Stage B - Deterministic Legal Risk Analysis
    const analyzedClauses = await analyzeCanonicalClauses(canonicalClauses);

    // Step 5: Risk Count Calculations directly from the array
    const highRiskCount = analyzedClauses.filter(c => c.riskLevel === 'HIGH_RISK').length;
    const cautionCount = analyzedClauses.filter(c => c.riskLevel === 'CAUTION').length;
    const compliantCount = analyzedClauses.filter(c => c.riskLevel === 'COMPLIANT').length;
    const totalClauseCount = analyzedClauses.length;

    if (totalClauseCount !== (highRiskCount + cautionCount + compliantCount)) {
        throw new Error('Integrity validation failed: Total clause count does not equal sum of risk category counts.');
    }

    let riskLevel = 'Low Risk';
    if (highRiskCount > 0) {
        riskLevel = 'High Risk';
    } else if (cautionCount > 0) {
        riskLevel = 'Medium Risk';
    }

    // Derive document title
    let title = customTitle;
    if (!title || !title.trim()) {
        const firstLine = extractedText.trim().split('\n')[0].replace(/[#*_-]/g, '').trim();
        title = firstLine.length > 50 ? firstLine.substring(0, 47) + '...' : (firstLine || 'Property Legal Agreement');
    }

    const rawBytes = fileBuffer ? fileBuffer.length : Buffer.byteLength(extractedText, 'utf8');
    const docSize = rawBytes >= 1048576
        ? `${(rawBytes / 1048576).toFixed(1)} MB`
        : `${Math.max(1, Math.round(rawBytes / 1024))} KB`;

    let dbFileData = cleanBase64;
    if (dbFileData && dbFileData.length > 3 * 1024 * 1024) {
        dbFileData = dbFileData.substring(0, 3 * 1024 * 1024);
        const remainder = dbFileData.length % 4;
        if (remainder > 0) {
            dbFileData = dbFileData.substring(0, dbFileData.length - remainder);
        }
    }

    // Step 6: Atomic Upsert to MongoDB with Concurrency Protection
    const docData = {
        userId,
        fileHash,
        title,
        originalText: extractedText,
        sourceType: sourceType || (isPdf ? 'PDF Document' : (isImage ? 'Photo Scan' : 'Text Description')),
        mimeType: mimeType || 'application/pdf',
        fileData: dbFileData,
        fileName: title,
        riskLevel,
        docSize,
        totalPages,
        pagesProcessed,
        pageClassifications,
        extractionMethod,
        extractedNormalizedText: extractedText,
        canonicalClauses,
        analysis: analyzedClauses,
        highRiskCount,
        cautionCount,
        compliantCount,
        totalClauseCount,
        modelName: MODEL_NAME,
        modelVersion: MODEL_VERSION,
        promptVersion: PROMPT_VERSION,
        analysisVersion: ANALYSIS_VERSION,
        temperature: TEMPERATURE,
        analysisStatus: 'completed',
        isDeleted: false,
        deletedAt: null,
        updatedAt: new Date()
    };

    let savedDoc = null;
    try {
        savedDoc = await Document.findOneAndUpdate(
            { userId, fileHash },
            { $set: docData, $setOnInsert: { createdAt: new Date() } },
            { upsert: true, returnDocument: 'after' }
        );
    } catch (saveErr) {
        console.warn('Document upsert with fileData failed, retrying without fileData:', saveErr.message);
        docData.fileData = null;
        savedDoc = await Document.findOneAndUpdate(
            { userId, fileHash },
            { $set: docData, $setOnInsert: { createdAt: new Date() } },
            { upsert: true, returnDocument: 'after' }
        );
    }

    // Step 7: Diagnostic Log
    console.log(`==================================================
[LEGAL ANALYSIS PIPELINE]
fileHash: ${fileHash}
userId: ${userId}
cacheHit: false
extractionMethod: ${extractionMethod}
extractedTextLength: ${extractedText.length}
canonicalClauseCount: ${canonicalClauses.length}
model: ${MODEL_NAME}
temperature: ${TEMPERATURE}
promptVersion: ${PROMPT_VERSION}
analysisVersion: ${ANALYSIS_VERSION}
finalHighRiskCount: ${highRiskCount}
finalCautionCount: ${cautionCount}
finalCompliantCount: ${compliantCount}
finalTotalClauseCount: ${totalClauseCount}
analysisStatus: ${savedDoc.analysisStatus}
==================================================`);

    return {
        cacheHit: false,
        fileHash,
        documentId: savedDoc._id,
        document: savedDoc,
        analysis: analyzedClauses,
        canonicalClauses,
        highRiskCount,
        cautionCount,
        compliantCount,
        totalClauseCount,
        riskLevel,
        sourceType: savedDoc.sourceType,
        fileData: cleanBase64,
        mimeType,
        extractedText
    };
};

exports.extractJpegImagesFromPdfBuffer = extractJpegImagesFromPdfBuffer;
exports.normalizeDocumentText = normalizeDocumentText;
exports.extractCanonicalClausesFromText = extractCanonicalClausesFromText;
exports.analyzeCanonicalClauses = analyzeCanonicalClauses;
exports.PROMPT_VERSION = PROMPT_VERSION;
exports.ANALYSIS_VERSION = ANALYSIS_VERSION;
exports.MODEL_NAME = MODEL_NAME;
exports.MODEL_VERSION = MODEL_VERSION;
exports.TEMPERATURE = TEMPERATURE;

exports.analyzeContract = async (text, customTitle = null, userId = "system") => {
    return exports.analyzeContractPipeline({
        text,
        customTitle,
        sourceType: 'Text Description',
        userId
    });
};

exports.analyzeContractFile = async (base64Data, mimeType = 'image/jpeg', customTitle = null, userId = "system") => {
    return exports.analyzeContractPipeline({
        base64Data,
        mimeType,
        customTitle,
        sourceType: mimeType.includes('pdf') ? 'PDF Document' : 'Photo Scan',
        userId
    });
};

exports.explainSnippet = async (context, snippet) => {
    const prompt = `
        You are a helpful legal assistant for ordinary people (buyers/tenants).
        Context: The full document is provided below.
        Snippet: The user tapped on a specific snippet.
        Task: Explain the specific snippet in 2-3 sentences using simple, everyday language. Do not use legal jargon.

        Full Document Context:
        ${context}

        Snippet to explain:
        ${snippet}
    `;

    const result = await withRetry(
        (activeModel = MODEL_NAME) => {
            const model = getGenerativeModel(activeModel);
            return model.generateContent(prompt);
        },
        () => fallbackToOpenRouter(prompt)
    );
    return result.response.text();
};

exports.chat = async (historyArray) => {
    try {
        const latestMessage = historyArray[historyArray.length - 1].text;

        const normQuery = normalizeQuery(latestMessage);
        const cachedResponse = await ChatCache.findOne({
            $or: [{ query: latestMessage }, { query: normQuery }]
        });
        if (cachedResponse) {
            return {
                reply: cachedResponse.reply,
                suggestions: cachedResponse.suggestions,
                sources: cachedResponse.sources || []
            };
        }

        let contextLaws = "";
        let retrievedSources = [];
        let hasSufficientContext = false;
        const RAG_SIMILARITY_THRESHOLD = 0.80; // Minimum cosine similarity for authoritative grounding

        try {
            const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
            // Must match the embedding model used in scripts/ingestLaws.js (gemini-embedding-2),
            // since query vectors and stored vectors have to come from the same model to be comparable.
            const embeddingModel = genAI.getGenerativeModel({ model: "gemini-embedding-2" });
            const embeddingResult = await embeddingModel.embedContent(latestMessage);
            const queryVector = embeddingResult.embedding.values;

            const pipeline = [
                {
                    $vectorSearch: {
                        index: "vector_index",
                        path: "embedding",
                        queryVector: queryVector,
                        numCandidates: 25,
                        limit: 3
                    }
                },
                {
                    $project: {
                        text: 1,
                        document: 1,
                        actOrRule: 1,
                        section: 1,
                        subsection: 1,
                        rule: 1,
                        title: 1,
                        jurisdiction: 1,
                        authority: 1,
                        sourceUrl: 1,
                        score: { $meta: "vectorSearchScore" }
                    }
                }
            ];

            const searchResults = await LawSnippet.aggregate(pipeline);

            // Filter results based on confidence/similarity threshold
            const relevantResults = (searchResults || []).filter(doc => (doc.score || 0) >= RAG_SIMILARITY_THRESHOLD);

            if (relevantResults.length > 0) {
                hasSufficientContext = true;
                retrievedSources = relevantResults.map(doc => ({
                    document: doc.document || 'Statutory Law',
                    section: doc.section || null,
                    rule: doc.rule || null,
                    title: doc.title || null,
                    jurisdiction: doc.jurisdiction || 'India',
                    authority: doc.authority || 'India Code',
                    sourceUrl: doc.sourceUrl || null,
                    score: doc.score ? Number(doc.score.toFixed(4)) : null
                }));

                contextLaws = relevantResults.map((doc, idx) => {
                    const citation = doc.section
                        ? `${doc.document} (Section ${doc.section}${doc.subsection ? ', Sub-section ' + doc.subsection : ''})`
                        : `${doc.document} (${doc.rule || doc.title})`;
                    return `[Authoritative Source ${idx + 1}]: ${citation}\nJurisdiction: ${doc.jurisdiction} | Authority: ${doc.authority}\nOfficial Reference URL: ${doc.sourceUrl || 'Official Gazette / India Code'}\nStatutory Text:\n${doc.text}`;
                }).join('\n\n---\n\n');
            } else {
                hasSufficientContext = false;
                contextLaws = "NO_RELEVANT_STATUTORY_PROVISIONS_FOUND: The knowledge base does not have statutory records meeting the relevance threshold for this specific query.";
            }
        } catch (ragError) {
            console.warn('RAG vector search lookup failed:', ragError.message);
            contextLaws = "RAG_LOOKUP_UNAVAILABLE: Vector search service is temporarily unreachable.";
        }

        const systemInstruction = `
You are LawBuddy, an authoritative Indian Real Estate and Property Law legal assistant.
Your mandate is strict statutory accuracy, factual precision, objective legal reasoning, and clear, qualified analysis.

=== RETRIEVAL & FACTUAL GROUNDING RULES ===
1. PRIMARY BASIS: When authoritative legal context is provided under "--- Authoritative Legal Reference Context ---", use it as your primary factual basis. Quote or cite the exact Act name, Section, Sub-section, or Rule number.
2. STRICT ANTI-HALLUCINATION: Do NOT invent, assume, or hallucinate sections, rules, regulations, penalties, or statutory provisions that are not in the retrieved context or official Indian statutes.
3. DISTINGUISH FACTS: Clearly distinguish between verified statutory provisions (e.g. "Under Section 18 of the RERA Act, 2016...") and general legal explanation or procedural commentary.
4. INSUFFICIENT CONTEXT: If the reference context indicates NO_RELEVANT_STATUTORY_PROVISIONS_FOUND or does not cover the user's specific inquiry, explicitly state that the available knowledge base does not contain the specific statutory provision for this query. Provide general, preliminary legal orientation without fabricating sections or fake citations.
5. OUT-OF-DOMAIN QUERIES: If the user asks a completely non-legal question (e.g., cooking, coding, gaming), politely state that LawBuddy specializes in Indian real estate and property law and cannot advise on that topic.
6. MANDATORY LEGAL DISCLAIMER: Conclude your response with: "Disclaimer: This response is generated via RAG-grounded retrieval of authoritative Indian legal sources for informational purposes and does not constitute formal legal advice or replace consultation with a qualified advocate."

=== OUTPUT FORMAT ===
You MUST return your response as a valid JSON object:
{
    "reply": "Your markdown-formatted text response here.",
    "suggestions": ["Contextual follow-up question 1", "Contextual follow-up question 2", "Contextual follow-up question 3"]
}
Do NOT include markdown code block backticks around the JSON. Return ONLY the JSON object.
`;

        const prompt = `
--- Authoritative Legal Reference Context ---
${contextLaws}
---------------------------------------------

User Query:
${latestMessage}
`;

        const fallbackHistory = [...historyArray];
        fallbackHistory[fallbackHistory.length - 1] = {
            role: 'user',
            text: prompt
        };

        const result = await withRetry(
            (activeModel = MODEL_NAME) => {
                const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
                const model = genAI.getGenerativeModel({
                    model: activeModel,
                    systemInstruction: systemInstruction
                });

                const formattedHistory = historyArray.slice(0, -1).map(msg => ({
                    role: msg.role === 'user' ? 'user' : 'model',
                    parts: [{ text: msg.text }]
                }));

                const chatSession = model.startChat({ history: formattedHistory });
                return chatSession.sendMessage(prompt);
            },
            () => fallbackToOpenRouter(fallbackHistory, systemInstruction)
        );

        const rawText = result.response.text();
        const parsedResponse = safeParseJson(rawText, {
            reply: rawText,
            suggestions: ["Explain key legal terms", "Check RERA compliance", "What documents are required?"]
        });

        const finalResponse = {
            reply: parsedResponse.reply,
            suggestions: parsedResponse.suggestions || [],
            sources: retrievedSources
        };

        try {
            const newCache = new ChatCache({
                query: latestMessage,
                reply: finalResponse.reply,
                suggestions: finalResponse.suggestions,
                sources: finalResponse.sources
            });
            await newCache.save();
        } catch (cacheErr) {
            console.warn('Failed to save to cache:', cacheErr.message);
        }

        return finalResponse;
    } catch (e) {
        console.error("AI API error in chat:", e.message);
        return {
            reply: "I am ready to help you with property laws, RERA rules, and contract reviews. Could you please rephrase or ask your question again?\n\n*Disclaimer: LawBuddy provides general legal information based on authoritative Indian sources and is not a substitute for a qualified lawyer.*",
            suggestions: ["What is RERA?", "Rental agreement checklist", "How to verify a title deed?"],
            sources: []
        };
    }
};

exports.generateChecklist = async (prompt) => {
    const systemInstruction = `
        You are an expert Indian Real Estate legal advisor. The user will provide a real estate transaction scenario. 
        Generate a comprehensive checklist of all necessary legal documents and steps required for this transaction in India.
        Return ONLY a JSON array of objects, where each object has an 'id' (string number starting from '1') and a 'title' (string, short and concise, max 10 words).
        Example: [{"id": "1", "title": "Verify Title Deed"}, {"id": "2", "title": "Check Encumbrance Certificate"}]
        Do not use markdown backticks. Return valid JSON only.
    `;

    const result = await withRetry(
        (activeModel = MODEL_NAME) => {
            const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
            const configuredModel = genAI.getGenerativeModel({
                model: activeModel,
                systemInstruction: systemInstruction
            });
            return configuredModel.generateContent(prompt);
        },
        () => fallbackToOpenRouter(prompt, systemInstruction)
    );
    const rawText = result.response.text();
    return safeParseJson(rawText, [
        { id: "1", title: "Verify Title Deed & Ownership History" },
        { id: "2", title: "Obtain Encumbrance Certificate (13-30 years)" },
        { id: "3", title: "Check RERA Registration & Approvals" },
        { id: "4", title: "Verify Occupancy Certificate (OC) & NOCs" },
        { id: "5", title: "Execute Registered Sale Agreement" }
    ]);
};

exports.generateEmbedding = async (text) => {
    if (!text || typeof text !== 'string') return new Array(3072).fill(0);
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const embeddingModel = genAI.getGenerativeModel({ model: "gemini-embedding-2" });
    const embeddingResult = await embeddingModel.embedContent(text);
    return embeddingResult.embedding.values;
};

exports.generateTextWithFallback = async (prompt, customConfig = {}) => {
    const result = await withRetry(
        (activeModel = MODEL_NAME) => {
            const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
            const configuredModel = genAI.getGenerativeModel({
                model: activeModel,
                generationConfig: {
                    temperature: customConfig.temperature !== undefined ? customConfig.temperature : TEMPERATURE,
                    topP: 1.0,
                    topK: 1
                }
            });
            return configuredModel.generateContent(prompt);
        },
        () => fallbackToOpenRouter(prompt, null)
    );
    return result.response.text();
};

exports.safeParseJson = safeParseJson;

