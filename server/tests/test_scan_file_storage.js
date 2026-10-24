const assert = require('assert');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const mongoose = require('mongoose');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lawbuddy-scan-storage-'));
process.env.SCAN_FILES_DIR = tempDir;

const scanJobService = require('../src/services/scanJobService');
const cleanupService = require('../src/services/documentCleanupService');
const ScanJob = require('../src/models/ScanJob');

async function run() {
  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/lawbuddy_test';
  let mongod = null;
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
    console.log('✓ Scan uploads and cleanup share SCAN_FILES_DIR; legacy relative paths remain readable.');

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

    jobId = `missing_source_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`;
    const missingJob = new ScanJob({
      jobId,
      userId: `storage_test_${Date.now()}`,
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
    console.log('✓ Missing source files fail safely instead of producing a placeholder legal report.');
  } finally {
    if (jobId && mongoose.connection.readyState === 1) {
      await ScanJob.deleteOne({ jobId }).catch(() => {});
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
