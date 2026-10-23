const assert = require('assert');
const path = require('path');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

require('dotenv').config({ path: path.join(__dirname, '../.env') });

const Checklist = require('../src/models/Checklist');
const Document = require('../src/models/Document');
const User = require('../src/models/User');
const crossReferenceService = require('../src/services/crossReferenceService');
const documentCleanupService = require('../src/services/documentCleanupService');
const checklistRoutes = require('../src/routes/checklistRoutes');
const documentRoutes = require('../src/routes/documentRoutes');
const JWT_SECRET = require('../src/config/jwt');

function createTestApp() {
    const app = express();
    app.use(express.json());
    app.use('/api', checklistRoutes);
    app.use('/api', documentRoutes);
    return app;
}

function makeRequest(server, { method, urlPath, token = null, body = null }) {
    return new Promise((resolve, reject) => {
        const address = server.address();
        const options = {
            hostname: '127.0.0.1',
            port: address.port,
            path: urlPath,
            method: method,
            headers: {}
        };
        if (token) {
            options.headers['Authorization'] = `Bearer ${token}`;
        }
        if (body) {
            const data = JSON.stringify(body);
            options.headers['Content-Type'] = 'application/json';
            options.headers['Content-Length'] = Buffer.byteLength(data);
        }

        const req = http.request(options, (res) => {
            const chunks = [];
            res.on('data', chunk => chunks.push(chunk));
            res.on('end', () => {
                const raw = Buffer.concat(chunks).toString('utf8');
                let parsed = null;
                try {
                    parsed = JSON.parse(raw);
                } catch (_) {}
                resolve({ status: res.statusCode, headers: res.headers, body: parsed, raw });
            });
        });
        req.on('error', reject);
        if (body) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}

async function runTests() {
    console.log('=== Starting LawBuddy Automatic Checklist Item Cleanup Test Suite ===\n');

    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
    try {
        await mongoose.connect(uri, { serverSelectionTimeoutMS: 4000 });
        console.log('Connected to MongoDB');
    } catch (err) {
        console.warn('MongoDB not reachable for DB-backed tests, skipping:', err.message);
        return;
    }

    const testUserId = `test_auto_cleanup_${Date.now()}`;
    const userEmail = `${testUserId}@example.com`;

    const app = createTestApp();
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));

    try {
        // Setup authenticated user
        await User.create({
            userId: testUserId,
            email: userEmail,
            full_name: 'Auto Cleanup Test User',
            passwordHash: 'dummy_hash',
            tokenVersion: 0
        });
        const token = jwt.sign({ userId: testUserId, email: userEmail, tokenVersion: 0 }, JWT_SECRET, { expiresIn: '1h' });

        // Clean up any existing state
        await Checklist.deleteMany({ userId: testUserId });
        await Document.deleteMany({ userId: testUserId });

        // -------------------------------------------------------------------------
        // 1. Automatically generated items with numeric IDs receive source: 'auto'
        // -------------------------------------------------------------------------
        console.log('1. Testing auto-generated item receives source: "auto" and numeric ID...');
        // Create a custom checklist that has no matching items for a custom category
        const customChecklist = await Checklist.create({
            userId: testUserId,
            type: 'custom_property_review',
            title: 'Custom Property Review',
            items: [
                {
                    id: 'custom_task_1',
                    title: 'Inspect physical boundary markers',
                    isCompleted: false,
                    status: 'NOT_STARTED',
                    linkedIssues: [],
                    source: 'manual'
                }
            ]
        });

        const doc1 = await Document.create({
            userId: testUserId,
            fileHash: `hash_auto_${Date.now()}`,
            title: 'Special Agreement Document',
            originalText: 'Agreement text',
            analysisStatus: 'completed',
            riskLevel: 'High Risk',
            analysis: [
                {
                    clauseId: 'CLAUSE-SPECIAL-1',
                    title: 'Unilateral Escrow Clause',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'Special escrow concern',
                    reason: 'Promoter escrow withdrawal without architect certificate',
                    statutoryCitations: ['RERA Section 4']
                }
            ]
        });

        // Trigger sync - should append a new targeted auto item
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc1);

        const checklistAfterSync = await Checklist.findById(customChecklist._id);
        const autoItem = checklistAfterSync.items.find(i => i.source === 'auto');
        assert.ok(autoItem, 'An item with source: "auto" must be created');
        assert.ok(/^[0-9]+$/.test(autoItem.id), `ID must be numeric, got: ${autoItem.id}`);
        assert.strictEqual(autoItem.status, 'FLAGGED');
        assert.strictEqual(autoItem.isCompleted, false);
        assert.strictEqual(autoItem.linkedIssues.length, 1);
        console.log(`  ✓ Auto-generated item created with ID "${autoItem.id}" (numeric: true) and source: "${autoItem.source}"`);

        // -------------------------------------------------------------------------
        // 2. A numeric-ID automatic item is correctly recognized by cleanup
        // -------------------------------------------------------------------------
        console.log('\n2. Testing isAutomaticItem correctly recognizes numeric-ID automatic items...');
        assert.strictEqual(crossReferenceService.isAutomaticItem(autoItem), true, 'autoItem should be recognized as automatic');
        
        const manualWithNumericId = { id: Date.now().toString(), title: 'Manual task', source: 'manual' };
        assert.strictEqual(crossReferenceService.isAutomaticItem(manualWithNumericId), false, 'Manual item with numeric ID must not be auto');
        console.log('  ✓ Numeric ID automatic item recognized without relying on ID format');

        // -------------------------------------------------------------------------
        // 3 & 4. Obsolete auto item is cleaned up; active auto item is preserved
        // -------------------------------------------------------------------------
        console.log('\n3 & 4. Testing active auto item is preserved, and obsolete auto item is cleaned up...');
        // First run cleanup while doc1 is still active:
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        let chkActive = await Checklist.findById(customChecklist._id);
        let preservedAuto = chkActive.items.find(i => i.id === autoItem.id);
        assert.ok(preservedAuto, 'Auto item linked to active document must be preserved');
        console.log('  ✓ Auto item linked to active issue is preserved');

        // Now soft-delete doc1
        doc1.isDeleted = true;
        doc1.deletedAt = new Date();
        await doc1.save();

        // Run cleanup (as triggered on document deletion)
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        let chkCleaned = await Checklist.findById(customChecklist._id);
        let cleanedAuto = chkCleaned.items.find(i => i.id === autoItem.id);
        assert.strictEqual(cleanedAuto, undefined, 'Obsolete automatic item with 0 linked issues must be cleaned up');
        console.log('  ✓ Obsolete automatic item successfully removed when source document is removed');

        // -------------------------------------------------------------------------
        // 5. Manually created checklist items remain intact
        // -------------------------------------------------------------------------
        console.log('\n5. Testing manually created checklist items remain intact...');
        const manualTask = chkCleaned.items.find(i => i.id === 'custom_task_1');
        assert.ok(manualTask, 'Manual checklist item must not be removed by orphan cleanup');
        assert.strictEqual(manualTask.source, 'manual');

        // Add another manual item via POST route
        const addRes = await makeRequest(server, {
            method: 'POST',
            urlPath: `/api/checklists/${customChecklist.type}/items`,
            token,
            body: { title: 'User Manual Task with Numeric ID' }
        });
        assert.strictEqual(addRes.status, 200);
        assert.strictEqual(addRes.body.item.source, 'manual');

        // Run cleanup again
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        const chkAfterManualCheck = await Checklist.findById(customChecklist._id);
        const addedManual = chkAfterManualCheck.items.find(i => i.title === 'User Manual Task with Numeric ID');
        assert.ok(addedManual, 'Manual item created via route must remain intact');
        assert.strictEqual(addedManual.source, 'manual');
        console.log('  ✓ Manually created checklist items remain intact');

        // -------------------------------------------------------------------------
        // 6. Legacy items without a source field are preserved
        // -------------------------------------------------------------------------
        console.log('\n6. Testing legacy items without a source field are preserved...');
        // Insert legacy item without source field
        chkAfterManualCheck.items.push({
            id: 'legacy_custom_id_99',
            title: 'Legacy Custom Investigation Task',
            isCompleted: false,
            status: 'NOT_STARTED',
            linkedIssues: []
        });
        await chkAfterManualCheck.save();

        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        const chkLegacy = await Checklist.findById(customChecklist._id);
        const legacyItem = chkLegacy.items.find(i => i.id === 'legacy_custom_id_99');
        assert.ok(legacyItem, 'Legacy item without source field must be preserved');
        console.log('  ✓ Legacy item without source field is preserved');

        // -------------------------------------------------------------------------
        // 7. Completed/ticked items retain their completion status
        // -------------------------------------------------------------------------
        console.log('\n7. Testing completed/ticked items retain status when source issue disappears...');
        // Add another auto item, tick it, and delete the source document
        const doc2 = await Document.create({
            userId: testUserId,
            fileHash: `hash_auto2_${Date.now()}`,
            title: 'Doc 2 for completion test',
            originalText: 'Text',
            analysisStatus: 'completed',
            analysis: [
                {
                    clauseId: 'CLAUSE-AUTO-COMPLETION',
                    title: 'Delayed Handover Penalty',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'Completion delay concern',
                    reason: 'Unreasonable grace period'
                }
            ]
        });

        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc2);
        let chkWithDoc2 = await Checklist.findById(customChecklist._id);
        let doc2AutoItem = chkWithDoc2.items.find(i =>
            i.linkedIssues && i.linkedIssues.some(li => li.clauseId === 'CLAUSE-AUTO-COMPLETION')
        );
        assert.ok(doc2AutoItem, 'Auto item for doc 2 must exist');

        // User marks this item completed / verified
        doc2AutoItem.isCompleted = true;
        doc2AutoItem.status = 'VERIFIED';
        await chkWithDoc2.save();

        // Delete doc2
        doc2.isDeleted = true;
        doc2.deletedAt = new Date();
        await doc2.save();

        // Run cleanup
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        let chkAfterDoc2Delete = await Checklist.findById(customChecklist._id);
        let preservedCompleted = chkAfterDoc2Delete.items.find(i => i.id === doc2AutoItem.id);
        assert.ok(preservedCompleted, 'Completed auto item must NOT be removed even when source doc is deleted');
        assert.strictEqual(preservedCompleted.isCompleted, true);
        assert.strictEqual(preservedCompleted.status, 'VERIFIED');
        assert.strictEqual(preservedCompleted.linkedIssues.length, 0, 'Orphaned linked issue should be pruned');
        console.log('  ✓ Completed/ticked item retained with status VERIFIED when source issue disappeared');

        // -------------------------------------------------------------------------
        // 8. Items with both automatic and manual associations are not incorrectly removed
        // -------------------------------------------------------------------------
        console.log('\n8. Testing items with both automatic and manual associations are preserved...');
        // Create a manual item, link a document issue to it, then delete document
        const dualItem = {
            id: 'manual_dual_' + Date.now(),
            title: 'Verify Encumbrance Certificate',
            isCompleted: false,
            status: 'NOT_STARTED',
            linkedIssues: [],
            source: 'manual'
        };
        chkAfterDoc2Delete.items.push(dualItem);
        await chkAfterDoc2Delete.save();

        const doc3 = await Document.create({
            userId: testUserId,
            fileHash: `hash_auto3_${Date.now()}`,
            title: 'Doc 3 EC review',
            originalText: 'Text',
            analysisStatus: 'completed',
            analysis: [
                {
                    clauseId: 'CLAUSE-EC-DUAL',
                    title: 'Title Recital',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'title concern',
                    reason: 'Missing EC'
                }
            ]
        });

        // Sync links issue to the manual item
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc3);
        let chkDual = await Checklist.findById(customChecklist._id);
        let dualLinked = chkDual.items.find(i => i.id === dualItem.id);
        assert.ok(dualLinked.linkedIssues.length > 0, 'Issue should be linked to manual item');
        assert.strictEqual(dualLinked.source, 'manual');

        // Delete doc3
        doc3.isDeleted = true;
        doc3.deletedAt = new Date();
        await doc3.save();

        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        let chkAfterDualCleanup = await Checklist.findById(customChecklist._id);
        let dualAfter = chkAfterDualCleanup.items.find(i => i.id === dualItem.id);
        assert.ok(dualAfter, 'Manual item with automatic associations must not be removed when issue disappears');
        assert.strictEqual(dualAfter.status, 'NOT_STARTED');
        assert.strictEqual(dualAfter.linkedIssues.length, 0);
        console.log('  ✓ Item with both automatic and manual associations preserved');

        // -------------------------------------------------------------------------
        // 9. Repeated synchronization and cleanup are idempotent
        // -------------------------------------------------------------------------
        console.log('\n9. Testing idempotency of sync and cleanup...');
        const doc4 = await Document.create({
            userId: testUserId,
            fileHash: `hash_auto4_${Date.now()}`,
            title: 'Doc 4 Idempotency',
            originalText: 'Text',
            analysisStatus: 'completed',
            analysis: [
                {
                    clauseId: 'CLAUSE-IDEMPOTENT',
                    title: 'RERA Escrow Verification',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'rera concern',
                    reason: 'Escrow missing'
                }
            ]
        });

        // Sync 3 times
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc4);
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc4);
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, doc4);

        let chkIdempotent1 = await Checklist.findById(customChecklist._id);
        const countBeforeCleanup = chkIdempotent1.items.length;

        // Cleanup 3 times
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);

        let chkIdempotent2 = await Checklist.findById(customChecklist._id);
        assert.strictEqual(chkIdempotent2.items.length, countBeforeCleanup, 'Repeated cleanup must be idempotent');
        console.log('  ✓ Repeated sync and cleanup are strictly idempotent');

        // -------------------------------------------------------------------------
        // 10. Previous zero-active-documents data-loss regression still passes
        // -------------------------------------------------------------------------
        console.log('\n10. Testing zero active documents data-loss regression...');
        // Soft delete all documents for user
        await Document.updateMany({ userId: testUserId }, { $set: { isDeleted: true, deletedAt: new Date() } });
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);

        const chkZeroDocs = await Checklist.findById(customChecklist._id);
        assert.ok(chkZeroDocs, 'Checklist must NOT be deleted when zero active documents exist');
        assert.strictEqual(chkZeroDocs.isDeleted, false);
        // Manual items and completed items must still be there
        assert.ok(chkZeroDocs.items.some(i => i.id === 'custom_task_1'), 'Manual task 1 preserved');
        assert.ok(chkZeroDocs.items.some(i => i.isCompleted === true), 'Completed items preserved');
        console.log('  ✓ Checklist and non-obsolete items preserved when zero active documents exist');

        // -------------------------------------------------------------------------
        // 11. GET /checklists remains strictly read-only
        // -------------------------------------------------------------------------
        console.log('\n11. Testing GET /api/checklists remains strictly read-only...');
        const preGet = await Checklist.findById(customChecklist._id).lean();
        const getRes = await makeRequest(server, { method: 'GET', urlPath: '/api/checklists', token });
        assert.strictEqual(getRes.status, 200);
        const postGet = await Checklist.findById(customChecklist._id).lean();

        assert.strictEqual(postGet.updatedAt.toISOString(), preGet.updatedAt.toISOString(), 'updatedAt must not change on GET');
        assert.strictEqual(postGet.items.length, preGet.items.length, 'Items count must not change on GET');
        console.log('  ✓ GET /checklists is strictly read-only');

        // -------------------------------------------------------------------------
        // 12. Document & Checklist Bin workflows remain intact
        // -------------------------------------------------------------------------
        console.log('\n12. Testing Bin workflows remain intact...');
        // Checklist soft-delete
        const delRes = await makeRequest(server, {
            method: 'DELETE',
            urlPath: `/api/checklists/${customChecklist.type}`,
            token
        });
        assert.strictEqual(delRes.status, 200);

        const binned = await Checklist.findById(customChecklist._id);
        assert.strictEqual(binned.isDeleted, true);

        // Restore
        const restRes = await makeRequest(server, {
            method: 'PATCH',
            urlPath: `/api/checklists/${customChecklist._id}/restore`,
            token
        });
        assert.strictEqual(restRes.status, 200);

        const restored = await Checklist.findById(customChecklist._id);
        assert.strictEqual(restored.isDeleted, false);
        console.log('  ✓ Bin workflow (soft-delete, bin, restore) remains intact');

        // Clean up test data
        await User.deleteMany({ userId: testUserId });
        await Checklist.deleteMany({ userId: testUserId });
        await Document.deleteMany({ userId: testUserId });

        console.log('\n🎉 ALL 12 AUTOMATIC ITEM CLEANUP TESTS PASSED SUCCESSFULLY!\n');
    } catch (err) {
        console.error('Test failed:', err);
        process.exitCode = 1;
    } finally {
        server.close();
        await mongoose.disconnect();
    }
}

runTests();
