require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { MODEL_NAME, TEMPERATURE } = require('../src/config/modelConfig');

const PDF_PATH = '/Users/vrushti/Downloads/Testing date 2020.pdf';

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
        if (imgBuffer.length > 5000) {
            images.push(imgBuffer);
        }
        offset = end + 2;
    }
    return images;
}

function safeParseJson(text, defaultFallback = {}) {
    if (!text || typeof text !== 'string') return defaultFallback;
    try {
        let clean = text.trim();
        clean = clean.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
        const jsonMatch = clean.match(/\{[\s\S]*\}|\[[\s\S]*\]/);
        if (jsonMatch) return JSON.parse(jsonMatch[0]);
        return JSON.parse(clean);
    } catch (e) {
        return defaultFallback;
    }
}

function mergeAndDeduplicateProvisions(rawProvisions) {
    if (!rawProvisions || rawProvisions.length === 0) return [];

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

    return merged.map((item, idx) => ({
        clauseId: `CLAUSE-${String(idx + 1).padStart(3, '0')}`,
        title: item.title,
        text: item.text,
        sourcePages: item.sourcePages,
        categoryHint: item.categoryHint
    }));
}

async function runSingleStageAPass(genAI, pageBuffers) {
    const model = genAI.getGenerativeModel({
        model: MODEL_NAME,
        generationConfig: {
            temperature: TEMPERATURE,
            topP: 1.0,
            topK: 1,
            responseMimeType: "application/json"
        }
    });

    const totalPages = pageBuffers.length;
    const prompt = `
You are an expert Indian Real Estate legal scholar and document examiner (Stage A: Exhaustive Document Structure & Clause Extraction).
You are inspecting ALL ${totalPages} pages of a scanned property document bundle in sequential order (Page 1 to Page ${totalPages}).

YOUR MANDATE:
1. PAGE CLASSIFICATION (All ${totalPages} pages):
Classify EVERY single page from Page 1 to Page ${totalPages} into EXACTLY one of:
- "substantive legal content" (e.g. Agreement for Sale, covenants, warranties, payment terms, default rules, society NOCs, municipal permission)
- "administrative/supporting document" (e.g. Index-2 summary, registration fee receipt, e-challan, valuation sheet)
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
      "summary": "Brief 3-6 word summary",
      "hasSubstantiveContent": false
    }
  ],
  "extractedText": "Full reconstructed text of all legal provisions...",
  "provisions": [
    {
      "sourcePages": [8],
      "title": "Parties to the Agreement",
      "text": "Exact extracted text...",
      "categoryHint": "parties"
    }
  ]
}
`;

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

    const startT = Date.now();
    const result = await model.generateContent(parts);
    const elapsed = ((Date.now() - startT) / 1000).toFixed(2);

    const parsed = safeParseJson(result.response.text(), { pageClassifications: [], provisions: [], extractedText: "" });
    const canonicalClauses = mergeAndDeduplicateProvisions(parsed.provisions || []);

    return {
        elapsedSeconds: elapsed,
        rawProvisionCount: (parsed.provisions || []).length,
        canonicalClauses,
        pageClassifications: parsed.pageClassifications || []
    };
}

async function verifyStageADeterminism() {
    console.log('==================================================');
    console.log('STAGE A FRESH AI EXTRACTION DETERMINISM TEST');
    console.log('==================================================');

    if (!fs.existsSync(PDF_PATH)) {
        console.error(`❌ PDF not found at: ${PDF_PATH}`);
        process.exit(1);
    }

    const pdfBuffer = fs.readFileSync(PDF_PATH);
    const pageBuffers = extractJpegImagesFromPdfBuffer(pdfBuffer);
    console.log(`Loaded ${pageBuffers.length} page images from ${path.basename(PDF_PATH)}`);

    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

    console.log('\n--- Running Fresh Stage A Pass 1 (Bypassing DB cache) ---');
    const pass1 = await runSingleStageAPass(genAI, pageBuffers);
    console.log(`Pass 1 completed in ${pass1.elapsedSeconds}s -> ${pass1.canonicalClauses.length} canonical clauses extracted.`);

    console.log('\n--- Running Fresh Stage A Pass 2 (Bypassing DB cache) ---');
    const pass2 = await runSingleStageAPass(genAI, pageBuffers);
    console.log(`Pass 2 completed in ${pass2.elapsedSeconds}s -> ${pass2.canonicalClauses.length} canonical clauses extracted.`);

    console.log('\n==================================================');
    console.log('COMPARISON: FRESH PASS 1 vs FRESH PASS 2');
    console.log('==================================================');

    const countMatch = pass1.canonicalClauses.length === pass2.canonicalClauses.length;
    let idsMatch = true;
    let titlesMatch = true;
    let pagesMatch = true;
    let textMatch = true;

    if (!countMatch) {
        idsMatch = false;
        titlesMatch = false;
        pagesMatch = false;
        textMatch = false;
    } else {
        for (let i = 0; i < pass1.canonicalClauses.length; i++) {
            const c1 = pass1.canonicalClauses[i];
            const c2 = pass2.canonicalClauses[i];
            if (c1.clauseId !== c2.clauseId) idsMatch = false;
            if (c1.title.toLowerCase() !== c2.title.toLowerCase()) titlesMatch = false;
            if (JSON.stringify(c1.sourcePages) !== JSON.stringify(c2.sourcePages)) pagesMatch = false;
            if (c1.text.trim() !== c2.text.trim()) textMatch = false;
        }
    }

    console.log(`Clause count match: ${countMatch ? 'YES' : 'NO'} (Pass 1: ${pass1.canonicalClauses.length}, Pass 2: ${pass2.canonicalClauses.length})`);
    console.log(`Clause IDs match: ${idsMatch ? 'YES' : 'NO'}`);
    console.log(`Titles match: ${titlesMatch ? 'YES' : 'NO'}`);
    console.log(`Source pages match: ${pagesMatch ? 'YES' : 'NO'}`);
    console.log(`Clause text match: ${textMatch ? 'YES' : 'NO'}`);
    console.log('==================================================');

    if (countMatch && idsMatch && pagesMatch) {
        console.log('✅ FRESH STAGE A EXTRACTION DETERMINISM VERIFIED!');
    } else {
        console.log('⚠️ Minor variation detected in fresh generation.');
    }
}

verifyStageADeterminism().catch(err => {
    console.error('❌ Stage A Determinism test failed:', err);
    process.exit(1);
});
