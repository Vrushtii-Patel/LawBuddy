process.env.NODE_ENV = 'test';
if (!process.env.JWT_SECRET) {
    process.env.JWT_SECRET = 'checklist-bin-test-secret-key-12345';
}

const assert = require('assert');
const path = require('path');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const Checklist = require('../src/models/Checklist');
const Document = require('../src/models/Document');
const User = require('../src/models/User');
const documentCleanupService = require('../src/services/documentCleanupService');
const crossReferenceService = require('../src/services/crossReferenceService');
const checklistRoutes = require('../src/routes/checklistRoutes');
const JWT_SECRET = require('../src/config/jwt');

const testUserId = `test_chk_bin_user_${Date.now()}`;

function makeToken(userId) {
    return jwt.sign({ userId, email: `${userId}@example.com`, tokenVersion: 0 }, JWT_SECRET, { expiresIn: '1h' });
}

function makeRequest(server, options, body = null) {
    return new Promise((resolve, reject) => {
        const addr = server.address();
        const reqOptions = {
            hostname: '127.0.0.1',
            port: addr.port,
            path: options.path,
            method: options.method || 'GET',
            headers: options.headers || {}
        };

        const req = http.request(reqOptions, (res) => {
            let data = '';
            res.on('data', chunk => { data += chunk; });
            res.on('end', () => {
                let parsed = null;
                try {
                    parsed = JSON.parse(data);
                } catch (_) {
                    parsed = data;
                }
                resolve({
                    statusCode: res.statusCode,
                    headers: res.headers,
                    body: parsed
                });
            });
        });

        req.on('error', reject);
        if (body) {
            req.write(typeof body === 'string' ? body : JSON.stringify(body));
        }
        req.end();
    });
}

