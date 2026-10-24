process.env.NODE_ENV = 'test';
if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = 'scan-storage-test-secret-12345';
}

const assert = require('assert');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lawbuddy-scan-storage-'));
process.env.SCAN_FILES_DIR = tempDir;

const scanJobService = require('../src/services/scanJobService');
const cleanupService = require('../src/services/documentCleanupService');
const llmService = require('../src/services/llmService');
const ScanJob = require('../src/models/ScanJob');
const Document = require('../src/models/Document');
const User = require('../src/models/User');
const documentRoutes = require('../src/routes/documentRoutes');
const JWT_SECRET = require('../src/config/jwt');

function makeToken(userId) {
  return jwt.sign({ userId, email: `${userId}@example.com`, tokenVersion: 0 }, JWT_SECRET, { expiresIn: '1h' });
}

function makeRequest(server, options) {
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
      const chunks = [];
      res.on('data', chunk => { chunks.push(chunk); });
      res.on('end', () => {
        const rawBody = Buffer.concat(chunks);
        let parsed = null;
        try {
          parsed = JSON.parse(rawBody.toString('utf8'));
        } catch (_) {
          parsed = rawBody;
        }
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: parsed,
          rawBody
        });
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function run() {
  console.log('=== Starting Scan File Storage & Whole-File Preservation Test Suite ===\n');

  let mongod = null;
  let jobId = null;
  let testUserId = `storage_user_${Date.now()}`;
  let server = null;

  try {
    const payload = Buffer.from('LawBuddy durable storage path test');
    const fileHash = crypto.createHash('sha256').update(payload).digest('hex');
    const storedPath = scanJobService.saveFileToStorage(payload, fileHash);

    assert.strictEqual(path.resolve(cleanupService.UPLOADS_DIR), path.resolve(tempDir));
    assert.strictEqual(path.dirname(storedPath), path.resolve(tempDir));
    assert.deepStrictEqual(scanJobService.readFileFromStorage(storedPath), payload);

    // Legacy relative paths must still resolve to the configured storage directory.
    const legacyPath = path.join('uploads', 'scan_files', `${fileHash}.dat`);
    assert.deepStrictEqual(scanJobService.readFileFromStorage(legacyPath), payload);
    console.log('✓ Test 1: Scan uploads and cleanup share SCAN_FILES_DIR; legacy relative paths remain readable.');

    const uri = process.env.MONGODB_URI;
    if (uri) {
      try {
        await mongoose.connect(uri, { family: 4, serverSelectionTimeoutMS: 2000 });
      } catch (_) {
        const { MongoMemoryServer } = require('mongodb-memory-server');
        mongod = await MongoMemoryServer.create();
        await mongoose.connect(mongod.getUri());
      }
    } else {
      const { MongoMemoryServer } = require('mongodb-memory-server');
      mongod = await MongoMemoryServer.create();
      await mongoose.connect(mongod.getUri());
    }

    // Set up test HTTP server
    const app = express();
    app.use(express.json());
    app.use('/api', documentRoutes);
    server = http.createServer(app);
    await new Promise(r => server.listen(0, r));

    await User.create({
      userId: testUserId,
      full_name: 'Storage Test User',
      email: `${testUserId}@example.com`,
      emailVerified: true,
      tokenVersion: 0
    });

    const authToken = makeToken(testUserId);
    const authHeaders = {
      'Authorization': `Bearer ${authToken}`
    };

    // Test 2: Missing source file failure
    jobId = `missing_source_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`;
    const missingJob = new ScanJob({
      jobId,
      userId: testUserId,
      fileHash: crypto.createHash('sha256').update(jobId).digest('hex'),
      storagePath: path.join(tempDir, 'missing-source.dat'),
      mimeType: 'application/pdf',
      status: 'QUEUED',
      completedSteps: ['UPLOAD', 'TEXT_EXTRACTION'],
      extractedText: 'Property Agreement'
    });
    await missingJob.save();

    await assert.rejects(
      () => scanJobService.executeJobPipeline(jobId),
      /Uploaded source file is missing from storage/
    );
    const failedJob = await ScanJob.findOne({ jobId });
    assert.strictEqual(failedJob.status, 'FAILED');
    assert.match(failedJob.errorInfo.message, /Uploaded source file is missing from storage/);
    console.log('✓ Test 2: Missing source files fail safely instead of producing a placeholder legal report.');

    // Stub llmService.analyzeCanonicalClauses to avoid live Gemini API calls in test
    const originalAnalyze = llmService.analyzeCanonicalClauses;
    llmService.analyzeCanonicalClauses = async (clauses) => {
      return (clauses || []).map((c, idx) => ({
        clauseId: c.clauseId || `CLAUSE-${idx + 1}`,
        title: c.title || 'Legal Due Diligence Clause',
        text: c.text || 'Standard legal provision',
        riskLevel: 'COMPLIANT',
        findingCategory: 'Documentation/title concern',
        reason: 'Clause verified under applicable property laws.',
        statutoryCitations: ['Transfer of Property Act 1882 Section 54']
      }));
    };

    try {
      // =========================================================================
      // ITEM 24 TESTS: Whole-File Preservation and No Base64 Truncation
      // =========================================================================

      // Test 3: Small file (<= 3 MB base64) is preserved whole in MongoDB fileData
      const smallBuffer = crypto.randomBytes(50 * 1024); // 50 KB
      const smallBase64 = smallBuffer.toString('base64');
      const smallRes = await llmService.analyzeContractPipeline({
        userId: testUserId,
        base64Data: smallBase64,
        mimeType: 'text/plain',
        text: 'Title Deed Clause: Seller warrants clear marketable title.',
        customTitle: 'Small Test Contract'
      });

      const smallDocInDb = await Document.findById(smallRes.documentId);
      assert.notStrictEqual(smallDocInDb.fileData, null, 'Small file base64 must be stored in database');
      assert.strictEqual(smallDocInDb.fileData, smallBase64, 'Small file base64 must match full original without truncation');
      const decodedSmall = Buffer.from(smallDocInDb.fileData, 'base64');
      assert.deepStrictEqual(decodedSmall, smallBuffer, 'Decoded base64 must match original buffer exactly');
      console.log('✓ Test 3: Files within size limit (<= 3 MB base64) are stored 100% whole in MongoDB without alteration.');

      // Test 4: Large file (> 3 MB base64) stores whole file on disk and null in DB (NEVER truncated)
      // 2.5 MB binary -> ~3.49 MB base64 (> 3 MB limit)
      const largeBuffer = crypto.randomBytes(2500 * 1024);
      const largeBase64 = largeBuffer.toString('base64');
      assert.ok(largeBase64.length > 3 * 1024 * 1024, 'Base64 length must exceed 3 MB limit for test');

      const largeRes = await llmService.analyzeContractPipeline({
        userId: testUserId,
        base64Data: largeBase64,
        mimeType: 'text/plain',
        text: 'Large Multi-Page Master Lease Agreement with covenants and terms.',
        customTitle: 'Large Test Contract'
      });

      const largeDocInDb = await Document.findById(largeRes.documentId);
      // Critical check for Item 24: fileData must be null, NOT a truncated 3 MB substring!
      assert.strictEqual(largeDocInDb.fileData, null, 'fileData in MongoDB must be null for large files to prevent file corruption');
      assert.notStrictEqual(largeDocInDb.fileData?.length, 3 * 1024 * 1024, 'fileData must NEVER be truncated to a partial 3 MB string');

      // Verify the durable storage file on disk exists and contains the full uncorrupted buffer
      const storedDiskBuffer = scanJobService.readFileFromStorage(path.join(tempDir, `${largeDocInDb.fileHash}.dat`));
      assert.notStrictEqual(storedDiskBuffer, null, 'Durable disk file must exist');
      assert.strictEqual(storedDiskBuffer.length, largeBuffer.length, 'Stored disk file must match exact original length');
      assert.deepStrictEqual(storedDiskBuffer, largeBuffer, 'Stored disk file must be byte-for-byte identical to original');
      console.log('✓ Test 4: Large files (> 3 MB base64) store null in MongoDB and complete original file on disk (never corrupted).');

      // Test 5: GET /api/documents/:id/file serves the complete large file from disk
      const downloadRes = await makeRequest(server, {
        path: `/api/documents/${largeDocInDb._id}/file`,
        method: 'GET',
        headers: authHeaders
      });

      assert.strictEqual(downloadRes.statusCode, 200, 'File retrieval endpoint must return 200');
      assert.strictEqual(downloadRes.headers['content-type'], 'text/plain');
      assert.strictEqual(Number(downloadRes.headers['content-length']), largeBuffer.length);
      assert.deepStrictEqual(downloadRes.rawBody, largeBuffer, 'Served file must be the complete uncorrupted binary');
      console.log('✓ Test 5: GET /api/documents/:id/file cleanly serves complete file from durable disk storage.');

      // Test 6: Safe fail-closed (404) if disk file is missing and fileData is null
      fs.unlinkSync(path.join(tempDir, `${largeDocInDb.fileHash}.dat`));
      const missingDownloadRes = await makeRequest(server, {
        path: `/api/documents/${largeDocInDb._id}/file`,
        method: 'GET',
        headers: authHeaders
      });

      assert.strictEqual(missingDownloadRes.statusCode, 404, 'Must return 404 when file binary is missing');
      assert.strictEqual(missingDownloadRes.body.error, 'Document file binary not found');
      console.log('✓ Test 6: Missing file safely returns HTTP 404 rather than serving corrupt or truncated bytes.');

    } finally {
      llmService.analyzeCanonicalClauses = originalAnalyze;
    }

    console.log('\n🎉 ALL 6 SCAN FILE STORAGE & WHOLE-FILE PRESERVATION TESTS PASSED SUCCESSFULLY!');
  } finally {
    if (server) {
      server.close();
    }
    if (jobId && mongoose.connection.readyState === 1) {
      await ScanJob.deleteMany({ userId: testUserId }).catch(() => {});
      await Document.deleteMany({ userId: testUserId }).catch(() => {});
      await User.deleteMany({ userId: testUserId }).catch(() => {});
    }
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect().catch(() => {});
    }
    if (mongod) {
      await mongod.stop().catch(() => {});
    }
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

run().catch(err => {
  console.error('Scan file storage test failed:', err);
  process.exit(1);
});
