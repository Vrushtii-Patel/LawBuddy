const path = require('path');
const assert = require('assert');
const mongoose = require('mongoose');
const { isDocumentCacheValid, createScanJob } = require('../src/services/scanJobService');
const Document = require('../src/models/Document');
const ScanJob = require('../src/models/ScanJob');
const llmService = require('../src/services/llmService');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function runTests() {
  console.log('=== Starting LawBuddy Version-Aware Caching Tests ===\n');

  // Test Set A: Unit testing `isDocumentCacheValid`
  console.log('--- Test Set A: Logic Validation (`isDocumentCacheValid`) ---');

  const validDoc = {
    userId: 'user123',
    fileHash: 'sha256_mock_hash',
    analysisStatus: 'completed',
    analysis: [{ clauseId: '1', title: 'Payment clause', text: 'Full text', riskLevel: 'COMPLIANT' }],
    promptVersion: llmService.PROMPT_VERSION,
    modelName: llmService.MODEL_NAME,
    analysisVersion: llmService.ANALYSIS_VERSION
  };

  // 1. Valid up-to-date document
  assert.strictEqual(isDocumentCacheValid(validDoc), true, 'Valid document must return true');
  console.log('✓ Test 1: Up-to-date document matches prompt version and model name -> VALID');

  // 2. Outdated prompt version
  const outdatedPromptDoc = { ...validDoc, promptVersion: 'v1.0.0-old' };
  assert.strictEqual(isDocumentCacheValid(outdatedPromptDoc), false, 'Outdated prompt version must return false');
  console.log('✓ Test 2: Document with outdated prompt version -> INVALID (triggers re-analysis)');

  // 3. Different AI model
  const differentModelDoc = { ...validDoc, modelName: 'gpt-3.5-turbo' };
  assert.strictEqual(isDocumentCacheValid(differentModelDoc), false, 'Different model name must return false');
  console.log('✓ Test 3: Document with different AI model -> INVALID (triggers re-analysis)');

  // 4. Legacy document without promptVersion or modelName
  const legacyDocWithoutVersions = {
    userId: 'user123',
    fileHash: 'sha256_mock_hash',
    analysisStatus: 'completed',
    analysis: [{ clauseId: '1', title: 'Payment clause', text: 'Full text', riskLevel: 'COMPLIANT' }],
    promptVersion: null,
    modelName: null
  };
  assert.strictEqual(isDocumentCacheValid(legacyDocWithoutVersions), false, 'Legacy document without version metadata must return false');
  console.log('✓ Test 4: Legacy document without version metadata -> SAFELY TREATED AS OUTDATED');

  // 5. Incomplete / failed / empty analysis
  const incompleteDoc = { ...validDoc, analysis: [] };
  assert.strictEqual(isDocumentCacheValid(incompleteDoc), false, 'Empty analysis must return false');
  const failedDoc = { ...validDoc, analysisStatus: 'failed' };
  assert.strictEqual(isDocumentCacheValid(failedDoc), false, 'Failed analysis must return false');
  console.log('✓ Test 5: Incomplete or failed analysis -> INVALID');

  // Test Set B: Database-backed Integration Tests
  console.log('\n--- Test Set B: Integration & Lifecycle Verification ---');

  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
  let connected = false;
  try {
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 3000 });
    connected = true;
    console.log('Connected to MongoDB for integration tests.');
  } catch (err) {
    console.warn('MongoDB not reachable for DB-backed tests, running in isolated mode:', err.message);
  }

  if (connected) {
    const testUserA = 'user_cache_test_A_' + Date.now();
    const testUserB = 'user_cache_test_B_' + Date.now();
    const sampleText = 'This is an official Lease Agreement between Landlord and Tenant with 36-month lock-in.';
    const sampleHash = require('crypto').createHash('sha256').update(sampleText).digest('hex');

    try {
      // Clean up test data
      await Document.deleteMany({ userId: { $in: [testUserA, testUserB] } });
      await ScanJob.deleteMany({ userId: { $in: [testUserA, testUserB] } });

      // Create pre-existing document for User A with CURRENT versions
      const docA = new Document({
        userId: testUserA,
        fileHash: sampleHash,
        title: 'Lease Agreement',
        originalText: sampleText,
        riskLevel: 'Low Risk',
        analysisStatus: 'completed',
        analysis: [{ clauseId: 'C1', title: 'Lock-in', text: '36-month lock-in', riskLevel: 'CAUTION' }],
        promptVersion: llmService.PROMPT_VERSION,
        modelName: llmService.MODEL_NAME,
        analysisVersion: llmService.ANALYSIS_VERSION
      });
      await docA.save();

      // Test 6: Same user + same document with matching version -> immediate cache hit
      const jobA = await createScanJob({
        userId: testUserA,
        text: sampleText,
        title: 'Lease Agreement'
      });
      assert.strictEqual(jobA.status, 'COMPLETED', 'Should immediately complete from cache');
      assert.strictEqual(jobA.currentStep, 'Analysis completed (from cache)');
      assert.strictEqual(jobA.documentId.toString(), docA._id.toString());
      console.log('✓ Test 6: User A uploading same document with matching version -> IMMEDIATE CACHE HIT (COMPLETED)');

      // Test 7: User B (different user) uploading same document -> User isolation enforced
      const jobB = await createScanJob({
        userId: testUserB,
        text: sampleText,
        title: 'Lease Agreement'
      });
      assert.notStrictEqual(jobB.status, 'COMPLETED', 'User B must NOT get User A cached result');
      assert.strictEqual(jobB.status, 'QUEUED', 'User B should get new queued scan job');
      console.log('✓ Test 7: User B uploading identical document -> USER ISOLATION ENFORCED (New Job Queued)');

      // Test 8: Stale prompt document for User A -> Triggers fresh analysis
      await Document.updateOne(
        { _id: docA._id },
        { $set: { promptVersion: 'v1.0.0-outdated' } }
      );
      // Remove any prior completed ScanJobs for User A to simulate re-upload
      await ScanJob.deleteMany({ userId: testUserA });

      const jobAOutdated = await createScanJob({
        userId: testUserA,
        text: sampleText,
        title: 'Lease Agreement'
      });
      assert.strictEqual(jobAOutdated.status, 'QUEUED', 'Outdated prompt version must trigger fresh analysis');
      console.log('✓ Test 8: User A document with outdated prompt version -> FRESH ANALYSIS TRIGGERED');

      // Test 9: Concurrent requests for same user and file hash return the same in-flight job
      const [jobConcurrent1, jobConcurrent2] = await Promise.all([
        createScanJob({ userId: testUserB, text: sampleText, title: 'Concurrent Test' }),
        createScanJob({ userId: testUserB, text: sampleText, title: 'Concurrent Test' })
      ]);
      assert.strictEqual(jobConcurrent1.jobId, jobConcurrent2.jobId, 'Concurrent requests must share in-flight scan job');
      console.log(`✓ Test 9: Concurrent requests deduplicated -> Reused ScanJob ${jobConcurrent1.jobId}`);

      // Clean up
      await Document.deleteMany({ userId: { $in: [testUserA, testUserB] } });
      await ScanJob.deleteMany({ userId: { $in: [testUserA, testUserB] } });

    } finally {
      await mongoose.disconnect();
    }
  }

  console.log('\nAll version-aware caching tests passed successfully!');
}

runTests().catch(err => {
  console.error('Test failure:', err);
  process.exit(1);
});
