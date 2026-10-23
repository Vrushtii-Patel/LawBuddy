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

// Test Express server helper
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
    console.log('=== Starting Checklist Data-Loss Prevention & Read-Only GET Test Suite ===\n');

    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
    try {
        await mongoose.connect(uri, { serverSelectionTimeoutMS: 4000 });
        console.log('Connected to MongoDB');
    } catch (err) {
        console.warn('MongoDB not reachable for DB-backed tests, skipping:', err.message);
        return;
    }

    const testUserId = `test_dl_user_${Date.now()}`;
    const userEmail = `${testUserId}@example.com`;

    // Spin up test server
    const app = createTestApp();
    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));

    try {
        // Create test user for JWT auth
        await User.create({
            userId: testUserId,
            email: userEmail,
            full_name: 'Data Loss Test User',
            passwordHash: 'dummy_hash',
            tokenVersion: 0
        });
        const token = jwt.sign({ userId: testUserId, email: userEmail, tokenVersion: 0 }, JWT_SECRET, { expiresIn: '1h' });

        // =========================================================================
        // Test 1: Zero active documents does NOT delete auto-generated checklist
        // =========================================================================
        console.log('1. Testing zero active documents preservation in cleanOrphanChecklistIssues()...');

        // Confirm 0 documents exist
        const initialDocCount = await Document.countDocuments({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(initialDocCount, 0, 'Must have zero active documents');

        // Seed an auto-generated due diligence checklist
        const autoChecklist = await Checklist.create({
            userId: testUserId,
            type: `due_diligence_${testUserId}`,
            title: 'Due Diligence: Purchase Agreement',
            items: [
                {
                    id: '1',
                    title: 'Verify Encumbrance Certificate (EC) for 30+ Years',
                    isCompleted: true,
                    status: 'VERIFIED',
                    linkedIssues: [{ documentId: new mongoose.Types.ObjectId().toString(), clauseId: 'CLAUSE-EC-1', reason: 'Historical issue' }]
                },
                {
                    id: '2',
                    title: 'Verify Title Deed & 30-Year Chain of Documents',
                    isCompleted: false,
                    status: 'FLAGGED',
                    linkedIssues: [{ documentId: new mongoose.Types.ObjectId().toString(), clauseId: 'CLAUSE-TITLE-1', reason: 'Historical title flag' }]
                },
                {
                    id: '3',
                    title: 'Verify MahaRERA Project Registration & Sanctioned Plans',
                    isCompleted: false,
                    status: 'NOT_STARTED',
                    linkedIssues: []
                }
            ]
        });

        // Run cleanOrphanChecklistIssues with 0 active documents
        await crossReferenceService.cleanOrphanChecklistIssues(testUserId);

        // Verify checklist was NOT hard-deleted
        const checklistAfterCleanup = await Checklist.findById(autoChecklist._id);
        assert.ok(checklistAfterCleanup, 'Checklist must still exist in MongoDB');
        assert.strictEqual(checklistAfterCleanup.isDeleted, false, 'Checklist must not be soft-deleted');
        assert.strictEqual(checklistAfterCleanup.items.length, 3, 'All 3 items must be preserved');

        // Verify completed/ticked items remain completed
        const item1 = checklistAfterCleanup.items.find(i => i.id === '1');
        assert.strictEqual(item1.isCompleted, true, 'Completed item must remain isCompleted: true');
        assert.strictEqual(item1.status, 'VERIFIED', 'Completed item status must remain VERIFIED');
        assert.strictEqual(item1.linkedIssues.length, 0, 'Orphaned linked issues should be stripped');

        // Verify pending item status reset safely without dropping item
        const item2 = checklistAfterCleanup.items.find(i => i.id === '2');
        assert.strictEqual(item2.isCompleted, false, 'Pending item must remain pending');
        assert.strictEqual(item2.status, 'NOT_STARTED', 'Flagged item with zero documents resets to NOT_STARTED');
        assert.strictEqual(item2.linkedIssues.length, 0, 'Orphaned linked issues should be stripped');

        const item3 = checklistAfterCleanup.items.find(i => i.id === '3');
        assert.strictEqual(item3.isCompleted, false, 'Untouched pending item remains pending');
        assert.strictEqual(item3.status, 'NOT_STARTED', 'Untouched pending item status remains NOT_STARTED');

        console.log('  ✓ Auto-generated checklist preserved with zero active documents');
        console.log('  ✓ Completed/ticked items remain verified');
        console.log('  ✓ Pending items remain present');

        // =========================================================================
        // Test 2: GET /checklists endpoint is strictly read-only
        // =========================================================================
        console.log('\n2. Testing GET /api/checklists is strictly read-only (no deletes, inserts, or updates)...');

        // Snapshot database state before GET
        const preGetChecklist = await Checklist.findById(autoChecklist._id).lean();
        const preGetDocCount = await Document.countDocuments({});
        const preGetChecklistCount = await Checklist.countDocuments({});

        // Execute GET request
        const getRes = await makeRequest(server, {
            method: 'GET',
            urlPath: '/api/checklists',
            token
        });

        assert.strictEqual(getRes.status, 200, 'GET /checklists should return 200');
        assert.ok(Array.isArray(getRes.body), 'Response should be an array');
        assert.strictEqual(getRes.body.length, 1, 'Should return exactly 1 checklist');
        assert.strictEqual(getRes.body[0]._id.toString(), autoChecklist._id.toString());
        assert.strictEqual(getRes.body[0].items.length, 3, 'All 3 items returned');

        // Snapshot database state after GET
        const postGetChecklist = await Checklist.findById(autoChecklist._id).lean();
        const postGetDocCount = await Document.countDocuments({});
        const postGetChecklistCount = await Checklist.countDocuments({});

        // Verify no records inserted or deleted
        assert.strictEqual(postGetDocCount, preGetDocCount, 'No Document records inserted or deleted');
        assert.strictEqual(postGetChecklistCount, preGetChecklistCount, 'No Checklist records inserted or deleted');

        // Verify checklist document was NOT updated
        assert.strictEqual(
            postGetChecklist.updatedAt.toISOString(),
            preGetChecklist.updatedAt.toISOString(),
            'Checklist updatedAt timestamp must not change on GET'
        );
        assert.strictEqual(postGetChecklist.__v, preGetChecklist.__v, 'Checklist version (__v) must not change on GET');
        assert.deepStrictEqual(postGetChecklist.items, preGetChecklist.items, 'Checklist items must be identical');

        console.log('  ✓ GET /api/checklists returned correct data');
        console.log('  ✓ Zero records deleted, inserted, or updated during GET');

        // =========================================================================
        // Test 3: GET /checklists does NOT insert a checklist when user has 0 checklists
        // =========================================================================
        console.log('\n3. Testing GET /api/checklists with analyzed docs but 0 active checklists (no auto-creation on GET)...');

        const testUser2Id = `test_dl_user2_${Date.now()}`;
        const user2Email = `${testUser2Id}@example.com`;
        await User.create({
            userId: testUser2Id,
            email: user2Email,
            full_name: 'User 2',
            passwordHash: 'dummy',
            tokenVersion: 0
        });
        const token2 = jwt.sign({ userId: testUser2Id, email: user2Email, tokenVersion: 0 }, JWT_SECRET, { expiresIn: '1h' });

        // Create completed document for User 2, but NO checklist
        await Document.create({
            userId: testUser2Id,
            fileHash: `hash_u2_${Date.now()}`,
            title: 'Sample Flat Allotment',
            originalText: 'Agreement text',
            analysisStatus: 'completed',
            riskLevel: 'Low Risk',
            analysis: []
        });

        const user2ChecklistsBefore = await Checklist.countDocuments({ userId: testUser2Id });
        assert.strictEqual(user2ChecklistsBefore, 0, 'User 2 has 0 checklists');

        const getRes2 = await makeRequest(server, {
            method: 'GET',
            urlPath: '/api/checklists',
            token: token2
        });

        assert.strictEqual(getRes2.status, 200);
        assert.deepStrictEqual(getRes2.body, [], 'Should return empty array');

        const user2ChecklistsAfter = await Checklist.countDocuments({ userId: testUser2Id });
        assert.strictEqual(user2ChecklistsAfter, 0, 'GET must NOT insert a checklist as a side effect');
        console.log('  ✓ GET does not insert checklists as a side effect');

        // =========================================================================
        // Test 4: Document soft-delete & permanent deletion preserves existing checklists
        // =========================================================================
        console.log('\n4. Testing Document soft-delete & permanent deletion preserve existing checklists...');

        // Create active document for user 1
        const activeDoc = await Document.create({
            userId: testUserId,
            fileHash: `doc_hash_${Date.now()}`,
            title: 'Registered Sale Deed',
            originalText: 'Sale text',
            analysisStatus: 'completed',
            riskLevel: 'High Risk',
            analysis: [
                {
                    clauseId: 'CLAUSE-TITLE-1',
                    title: 'Title Recital',
                    riskLevel: 'HIGH_RISK',
                    findingCategory: 'title concern',
                    reason: 'Missing chain of title',
                    statutoryCitations: ['Transfer of Property Act Section 55']
                }
            ]
        });

        // Sync document to checklist
        await crossReferenceService.syncDocumentIssuesWithChecklists(testUserId, activeDoc);

        // Verify issue was linked
        const syncedChk = await Checklist.findById(autoChecklist._id);
        const titleItem = syncedChk.items.find(i => i.title.toLowerCase().includes('title deed'));
        assert.strictEqual(titleItem.status, 'FLAGGED');
        assert.ok(titleItem.linkedIssues.length > 0);

        // Perform explicit Document Soft Delete via route DELETE /api/documents/:id
        const docDeleteRes = await makeRequest(server, {
            method: 'DELETE',
            urlPath: `/api/documents/${activeDoc._id}`,
            token
        });
        assert.strictEqual(docDeleteRes.status, 200, 'Document soft-delete should succeed');

        // Verify document is in Recycle Bin
        const softDeletedDoc = await Document.findById(activeDoc._id);
        assert.strictEqual(softDeletedDoc.isDeleted, true, 'Document must be marked isDeleted: true');

        // Verify Checklist was NOT deleted
        const chkAfterDocSoftDelete = await Checklist.findById(autoChecklist._id);
        assert.ok(chkAfterDocSoftDelete, 'Checklist must NOT be deleted when document is soft deleted');
        assert.strictEqual(chkAfterDocSoftDelete.isDeleted, false, 'Checklist must not be moved to bin');
        assert.strictEqual(chkAfterDocSoftDelete.items.length, 3, 'All items must remain intact');

        // Completed item remains VERIFIED
        const item1After = chkAfterDocSoftDelete.items.find(i => i.id === '1');
        assert.strictEqual(item1After.isCompleted, true, 'Completed item remains isCompleted: true');
        assert.strictEqual(item1After.status, 'VERIFIED', 'Completed item status remains VERIFIED');

        // Title item reverted to NOT_STARTED since its only doc is now in bin
        const item2After = chkAfterDocSoftDelete.items.find(i => i.id === '2');
        assert.strictEqual(item2After.isCompleted, false);
        assert.strictEqual(item2After.status, 'NOT_STARTED');

        // Now permanently delete the document from Recycle Bin
        await documentCleanupService.permanentlyDeleteDocument(activeDoc._id.toString(), testUserId);

        // Verify checklist is STILL preserved after permanent document deletion
        const chkAfterDocPermDelete = await Checklist.findById(autoChecklist._id);
        assert.ok(chkAfterDocPermDelete, 'Checklist must NOT be deleted when document is permanently deleted');
        assert.strictEqual(chkAfterDocPermDelete.isDeleted, false);
        assert.strictEqual(chkAfterDocPermDelete.items.find(i => i.id === '1').isCompleted, true);

        console.log('  ✓ Document soft-delete to bin preserves checklist and completed items');
        console.log('  ✓ Document permanent deletion preserves checklist and completed items');

        // =========================================================================
        // Test 5: Bin/trash workflow for checklists is preserved
        // =========================================================================
        console.log('\n5. Testing Checklist Bin/trash workflow remains intact...');

        // Soft-delete checklist via DELETE /api/checklists/:type
        const chkDeleteRes = await makeRequest(server, {
            method: 'DELETE',
            urlPath: `/api/checklists/${autoChecklist.type}`,
            token
        });
        assert.strictEqual(chkDeleteRes.status, 200);

        // Verify checklist is in Bin
        const binnedChecklist = await Checklist.findById(autoChecklist._id);
        assert.strictEqual(binnedChecklist.isDeleted, true, 'Checklist is marked isDeleted: true');
        assert.ok(binnedChecklist.deletedAt, 'deletedAt must be set');

        // Active listing does NOT return binned checklist
        const activeRes = await makeRequest(server, { method: 'GET', urlPath: '/api/checklists', token });
        assert.strictEqual(activeRes.body.length, 0, 'Active checklists should not include binned checklist');

        // Bin listing returns binned checklist
        const binRes = await makeRequest(server, { method: 'GET', urlPath: '/api/checklists/bin', token });
        assert.strictEqual(binRes.body.length, 1, 'Recycle bin returns the binned checklist');

        // Restore checklist from Bin
        const restoreRes = await makeRequest(server, {
            method: 'PATCH',
            urlPath: `/api/checklists/${autoChecklist._id}/restore`,
            token
        });
        assert.strictEqual(restoreRes.status, 200);

        const restoredChecklist = await Checklist.findById(autoChecklist._id);
        assert.strictEqual(restoredChecklist.isDeleted, false, 'Restored checklist isDeleted must be false');
        assert.strictEqual(restoredChecklist.deletedAt, null, 'Restored checklist deletedAt must be null');

        // Completed item remains verified after restoration
        assert.strictEqual(restoredChecklist.items.find(i => i.id === '1').isCompleted, true);
        assert.strictEqual(restoredChecklist.items.find(i => i.id === '1').status, 'VERIFIED');

        // Soft-delete again, then permanently delete
        await makeRequest(server, { method: 'DELETE', urlPath: `/api/checklists/${autoChecklist.type}`, token });
        const permDeleteRes = await makeRequest(server, {
            method: 'DELETE',
            urlPath: `/api/checklists/${autoChecklist._id}/permanent`,
            token
        });
        assert.strictEqual(permDeleteRes.status, 200);

        const afterPermDelete = await Checklist.findById(autoChecklist._id);
        assert.strictEqual(afterPermDelete, null, 'Checklist must be permanently deleted from database');

        console.log('  ✓ Checklist soft-delete, bin listing, restore, and permanent deletion workflow intact');

        // Clean up test data
        await User.deleteMany({ userId: { $in: [testUserId, testUser2Id] } });
        await Checklist.deleteMany({ userId: { $in: [testUserId, testUser2Id] } });
        await Document.deleteMany({ userId: { $in: [testUserId, testUser2Id] } });

        console.log('\n🎉 ALL 5 DATA-LOSS PREVENTION TESTS PASSED SUCCESSFULLY!\n');
    } catch (err) {
        console.error('Test suite failed:', err);
        process.exitCode = 1;
    } finally {
        server.close();
        await mongoose.disconnect();
    }
}

runTests();
