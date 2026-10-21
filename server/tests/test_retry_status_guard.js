/**
 * Test Suite: Scan & Comparison Retry Status Guards & Race-Condition Protection
 * Verifies that:
 * 1. Only FAILED jobs can be retried.
 * 2. Rapid double-clicks on retry atomically increment manualRetriesCount exactly once.
 * 3. Already running / retrying jobs cleanly return current state without duplicate execution.
 * 4. Completed jobs return completed status.
 * 5. Non-failed jobs reject retry attempts with 400.
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
if (!process.env.JWT_SECRET) {
    process.env.JWT_SECRET = 'test_jwt_secret_for_retry_guard_tests_only';
}

const assert = require('assert');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const JWT_SECRET = require('../src/config/jwt');
const ScanJob = require('../src/models/ScanJob');
const DocumentComparison = require('../src/models/DocumentComparison');
const documentRoutes = require('../src/routes/documentRoutes');
const comparisonRoutes = require('../src/routes/comparisonRoutes');
const scanJobService = require('../src/services/scanJobService');
const comparisonService = require('../src/services/comparisonService');

const testUserId = `test_retry_user_${Date.now()}`;
const testToken = jwt.sign({ userId: testUserId, email: 'retry_test@example.com' }, JWT_SECRET, { expiresIn: '1h' });

function makeRequest(server, { method, path, headers = {}, body = null }) {
    return new Promise((resolve, reject) => {
        const payload = body ? JSON.stringify(body) : null;
        const reqHeaders = {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${testToken}`,
            ...headers
        };
        if (payload) {
            reqHeaders['Content-Length'] = Buffer.byteLength(payload);
        }

        const addr = server.address();
        const req = http.request({
            hostname: '127.0.0.1',
            port: addr.port,
            path,
            method,
            headers: reqHeaders
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                let parsed = null;
                try {
                    parsed = JSON.parse(data);
                } catch (_) {
                    parsed = data;
                }
                resolve({ status: res.statusCode, body: parsed, headers: res.headers });
            });
        });

        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
    });
}

async function runTests() {
    console.log('=== Starting LawBuddy Scan & Comparison Retry Status Guard Test Suite ===\n');

    const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/lawbuddy';
    if (mongoose.connection.readyState !== 1) {
        try {
            await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
        } catch (dbErr) {
            const { MongoMemoryServer } = require('mongodb-memory-server');
            const mongod = await MongoMemoryServer.create();
            await mongoose.connect(mongod.getUri());
        }
    }

    // Set up test express server
    const app = express();
    app.use(express.json());
    app.use('/api', documentRoutes);
    app.use('/api', comparisonRoutes);

    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));

    // Track mock pipeline calls
    let executedPipelines = [];
    const origExecuteScan = scanJobService.executeJobPipeline;
    scanJobService.executeJobPipeline = async (jobId) => {
        executedPipelines.push(jobId);
        return { jobId, status: 'RETRYING' };
    };

    let executedComparisons = [];
    const origExecuteComp = comparisonService.executeComparisonPipeline;
    comparisonService.executeComparisonPipeline = async (comparisonId) => {
        executedComparisons.push(comparisonId);
        return { comparisonId, status: 'RETRYING' };
    };

    const User = require('../src/models/User');

    try {
        await User.deleteMany({ userId: testUserId });
        await ScanJob.deleteMany({ userId: testUserId });
        await DocumentComparison.deleteMany({ userId: testUserId });

        await User.create({
            userId: testUserId,
            email: 'retry_test@example.com',
            full_name: 'Retry Test User',
            passwordHash: 'dummy_hash',
            isEmailVerified: true,
            tokenVersion: 0
        });

        // ---------------------------------------------------------------------
        // TEST 1: Retrying a COMPLETED job returns message without re-executing
        // ---------------------------------------------------------------------
        const completedJob = await ScanJob.create({
            jobId: `job_completed_${Date.now()}`,
            userId: testUserId,
            fileHash: `hash_completed_${Date.now()}`,
            status: 'COMPLETED',
            currentStep: 'Analysis completed',
            manualRetriesCount: 0
        });

        const completedRes = await makeRequest(server, {
            method: 'POST',
            path: `/api/scans/${completedJob.jobId}/retry`
        });

        assert.strictEqual(completedRes.status, 200);
        assert.strictEqual(completedRes.body.status, 'COMPLETED');
        assert.strictEqual(completedRes.body.message, 'Job is already completed');
        assert.strictEqual(executedPipelines.length, 0, 'Completed job must not trigger pipeline');
        console.log('✓ Test 1 Passed: Retrying COMPLETED job safely returns without re-executing.');

        // ---------------------------------------------------------------------
        // TEST 2: Retrying a non-FAILED job returns 400
        // ---------------------------------------------------------------------
        const customJobId = `job_custom_${Date.now()}`;
        await ScanJob.collection.insertOne({
            jobId: customJobId,
            userId: testUserId,
            fileHash: `hash_custom_${Date.now()}`,
            status: 'CANCELLED',
            currentStep: 'Cancelled by admin',
            manualRetriesCount: 0,
            completedSteps: []
        });

        const nonFailedRes = await makeRequest(server, {
            method: 'POST',
            path: `/api/scans/${customJobId}/retry`
        });

        assert.strictEqual(nonFailedRes.status, 400);
        assert.ok(nonFailedRes.body.error.includes('Only failed scan jobs can be retried'));
        console.log('✓ Test 2 Passed: Retrying non-FAILED job is rejected with 400.');

        // ---------------------------------------------------------------------
        // TEST 3: Retrying an already RUNNING job returns running status
        // ---------------------------------------------------------------------
        const runningJob = await ScanJob.create({
            jobId: `job_running_${Date.now()}`,
            userId: testUserId,
            fileHash: `hash_running_${Date.now()}`,
            status: 'OCR_PROCESSING',
            currentStep: 'Extracting text...',
            manualRetriesCount: 0
        });

        const runningRes = await makeRequest(server, {
            method: 'POST',
            path: `/api/scans/${runningJob.jobId}/retry`
        });

        assert.strictEqual(runningRes.status, 200);
        assert.strictEqual(runningRes.body.message, 'Scan job is already running');
        assert.strictEqual(runningRes.body.status, 'OCR_PROCESSING');
        assert.strictEqual(executedPipelines.length, 0, 'Running job must not trigger duplicate pipeline');
        console.log('✓ Test 3 Passed: Retrying in-progress job is ignored without duplicate execution.');

        // ---------------------------------------------------------------------
        // TEST 4: Double-click retry on FAILED job executes pipeline exactly once
        // ---------------------------------------------------------------------
        const failedJob = await ScanJob.create({
            jobId: `job_failed_${Date.now()}`,
            userId: testUserId,
            fileHash: `hash_failed_${Date.now()}`,
            status: 'FAILED',
            currentStep: 'Failed at OCR',
            manualRetriesCount: 0
        });

        // Simulate simultaneous double-click
        const [click1, click2] = await Promise.all([
            makeRequest(server, {
                method: 'POST',
                path: `/api/scans/${failedJob.jobId}/retry`
            }),
            makeRequest(server, {
                method: 'POST',
                path: `/api/scans/${failedJob.jobId}/retry`
            })
        ]);

        assert.strictEqual(click1.status, 200);
        assert.strictEqual(click2.status, 200);

        // One of them is the primary winner, the other is recognized as already running
        const winner = click1.body.message === 'Scan job is already running' ? click2 : click1;
        const loser = click1.body.message === 'Scan job is already running' ? click1 : click2;

        assert.strictEqual(winner.body.status, 'RETRYING');
        assert.strictEqual(loser.body.message, 'Scan job is already running');

        // Check database state: manualRetriesCount must be exactly 1
        const freshJob = await ScanJob.findOne({ jobId: failedJob.jobId });
        assert.strictEqual(freshJob.manualRetriesCount, 1, 'manualRetriesCount must be incremented exactly once');
        assert.strictEqual(executedPipelines.length, 1, 'executeJobPipeline must be invoked exactly once');
        console.log('✓ Test 4 Passed: Simultaneous double-click retry cleanly deduplicated with atomic status claim.');

        // ---------------------------------------------------------------------
        // TEST 5: Comparison retry double-click guard
        // ---------------------------------------------------------------------
        const failedComp = await DocumentComparison.create({
            comparisonId: `comp_failed_${Date.now()}`,
            userId: testUserId,
            titleA: 'Version 1',
            fileHashA: 'hashA123',
            titleB: 'Version 2',
            fileHashB: 'hashB123',
            comparisonHash: `comp_hash_${Date.now()}`,
            status: 'FAILED',
            currentStep: 'Failed during diffing',
            manualRetriesCount: 0
        });

        const [compClick1, compClick2] = await Promise.all([
            makeRequest(server, {
                method: 'POST',
                path: `/api/comparisons/${failedComp.comparisonId}/retry`
            }),
            makeRequest(server, {
                method: 'POST',
                path: `/api/comparisons/${failedComp.comparisonId}/retry`
            })
        ]);

        assert.strictEqual(compClick1.status, 200);
        assert.strictEqual(compClick2.status, 200);

        const compWinner = compClick1.body.message === 'Comparison is already running' ? compClick2 : compClick1;
        const compLoser = compClick1.body.message === 'Comparison is already running' ? compClick1 : compClick2;

        assert.strictEqual(compWinner.body.status, 'RETRYING');
        assert.strictEqual(compLoser.body.message, 'Comparison is already running');

        const freshComp = await DocumentComparison.findOne({ comparisonId: failedComp.comparisonId });
        assert.strictEqual(freshComp.manualRetriesCount, 1, 'Comparison manualRetriesCount must be incremented exactly once');
        assert.strictEqual(executedComparisons.length, 1, 'Comparison executeComparisonPipeline must be invoked exactly once');
        console.log('✓ Test 5 Passed: Comparison retry double-click cleanly deduplicated.');

        console.log('\n🎉 ALL SCAN & COMPARISON RETRY STATUS GUARD TESTS PASSED SUCCESSFULLY!\n');
    } finally {
        scanJobService.executeJobPipeline = origExecuteScan;
        comparisonService.executeComparisonPipeline = origExecuteComp;
        await User.deleteMany({ userId: testUserId });
        await ScanJob.deleteMany({ userId: testUserId });
        await DocumentComparison.deleteMany({ userId: testUserId });
        await new Promise(resolve => server.close(resolve));
        await mongoose.disconnect();
    }
}

if (require.main === module) {
    runTests()
        .then(() => process.exit(0))
        .catch(err => {
            console.error('Test suite failed:', err);
            process.exit(1);
        });
}

module.exports = runTests;