async function runChecklistBinTests() {
    console.log('=== Starting LawBuddy Checklist Bin & Soft-Delete Test Suite ===\n');

    let mongod = null;
    const uri = process.env.MONGODB_URI;
    if (mongoose.connection.readyState !== 1) {
        try {
            if (uri) {
                await mongoose.connect(uri, { serverSelectionTimeoutMS: 2000 });
            } else {
                throw new Error('No MONGODB_URI set');
            }
        } catch (dbErr) {
            const { MongoMemoryServer } = require('mongodb-memory-server');
            mongod = await MongoMemoryServer.create();
            await mongoose.connect(mongod.getUri());
        }
    }

    // Set up test HTTP server for route testing
    const app = express();
    app.use(express.json());
    app.use('/api', checklistRoutes);
    const server = http.createServer(app);
    await new Promise(r => server.listen(0, r));

    try {
        // Clean up any test state
        await Checklist.deleteMany({ userId: testUserId });
        await Document.deleteMany({ userId: testUserId });
        await User.deleteMany({ userId: testUserId });

        await User.create({
            userId: testUserId,
            full_name: 'Test Checklist User',
            email: `${testUserId}@example.com`,
            emailVerified: true,
            tokenVersion: 0
        });

        const authToken = makeToken(testUserId);
        const authHeaders = {
            'Authorization': `Bearer ${authToken}`,
            'Content-Type': 'application/json'
        };

        // Create sample checklist
        const chk = await Checklist.create({
            userId: testUserId,
            type: 'buying-resale-test',
            title: 'Resale Property Verification Checklist',
            items: [
                { id: '1', title: 'Verify Title Deeds', isCompleted: false, status: 'NOT_STARTED' },
                { id: '2', title: 'Check Encumbrance Certificate', isCompleted: false, status: 'NOT_STARTED' }
            ]
        });

        console.log('✓ Initial setup: Checklist created.');

        // Test 1: Active listing query filters out isDeleted: true
        const initialActive = await Checklist.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(initialActive.length, 1, 'Initial active query must return 1 checklist');
        console.log('✓ Test 1: Active query initially returns the checklist.');

        // Test 2: Soft-delete sets isDeleted: true and deletedAt
        chk.isDeleted = true;
        chk.deletedAt = new Date();
        await chk.save();

        const activeAfterSoftDelete = await Checklist.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(activeAfterSoftDelete.length, 0, 'Active query must return 0 checklists after soft delete');

        const binnedChecklists = await Checklist.find({ userId: testUserId, isDeleted: true });
        assert.strictEqual(binnedChecklists.length, 1, 'Bin query must return the soft-deleted checklist');
        console.log('✓ Test 2: Soft-delete moves checklist to bin.');

        // Test 3: Restore checklist resets isDeleted and deletedAt
        chk.isDeleted = false;
        chk.deletedAt = null;
        await chk.save();

        const activeAfterRestore = await Checklist.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(activeAfterRestore.length, 1, 'Active query must return 1 checklist after restoration');
        const binnedAfterRestore = await Checklist.find({ userId: testUserId, isDeleted: true });
        assert.strictEqual(binnedAfterRestore.length, 0, 'Bin query must return 0 checklists after restoration');
        console.log('✓ Test 3: Checklist restore successfully reactivates checklist into active collection.');

        // Test 4: Reject permanent delete on active (non-binned) checklist
        let rejected = false;
        try {
            await documentCleanupService.permanentlyDeleteChecklist(chk._id.toString(), testUserId);
        } catch (err) {
            rejected = true;
            assert.ok(err.message.includes('must be in the bin'), 'Should reject permanent deletion of non-binned checklist');
        }
        assert.strictEqual(rejected, true, 'Permanent delete must be rejected on active checklist');
        console.log('✓ Test 4: Permanent deletion correctly rejected for non-binned active checklist.');

        // Test 5: Permanent delete on soft-deleted checklist cleanly removes row
        chk.isDeleted = true;
        chk.deletedAt = new Date();
        await chk.save();

        await documentCleanupService.permanentlyDeleteChecklist(chk._id.toString(), testUserId);

        const chkAfterPermDelete = await Checklist.findById(chk._id);
        assert.strictEqual(chkAfterPermDelete, null, 'Checklist row must be removed from MongoDB');
        console.log('✓ Test 5: Permanent deletion cleanly deletes Checklist row from MongoDB.');

        // Test 6: Auto-purge checklists older than 30 days
        const thirtyOneDaysAgo = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
        const expiredChk = await Checklist.create({
            userId: testUserId,
            type: 'expired-checklist-test',
            title: 'Expired Old Checklist',
            items: [{ id: '1', title: 'Old Task', isCompleted: false }],
            isDeleted: true,
            deletedAt: thirtyOneDaysAgo
        });

        const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000);
        const recentChk = await Checklist.create({
            userId: testUserId,
            type: 'recent-checklist-test',
            title: 'Recent Binned Checklist',
            items: [{ id: '1', title: 'Recent Task', isCompleted: false }],
            isDeleted: true,
            deletedAt: twoDaysAgo
        });

        const purgedCount = await documentCleanupService.purgeExpiredBinnedChecklists(testUserId, 30);
        assert.strictEqual(purgedCount, 1, 'Auto-purge must only purge checklists older than 30 days');

        const remainingBinned = await Checklist.find({ userId: testUserId, isDeleted: true });
        assert.strictEqual(remainingBinned.length, 1, 'Recent binned checklist must remain in bin');
        assert.strictEqual(remainingBinned[0]._id.toString(), recentChk._id.toString());
        console.log('✓ Test 6: 30-day auto-purge cleanly purges expired checklists while preserving recent binned items.');

        await documentCleanupService.permanentlyDeleteChecklist(recentChk._id.toString(), testUserId);

        // =========================================================================
        // ITEM 19 TESTS: Auto-Creation Prevention & Restore Collision Resolution
        // =========================================================================

        // Test 7: When user soft-deletes their default checklist, auto-sync does NOT resurrect a duplicate
        const defaultType = 'due_diligence_' + testUserId;
        const defaultChk = await Checklist.create({
            userId: testUserId,
            type: defaultType,
            title: 'Due Diligence: Original Default Checklist',
            items: [{ id: '1', title: 'Check Deeds', isCompleted: true, status: 'VERIFIED' }],
            isDeleted: true,
            deletedAt: new Date()
        });

        // Add a mock completed document for this user to trigger potential sync
        const mockDoc = await Document.create({
            userId: testUserId,
            fileHash: 'doc_hash_' + Date.now(),
            title: 'Test Sale Deed',
            originalText: 'Standard sale deed content',
            analysisStatus: 'completed',
            riskLevel: 'Low Risk',
            analysis: []
        });

        // Call syncAllUserDocuments - should NOT create another checklist because default is in bin
        await crossReferenceService.syncAllUserDocuments(testUserId);

        const activeAfterSync = await Checklist.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(activeAfterSync.length, 0, 'Must NOT auto-create a new default checklist while one exists in the Recycle Bin');

        // Also test GET /api/checklists does not resurrect it
        const getRes = await makeRequest(server, {
            path: '/api/checklists',
            method: 'GET',
            headers: authHeaders
        });
        assert.strictEqual(getRes.statusCode, 200);
        assert.strictEqual(getRes.body.length, 0, 'GET /checklists must return 0 active checklists and not auto-recreate');
        console.log('✓ Test 7: Auto-sync does NOT resurrect a duplicate default checklist while one is in the Recycle Bin');

        // Test 8: Clean restore of the binned checklist via API route
        const restoreRes = await makeRequest(server, {
            path: `/api/checklists/${defaultChk._id}/restore`,
            method: 'PATCH',
            headers: authHeaders
        });
        assert.strictEqual(restoreRes.statusCode, 200, 'Restoring binned checklist should succeed with 200');
        assert.strictEqual(restoreRes.body.checklist.isDeleted, false);
        assert.strictEqual(restoreRes.body.checklist.type, defaultType);

        const activeAfterApiRestore = await Checklist.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(activeAfterApiRestore.length, 1, 'Restored checklist must now be active');
        console.log('✓ Test 8: Binned checklist successfully restored via PATCH /api/checklists/:id/restore');

        // Test 9: Restore collision when an active checklist of the same type exists returns 409 Conflict
        // 1. Soft-delete the restored checklist
        await Checklist.findByIdAndUpdate(defaultChk._id, {
            $set: { isDeleted: true, deletedAt: new Date() }
        });

        // 2. Create a replacement active checklist of the exact same type
        const replacementActive = await Checklist.create({
            userId: testUserId,
            type: defaultType,
            title: 'Due Diligence: Newly Created Active Replacement',
            items: [{ id: '1', title: 'New Task', isCompleted: false }],
            isDeleted: false
        });

        // 3. Attempt to restore the binned checklist without replace
        const collisionRes = await makeRequest(server, {
            path: `/api/checklists/${defaultChk._id}/restore`,
            method: 'PATCH',
            headers: authHeaders
        });

        assert.strictEqual(collisionRes.statusCode, 409, 'Must return HTTP 409 Conflict when active checklist of same type exists');
        assert.strictEqual(collisionRes.body.code, 'CHECKLIST_TYPE_CONFLICT');
        assert.ok(collisionRes.body.error.includes('already exists'), 'Error message must explain the type collision');
        assert.strictEqual(collisionRes.body.activeChecklistId, replacementActive._id.toString());
        console.log('✓ Test 9: Restoring into an existing active type safely returns HTTP 409 Conflict instead of 500 error');

        // Test 10: Restore with ?replace=true safely moves the active conflicting checklist to bin and activates restored one
        const replaceRes = await makeRequest(server, {
            path: `/api/checklists/${defaultChk._id}/restore?replace=true`,
            method: 'PATCH',
            headers: authHeaders
        });

        assert.strictEqual(replaceRes.statusCode, 200, 'Restore with ?replace=true must succeed with 200');
        assert.strictEqual(replaceRes.body.checklist.isDeleted, false);

        // Verify that the replacement was moved to bin
        const demotedReplacement = await Checklist.findById(replacementActive._id);
        assert.strictEqual(demotedReplacement.isDeleted, true, 'Conflicting active checklist must be moved to bin');

        // Verify that only the chosen restored checklist is now active
        const activeChecklistsFinal = await Checklist.find({ userId: testUserId, isDeleted: { $ne: true } });
        assert.strictEqual(activeChecklistsFinal.length, 1);
        assert.strictEqual(activeChecklistsFinal[0]._id.toString(), defaultChk._id.toString());
        console.log('✓ Test 10: Restore with ?replace=true safely swaps conflicting checklist to bin and reactivates target checklist');

        console.log('\n🎉 ALL 10 CHECKLIST BIN, AUTO-PURGE & RESTORE COLLISION TESTS PASSED SUCCESSFULLY!');
    } finally {
        server.close();
        await Checklist.deleteMany({ userId: testUserId });
        await Document.deleteMany({ userId: testUserId });
        await User.deleteMany({ userId: testUserId });
        if (mongod) await mongod.stop();
    }
}

if (require.main === module) {
    runChecklistBinTests()
        .then(() => process.exit(0))
        .catch(err => {
            console.error('Test failure:', err);
            process.exit(1);
        });
}

module.exports = { runChecklistBinTests };
