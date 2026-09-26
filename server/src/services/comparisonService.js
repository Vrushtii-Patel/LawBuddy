const crypto = require('crypto');
const mongoose = require('mongoose');
const DocumentComparison = require('../models/DocumentComparison');
const Document = require('../models/Document');
const LawSnippet = require('../models/LawSnippet');
const scanJobService = require('./scanJobService');
const llmService = require('./llmService');

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

function computeComparisonHash(userId, fileHashA, fileHashB) {
    return crypto.createHash('sha256').update(`${userId}:${fileHashA}:${fileHashB}`).digest('hex');
}

/**
 * Calculates Token Jaccard Similarity between two strings
 */
const COMPARISON_RAG_THRESHOLD = 0.70;

const STOPWORDS = new Set(['the', 'a', 'an', 'and', 'or', 'of', 'in', 'on', 'at', 'to', 'for', 'with', 'by', 'as', 'is', 'are', 'was', 'were', 'be', 'this', 'that', 'all']);

const LEGAL_TOPIC_NOUNS = [
    'possession', 'handover', 'defect', 'liability', 'structural', 'forfeiture',
    'cancellation', 'refund', 'maintenance', 'arbitration', 'dispute', 'jurisdiction',
    'conveyance', 'society', 'earnest', 'payment', 'installment', 'interest',
    'indemnity', 'penalty', 'termination', 'force majeure', 'title', 'warranty'
];

function calculateJaccardSimilarity(str1, str2) {
    if (!str1 || !str2) return 0.0;
    const tokens1 = new Set(str1.toLowerCase().replace(/[^a-z0-9\s]/g, '').split(/\s+/).filter(t => t.length > 1 && !STOPWORDS.has(t)));
    const tokens2 = new Set(str2.toLowerCase().replace(/[^a-z0-9\s]/g, '').split(/\s+/).filter(t => t.length > 1 && !STOPWORDS.has(t)));
    if (tokens1.size === 0 || tokens2.size === 0) return 0.0;
    
    let intersection = 0;
    for (const t of tokens1) {
        if (tokens2.has(t)) intersection++;
    }
    const union = new Set([...tokens1, ...tokens2]).size;
    return union > 0 ? intersection / union : 0.0;
}

function calculateCharacterSequenceSimilarity(str1, str2) {
    if (!str1 || !str2) return 0.0;
    const s1 = str1.toLowerCase().replace(/\s+/g, ' ').trim();
    const s2 = str2.toLowerCase().replace(/\s+/g, ' ').trim();
    if (s1 === s2) return 1.0;
    const maxLen = Math.max(s1.length, s2.length);
    if (maxLen === 0) return 1.0;

    const words1 = s1.split(' ');
    const set2 = new Set(s2.split(' '));
    let commonChars = 0;
    for (const w of words1) {
        if (set2.has(w)) commonChars += w.length;
    }
    return Math.min(1.0, commonChars / maxLen);
}

/**
 * Extracts pure topic keywords from a clause title (e.g. "Section 18 — Date of Possession" -> "date of possession")
 */
