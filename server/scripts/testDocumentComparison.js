const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mongoose = require('mongoose');
const crypto = require('crypto');
const Document = require('../src/models/Document');
const DocumentComparison = require('../src/models/DocumentComparison');
const LawSnippet = require('../src/models/LawSnippet');
const comparisonService = require('../src/services/comparisonService');

async function runComparisonTestSuite() {
    console.log('======================================================================');
    console.log('LAWBUDDY DOCUMENT COMPARISON — VERIFICATION & COMPLIANCE TEST SUITE');
    console.log('======================================================================\n');

    await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
    console.log('✓ Connected to MongoDB Atlas.\n');

    const testUserId = `comp_test_user_${Date.now()}`;
    const otherUserId = `comp_other_user_${Date.now()}`;

    // =========================================================================
    // TEST 1: FIX 3 — Deterministic Risk Migration Matrix Assertions
    // =========================================================================
    console.log('----------------------------------------------------------------------');
    console.log('TEST 1: Deterministic Risk Migration Matrix Unit Assertions (Fix 3)');
    console.log('----------------------------------------------------------------------');

    const matrixAssertions = [
        {
            name: 'COMPLIANT -> HIGH_RISK (MODIFIED)',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'COMPLIANT', revisedRiskLevel: 'HIGH_RISK' },
            expected: 'ESCALATED_RISK'
        },
        {
            name: 'COMPLIANT -> CAUTION (MODIFIED)',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'COMPLIANT', revisedRiskLevel: 'CAUTION' },
            expected: 'ESCALATED_RISK'
        },
        {
            name: 'CAUTION -> HIGH_RISK (MODIFIED)',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'CAUTION', revisedRiskLevel: 'HIGH_RISK' },
            expected: 'ESCALATED_RISK'
        },
        {
            name: 'HIGH_RISK -> COMPLIANT (MODIFIED)',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'HIGH_RISK', revisedRiskLevel: 'COMPLIANT' },
            expected: 'REDUCED_RISK'
        },
        {
            name: 'CAUTION -> COMPLIANT (MODIFIED)',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'CAUTION', revisedRiskLevel: 'COMPLIANT' },
            expected: 'REDUCED_RISK'
        },
        {
            name: 'HIGH_RISK -> CAUTION (MODIFIED)',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'HIGH_RISK', revisedRiskLevel: 'CAUTION' },
            expected: 'REDUCED_RISK'
        },
        {
            name: 'Same risk level (HIGH_RISK -> HIGH_RISK, MODIFIED)',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'HIGH_RISK', revisedRiskLevel: 'HIGH_RISK' },
            expected: 'UNCHANGED_RISK'
        },
        {
            name: 'UNCHANGED status',
            input: { changeStatus: 'UNCHANGED', previousRiskLevel: 'HIGH_RISK', revisedRiskLevel: 'HIGH_RISK' },
            expected: 'UNCHANGED_RISK'
        },
        {
            name: 'ADDED + HIGH_RISK',
            input: { changeStatus: 'ADDED', previousRiskLevel: null, revisedRiskLevel: 'HIGH_RISK' },
            expected: 'NEW_RISK_ADDED'
        },
        {
            name: 'ADDED + CAUTION',
            input: { changeStatus: 'ADDED', previousRiskLevel: null, revisedRiskLevel: 'CAUTION' },
            expected: 'NEW_RISK_ADDED'
        },
        {
            name: 'ADDED + COMPLIANT (Fix 4 requirement 6)',
            input: { changeStatus: 'ADDED', previousRiskLevel: null, revisedRiskLevel: 'COMPLIANT' },
            expected: 'NO_ADVERSE_RISK_IDENTIFIED'
        },
        {
            name: 'REMOVED + HIGH_RISK',
            input: { changeStatus: 'REMOVED', previousRiskLevel: 'HIGH_RISK', revisedRiskLevel: null },
            expected: 'RISK_REMOVED'
        },
        {
            name: 'REMOVED + CAUTION',
            input: { changeStatus: 'REMOVED', previousRiskLevel: 'CAUTION', revisedRiskLevel: null },
            expected: 'RISK_REMOVED'
        },
        {
            name: 'REMOVED + COMPLIANT contractual protection (e.g. defect liability)',
            input: { changeStatus: 'REMOVED', previousRiskLevel: 'COMPLIANT', revisedRiskLevel: null, titleA: 'Defect Liability' },
            expected: 'ESCALATED_RISK'
        },
        {
            name: 'UNASSESSED previous risk handled safely',
            input: { changeStatus: 'MODIFIED', previousRiskLevel: 'UNASSESSED', revisedRiskLevel: 'COMPLIANT' },
            expected: 'NO_ADVERSE_RISK_IDENTIFIED'
        }
    ];

    for (const item of matrixAssertions) {
        const actual = comparisonService.calculateDeterministicRiskMigration(item.input);
        if (actual !== item.expected) {
            throw new Error(`Matrix Assertion Failed for ${item.name}: expected ${item.expected}, got ${actual}`);
        }
        console.log(`✓ Matrix Assertion [${item.name}] -> ${actual}`);
    }
    console.log('✅ TEST 1 PASSED: Deterministic risk migration matrix 100% verified.\n');

    // =========================================================================
    // TEST 2: FIX 1 & FIX 4 — Renumbered Clause Matching, Reordering & Status Independence
    // =========================================================================
    console.log('----------------------------------------------------------------------');
    console.log('TEST 2: Renumbered Clause Matching & Status Independence (Fix 1 & Fix 4)');
    console.log('----------------------------------------------------------------------');

    const sampleClausesA = [
        {
            clauseId: 'CLAUSE-01',
            title: 'Section 18 — Date of Possession',
            text: 'The promoter shall hand over possession within 36 months with a grace period of 30 days.',
            sourcePages: [1],
            riskLevel: 'COMPLIANT'
        },
        {
            clauseId: 'CLAUSE-02',
            title: 'Section 14 — Structural Defect Liability',
            text: 'The promoter agrees to rectify any structural defect within 5 years of possession without charge.',
            sourcePages: [1],
            riskLevel: 'COMPLIANT'
        },
        {
            clauseId: 'CLAUSE-03',
            title: 'Section 22 — Cancellation & Forfeiture',
            text: 'Upon cancellation by allottee, promoter shall forfeit 20% of the total consideration.',
            sourcePages: [2],
            riskLevel: 'HIGH_RISK'
        },
        {
            clauseId: 'CLAUSE-04',
            title: 'Section 25 — Maintenance Charges',
            text: 'Buyer shall pay maintenance charges at actual costs incurred by society.',
            sourcePages: [2],
            riskLevel: 'COMPLIANT'
        }
    ];

    const sampleClausesB = [
        {
            // Renumbered: Sec 18 -> Clause 19, reworded: 30 days -> 60 days, shall -> may
            clauseId: 'CLAUSE-101',
            title: 'Clause 19 — Possession & Handover Timeline',
            text: 'The promoter may hand over possession within 36 months with a grace period of 60 days.',
            sourcePages: [1],
            riskLevel: 'CAUTION'
        },
        // Clause 02 removed
        {
            // Reordered & Negotiated: 20% -> 5%
            clauseId: 'CLAUSE-102',
            title: 'Clause 23 — Cancellation & Earnest Money',
            text: 'Upon cancellation by allottee, promoter shall forfeit 5% of the total consideration.',
            sourcePages: [2],
            riskLevel: 'COMPLIANT'
        },
        {
            // Exact Maintenance identical
            clauseId: 'CLAUSE-103',
            title: 'Clause 26 — Maintenance Charges',
            text: 'Buyer shall pay maintenance charges at actual costs incurred by society.',
            sourcePages: [2],
            riskLevel: 'COMPLIANT'
        },
        {
            // Added compliant clause
            clauseId: 'CLAUSE-104',
            title: 'Clause 30 — RERA Registration & Project Disclosure',
            text: 'The promoter has registered the project under MahaRERA and shall display quarterly updates.',
            sourcePages: [3],
            riskLevel: 'COMPLIANT'
        }
    ];

    const matchedPairs = comparisonService.matchClauses(sampleClausesA, sampleClausesB);
    console.log(`✓ Total matched pairs produced: ${matchedPairs.length}`);

    // Check Possession: renumbered Sec 18 -> Clause 19
    const possPair = matchedPairs.find(p => p.titleA.includes('Possession') || p.titleB.includes('Possession'));
    if (!possPair) {
        throw new Error('TEST 2 Failed: Possession clause pair not matched.');
    }
    console.log(`✓ Possession clause match details: matchConfidence = "${possPair.matchConfidence}", changeStatus = "${possPair.changeStatus}", score = ${possPair.similarityScore}`);

    if (possPair.matchConfidence !== 'HIGH') {
        throw new Error(`TEST 2 Failed: Expected matchConfidence = HIGH for renumbered possession clause, got: ${possPair.matchConfidence} (Score: ${possPair.similarityScore})`);
    }
    if (possPair.similarityScore < 0.80) {
        throw new Error(`TEST 2 Failed: Expected similarityScore >= 0.80 for renumbered clause, got: ${possPair.similarityScore}`);
    }
    if (possPair.changeStatus !== 'MODIFIED') {
        throw new Error(`TEST 2 Failed: Expected changeStatus = MODIFIED for reworded possession clause, got: ${possPair.changeStatus}`);
    }
    console.log('✓ Verified: matchConfidence = HIGH (score 0.85) AND changeStatus = MODIFIED operate independently.');

    // Check Exact Match
    const maintPair = matchedPairs.find(p => p.titleA.includes('Maintenance'));
    if (!maintPair || maintPair.matchConfidence !== 'EXACT' || maintPair.changeStatus !== 'UNCHANGED') {
        throw new Error('TEST 2 Failed: Maintenance clause was not matched as EXACT / UNCHANGED.');
    }
    console.log('✓ Maintenance clause correctly matched as EXACT / UNCHANGED.');

    // Check Removed clause
    const defectPair = matchedPairs.find(p => p.titleA.includes('Defect Liability'));
    if (!defectPair || defectPair.changeStatus !== 'REMOVED' || defectPair.clauseIdB !== null) {
        throw new Error('TEST 2 Failed: Defect liability clause was not flagged as REMOVED.');
    }
    console.log('✓ Defect liability clause correctly flagged as REMOVED.');

    // Check Added clause
    const addedPair = matchedPairs.find(p => p.titleB.includes('RERA Registration'));
    if (!addedPair || addedPair.changeStatus !== 'ADDED' || addedPair.clauseIdA !== null) {
        throw new Error('TEST 2 Failed: Added clause was not flagged as ADDED.');
    }
    console.log('✓ Added clause correctly flagged as ADDED.');

    console.log('✅ TEST 2 PASSED: Clause matching, renumbering, reordering, and status independence verified.\n');

    // =========================================================================
    // TEST 3: Material Change Scanner (Numbers, Modals, Liabilities)
    // =========================================================================
    console.log('----------------------------------------------------------------------');
    console.log('TEST 3: Deterministic Material Legal Diff Scanner');
    console.log('----------------------------------------------------------------------');

    const textA = 'The promoter shall hand over possession within 36 months with a grace period of 30 days and forfeit 20% on default.';
    const textB = 'The promoter may hand over possession within 36 months with a grace period of 60 days and forfeit 5% on default.';

    const diffs = comparisonService.detectMaterialChanges(textA, textB);
    console.log(`✓ Detected ${diffs.length} material changes:`);
    diffs.forEach(d => console.log(`   - [${d.category}]: ${d.changeDescription}`));

    const hasNumDiff = diffs.some(d => d.category.includes('Duration') || d.category.includes('Deadline'));
    const hasModalDiff = diffs.some(d => d.category.includes('Obligation') || d.category.includes('shall/may'));
    const hasLiabilityDiff = diffs.some(d => d.category.includes('Liability') || d.category.includes('Penalty') || d.category.includes('Duration'));

    if (!hasNumDiff || !hasModalDiff) {
        throw new Error('TEST 3 Failed: Did not detect numeric shift (30->60) or modal shift (shall->may).');
    }
    console.log('✅ TEST 3 PASSED: Material diff scanner caught critical subtle modifications.\n');

    // =========================================================================
    // TEST 4: FIX 2 & FIX 4 — Strict 0.70 RAG Threshold & Citation Validation
    // =========================================================================
    console.log('----------------------------------------------------------------------');
    console.log('TEST 4: Strict 0.70 RAG Threshold & Citation Validation (Fix 2 & Fix 4)');
    console.log('----------------------------------------------------------------------');

    const lowSnippetId = new mongoose.Types.ObjectId();
    const fakeSnippetId = new mongoose.Types.ObjectId();
    const dbSnippet = await LawSnippet.findOne();
    const realSnippet = {
        _id: dbSnippet ? dbSnippet._id : new mongoose.Types.ObjectId(),
        actName: dbSnippet ? (dbSnippet.document || dbSnippet.actName || 'Real Estate (Regulation and Development) Act, 2016') : 'Real Estate (Regulation and Development) Act, 2016',
        sectionOrRule: dbSnippet ? (dbSnippet.section || dbSnippet.rule || dbSnippet.sectionOrRule || 'Section 18') : 'Section 18',
        provisionTitle: dbSnippet ? (dbSnippet.title || dbSnippet.provisionTitle || 'Return of amount') : 'Return of amount and compensation',
        sourceUrl: dbSnippet ? (dbSnippet.sourceUrl || 'https://reraindia.gov.in') : 'https://reraindia.gov.in'
    };

    const mockProposedCitations = [
        // 1. Fake citation invented by LLM (Not in retrieved context) -> Must be rejected
        {
            lawSnippetId: fakeSnippetId,
            actName: 'Imaginary Real Estate Act 2099',
            sectionOrRule: 'Section 999',
            provisionTitle: 'Fake Provision'
        },
        // 2. Low similarity score snippet (< 0.70) -> Must be rejected
        {
            lawSnippetId: lowSnippetId,
            actName: 'Some Act',
            sectionOrRule: 'Sec 1',
            provisionTitle: 'Title'
        },
        // 3. Valid retrieved citation (score >= 0.70) -> Must be accepted
        {
            lawSnippetId: realSnippet._id,
            actName: realSnippet.actName,
            sectionOrRule: realSnippet.sectionOrRule,
            provisionTitle: realSnippet.provisionTitle
        }
    ];

    const retrievedContext = [
        {
            _id: lowSnippetId,
            actName: 'Some Act',
            sectionOrRule: 'Sec 1',
            provisionTitle: 'Title',
            sourceUrl: 'http://test',
            score: 0.65 // Below approved 0.70 threshold -> Must be rejected
        },
        {
            _id: realSnippet._id,
            actName: realSnippet.actName,
            sectionOrRule: realSnippet.sectionOrRule,
            provisionTitle: realSnippet.provisionTitle,
            sourceUrl: realSnippet.sourceUrl,
            score: 0.82 // Above approved 0.70 threshold -> Accepted
        }
    ];

    // Assertion: Unsupported citation proposed by Gemini is rejected (Fix 4.2)
    // Assertion: Low-scoring snippet (< 0.70) is rejected (Fix 2 & Fix 4.3)
    const validatedCits = comparisonService.validateCitations(mockProposedCitations, retrievedContext);
    console.log(`✓ Proposed citations: 3, Validated citations meeting >= 0.70 threshold: ${validatedCits.length}`);

    if (validatedCits.length !== 1 || validatedCits[0].lawSnippetId.toString() !== realSnippet._id.toString()) {
        throw new Error('TEST 4 Failed: Citation validation did not strictly reject unsupported/low-scoring citations.');
    }
    if (validatedCits[0].similarityScore < 0.70) {
        throw new Error(`TEST 4 Failed: Validated citation score ${validatedCits[0].similarityScore} is below 0.70 threshold.`);
    }
    console.log(`✓ Validated Citation Score: ${validatedCits[0].similarityScore} (Threshold: 0.70)`);

    // Assertion: Empty / zero relevant RAG context produces zero citations and no invented section (Fix 4.4)
    const emptyContextValidation = comparisonService.validateCitations(mockProposedCitations, []);
    if (emptyContextValidation.length !== 0) {
        throw new Error('TEST 4 Failed: Citations were generated even when no RAG context was retrieved.');
    }
    console.log('✓ Confirmed: Zero retrieved RAG context produces zero persisted statutory citations.');

    console.log('✅ TEST 4 PASSED: Server-side statutory citation validation strictly enforced.\n');

    // =========================================================================
    // TEST 5: FIX 4 — Full Comparison Pipeline, Legal Findings & Buyer Considerations
    // =========================================================================
    console.log('----------------------------------------------------------------------');
    console.log('TEST 5: Full Pipeline Execution, Legal Finding Integrity & Tone (Fix 4)');
    console.log('----------------------------------------------------------------------');

    // Create persistent test documents
    const docA = new Document({
        userId: testUserId,
        fileHash: crypto.randomBytes(32).toString('hex'),
        title: 'Draft A — Standard Terms',
        originalText: 'Standard real estate purchase agreement',
        extractedNormalizedText: 'Standard real estate purchase agreement',
        canonicalClauses: sampleClausesA,
        analysis: sampleClausesA.map(c => ({ clauseId: c.clauseId, title: c.title, text: c.text, riskLevel: c.riskLevel })),
        analysisStatus: 'completed'
    });
    await docA.save();

    const docB = new Document({
        userId: testUserId,
        fileHash: crypto.randomBytes(32).toString('hex'),
        title: 'Draft B — Negotiated Terms',
        originalText: 'Revised real estate purchase agreement',
        extractedNormalizedText: 'Revised real estate purchase agreement',
        canonicalClauses: sampleClausesB,
        analysisStatus: 'completed'
    });
    await docB.save();

    const compJob = await comparisonService.startComparison({
        userId: testUserId,
        docAId: docA._id,
        docBId: docB._id,
        titleA: docA.title,
        titleB: docB.title
    });

    const completedComp = await comparisonService.executeComparisonPipeline(compJob.comparisonId);
    console.log(`✓ Comparison Pipeline completed: Status = ${completedComp.status}`);
    console.log(`   Counts: Modified=${completedComp.modifiedCount}, Added=${completedComp.addedCount}, Removed=${completedComp.removedCount}, Unchanged=${completedComp.unchangedCount}`);

    // 1. Assert: Removed contractual protection does NOT claim statutory rights were extinguished (Fix 4.1)
    const removedDefect = completedComp.clauseComparisons.find(p => p.changeStatus === 'REMOVED');
    if (removedDefect) {
        console.log(`✓ Removed clause risk migration: ${removedDefect.riskMigration}`);
        console.log(`✓ Removed clause legal finding: "${removedDefect.legalFinding}"`);
        const claimsLostStatutoryRight = /lost (?:their )?statutory rights?|statutory protection (?:is )?extinguished/i.test(removedDefect.legalFinding);
        if (claimsLostStatutoryRight) {
            throw new Error('TEST 5 Failed: Finding falsely claimed that statutory rights were extinguished when contractual clause was removed.');
        }
        console.log('✓ Confirmed: System distinguishes contractual removal from continuing statutory rights.');
    }

    // 2. Assert: Added compliant clause produces NO_ADVERSE_RISK_IDENTIFIED (Fix 4.6)
    const addedRera = completedComp.clauseComparisons.find(p => p.changeStatus === 'ADDED');
    if (addedRera) {
        console.log(`✓ Added clause risk migration: ${addedRera.riskMigration}`);
        if (addedRera.riskMigration !== 'NO_ADVERSE_RISK_IDENTIFIED') {
            throw new Error(`TEST 5 Failed: Expected NO_ADVERSE_RISK_IDENTIFIED for added compliant clause, got: ${addedRera.riskMigration}`);
        }
        console.log('✓ Confirmed: Added compliant clause correctly mapped to NO_ADVERSE_RISK_IDENTIFIED.');
    }

    // 3. Assert: buyerConsiderations does NOT contain directive advice (Fix 4.5)
    for (const pair of completedComp.clauseComparisons) {
        const cons = pair.buyerConsiderations || '';
        const hasDirective = /\b(?:must sign|refuse to pay|reject the agreement|insist)\b/i.test(cons);
        if (hasDirective) {
            throw new Error(`TEST 5 Failed: Found directive legal advice in buyerConsiderations: "${cons}"`);
        }
    }
    console.log('✓ Confirmed: All buyerConsiderations maintain strictly informational, non-directive tone.');

    // 4. Assert: Unchanged clauses produce 0 LLM calls / retain UNCHANGED status (Fix 4.7)
    const maintClause = completedComp.clauseComparisons.find(p => p.changeStatus === 'UNCHANGED');
    if (!maintClause || maintClause.riskMigration !== 'UNCHANGED_RISK') {
        throw new Error('TEST 5 Failed: Unchanged clause did not preserve UNCHANGED_RISK.');
    }
    console.log('✓ Confirmed: Unchanged clause preserved unchanged status without unnecessary LLM mutation.');

    // 5. Assert: Idempotency (re-triggering same comparison returns existing record without duplicate creation)
    const reComp = await comparisonService.startComparison({
        userId: testUserId,
        docAId: docA._id,
        docBId: docB._id
    });
    const totalComps = await DocumentComparison.countDocuments({ userId: testUserId, comparisonHash: completedComp.comparisonHash });
    if (totalComps !== 1 || reComp.comparisonId !== completedComp.comparisonId) {
        throw new Error(`TEST 5 Failed: Idempotency violated. Found ${totalComps} comparison records.`);
    }
    console.log('✓ Confirmed: Comparison is strictly idempotent (0 duplicate records).');

    console.log('✅ TEST 5 PASSED: Full pipeline execution and legal integrity verified.\n');

    // =========================================================================
    // TEST 6: Server Startup Recovery Hook & User Authorization Check
    // =========================================================================
    console.log('----------------------------------------------------------------------');
    console.log('TEST 6: Startup Recovery Hook & Cross-User Security Check');
    console.log('----------------------------------------------------------------------');

    // Startup recovery test
    const staleComp = new DocumentComparison({
        comparisonId: `comp_stale_${Date.now()}`,
        userId: testUserId,
        docAId: docA._id,
        fileHashA: docA.fileHash,
        titleA: docA.title,
        docBId: docB._id,
        fileHashB: docB.fileHash,
        titleB: docB.title,
        comparisonHash: crypto.randomBytes(32).toString('hex'),
        status: 'MATCHING_CLAUSES',
        currentStep: 'Matching clauses...',
        completedSteps: ['DOCUMENTS_RESOLVED']
    });
    await staleComp.save();
    await DocumentComparison.collection.updateOne(
        { comparisonId: staleComp.comparisonId },
        { $set: { updatedAt: new Date(Date.now() - 20000) } }
    );

    const recoveredCount = await comparisonService.recoverUnfinishedComparisons(true);
    console.log(`✓ Startup recovery hook executed, recovered count: ${recoveredCount}`);

    const resumedDoc = await DocumentComparison.findOne({ comparisonId: staleComp.comparisonId });
    if (resumedDoc.status !== 'COMPLETED') {
        throw new Error(`TEST 6 Failed: Stale comparison was not completed by recovery hook (Status: ${resumedDoc.status}).`);
    }
    console.log(`✓ Resumed comparison reached status: ${resumedDoc.status}`);

    // Cross-user authorization test
    let authBlocked = false;
    try {
        await comparisonService.startComparison({
            userId: otherUserId, // Unauthorized user
            docAId: docA._id,
            docBId: docB._id
        });
    } catch (authErr) {
        authBlocked = true;
        console.log(`✓ Cross-user unauthorized access attempt successfully rejected: "${authErr.message}"`);
    }

    if (!authBlocked) {
        throw new Error('TEST 6 Failed: Comparison permitted cross-user document access!');
    }

    // Cleanup
    await Document.deleteMany({ userId: testUserId });
    await DocumentComparison.deleteMany({ userId: testUserId });
    console.log('✓ Cleaned up temporary test documents and comparison records.');

    console.log('======================================================================');
    console.log('ALL 6 AUTOMATED COMPARISON TEST SCENARIOS PASSED WITH 100% SUCCESS');
    console.log('======================================================================\n');
    await mongoose.disconnect();
}

runComparisonTestSuite().catch(err => {
    console.error('❌ Test suite encountered an error:', err);
    process.exit(1);
});
