/**
 * Regression tests: when the AI cannot produce a real analysis, the legal
 * analysis step must FAIL instead of returning clauses marked COMPLIANT.
 *
 * No network or database is needed: the Gemini client is replaced with a stub.
 */
const assert = require('assert');
const Module = require('module');

process.env.GEMINI_API_KEY = 'test-key';
delete process.env.OPENROUTER_API_KEY;
process.env.NODE_ENV = 'test';

// ---- Stub the Gemini SDK so every call is scripted -------------------------
let script = [];          // each item: () => string (response text) or throws
let callCount = 0;
const originalLoad = Module._load;
Module._load = function (request, ...rest) {
    if (request === '@google/generative-ai') {
        return {
            GoogleGenerativeAI: class {
                getGenerativeModel() {
                    return {
                        generateContent: async () => {
                            callCount++;
                            const step = script.length > 1 ? script.shift() : script[0];
                            const text = step();
                            return { response: { text: () => text } };
                        }
                    };
                }
            }
        };
    }
    return originalLoad.call(this, request, ...rest);
};

const llm = require('../src/services/llmService');

const clauses = [
    { clauseId: 'CLAUSE-001', title: 'Forfeiture', text: 'Developer may forfeit 100% of amount paid on any delay.', sourcePages: [1] },
    { clauseId: 'CLAUSE-002', title: 'Possession', text: 'Possession in 60 months, no compensation for delay.', sourcePages: [1] }
];

const good = (items) => () => JSON.stringify({ clauses: items });
const item = (id, riskLevel, extra = {}) => ({
    clauseId: id, riskLevel, findingCategory: 'Potential legal concern',
    reason: `real analysis for ${id}`, reraReferences: [], buyerImpact: 'b', recommendation: 'r', ...extra
});
const quota = () => { throw new Error('429 quota exceeded'); };

async function expectRejects(label, fn, code) {
    let result;
    try {
        result = await llm.analyzeCanonicalClauses(clauses);
    } catch (err) {
        assert.ok(err instanceof llm.AiAnalysisError, `${label}: should throw AiAnalysisError, got ${err && err.name}`);
        assert.strictEqual(err.code, code, `${label}: wrong error code ${err.code}`);
        console.log(`✓ ${label}`);
        return err;
    }
    assert.fail(`${label}: resolved instead of throwing -> ${JSON.stringify(result.map(c => [c.clauseId, c.riskLevel]))}`);
}

async function run() {
    console.log('--- AI failure handling tests ---');
    assert.ok(llm.AiAnalysisError, 'llmService must export AiAnalysisError');

    // 1. AI completely unavailable
    script = [quota]; callCount = 0;
    const err1 = await expectRejects('1. AI unavailable (429 on every call) -> throws, never "COMPLIANT"', null, 'AI_ANALYSIS_UNAVAILABLE');
    assert.ok(/429/.test(err1.message), 'error message should keep the cause so retry logic can classify it');

    // 2. AI returns unusable text every time
    script = [() => 'this is not json']; callCount = 0;
    await expectRejects('2. AI returns garbage every time -> throws', null, 'AI_ANALYSIS_INCOMPLETE');

    // 3. AI returns only one of two clauses every time (old code marked the other COMPLIANT)
    script = [good([item('CLAUSE-001', 'HIGH_RISK')])]; callCount = 0;
    await expectRejects('3. AI skips a clause every time -> throws (no silent COMPLIANT)', null, 'AI_ANALYSIS_INCOMPLETE');

    // 4. Unrecognised risk level must not become COMPLIANT
    script = [good([item('CLAUSE-001', 'HIGH_RISK'), item('CLAUSE-002', 'UNKNOWN')])]; callCount = 0;
    await expectRejects('4. Unrecognised riskLevel every time -> throws', null, 'AI_ANALYSIS_INCOMPLETE');

    // 5. Healthy response is returned as-is
    script = [good([item('CLAUSE-001', 'HIGH_RISK'), item('CLAUSE-002', 'CAUTION')])]; callCount = 0;
    let out = await llm.analyzeCanonicalClauses(clauses);
    assert.deepStrictEqual(out.map(c => c.riskLevel), ['HIGH_RISK', 'CAUTION']);
    assert.strictEqual(callCount, 1, 'healthy response needs exactly one AI call');
    console.log('✓ 5. Healthy AI response preserves HIGH_RISK / CAUTION');

    // 6. First attempt bad, second good -> retry works
    script = [() => 'oops', good([item('CLAUSE-001', 'HIGH_RISK'), item('CLAUSE-002', 'COMPLIANT')])]; callCount = 0;
    out = await llm.analyzeCanonicalClauses(clauses);
    assert.deepStrictEqual(out.map(c => c.riskLevel), ['HIGH_RISK', 'COMPLIANT']);
    assert.strictEqual(callCount, 2);
    console.log('✓ 6. Bad first attempt, good second attempt -> succeeds');

    // 7. Every clause analysed but strict validation fails (extra unknown id) -> real data is kept
    script = [good([item('CLAUSE-001', 'HIGH_RISK'), item('CLAUSE-002', 'CAUTION'), item('CLAUSE-999', 'COMPLIANT')])]; callCount = 0;
    out = await llm.analyzeCanonicalClauses(clauses);
    assert.deepStrictEqual(out.map(c => [c.clauseId, c.riskLevel]), [['CLAUSE-001', 'HIGH_RISK'], ['CLAUSE-002', 'CAUTION']]);
    console.log('✓ 7. Complete AI output with an extra id still keeps the AI\'s real verdicts');

    // 8. Empty input still returns an empty list
    out = await llm.analyzeCanonicalClauses([]);
    assert.deepStrictEqual(out, []);
    console.log('✓ 8. No clauses -> empty result');

    console.log('\nALL AI FAILURE HANDLING TESTS PASSED (8/8)');
}

run().then(() => process.exit(0)).catch(err => {
    console.error('\nTEST FAILED:', err.message);
    process.exit(1);
});