function cleanTitle(title) {
    if (!title) return '';
    return title.toLowerCase()
        .replace(/^(?:section|clause|article|rule|point|schedule)\s*\d+[\s.:–—-]*\s*/i, '')
        .replace(/[^a-z0-9\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
}

function hasSharedLegalTopic(titleA, titleB) {
    const tA = (titleA || '').toLowerCase();
    const tB = (titleB || '').toLowerCase();
    for (const topic of LEGAL_TOPIC_NOUNS) {
        if (tA.includes(topic) && tB.includes(topic)) {
            return true;
        }
    }
    return false;
}

/**
 * Deterministic Risk Migration Calculator
 */
function calculateDeterministicRiskMigration({
    changeStatus,
    previousRiskLevel,
    revisedRiskLevel,
    titleA = '',
    textA = ''
}) {
    const prev = previousRiskLevel || 'UNASSESSED';
    const rev = revisedRiskLevel || 'COMPLIANT';

    const protectiveKeywords = ['defect', 'possession', 'refund', 'warranty', 'society', 'conveyance', 'title'];
    const isProtective = protectiveKeywords.some(k => 
        (titleA || '').toLowerCase().includes(k) || (textA || '').toLowerCase().includes(k)
    );

    if (changeStatus === 'UNCHANGED') {
        return 'UNCHANGED_RISK';
    }

    if (changeStatus === 'ADDED') {
        if (rev === 'HIGH_RISK' || rev === 'CAUTION') {
            return 'NEW_RISK_ADDED';
        }
        return 'NO_ADVERSE_RISK_IDENTIFIED';
    }

    if (changeStatus === 'REMOVED') {
        if (prev === 'HIGH_RISK' || prev === 'CAUTION') {
            return 'RISK_REMOVED';
        }
        if (prev === 'COMPLIANT' || isProtective) {
            return 'ESCALATED_RISK';
        }
        return 'UNCHANGED_RISK';
    }

    if (changeStatus === 'MODIFIED' || changeStatus === 'SPLIT' || changeStatus === 'MERGED') {
        if (prev === 'COMPLIANT' && (rev === 'HIGH_RISK' || rev === 'CAUTION')) {
            return 'ESCALATED_RISK';
        }
        if (prev === 'CAUTION' && rev === 'HIGH_RISK') {
            return 'ESCALATED_RISK';
        }
        if ((prev === 'HIGH_RISK' || prev === 'CAUTION') && rev === 'COMPLIANT') {
            return 'REDUCED_RISK';
        }
        if (prev === 'HIGH_RISK' && rev === 'CAUTION') {
            return 'REDUCED_RISK';
        }
        if (prev === rev && prev !== 'UNASSESSED') {
            return 'UNCHANGED_RISK';
        }
        if (prev === 'UNASSESSED') {
            return (rev === 'HIGH_RISK' || rev === 'CAUTION') ? 'NEW_RISK_ADDED' : 'NO_ADVERSE_RISK_IDENTIFIED';
        }
        return 'UNCHANGED_RISK';
    }

    return 'UNCHANGED_RISK';
}

/**
 * Multi-Tier Clause Matching Engine
 */
function matchClauses(clausesA, clausesB) {
    const listA = Array.isArray(clausesA) ? [...clausesA] : [];
    const listB = Array.isArray(clausesB) ? [...clausesB] : [];

    const matchedPairs = [];
    const usedB = new Set();
    const usedA = new Set();

    // -------------------------------------------------------------------------
    // Phase 1: Normalization & Exact Match Pass
    // -------------------------------------------------------------------------
    for (let i = 0; i < listA.length; i++) {
        const a = listA[i];
        const normA = llmService.normalizeDocumentText(a.text || '');
        if (!normA) continue;

        for (let j = 0; j < listB.length; j++) {
            if (usedB.has(j)) continue;
            const b = listB[j];
            const normB = llmService.normalizeDocumentText(b.text || '');

            if (normA === normB) {
                usedA.add(i);
                usedB.add(j);
                const riskMigration = calculateDeterministicRiskMigration({
                    changeStatus: 'UNCHANGED',
                    previousRiskLevel: a.riskLevel,
                    revisedRiskLevel: b.riskLevel,
                    titleA: a.title,
                    textA: a.text
                });
                matchedPairs.push({
                    clausePairId: `PAIR-${matchedPairs.length + 1}`,
                    clauseIdA: a.clauseId || `CLAUSE-A-${i + 1}`,
                    titleA: a.title || '',
                    textA: a.text || '',
                    sourcePagesA: a.sourcePages || [1],
                    riskLevelA: a.riskLevel || null,
                    clauseIdB: b.clauseId || `CLAUSE-B-${j + 1}`,
                    titleB: b.title || '',
                    textB: b.text || '',
                    sourcePagesB: b.sourcePages || [1],
                    riskLevelB: b.riskLevel || null,
                    matchConfidence: 'EXACT',
                    changeStatus: 'UNCHANGED',
                    similarityScore: 1.0,
                    materialChangesDetected: [],
                    riskMigration
                });
                break;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Phase 2: Title Alignment & Semantic Similarity Pass
    // -------------------------------------------------------------------------
    const candidatePairs = [];

    for (let i = 0; i < listA.length; i++) {
        if (usedA.has(i)) continue;
        const a = listA[i];
        const cleanTitleA = cleanTitle(a.title);

        for (let j = 0; j < listB.length; j++) {
            if (usedB.has(j)) continue;
            const b = listB[j];
            const cleanTitleB = cleanTitle(b.title);

            const titleJaccard = calculateJaccardSimilarity(cleanTitleA, cleanTitleB);
            const bodyJaccard = calculateJaccardSimilarity(a.text, b.text);
            const bodySeqSim = calculateCharacterSequenceSimilarity(a.text, b.text);
            const sharedTopic = hasSharedLegalTopic(a.title, b.title);

            // Substantive body similarity combining token and character sequence overlap
            const effectiveBodySim = Math.max(bodyJaccard, bodySeqSim, 0.5 * bodyJaccard + 0.5 * bodySeqSim);
            const effectiveTitleSim = sharedTopic ? Math.max(0.85, titleJaccard) : titleJaccard;

            let compositeSim = 0.3 * effectiveTitleSim + 0.7 * effectiveBodySim;
            if (sharedTopic && effectiveBodySim >= 0.70) {
                compositeSim = Math.max(compositeSim, 0.85); // Confirmed renumbered topic match
            }

            if (compositeSim >= 0.50) {
                candidatePairs.push({ i, j, score: compositeSim, titleSim: effectiveTitleSim, bodySim: effectiveBodySim });
            }
        }
    }

    // Sort candidates descending by score to match best pairs first (Greedy Bipartite Alignment)
    candidatePairs.sort((x, y) => y.score - x.score);

    for (const cand of candidatePairs) {
        if (usedA.has(cand.i) || usedB.has(cand.j)) continue;
        usedA.add(cand.i);
        usedB.add(cand.j);

        const a = listA[cand.i];
        const b = listB[cand.j];

        let confidence = 'LOW';
        if (cand.score >= 0.80) {
            confidence = 'HIGH';
        } else if (cand.score >= 0.60) {
            confidence = 'MEDIUM';
        }

        const changeStatus = (cand.score >= 0.95 && a.text === b.text) ? 'UNCHANGED' : 'MODIFIED';
        const materialChanges = changeStatus === 'MODIFIED' ? detectMaterialChanges(a.text, b.text) : [];
        const riskMigration = calculateDeterministicRiskMigration({
            changeStatus,
            previousRiskLevel: a.riskLevel,
            revisedRiskLevel: b.riskLevel,
            titleA: a.title,
            textA: a.text
        });

        matchedPairs.push({
            clausePairId: `PAIR-${matchedPairs.length + 1}`,
            clauseIdA: a.clauseId || `CLAUSE-A-${cand.i + 1}`,
            titleA: a.title || '',
            textA: a.text || '',
            sourcePagesA: a.sourcePages || [1],
            riskLevelA: a.riskLevel || null,
            clauseIdB: b.clauseId || `CLAUSE-B-${cand.j + 1}`,
            titleB: b.title || '',
            textB: b.text || '',
            sourcePagesB: b.sourcePages || [1],
            riskLevelB: b.riskLevel || null,
            matchConfidence: confidence,
            changeStatus: 'MODIFIED', // Subject to diff scanner in next step
            similarityScore: parseFloat(cand.score.toFixed(3)),
            materialChangesDetected: []
        });
    }

    // -------------------------------------------------------------------------
    // Phase 3: Split & Merge Detection
    // -------------------------------------------------------------------------
    for (let i = 0; i < listA.length; i++) {
        if (usedA.has(i)) continue;
        const a = listA[i];

        // Check if a matches b[j] + b[j+1] (SPLIT)
        for (let j = 0; j < listB.length - 1; j++) {
            if (usedB.has(j) || usedB.has(j + 1)) continue;
            const combinedB = (listB[j].text || '') + ' ' + (listB[j + 1].text || '');
            const splitSim = calculateJaccardSimilarity(a.text, combinedB);
            if (splitSim >= 0.70) {
                usedA.add(i);
                usedB.add(j);
                usedB.add(j + 1);
                matchedPairs.push({
                    clausePairId: `PAIR-${matchedPairs.length + 1}`,
                    clauseIdA: a.clauseId || `CLAUSE-A-${i + 1}`,
                    titleA: a.title || '',
                    textA: a.text || '',
                    sourcePagesA: a.sourcePages || [1],
                    riskLevelA: a.riskLevel || null,
                    clauseIdB: `${listB[j].clauseId} & ${listB[j+1].clauseId}`,
                    titleB: `${listB[j].title} / ${listB[j+1].title}`,
                    textB: combinedB,
                    sourcePagesB: [...(listB[j].sourcePages || []), ...(listB[j+1].sourcePages || [])],
                    riskLevelB: listB[j].riskLevel || listB[j+1].riskLevel || null,
                    matchConfidence: 'MEDIUM',
                    changeStatus: 'SPLIT',
                    similarityScore: parseFloat(splitSim.toFixed(3)),
                    materialChangesDetected: [{
                        category: 'General Text',
                        changeDescription: 'Clause was split into two separate sub-clauses in Version B',
                        fromText: a.title,
                        toText: `${listB[j].title} & ${listB[j+1].title}`
                    }]
                });
                break;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Phase 4: Residual Unassigned Clauses (REMOVED in A, ADDED in B)
    // -------------------------------------------------------------------------
    for (let i = 0; i < listA.length; i++) {
        if (usedA.has(i)) continue;
        const a = listA[i];
        matchedPairs.push({
            clausePairId: `PAIR-${matchedPairs.length + 1}`,
            clauseIdA: a.clauseId || `CLAUSE-A-${i + 1}`,
            titleA: a.title || '',
            textA: a.text || '',
            sourcePagesA: a.sourcePages || [1],
            riskLevelA: a.riskLevel || null,
            clauseIdB: null,
            titleB: '',
            textB: '',
            sourcePagesB: [],
            riskLevelB: null,
            matchConfidence: 'NONE',
            changeStatus: 'REMOVED',
            similarityScore: 0.0,
            materialChangesDetected: []
        });
    }

    for (let j = 0; j < listB.length; j++) {
        if (usedB.has(j)) continue;
        const b = listB[j];
        matchedPairs.push({
            clausePairId: `PAIR-${matchedPairs.length + 1}`,
            clauseIdA: null,
            titleA: '',
            textA: '',
            sourcePagesA: [],
            riskLevelA: null,
            clauseIdB: b.clauseId || `CLAUSE-B-${j + 1}`,
            titleB: b.title || '',
            textB: b.text || '',
            sourcePagesB: b.sourcePages || [1],
            riskLevelB: b.riskLevel || null,
            matchConfidence: 'NONE',
            changeStatus: 'ADDED',
            similarityScore: 0.0,
            materialChangesDetected: []
        });
    }

    return matchedPairs;
}

/**
 * Deterministic Legal Diff Scanner
 * Scans for material changes (numbers, dates, modal verbs, penalties, conditions)
 */
function detectMaterialChanges(textA, textB) {
    const changes = [];
    if (!textA || !textB) return changes;

    const normA = llmService.normalizeDocumentText(textA);
    const normB = llmService.normalizeDocumentText(textB);
    if (normA === normB) return changes;

    // 1. Number & Percentage Extraction
    const numRegex = /\b(?:\d+(?:\.\d+)?%?|\b(?:one|two|three|four|five|six|seven|eight|nine|ten|twelve|fifteen|twenty|twenty-four|thirty|thirty-six|forty-eight|sixty|ninety)\b)/gi;
    const numsA = (textA.match(numRegex) || []).map(s => s.toLowerCase());
    const numsB = (textB.match(numRegex) || []).map(s => s.toLowerCase());

    const diffNumsA = numsA.filter(n => !numsB.includes(n));
    const diffNumsB = numsB.filter(n => !numsA.includes(n));
    if (diffNumsA.length > 0 || diffNumsB.length > 0) {
        changes.push({
            category: 'Duration / Deadline',
            changeDescription: `Numeric/Duration terms changed from [${diffNumsA.join(', ') || 'none'}] to [${diffNumsB.join(', ') || 'none'}]`,
            fromText: diffNumsA.join(', '),
            toText: diffNumsB.join(', ')
        });
    }

    // 2. Modal Verbs & Obligations
    const modalWords = ['shall', 'may', 'must', 'will', 'agrees to', 'sole discretion', 'without prior notice'];
    for (const w of modalWords) {
        const hasA = new RegExp(`\\b${w}\\b`, 'i').test(textA);
        const hasB = new RegExp(`\\b${w}\\b`, 'i').test(textB);
        if (hasA !== hasB) {
            changes.push({
                category: 'Obligation / Permission (shall/may)',
                changeDescription: `Obligation phrasing shifted regarding "${w}" (${hasA ? 'present in A' : 'absent in A'} → ${hasB ? 'present in B' : 'absent in B'})`,
                fromText: hasA ? w : '',
                toText: hasB ? w : ''
            });
        }
    }

    // 3. Forfeiture & Liabilities
    const liabilityTriggers = ['forfeit', 'forfeiture', 'penalty', 'liquidated damages', 'indemnify', 'hold harmless', 'waive'];
    for (const lt of liabilityTriggers) {
        const hasA = new RegExp(`\\b${lt}\\b`, 'i').test(textA);
        const hasB = new RegExp(`\\b${lt}\\b`, 'i').test(textB);
        if (hasA !== hasB) {
            changes.push({
                category: 'Liability / Indemnity / Penalty',
                changeDescription: `Liability/Penalty terms altered regarding "${lt}"`,
                fromText: hasA ? lt : '',
                toText: hasB ? lt : ''
            });
        }
    }

    // Fallback if no specific regex triggered but text differs
    if (changes.length === 0 && normA !== normB) {
        changes.push({
            category: 'General Text',
            changeDescription: 'Textual wording revised between versions',
            fromText: textA.substring(0, 100) + '...',
            toText: textB.substring(0, 100) + '...'
        });
    }

    return changes;
}

/**
 * Validates candidate statutory citations against the retrieved LawSnippets
 */
function validateCitations(proposedCitations, retrievedSnippets) {
    if (!Array.isArray(proposedCitations) || proposedCitations.length === 0) return [];
    if (!Array.isArray(retrievedSnippets) || retrievedSnippets.length === 0) return [];

    const validated = [];
    const snippetMap = new Map();
    for (const snip of retrievedSnippets) {
        if (snip && snip._id) {
            snippetMap.set(snip._id.toString(), snip);
        }
    }

    for (const cit of proposedCitations) {
        if (!cit) continue;
        let matchedSnippet = null;
        if (cit.lawSnippetId && snippetMap.has(cit.lawSnippetId.toString())) {
            matchedSnippet = snippetMap.get(cit.lawSnippetId.toString());
        } else if (cit.actName || cit.sectionOrRule) {
            // Match by actName and sectionOrRule
            matchedSnippet = retrievedSnippets.find(s => {
                const sAct = (s.actName || s.document || '').toLowerCase();
                const sSec = (s.sectionOrRule || s.section || s.rule || '').toLowerCase();
                const cAct = (cit.actName || '').toLowerCase();
                const cSec = (cit.sectionOrRule || '').toLowerCase();
                return (sAct.includes(cAct) || cAct.includes(sAct)) &&
                       (sSec.includes(cSec) || cSec.includes(sSec));
            });
        }

        if (!matchedSnippet) continue;

        const score = matchedSnippet.score !== undefined ? matchedSnippet.score : (matchedSnippet.similarityScore || 0);
        const actName = (matchedSnippet.actName || matchedSnippet.document || cit.actName || '').trim();
        const sectionOrRule = (matchedSnippet.sectionOrRule || matchedSnippet.section || matchedSnippet.rule || cit.sectionOrRule || '').trim();
        const provisionTitle = (matchedSnippet.provisionTitle || matchedSnippet.title || cit.provisionTitle || '').trim();
        const sourceUrl = (matchedSnippet.sourceUrl || cit.sourceUrl || '').trim();

        if (score >= COMPARISON_RAG_THRESHOLD && actName && sectionOrRule) {
            validated.push({
                lawSnippetId: matchedSnippet._id,
                actName,
                sectionOrRule,
                provisionTitle,
                sourceUrl,
                similarityScore: Number(Number(score).toFixed(4))
            });
        }
    }

    return validated;
}

/**
 * Vector Search against authoritative 73 LawSnippets
 */
async function retrieveLegalContextForClause(clauseText, topicHint = '') {
    try {
        const queryText = `${topicHint} ${clauseText}`.trim().substring(0, 500);
        const embedding = await llmService.generateEmbedding(queryText);

        const results = await LawSnippet.aggregate([
            {
                $vectorSearch: {
                    index: "vector_index",
                    path: "embedding",
                    queryVector: embedding,
                    numCandidates: 15,
                    limit: 3
                }
            },
            {
                $project: {
                    _id: 1,
                    actName: 1,
                    sectionOrRule: 1,
                    provisionTitle: 1,
                    snippetText: 1,
                    sourceUrl: 1,
                    score: { $meta: "vectorSearchScore" }
                }
            }
        ]);

        return results.filter(r => (r.score || 0) >= COMPARISON_RAG_THRESHOLD);
    } catch (e) {
        console.warn('Vector search warning during clause comparison:', e.message);
        return [];
    }
}

/**
 * Differential AI Legal & Risk Analysis via Gemini
 */
async function evaluateDifferentialLegalAnalysis(clausePairs) {
    const toAnalyze = clausePairs.filter(p => p.changeStatus !== 'UNCHANGED');
    if (toAnalyze.length === 0) return;

    for (const pair of toAnalyze) {
        try {
            const queryText = pair.textB || pair.textA || pair.titleB || pair.titleA;
            const topicHint = pair.titleB || pair.titleA || '';
            const retrievedSnippets = await retrieveLegalContextForClause(queryText, topicHint);

            let contextStr = '';
            if (retrievedSnippets.length > 0) {
                contextStr = retrievedSnippets.map((s, idx) => 
                    `[LawSnippet ${idx + 1}] ID: ${s._id}\nAct: ${s.actName}\nSection/Rule: ${s.sectionOrRule}\nTitle: ${s.provisionTitle}\nText: ${s.snippetText}\nURL: ${s.sourceUrl}`
                ).join('\n\n');
            } else {
                contextStr = 'No authoritative statutory provisions retrieved above similarity threshold.';
            }

            const prompt = `You are an expert Indian Real Estate Contract Differential Analyzer.
Analyze the contractual change between Version A and Version B:

CLAUSE METADATA:
Pair ID: ${pair.clausePairId}
Status: ${pair.changeStatus}
Title A: ${pair.titleA || 'N/A'}
Text A: ${pair.textA || 'N/A'}
Title B: ${pair.titleB || 'N/A'}
Text B: ${pair.textB || 'N/A'}
Detected Material Diffs: ${JSON.stringify(pair.materialChangesDetected)}

RETRIEVED LEGAL CONTEXT:
${contextStr}

INSTRUCTIONS:
1. Explain buyer impact in 1-2 clear, neutral sentences.
2. Determine risk level for Version B (or Version A if removed): HIGH_RISK, CAUTION, or COMPLIANT.
3. If this clause is REMOVED, note that the contractual term has been deleted and explain if statutory protection independently continues under the retrieved provisions. Do NOT claim the statutory right was removed.
4. If this clause is ADDED and COMPLIANT, risk migration must be NO_ADVERSE_RISK_IDENTIFIED.
5. In buyerConsiderations, write neutral informational advice for the buyer. Do NOT use directive words like "reject", "insist", or "must sign".
6. Only propose statutory citations that exist in the RETRIEVED LEGAL CONTEXT and genuinely support your finding.

Return strictly valid JSON:
{
  "buyerImpact": "...",
  "legalFinding": "...",
  "revisedRiskLevel": "HIGH_RISK | CAUTION | COMPLIANT",
  "statutoryCitations": [
    {
      "lawSnippetId": "...",
      "actName": "...",
      "sectionOrRule": "...",
      "provisionTitle": "...",
      "sourceUrl": "..."
    }
  ],
  "buyerConsiderations": "..."
}`;

            const responseText = await llmService.generateTextWithFallback(prompt, { temperature: 0.0 });
            const result = llmService.safeParseJson(responseText, {});

            pair.buyerImpact = result.buyerImpact || 'Contractual terms were modified between versions.';
            pair.legalFinding = result.legalFinding || 'Evaluated under standard contract principles.';
            pair.riskLevelB = result.revisedRiskLevel || (pair.changeStatus === 'ADDED' ? 'COMPLIANT' : pair.riskLevelA || 'COMPLIANT');
            pair.buyerConsiderations = (result.buyerConsiderations || '')
                .replace(/\b(?:reject|insist|must sign|refuse to pay|reject the agreement)\b/gi, 'review');

            // Deterministic Risk Migration Calculation (Overwrites LLM variance)
            pair.riskMigration = calculateDeterministicRiskMigration({
                changeStatus: pair.changeStatus,
                previousRiskLevel: pair.riskLevelA,
                revisedRiskLevel: pair.riskLevelB,
                titleA: pair.titleA,
                textA: pair.textA
            });

            // Server-side citation validation
            pair.statutoryCitations = validateCitations(result.statutoryCitations, retrievedSnippets);

        } catch (err) {
            console.warn(`[Pair ${pair.clausePairId}] Differential AI analysis fallback:`, err.message);
            pair.buyerImpact = 'Clause wording differs between agreement versions.';
            pair.legalFinding = 'Evaluated based on standard contractual fairness.';
            pair.riskLevelB = pair.changeStatus === 'ADDED' ? 'COMPLIANT' : (pair.riskLevelA || 'COMPLIANT');
            pair.buyerConsiderations = 'The buyer may wish to verify the operational effect of this revision.';
            pair.riskMigration = calculateDeterministicRiskMigration({
                changeStatus: pair.changeStatus,
                previousRiskLevel: pair.riskLevelA,
                revisedRiskLevel: pair.riskLevelB,
                titleA: pair.titleA,
                textA: pair.textA
            });
            pair.statutoryCitations = [];
        }
    }
}

/**
 * Creates and initializes a DocumentComparison job
 */
async function startComparison({
    userId,
    docAId,
    docBId,
    fileA,
    fileB,
    titleA = 'Agreement Version A',
    titleB = 'Agreement Version B'
}) {
    if (!userId) throw new Error('userId is required for comparison.');

    let finalDocA = null;
    let finalDocB = null;

    // Resolve Doc A
    if (docAId) {
        finalDocA = await Document.findOne({ _id: docAId, userId, isDeleted: { $ne: true } });
        if (!finalDocA) throw new Error(`Document A (${docAId}) not found or unauthorized.`);
    } else if (fileA) {
        const jobA = await scanJobService.createScanJob({
            userId,
            base64Data: fileA.base64Data || (typeof fileA === 'string' ? fileA : null),
            text: fileA.text || (typeof fileA === 'string' && !fileA.includes('base64') ? fileA : null),
            mimeType: fileA.mimeType || 'application/pdf',
            title: titleA
        });
        const completedJobA = await scanJobService.executeJobPipeline(jobA.jobId);
        finalDocA = await Document.findById(completedJobA.documentId);
    }

    // Resolve Doc B
    if (docBId) {
        finalDocB = await Document.findOne({ _id: docBId, userId, isDeleted: { $ne: true } });
        if (!finalDocB) throw new Error(`Document B (${docBId}) not found or unauthorized.`);
    } else if (fileB) {
        const jobB = await scanJobService.createScanJob({
            userId,
            base64Data: fileB.base64Data || (typeof fileB === 'string' ? fileB : null),
            text: fileB.text || (typeof fileB === 'string' && !fileB.includes('base64') ? fileB : null),
            mimeType: fileB.mimeType || 'application/pdf',
            title: titleB
        });
        const completedJobB = await scanJobService.executeJobPipeline(jobB.jobId);
        finalDocB = await Document.findById(completedJobB.documentId);
    }

    if (!finalDocA || !finalDocB) {
        throw new Error('Both Document A and Document B must be provided and resolved.');
    }

    const fileHashA = finalDocA.fileHash || crypto.createHash('sha256').update(finalDocA.extractedNormalizedText || finalDocA.originalText || finalDocA._id.toString()).digest('hex');
    const fileHashB = finalDocB.fileHash || crypto.createHash('sha256').update(finalDocB.extractedNormalizedText || finalDocB.originalText || finalDocB._id.toString()).digest('hex');

    const comparisonHash = computeComparisonHash(userId, fileHashA, fileHashB);

    // Check for existing comparison
    const existingComp = await DocumentComparison.findOne({ userId, comparisonHash, status: 'COMPLETED' });
    if (existingComp) {
        return existingComp;
    }

    const comparisonId = `comp_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

    const newComp = new DocumentComparison({
        comparisonId,
        userId,
        docAId: finalDocA._id,
        fileHashA,
        titleA: finalDocA.title || titleA,
        docBId: finalDocB._id,
        fileHashB,
        titleB: finalDocB.title || titleB,
        comparisonHash,
        status: 'QUEUED',
        currentStep: 'Comparison initialized',
        completedSteps: ['DOCUMENTS_RESOLVED']
    });

    await newComp.save();
    return newComp;
}

/**
 * Stage-by-Stage Resumable Comparison Pipeline Execution
 */
async function executeComparisonPipeline(comparisonId) {
    const comp = await DocumentComparison.findOne({ comparisonId });
    if (!comp) throw new Error(`Comparison ${comparisonId} not found.`);
    if (comp.status === 'COMPLETED') return comp;

    try {
        const docA = await Document.findById(comp.docAId);
        const docB = await Document.findById(comp.docBId);
        if (!docA || !docB) throw new Error('Referenced documents missing from database.');

        // =====================================================================
        // STAGE 2: MATCHING CLAUSES
        // =====================================================================
        if (!comp.completedSteps.includes('CLAUSES_MATCHED') || !comp.clauseComparisons || comp.clauseComparisons.length === 0) {
            console.log(`[Comparison ${comp.comparisonId}] STAGE 2: Matching clauses...`);
            comp.status = 'MATCHING_CLAUSES';
            comp.currentStep = 'Matching clauses across versions...';
            await comp.save();

            const clausesA = (docA.canonicalClauses && docA.canonicalClauses.length > 0)
                ? docA.canonicalClauses
                : (docA.analysis && docA.analysis.length > 0)
                    ? docA.analysis.map((a, idx) => ({ clauseId: a.clauseId || `CLAUSE-A-${idx+1}`, title: a.title || `Clause ${idx+1}`, text: a.text, sourcePages: a.sourcePages || [1] }))
                    : [{ clauseId: 'CLAUSE-A-1', title: docA.title || 'Document A', text: docA.extractedNormalizedText || docA.originalText || '', sourcePages: [1] }];

            const clausesB = (docB.canonicalClauses && docB.canonicalClauses.length > 0)
                ? docB.canonicalClauses
                : (docB.analysis && docB.analysis.length > 0)
                    ? docB.analysis.map((b, idx) => ({ clauseId: b.clauseId || `CLAUSE-B-${idx+1}`, title: b.title || `Clause ${idx+1}`, text: b.text, sourcePages: b.sourcePages || [1] }))
                    : [{ clauseId: 'CLAUSE-B-1', title: docB.title || 'Document B', text: docB.extractedNormalizedText || docB.originalText || '', sourcePages: [1] }];

            const matchedPairs = matchClauses(clausesA, clausesB);
            comp.clauseComparisons = matchedPairs;
            comp.totalClausesA = clausesA.length;
            comp.totalClausesB = clausesB.length;

            if (!comp.completedSteps.includes('CLAUSES_MATCHED')) comp.completedSteps.push('CLAUSES_MATCHED');
            await comp.save();
            console.log(`[Comparison ${comp.comparisonId}] STAGE 2 COMPLETE: Aligned ${matchedPairs.length} pairs.`);
        }

        // =====================================================================
        // STAGE 3: DIFFING CHANGES
        // =====================================================================
        if (!comp.completedSteps.includes('CHANGES_DIFFED')) {
            console.log(`[Comparison ${comp.comparisonId}] STAGE 3: Scanning material diffs...`);
            comp.status = 'DIFFING_CHANGES';
            comp.currentStep = 'Analyzing textual and numeric changes...';
            await comp.save();

            for (const pair of comp.clauseComparisons) {
                if (pair.changeStatus === 'MODIFIED' || pair.changeStatus === 'SPLIT') {
                    const diffs = detectMaterialChanges(pair.textA, pair.textB);
                    pair.materialChangesDetected = diffs;
                    if (diffs.length === 0 && pair.matchConfidence === 'EXACT') {
                        pair.changeStatus = 'UNCHANGED';
                    }
                }
            }

            if (!comp.completedSteps.includes('CHANGES_DIFFED')) comp.completedSteps.push('CHANGES_DIFFED');
            await comp.save();
            console.log(`[Comparison ${comp.comparisonId}] STAGE 3 COMPLETE: Material diffs scanned.`);
        }

        // =====================================================================
        // STAGE 4: DIFFERENTIAL LEGAL & RISK AI ANALYSIS
        // =====================================================================
        if (!comp.completedSteps.includes('AI_ANALYSIS')) {
            console.log(`[Comparison ${comp.comparisonId}] STAGE 4: AI Legal Analysis...`);
            comp.status = 'AI_ANALYSIS';
            comp.currentStep = 'Evaluating legal risk impact...';
            await comp.save();

            await evaluateDifferentialLegalAnalysis(comp.clauseComparisons);

            if (!comp.completedSteps.includes('AI_ANALYSIS')) comp.completedSteps.push('AI_ANALYSIS');
            await comp.save();
            console.log(`[Comparison ${comp.comparisonId}] STAGE 4 COMPLETE: AI Analysis complete.`);
        }

        // =====================================================================
        // STAGE 5: REPORT GENERATION & SUMMARY METRICS
        // =====================================================================
        console.log(`[Comparison ${comp.comparisonId}] STAGE 5: Generating comparison report...`);
        comp.status = 'REPORT_GENERATION';
        comp.currentStep = 'Compiling comparison summary...';
        await comp.save();

        let unchanged = 0;
        let modified = 0;
        let added = 0;
        let removed = 0;
        let escalated = 0;
        let reduced = 0;

        for (const pair of comp.clauseComparisons) {
            if (pair.changeStatus === 'UNCHANGED') unchanged++;
            else if (pair.changeStatus === 'MODIFIED') modified++;
            else if (pair.changeStatus === 'ADDED') added++;
            else if (pair.changeStatus === 'REMOVED') removed++;

            if (pair.riskMigration === 'ESCALATED_RISK' || pair.riskMigration === 'NEW_RISK_ADDED') escalated++;
            if (pair.riskMigration === 'REDUCED_RISK' || pair.riskMigration === 'RISK_REMOVED') reduced++;
        }

        comp.unchangedCount = unchanged;
        comp.modifiedCount = modified;
        comp.addedCount = added;
        comp.removedCount = removed;
        comp.escalatedRiskCount = escalated;
        comp.reducedRiskCount = reduced;
        comp.overallSummary = `Comparison complete: ${modified} modified, ${added} added, ${removed} removed, and ${unchanged} unchanged clauses across versions. ${escalated} risk escalation(s) identified for buyer review.`;

        if (!comp.completedSteps.includes('REPORT')) comp.completedSteps.push('REPORT');
        comp.status = 'COMPLETED';
        comp.currentStep = 'Comparison completed';
        comp.completedAt = new Date();
        comp.errorInfo = { message: null, stage: null, code: null, isTransient: false, timestamp: null };
        await comp.save();

        console.log(`[Comparison ${comp.comparisonId}] STAGE 5 COMPLETE: Report generated successfully.`);
        return comp;

    } catch (err) {
        console.error(`[Comparison ${comp.comparisonId}] Pipeline error:`, err.message);
        comp.status = 'FAILED';
        comp.currentStep = `Failed at ${comp.currentStep}: ${err.message}`;
        comp.errorInfo = {
            message: err.message,
            stage: comp.currentStep,
            code: err.code || 'COMPARISON_ERROR',
            isTransient: (err.message || '').includes('429') || (err.message || '').includes('timeout'),
            timestamp: new Date()
        };
        await comp.save();
        throw err;
    }
}

/**
 * Startup Recovery for Incomplete Document Comparisons
 */
async function recoverUnfinishedComparisons(awaitAll = false) {
    try {
        console.log('--- Checking for Unfinished DocumentComparisons (Startup Recovery) ---');
        const pendingStatuses = ['QUEUED', 'RESOLVING_DOCUMENTS', 'MATCHING_CLAUSES', 'DIFFING_CHANGES', 'AI_ANALYSIS', 'REPORT_GENERATION', 'RETRYING'];
        const staleThreshold = new Date(Date.now() - 5000);

        const unfinished = await DocumentComparison.find({
            status: { $in: pendingStatuses },
            updatedAt: { $lt: staleThreshold }
        });

        if (unfinished.length === 0) {
            console.log('✓ No unfinished DocumentComparisons found on startup.');
            return 0;
        }

        console.log(`Found ${unfinished.length} unfinished DocumentComparison(s) to recover.`);
        const promises = unfinished.map(c => {
            console.log(`[Startup Recovery] Resuming Comparison ${c.comparisonId} from completed stages [${c.completedSteps.join(', ')}]...`);
            return executeComparisonPipeline(c.comparisonId).catch(err => {
                console.error(`[Startup Recovery] Failed to recover Comparison ${c.comparisonId}:`, err.message);
            });
        });

        if (awaitAll) await Promise.all(promises);
        return unfinished.length;
    } catch (e) {
        console.warn('Startup comparison recovery warning:', e.message);
        return 0;
    }
}

module.exports = {
    startComparison,
    executeComparisonPipeline,
    matchClauses,
    detectMaterialChanges,
    validateCitations,
    calculateDeterministicRiskMigration,
    recoverUnfinishedComparisons
};
