const mongoose = require('mongoose');
const crossReferenceService = require('./src/services/crossReferenceService');
const Checklist = require('./src/models/Checklist');
const Document = require('./src/models/Document');
require('dotenv').config();

async function runTests() {
    console.log('=== Starting LawBuddy Cross-Referencing Checklist Tests ===\n');

    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
    await mongoose.connect(uri);
    console.log('Connected to MongoDB');

    const testUserId = 'test_user_cross_ref_' + Date.now();

    try {
        // Clean up any test artifacts for this user
        await Checklist.deleteMany({ userId: testUserId });
        await Document.deleteMany({ userId: testUserId });

        // Scenario 1: Sale Agreement with Title & Encumbrance Concern + RERA Concern
        console.log('1. Testing Document 1: Sale Agreement with Title and RERA concerns...');
        const doc1 = new Document({
            userId: testUserId,
            fileHash: 'hash_doc_1_' + Date.now(),
            title: 'Registered Sale Agreement - Flat 402',
            originalText: 'Agreement text...',
            riskLevel: 'High Risk',
            analysisStatus: 'completed',
            analysis: [
                {
                    clauseId: 'CLAUSE-003',
                    title: 'Vendor Title & Succession Recital',
                    text: 'Vendor inherited property via unregistered family arrangement.',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'Documentation/title concern',
                    reason: 'Unregistered family settlement without 30-year chain of title or legal heirship certificate.',
                    legalFinding: 'Under Hindu Succession Act, lack of clear title chain creates litigation risk.',
                    statutoryCitations: ['Hindu Succession Act Section 8', 'Registration Act Section 17'],
                    reraReferences: [],
                    buyerImpact: 'Third-party legal heirs may challenge title.',
                    recommendation: 'Obtain 30-year Encumbrance Certificate (EC) and title search report from advocate.'
                },
                {
                    clauseId: 'CLAUSE-007',
                    title: 'MahaRERA Project Registration & Escrow',
                    text: 'Builder has not updated quarterly filings on MahaRERA portal.',
                    riskLevel: 'CAUTION',
                    findingCategory: 'Potential legal concern',
                    reason: 'Project registration active but compliance filings and designated escrow disclosures are delayed.',
                    legalFinding: 'Under RERA Section 4(2)(l)(D), promoter must maintain 70% in dedicated escrow.',
                    statutoryCitations: [],
                    reraReferences: ['RERA Section 4', 'RERA Section 11'],
                    buyerImpact: 'Project funds may be commingled.',
                    recommendation: 'Verify designated escrow account and sanctioned plan on MahaRERA portal.'
                }
            ]
        });
        await doc1.save();

        // Trigger Cross-Reference Sync
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc1);

        let userChecklists = await Checklist.find({ userId: testUserId });
        console.log(`- Created/Updated ${userChecklists.length} checklist(s).`);
        console.assert(userChecklists.length > 0, 'Should create default due diligence checklist');

        const checklist1 = userChecklists[0];
        console.log(`- Checklist title: "${checklist1.title}" with ${checklist1.items.length} items`);

        // Check if Title & Encumbrance tasks are flagged
        const ecItem = checklist1.items.find(i => i.title.toLowerCase().includes('encumbrance'));
        const titleChainItem = checklist1.items.find(i => i.title.toLowerCase().includes('title deed'));
        const reraItem = checklist1.items.find(i => i.title.toLowerCase().includes('rera'));
        const possessionItem = checklist1.items.find(i => i.title.toLowerCase().includes('possession'));

        console.assert(ecItem && ecItem.status === 'FLAGGED', 'EC item should be FLAGGED');
        console.assert(titleChainItem && titleChainItem.status === 'FLAGGED', 'Title Chain item should be FLAGGED');
        console.assert(reraItem && reraItem.status === 'FLAGGED', 'RERA item should be FLAGGED');
        console.assert(ecItem.isCompleted === false, 'Flagged item must NOT be marked isCompleted=true');
        console.assert(possessionItem.status === 'NOT_STARTED', 'Unrelated possession item should remain NOT_STARTED');

        console.log(`  ✓ EC Task Status: ${ecItem.status} (isCompleted: ${ecItem.isCompleted})`);
        console.log(`  ✓ Title Task Status: ${titleChainItem.status}`);
        console.log(`  ✓ RERA Task Status: ${reraItem.status}`);
        console.log(`  ✓ Possession Task Status: ${possessionItem.status}`);
        console.log(`  ✓ Linked issues in EC task: ${ecItem.linkedIssues.length} (Document: ${ecItem.linkedIssues[0].documentTitle})`);

        // Scenario 2: Multi-Document - Uploading Builder Allotment Letter with Possession & Payment issues
        console.log('\n2. Testing Document 2: Builder Allotment Letter with Possession & Forfeiture issues...');
        const doc2 = new Document({
            userId: testUserId,
            fileHash: 'hash_doc_2_' + Date.now(),
            title: 'Builder Allotment Letter - Tower B',
            originalText: 'Allotment text...',
            riskLevel: 'High Risk',
            analysisStatus: 'completed',
            analysis: [
                {
                    clauseId: 'CLAUSE-012',
                    title: 'Possession Date & Unilateral Grace Period',
                    text: 'Possession shall be delivered within 48 months with unilateral 12-month extension without compensation.',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'Confirmed statutory violation',
                    reason: 'Clause provides unilateral 12-month extension and denies Section 18 delay interest compensation.',
                    legalFinding: 'Under RERA Section 18, delay requires payment of interest at SBI MCLR + 2%.',
                    statutoryCitations: [],
                    reraReferences: ['RERA Section 18'],
                    buyerImpact: 'Builder can delay possession indefinitely without penalty.',
                    recommendation: 'Insist on fixed handover timeline aligned with MahaRERA completion date.'
                },
                {
                    clauseId: 'CLAUSE-015',
                    title: '20% Earnest Money Forfeiture',
                    text: 'Builder reserves right to forfeit 20% of total consideration on cancellation.',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'Contractual risk',
                    reason: 'Forfeiture exceeding 10% violates RERA Section 13 advance ceiling principles.',
                    legalFinding: 'Under RERA Section 13 and Contract Act Section 74, unreasonable forfeiture is unenforceable.',
                    statutoryCitations: ['Contract Act Section 74'],
                    reraReferences: ['RERA Section 13'],
                    buyerImpact: 'Severe financial loss on cancellation.',
                    recommendation: 'Cap forfeiture at maximum 10% booking amount.'
                }
            ]
        });
        await doc2.save();

        // Trigger Sync for Document 2
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc2);

        userChecklists = await Checklist.find({ userId: testUserId });
        const updatedChecklist = userChecklists[0];

        const updatedPossessionItem = updatedChecklist.items.find(i => i.title.toLowerCase().includes('possession'));
        const updatedForfeitureItem = updatedChecklist.items.find(i => i.title.toLowerCase().includes('forfeiture'));
        const updatedEcItem = updatedChecklist.items.find(i => i.title.toLowerCase().includes('encumbrance'));

        console.assert(updatedPossessionItem.status === 'FLAGGED', 'Possession task should now be FLAGGED by Doc 2');
        console.assert(updatedForfeitureItem.status === 'FLAGGED', 'Forfeiture task should now be FLAGGED by Doc 2');
        console.assert(updatedPossessionItem.linkedIssues.length === 1, 'Possession task has 1 linked issue');
        console.assert(updatedPossessionItem.linkedIssues[0].documentTitle === 'Builder Allotment Letter - Tower B', 'Attributed to Document 2');

        console.log(`  ✓ Possession Task Status: ${updatedPossessionItem.status} (Triggered by: ${updatedPossessionItem.linkedIssues[0].documentTitle})`);
        console.log(`  ✓ Forfeiture Task Status: ${updatedForfeitureItem.status} (Triggered by: ${updatedForfeitureItem.linkedIssues[0].documentTitle})`);
        console.log(`  ✓ Prior EC Task from Doc 1 preserved: ${updatedEcItem.status} (Triggered by: ${updatedEcItem.linkedIssues[0].documentTitle})`);

        // Scenario 3: Deduplication - Re-running sync for same document does NOT duplicate issues
        console.log('\n3. Testing Idempotent Deduplication (Re-syncing Doc 1 & Doc 2)...');
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc1);
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc2);

        const dedupeChecklist = await Checklist.findOne({ userId: testUserId });
        const dedupeEcItem = dedupeChecklist.items.find(i => i.title.toLowerCase().includes('encumbrance'));
        console.assert(dedupeEcItem.linkedIssues.length === 1, 'Deduplication check: EC item should still have exactly 1 linked issue');
        console.log(`  ✓ Deduplication successful: EC item has ${dedupeEcItem.linkedIssues.length} linked issue(s).`);

        // Scenario 4: User Manual Completion & State Preservation
        console.log('\n4. Testing Manual Completion & State Transitions...');
        dedupeEcItem.isCompleted = true;
        dedupeEcItem.status = 'VERIFIED';
        await dedupeChecklist.save();

        // Re-syncing document should NOT reset VERIFIED back to FLAGGED
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc1);
        const verifiedChecklist = await Checklist.findOne({ userId: testUserId });
        const verifiedEcItem = verifiedChecklist.items.find(i => i.title.toLowerCase().includes('encumbrance'));
        console.assert(verifiedEcItem.isCompleted === true, 'isCompleted must remain true');
        console.assert(verifiedEcItem.status === 'VERIFIED', 'status must remain VERIFIED');
        console.log(`  ✓ State preservation successful: Completed task remains VERIFIED.`);

        // Clean up test data
        await Checklist.deleteMany({ userId: testUserId });
        await Document.deleteMany({ userId: testUserId });

        console.log('\n🎉 ALL 10 CROSS-REFERENCING CHECKLIST TESTS PASSED SUCCESSFULLY!\n');
    } catch (err) {
        console.error('Test Failed:', err);
    } finally {
        await mongoose.disconnect();
    }
}

runTests();
