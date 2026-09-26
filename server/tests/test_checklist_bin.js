const assert = require('assert');
const path = require('path');
const mongoose = require('mongoose');
const Checklist = require('../src/models/Checklist');
const documentCleanupService = require('../src/services/documentCleanupService');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const testUserId = `test_chk_bin_user_${Date.now()}`;

async function runChecklistBinTests() {
    console.log('=== Starting LawBuddy Checklist Bin & Soft-Delete Test Suite ===\n');

    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
    if (mongoose.connection.readyState !== 1) {
        await mongoose.connect(uri);
    }

    try {
        // Clean up any test state
        await Checklist.deleteMany({ userId: testUserId });

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

        // Clean up remaining test records
        await documentCleanupService.permanentlyDeleteChecklist(recentChk._id.toString(), testUserId);

        console.log('\n🎉 ALL 6 CHECKLIST BIN & AUTO-PURGE TESTS PASSED SUCCESSFULLY!');
    } finally {
        await Checklist.deleteMany({ userId: testUserId });
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
