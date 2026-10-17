/**
 * Regression tests: the AI's findingCategory, legalFinding and statutoryCitations
 * must survive analysis (they used to be thrown away), and must always be safe to
 * save in the database. No network or database is needed.
 */
const assert = require('assert');
const Module = require('module');

process.env.GEMINI_API_KEY = 'test-key';
delete process.env.OPENROUTER_API_KEY;
process.env.NODE_ENV = 'test';

let script = [];
let lastSystemInstruction = '';
const originalLoad = Module._load;
Module._load = function (request, ...rest) {
    if (request === '@google/generative-ai') {
        return {
            GoogleGenerativeAI: class {
                getGenerativeModel(params) {
                    lastSystemInstruction = (params && params.systemInstruction) || lastSystemInstruction;
                    return {
                        generateContent: async () => {
                            const step = script.length > 1 ? script.shift() : script[0];
                            return { response: { text: () => step() } };
                        }
                    };
                }
            }
        };
    }
    return originalLoad.call(this, request, ...rest);
};

const llm = require('../src/services/llmService');
const ScanJob = require('../src/models/ScanJob');
const Document = require('../src/models/Document');
const { classifyFinding } = require('../src/services/crossReferenceService');

const two = [
    { clauseId: 'CLAUSE-001', title: 'Forfeiture', text: 'Developer may forfeit 100% of amount paid.', sourcePages: [1] },
    { clauseId: 'CLAUSE-002', title: 'Title', text: 'Seller warrants good title.', sourcePages: [1] }
];
const reply = (items) => () => JSON.stringify({ clauses: items });
const base = (id, riskLevel, extra = {}) => ({ clauseId: id, riskLevel, reason: 'r', ...extra });

async function analyze(items, clauses = two) {
    script = [reply(items)];
    return llm.analyzeCanonicalClauses(clauses);
}

