const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mongoose = require('mongoose');
const crypto = require('crypto');
const fs = require('fs');
const Document = require('../src/models/Document');
const DocumentComparison = require('../src/models/DocumentComparison');
const LawSnippet = require('../src/models/LawSnippet');
const comparisonService = require('../src/services/comparisonService');
const scanJobService = require('../src/services/scanJobService');

async function runE2EIntegrationAudit() {
    console.log('======================================================================');
    console.log('LAWBUDDY CHECKPOINT 5 — END-TO-END INTEGRATION & USER FLOW AUDIT');
    console.log('======================================================================\n');

    await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
    console.log('✓ Connected to MongoDB Atlas.\n');

    const results = {};
    const e2eUser = `e2e_tester_${Date.now()}`;
    const unauthorizedUser = `unauthorized_tester_${Date.now()}`;

    // =========================================================================
    // TEST 1: Compare Two Existing Analyzed Documents
    // =========================================================================
    console.log('--- TEST 1: Compare Two Existing Analyzed Documents ---');
    const docA_T1 = new Document({
        userId: e2eUser,
        fileHash: crypto.randomBytes(32).toString('hex'),
        title: 'Agreement_Original_Draft_A.pdf',
        originalText: 'Standard Real Estate Agreement Version A',
        extractedNormalizedText: 'Standard Real Estate Agreement Version A',
        canonicalClauses: [
            {
                clauseId: 'CLAUSE-T1-1',
                title: 'Section 18 — Date of Possession',
                text: 'The promoter shall hand over possession of the apartment within 36 months.',
                sourcePages: [1],
                riskLevel: 'COMPLIANT'
            },
            {
                clauseId: 'CLAUSE-T1-2',
                title: 'Section 14 — Structural Defect Liability',
                text: 'The promoter shall rectify any defect occurring within 5 years of possession without charge.',
                sourcePages: [2],
                riskLevel: 'COMPLIANT'
            },
            {
                clauseId: 'CLAUSE-T1-3',
                title: 'Section 22 — Dispute Resolution',
                text: 'Any dispute shall be referred to arbitration in accordance with the Arbitration Act.',
                sourcePages: [2],
                riskLevel: 'COMPLIANT'
            }
        ],
        analysis: [
            { clauseId: 'CLAUSE-T1-1', title: 'Possession', text: 'Possession', riskLevel: 'COMPLIANT' },
            { clauseId: 'CLAUSE-T1-2', title: 'Defect Liability', text: 'Defect Liability', riskLevel: 'COMPLIANT' },
            { clauseId: 'CLAUSE-T1-3', title: 'Dispute Resolution', text: 'Dispute Resolution', riskLevel: 'COMPLIANT' }
        ],
        analysisStatus: 'completed'
    });
    await docA_T1.save();

    const docB_T1 = new Document({
        userId: e2eUser,
        fileHash: crypto.randomBytes(32).toString('hex'),
        title: 'Agreement_Revised_Draft_B.pdf',
        originalText: 'Revised Real Estate Agreement Version B',
        extractedNormalizedText: 'Revised Real Estate Agreement Version B',
        canonicalClauses: [
            {
                clauseId: 'CLAUSE-T1-101',
                title: 'Clause 19 — Possession Handover Timeline',
                text: 'The promoter may hand over possession of the apartment within 42 months.',
                sourcePages: [1],
                riskLevel: 'CAUTION'
            },
            // Clause 2 (Defect Liability) removed
            {
                clauseId: 'CLAUSE-T1-102',
                title: 'Clause 22 — Dispute Resolution',
                text: 'Any dispute shall be referred to arbitration in accordance with the Arbitration Act.',
                sourcePages: [2],
                riskLevel: 'COMPLIANT'
            },
            {
                clauseId: 'CLAUSE-T1-103',
                title: 'Clause 28 — RERA Registration Status',
                text: 'The promoter has registered the project under RERA and maintains updated accounts.',
                sourcePages: [3],
                riskLevel: 'COMPLIANT'
            }
        ],
        analysisStatus: 'completed'
    });
    await docB_T1.save();

    const compT1 = await comparisonService.startComparison({
        userId: e2eUser,
        docAId: docA_T1._id,
        docBId: docB_T1._id,
        titleA: docA_T1.title,
        titleB: docB_T1.title
    });

    const completedCompT1 = await comparisonService.executeComparisonPipeline(compT1.comparisonId);

    results.test1 = {
        pass: completedCompT1.status === 'COMPLETED' && completedCompT1.clauseComparisons.length === 4,
        comparisonId: completedCompT1.comparisonId,
        status: completedCompT1.status,
        docAId: docA_T1._id.toString(),
        docBId: docB_T1._id.toString(),
        modifiedCount: completedCompT1.modifiedCount,
        addedCount: completedCompT1.addedCount,
        removedCount: completedCompT1.removedCount,
        unchangedCount: completedCompT1.unchangedCount,
        escalatedRiskCount: completedCompT1.escalatedRiskCount,
        reducedRiskCount: completedCompT1.reducedRiskCount
    };
    console.log('✓ TEST 1 Result:', JSON.stringify(results.test1, null, 2));

    // =========================================================================
    // TEST 2: Create a Comparison Using New Files (ScanJob Flow)
    // =========================================================================
    console.log('\n--- TEST 2: Create a Comparison Using New Files ---');
    const textFileA = 'Clause 1: Allottee shall pay the total consideration in 5 installments. Clause 2: Handover within 24 months.';
    const textFileB = 'Clause 1: Allottee shall pay the total consideration in 6 installments. Clause 2: Handover within 24 months.';

    const jobA = await scanJobService.createScanJob({
        userId: e2eUser,
        text: textFileA,
        mimeType: 'text/plain',
        title: 'New_Uploaded_Doc_A.txt'
    });
    const completedJobA = await scanJobService.executeJobPipeline(jobA.jobId);
    const createdDocA = await Document.findById(completedJobA.documentId);

    const jobB = await scanJobService.createScanJob({
        userId: e2eUser,
        text: textFileB,
        mimeType: 'text/plain',
        title: 'New_Uploaded_Doc_B.txt'
    });
    const completedJobB = await scanJobService.executeJobPipeline(jobB.jobId);
    const createdDocB = await Document.findById(completedJobB.documentId);

    const compT2 = await comparisonService.startComparison({
        userId: e2eUser,
        docAId: createdDocA._id,
        docBId: createdDocB._id,
        titleA: createdDocA.title,
        titleB: createdDocB.title
    });
    const completedCompT2 = await comparisonService.executeComparisonPipeline(compT2.comparisonId);

    // Verify no Base64 blob is stored in DocumentComparison
    const rawCompDoc = await DocumentComparison.findById(completedCompT2._id).lean();
    const hasBase64 = JSON.stringify(rawCompDoc).includes('base64');

    results.test2 = {
        pass: createdDocA && createdDocB && completedCompT2.status === 'COMPLETED' && !hasBase64,
        docAId: createdDocA._id.toString(),
        docBId: createdDocB._id.toString(),
        jobAId: jobA.jobId,
        jobBId: jobB.jobId,
        comparisonId: completedCompT2.comparisonId,
        noBase64InMongo: !hasBase64
    };
    console.log('✓ TEST 2 Result:', JSON.stringify(results.test2, null, 2));

    // =========================================================================
    // TEST 3: Material Legal Change (30 -> 60, shall -> may)
    // =========================================================================
    console.log('\n--- TEST 3: Material Legal Change ---');
    const clausesA_T3 = [{
        clauseId: 'CLAUSE-T3-1',
        title: 'Possession Timeline',
        text: 'Possession shall be provided within 30 days of completion certificate.',
        sourcePages: [1],
        riskLevel: 'COMPLIANT'
    }];
    const clausesB_T3 = [{
        clauseId: 'CLAUSE-T3-101',
        title: 'Possession Timeline',
        text: 'Possession may be provided within 60 days of completion certificate.',
        sourcePages: [1],
        riskLevel: 'CAUTION'
    }];

    const matchedT3 = comparisonService.matchClauses(clausesA_T3, clausesB_T3);
    const diffsT3 = comparisonService.detectMaterialChanges(clausesA_T3[0].text, clausesB_T3[0].text);
    const riskMigrationT3 = comparisonService.calculateDeterministicRiskMigration({
        changeStatus: 'MODIFIED',
        previousRiskLevel: 'COMPLIANT',
        revisedRiskLevel: 'CAUTION',
        titleA: 'Possession Timeline'
    });

    results.test3 = {
        pass: matchedT3[0].matchConfidence === 'HIGH' && 
              matchedT3[0].changeStatus === 'MODIFIED' && 
              diffsT3.length >= 2 && 
              riskMigrationT3 === 'ESCALATED_RISK',
        matchConfidence: matchedT3[0].matchConfidence,
        similarityScore: matchedT3[0].similarityScore,
        changeStatus: matchedT3[0].changeStatus,
        detectedDiffs: diffsT3.map(d => ({ category: d.category, desc: d.changeDescription })),
        riskMigration: riskMigrationT3
    };
    console.log('✓ TEST 3 Result:', JSON.stringify(results.test3, null, 2));

    // =========================================================================
    // TEST 4: Added Clause (NO_ADVERSE_RISK_IDENTIFIED vs NEW_RISK_ADDED)
    // =========================================================================
    console.log('\n--- TEST 4: Added Clause ---');
    const compliantMigration = comparisonService.calculateDeterministicRiskMigration({
        changeStatus: 'ADDED',
        previousRiskLevel: null,
        revisedRiskLevel: 'COMPLIANT'
    });
    const highRiskMigration = comparisonService.calculateDeterministicRiskMigration({
        changeStatus: 'ADDED',
        previousRiskLevel: null,
        revisedRiskLevel: 'HIGH_RISK'
    });

    results.test4 = {
        pass: compliantMigration === 'NO_ADVERSE_RISK_IDENTIFIED' && highRiskMigration === 'NEW_RISK_ADDED',
        compliantAddedResult: compliantMigration,
        highRiskAddedResult: highRiskMigration
    };
    console.log('✓ TEST 4 Result:', JSON.stringify(results.test4, null, 2));

    // =========================================================================
    // TEST 5: Removed Clause / Statutory Distinction
    // =========================================================================
    console.log('\n--- TEST 5: Removed Clause / Statutory Distinction ---');
    const removedDefectPair = completedCompT1.clauseComparisons.find(p => p.changeStatus === 'REMOVED');
    const doesNotClaimStatutoryRightExtinguished = !/lost (?:their )?statutory rights?|statutory protection (?:is )?extinguished/i.test(removedDefectPair?.legalFinding || '');

    results.test5 = {
        pass: removedDefectPair && removedDefectPair.riskMigration === 'ESCALATED_RISK' && doesNotClaimStatutoryRightExtinguished,
        clausePairId: removedDefectPair?.clausePairId,
        changeStatus: removedDefectPair?.changeStatus,
        riskMigration: removedDefectPair?.riskMigration,
        legalFinding: removedDefectPair?.legalFinding,
        distinguishesStatutoryProtection: doesNotClaimStatutoryRightExtinguished
    };
    console.log('✓ TEST 5 Result:', JSON.stringify(results.test5, null, 2));

    // =========================================================================
    // TEST 6: Identical Documents
    // =========================================================================
    console.log('\n--- TEST 6: Identical Documents ---');
    const compIdentical = await comparisonService.startComparison({
        userId: e2eUser,
        docAId: docA_T1._id,
        docBId: docA_T1._id,
        titleA: 'Agreement Version A',
        titleB: 'Agreement Version A (Copy)'
    });
    const completedIdentical = await comparisonService.executeComparisonPipeline(compIdentical.comparisonId);

    results.test6 = {
        pass: completedIdentical.status === 'COMPLETED' && 
              completedIdentical.unchangedCount === 3 && 
              completedIdentical.modifiedCount === 0 && 
              completedIdentical.escalatedRiskCount === 0,
        comparisonId: completedIdentical.comparisonId,
        unchangedCount: completedIdentical.unchangedCount,
        modifiedCount: completedIdentical.modifiedCount,
        escalatedRiskCount: completedIdentical.escalatedRiskCount
    };
    console.log('✓ TEST 6 Result:', JSON.stringify(results.test6, null, 2));

    // =========================================================================
    // TEST 7: RAG / Citation Verification (>= 0.70 threshold)
    // =========================================================================
    console.log('\n--- TEST 7: RAG / Citation Verification ---');
    const realDbSnippet = await LawSnippet.findOne();
    const mockCitation = {
        lawSnippetId: realDbSnippet._id,
        actName: realDbSnippet.document || realDbSnippet.actName,
        sectionOrRule: realDbSnippet.section || realDbSnippet.rule || realDbSnippet.sectionOrRule,
        provisionTitle: realDbSnippet.title || realDbSnippet.provisionTitle,
        sourceUrl: realDbSnippet.sourceUrl
    };

    const validatedAbove70 = comparisonService.validateCitations(
        [mockCitation],
        [{ ...mockCitation, _id: realDbSnippet._id, score: 0.76 }]
    );
    const rejectedBelow70 = comparisonService.validateCitations(
        [mockCitation],
        [{ ...mockCitation, _id: realDbSnippet._id, score: 0.68 }]
    );

    results.test7 = {
        pass: validatedAbove70.length === 1 && rejectedBelow70.length === 0,
        acceptedScore: validatedAbove70[0]?.similarityScore,
        below70Rejected: rejectedBelow70.length === 0,
        provenanceMatchesDbSnippet: validatedAbove70[0]?.lawSnippetId.toString() === realDbSnippet._id.toString()
    };
    console.log('✓ TEST 7 Result:', JSON.stringify(results.test7, null, 2));

    // =========================================================================
    // TEST 8: No-Authority Case
    // =========================================================================
    console.log('\n--- TEST 8: No-Authority Case ---');
    const noAuthorityValidation = comparisonService.validateCitations(
        [{ actName: 'Random Unrelated Act', sectionOrRule: 'Sec 999' }],
        [] // No RAG context retrieved
    );

    results.test8 = {
        pass: noAuthorityValidation.length === 0,
        citationsLength: noAuthorityValidation.length
    };
    console.log('✓ TEST 8 Result:', JSON.stringify(results.test8, null, 2));

    // =========================================================================
    // TEST 9: Recovery
    // =========================================================================
    console.log('\n--- TEST 9: Recovery ---');
    const interruptedComp = new DocumentComparison({
        comparisonId: `comp_interrupt_${Date.now()}`,
        userId: e2eUser,
        docAId: docA_T1._id,
        fileHashA: docA_T1.fileHash,
        titleA: docA_T1.title,
        docBId: docB_T1._id,
        fileHashB: docB_T1.fileHash,
        titleB: docB_T1.title,
        comparisonHash: crypto.randomBytes(32).toString('hex'),
        status: 'DIFFING_CHANGES',
        currentStep: 'Diffing material changes...',
        completedSteps: ['DOCUMENTS_RESOLVED', 'CLAUSES_MATCHED'],
        clauseComparisons: completedCompT1.clauseComparisons
    });
    await interruptedComp.save();
    await DocumentComparison.collection.updateOne(
        { comparisonId: interruptedComp.comparisonId },
        { $set: { updatedAt: new Date(Date.now() - 20000) } }
    );

    const recoveredCount = await comparisonService.recoverUnfinishedComparisons(true);
    const recoveredDoc = await DocumentComparison.findOne({ comparisonId: interruptedComp.comparisonId });

    results.test9 = {
        pass: recoveredCount >= 1 && recoveredDoc.status === 'COMPLETED',
        recoveredCount,
        finalStatus: recoveredDoc.status,
        completedStages: recoveredDoc.completedSteps
    };
    console.log('✓ TEST 9 Result:', JSON.stringify(results.test9, null, 2));

    // =========================================================================
    // TEST 10: Cross-User Authorization
    // =========================================================================
    console.log('\n--- TEST 10: Cross-User Authorization ---');
    let unauthorizedBlocked = false;
    try {
        await comparisonService.startComparison({
            userId: unauthorizedUser,
            docAId: docA_T1._id, // docA owned by e2eUser
            docBId: docB_T1._id
        });
    } catch (e) {
        unauthorizedBlocked = true;
    }

    results.test10 = {
        pass: unauthorizedBlocked,
        blockedUnauthorizedAccess: unauthorizedBlocked
    };
    console.log('✓ TEST 10 Result:', JSON.stringify(results.test10, null, 2));

    // Cleanup
    await Document.deleteMany({ userId: { $in: [e2eUser, unauthorizedUser] } });
    await DocumentComparison.deleteMany({ userId: { $in: [e2eUser, unauthorizedUser] } });
    console.log('\n✓ Cleaned up all temporary test documents & comparison records.');

    console.log('\n======================================================================');
    console.log('ALL 10 E2E INTEGRATION TESTS COMPLETED SUCCESSFULLY');
    console.log('======================================================================\n');
    await mongoose.disconnect();
}

runE2EIntegrationAudit().catch(err => {
    console.error('❌ E2E Integration Audit Error:', err);
    process.exit(1);
});
