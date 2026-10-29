const assert = require('assert');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

process.env.NODE_ENV = 'test';
process.env.ENABLE_RATE_LIMIT_IN_TEST = 'true';
process.env.SCAN_RATE_LIMIT_MAX = '3';
process.env.SCAN_RETRY_RATE_LIMIT_MAX = '2';

if (!process.env.JWT_SECRET) {
    process.env.JWT_SECRET = 'scan-rate-limit-test-secret-key-12345';
}

const JWT_SECRET = require('../src/config/jwt');
const User = require('../src/models/User');
const ScanJob = require('../src/models/ScanJob');
const documentRoutes = require('../src/routes/documentRoutes');

function makeToken(userId) {
    return jwt.sign({ userId, email: `${userId}@example.com` }, JWT_SECRET, { expiresIn: '1h' });
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

const scanJobService = require('../src/services/scanJobService');

async function runTests() {
    console.log('=== Starting Scan Rate Limiter Test Suite ===\n');

    let mongod = null;
    let server = null;
    const origExecute = scanJobService.executeJobPipeline;
    scanJobService.executeJobPipeline = async (jobId) => {
        return { jobId, status: 'PROCESSING' };
    };

    try {
        mongod = await MongoMemoryServer.create();
        await mongoose.connect(mongod.getUri());

        const app = express();
        app.use(express.json({ limit: '2mb' }));
        app.use('/api', documentRoutes);

        server = http.createServer(app);
        await new Promise(resolve => server.listen(0, resolve));

        const userA = 'user_scan_alice';
        const userB = 'user_scan_bob';
        await User.create([
            { userId: userA, full_name: 'Alice Scanner', email: 'alice@example.com' },
            { userId: userB, full_name: 'Bob Scanner', email: 'bob@example.com' }
        ]);
        const tokenA = makeToken(userA);
        const tokenB = makeToken(userB);

        // --- TEST 1: User A sends scans within rate limit ---
        console.log('--- Test 1: User sends scans within limit ---');
        for (let i = 1; i <= 3; i++) {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenA}`
                }
            }, {
                text: `Sample lease contract clause ${i} under Indian contract laws.`,
                title: `Alice Contract ${i}`
            });

            assert.strictEqual(res.statusCode, 201, `Scan request ${i} should succeed with 201`);
            assert(res.body.jobId, `Scan request ${i} should return jobId`);
        }
        console.log('✓ Test 1 Passed: Scans within limit (up to 3) succeed with 201.');

        // --- TEST 2: User A 4th request exceeds rate limit and receives 429 ---
        console.log('\n--- Test 2: User exceeds scan rate limit (429 returned) ---');
        {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenA}`
                }
            }, {
                text: 'Another contract clause beyond the limit.',
                title: 'Alice Overflow Contract'
            });

            assert.strictEqual(res.statusCode, 429, 'Excess scan request should be rejected with 429');
            assert(res.body.error, 'Response must include error message');
            assert(
                res.body.error.toLowerCase().includes('too many document scans') ||
                res.body.error.toLowerCase().includes('wait a few minutes'),
                `Error message should be user-friendly advice: ${res.body.error}`
            );
            assert(
                res.headers['ratelimit-limit'] !== undefined || res.headers['retry-after'] !== undefined,
                'Standard rate limit or retry-after headers should be present'
            );
            console.log('✓ Test 2 Passed: 4th scan request returns HTTP 429 with friendly error and standard headers.');
        }

        // --- TEST 3: User B has independent rate limit quota ---
        console.log('\n--- Test 3: User B is not affected by User A rate limit ---');
        {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenB}`
                }
            }, {
                text: 'Bob independent lease agreement text.',
                title: 'Bob Contract 1'
            });

            assert.strictEqual(res.statusCode, 201, 'User B request should succeed even when User A is limited');
            assert(res.body.jobId, 'User B request should return jobId');
            console.log('✓ Test 3 Passed: User B quota is isolated and succeeds with 201.');
        }

        // --- TEST 4: Retry rate limiter ---
        console.log('\n--- Test 4: Scan retry endpoint rate limiting ---');
        {
            const failedJob = await ScanJob.create({
                jobId: 'failed_job_test_1',
                userId: userB,
                fileHash: 'test_hash_retry_123',
                title: 'Failed Job For Retry',
                status: 'FAILED',
                sourceType: 'Text Description',
                mimeType: 'text/plain',
                completedSteps: [],
                errorInfo: { stage: 'AI Legal Analysis', message: 'Simulated failure' }
            });

            // 1st retry: permitted (may return 200 or update job)
            const retry1 = await makeRequest(server, {
                method: 'POST',
                path: `/api/scans/${failedJob.jobId}/retry`,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenB}`
                }
            });
            assert(retry1.statusCode === 200 || retry1.statusCode === 400, `Retry 1 status: ${retry1.statusCode}`);

            // Reset job to FAILED so second retry is valid logic-wise
            await ScanJob.updateOne({ jobId: failedJob.jobId }, { status: 'FAILED' });

            // 2nd retry: permitted
            const retry2 = await makeRequest(server, {
                method: 'POST',
                path: `/api/scans/${failedJob.jobId}/retry`,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenB}`
                }
            });
            assert(retry2.statusCode === 200 || retry2.statusCode === 400, `Retry 2 status: ${retry2.statusCode}`);

            // Reset job to FAILED
            await ScanJob.updateOne({ jobId: failedJob.jobId }, { status: 'FAILED' });

            // 3rd retry: exceeds SCAN_RETRY_RATE_LIMIT_MAX (2) -> 429
            const retry3 = await makeRequest(server, {
                method: 'POST',
                path: `/api/scans/${failedJob.jobId}/retry`,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenB}`
                }
            });
            assert.strictEqual(retry3.statusCode, 429, 'Excess retry attempt should be rejected with 429');
            assert(retry3.body.error.toLowerCase().includes('retry'), `Retry error message should mention retrying: ${retry3.body.error}`);
            console.log('✓ Test 4 Passed: Excessive scan retry attempts return HTTP 429.');
        }

        console.log('\n🎉 ALL SCAN RATE LIMITER TESTS PASSED (100%)!\n');
    } finally {
        scanJobService.executeJobPipeline = origExecute;
        if (server) {
            await new Promise(resolve => server.close(resolve));
        }
        if (mongoose.connection.readyState !== 0) {
            await mongoose.disconnect();
        }
        if (mongod) {
            await mongod.stop();
        }
    }
}

runTests().catch(err => {
    console.error('Test Suite Failed:', err);
    process.exit(1);
});