async function run() {
    console.log('--- Finding fields tests ---');

    // 1. All three fields come out
    let out = await analyze([
        base('CLAUSE-001', 'HIGH_RISK', {
            findingCategory: 'Potential legal concern',
            legalFinding: 'Full forfeiture may be treated as a penalty.',
            statutoryCitations: ['Indian Contract Act, 1872 - Section 74']
        }),
        base('CLAUSE-002', 'CAUTION', { findingCategory: 'Documentation/title concern' })
    ]);
    assert.strictEqual(out[0].findingCategory, 'Potential legal concern');
    assert.strictEqual(out[0].legalFinding, 'Full forfeiture may be treated as a penalty.');
    assert.deepStrictEqual(out[0].statutoryCitations, ['Indian Contract Act, 1872 - Section 74']);
    assert.strictEqual(out[1].findingCategory, 'Documentation/title concern');
    console.log('✓ 1. findingCategory, legalFinding and statutoryCitations are kept');

    // 2. Messy category text is cleaned up to an allowed value
    const variants = [
        ['potential legal concern', 'HIGH_RISK', 'Potential legal concern'],
        ['[Contractual risk]', 'CAUTION', 'Contractual risk'],
        ['Documentation / title concern', 'CAUTION', 'Documentation/title concern'],
        ['Applicability uncertain', 'CAUTION', 'Applicability uncertain'],
        ['[Potential legal concern] - FACT FROM DOCUMENT: ...', 'HIGH_RISK', 'Potential legal concern'],
        ['No material issue identified / Applicability uncertain', 'COMPLIANT', 'No material issue identified']
    ];
    for (const [raw, risk, expected] of variants) {
        out = await analyze([base('CLAUSE-001', risk, { findingCategory: raw }), base('CLAUSE-002', 'COMPLIANT')]);
        assert.strictEqual(out[0].findingCategory, expected, `"${raw}" -> "${out[0].findingCategory}"`);
    }
    console.log('✓ 2. Capitals, brackets, spacing and extra text are normalised');

    // 3. Unknown / missing category falls back by risk level
    out = await analyze([base('CLAUSE-001', 'HIGH_RISK', { findingCategory: 'Totally made up' }), base('CLAUSE-002', 'CAUTION')]);
    assert.strictEqual(out[0].findingCategory, 'Potential legal concern');
    assert.strictEqual(out[1].findingCategory, 'Contractual risk');
    out = await analyze([base('CLAUSE-001', 'COMPLIANT'), base('CLAUSE-002', 'COMPLIANT', { findingCategory: 42 })]);
    assert.strictEqual(out[0].findingCategory, 'No material issue identified');
    assert.strictEqual(out[1].findingCategory, 'No material issue identified');
    console.log('✓ 3. Unknown or missing category falls back to one that matches the risk level');

    // 4. A HIGH_RISK / CAUTION clause can never say "No material issue identified"
    out = await analyze([
        base('CLAUSE-001', 'HIGH_RISK', { findingCategory: 'No material issue identified' }),
        base('CLAUSE-002', 'CAUTION', { findingCategory: 'No material issue identified' })
    ]);
    assert.strictEqual(out[0].findingCategory, 'Potential legal concern');
    assert.strictEqual(out[1].findingCategory, 'Contractual risk');
    console.log('✓ 4. Risky clauses never keep the contradictory "No material issue identified"');

    // 5. Citations are cleaned
    const long = 'x'.repeat(500);
    const many = Array.from({ length: 30 }, (_, i) => `Section ${i}`);
    out = await analyze([
        base('CLAUSE-001', 'HIGH_RISK', { statutoryCitations: ['  Section 74  ', 'section 74', 42, null, '', long] }),
        base('CLAUSE-002', 'CAUTION', { statutoryCitations: many })
    ]);
    assert.strictEqual(out[0].statutoryCitations[0], 'Section 74');
    assert.strictEqual(out[0].statutoryCitations.length, 2, 'duplicates and non-strings removed');
    assert.strictEqual(out[0].statutoryCitations[1].length, 300, 'long entry capped at 300');
    assert.strictEqual(out[1].statutoryCitations.length, 20, 'capped at 20 entries');
    out = await analyze([base('CLAUSE-001', 'HIGH_RISK', { statutoryCitations: 'Section 55' }), base('CLAUSE-002', 'CAUTION')]);
    assert.deepStrictEqual(out[0].statutoryCitations, ['Section 55']);
    assert.deepStrictEqual(out[1].statutoryCitations, []);
    console.log('✓ 5. Citations: trimmed, de-duplicated, capped, single string accepted, missing -> []');

    // 6. legalFinding is cleaned
    out = await analyze([
        base('CLAUSE-001', 'HIGH_RISK', { legalFinding: '  trimmed  ' }),
        base('CLAUSE-002', 'CAUTION', { legalFinding: { not: 'a string' } })
    ]);
    assert.strictEqual(out[0].legalFinding, 'trimmed');
    assert.strictEqual(out[1].legalFinding, '');
    out = await analyze([base('CLAUSE-001', 'HIGH_RISK', { legalFinding: 'y'.repeat(5000) }), base('CLAUSE-002', 'CAUTION')]);
    assert.strictEqual(out[0].legalFinding.length, 4000);
    console.log('✓ 6. legalFinding: trimmed, non-text -> "", capped at 4000');

    // 7. The "extra id" recovery path keeps the fields too
    out = await analyze([
        base('CLAUSE-001', 'HIGH_RISK', { findingCategory: 'Contractual risk', legalFinding: 'lf', statutoryCitations: ['S1'] }),
        base('CLAUSE-002', 'CAUTION', { findingCategory: 'Documentation/title concern' }),
        base('CLAUSE-999', 'COMPLIANT')
    ]);
    assert.strictEqual(out.length, 2);
    assert.strictEqual(out[0].findingCategory, 'Contractual risk');
    assert.strictEqual(out[0].legalFinding, 'lf');
    assert.deepStrictEqual(out[0].statutoryCitations, ['S1']);
    console.log('✓ 7. Recovery path (extra id from AI) keeps the fields');

    // 8. Everything produced can be saved: Mongoose accepts it (no validation error)
    out = await analyze([
        base('CLAUSE-001', 'HIGH_RISK', { findingCategory: 'Totally made up', statutoryCitations: ['S'] }),
        base('CLAUSE-002', 'CAUTION', { findingCategory: 'applicability UNCERTAIN' })
    ]);
    const job = new ScanJob({ jobId: 'j1', userId: new (require('mongoose').Types.ObjectId)(), fileHash: 'h', analysis: out });
    const jobErr = job.validateSync();
    const analysisErrors = jobErr ? Object.keys(jobErr.errors).filter(k => k.startsWith('analysis')) : [];
    assert.deepStrictEqual(analysisErrors, [], 'ScanJob rejected analysis: ' + analysisErrors.join(', '));
    assert.strictEqual(job.analysis[0].findingCategory, 'Potential legal concern');
    const doc = new Document({ userId: new (require('mongoose').Types.ObjectId)(), analysis: out });
    assert.strictEqual(doc.analysis[1].findingCategory, 'Applicability uncertain');
    console.log('✓ 8. Saved analysis passes ScanJob/Document schema validation');

    // 9. The checklist classifier now sees the category
    const titleFinding = (await analyze([
        base('CLAUSE-001', 'CAUTION', { findingCategory: 'Documentation/title concern' }), base('CLAUSE-002', 'COMPLIANT')
    ]))[0];
    titleFinding.reason = 'x'; titleFinding.title = 'x'; titleFinding.text = 'x';
    assert.ok(classifyFinding(titleFinding).includes('TITLE'), 'category should steer the checklist classification');
    console.log('✓ 9. Checklist classifier uses the preserved category');

    // 10. The AI is actually asked for the fields, and the prompt lists all 6 categories
    for (const needle of ['"legalFinding"', '"statutoryCitations"', 'Applicability uncertain', 'Never invent a section number']) {
        assert.ok(lastSystemInstruction.includes(needle), `prompt is missing: ${needle}`);
    }
    assert.ok(llm.FINDING_CATEGORIES.length === 6);
    console.log('✓ 10. Prompt asks for legalFinding and statutoryCitations and lists all 6 categories');

    // 11. Old cached analyses (no finding fields) are not reused
    assert.notStrictEqual(llm.PROMPT_VERSION, 'v1.1.0', 'PROMPT_VERSION must change so old cached analyses are redone');
    console.log('✓ 11. Prompt version bumped, so analyses cached without these fields are re-run');

    console.log('\nALL FINDING FIELDS TESTS PASSED (11/11)');
}

run().then(() => process.exit(0)).catch(err => {
    console.error('\nTEST FAILED:', err.message);
    process.exit(1);
});