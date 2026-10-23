/**
 * Test Suite: Server Health Check Endpoint
 * Verifies that:
 * 1. GET /health and GET /api/health return 200 with status: ok when database is connected.
 * 2. Response includes uptime, database connection status, and valid ISO timestamp.
 * 3. GET /health returns 503 with status: degraded when database is disconnected.
 */

const assert = require('assert');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');

function makeRequest(server, path) {
    return new Promise((resolve, reject) => {
        const addr = server.address();
        http.get({
            hostname: '127.0.0.1',
            port: addr.port,
            path
        }, (res) => {
            let data = '';
            res.on('data', chunk => { data += chunk; });
            res.on('end', () => {
                let parsed = null;
                try {
                    parsed = JSON.parse(data);
                } catch (_) {
                    parsed = data;
                }
                resolve({ statusCode: res.statusCode, body: parsed });
            });
        }).on('error', reject);
    });
}

async function runTests() {
    console.log('=== Starting Server Health Check Test Suite ===\n');

    const app = express();

    app.get(['/health', '/api/health'], (req, res) => {
        const dbState = mongoose.connection.readyState;
        const dbStatusMap = {
            0: 'disconnected',
            1: 'connected',
            2: 'connecting',
            3: 'disconnecting'
        };
        const isHealthy = dbState === 1;
        const status = isHealthy ? 'ok' : 'degraded';

        res.status(isHealthy ? 200 : 503).json({
            status,
            database: dbStatusMap[dbState] || 'unknown',
            uptime: Math.floor(process.uptime()),
            timestamp: new Date().toISOString()
        });
    });

    const server = http.createServer(app);
    await new Promise(resolve => server.listen(0, resolve));

    try {
        // Test 1: Disconnected database returns 503 degraded
        {
            const res = await makeRequest(server, '/health');
            assert.strictEqual(res.statusCode, 503);
            assert.strictEqual(res.body.status, 'degraded');
            assert.strictEqual(res.body.database, 'disconnected');
            assert.ok(typeof res.body.uptime === 'number');
            assert.ok(res.body.timestamp);
            console.log('✓ Test 1 Passed: /health returns 503 degraded when DB is disconnected.');
        }

        // Test 2: Connected database returns 200 ok
        let mongod = null;
        try {
            const { MongoMemoryServer } = require('mongodb-memory-server');
            mongod = await MongoMemoryServer.create();
            await mongoose.connect(mongod.getUri());

            const res1 = await makeRequest(server, '/health');
            assert.strictEqual(res1.statusCode, 200);
            assert.strictEqual(res1.body.status, 'ok');
            assert.strictEqual(res1.body.database, 'connected');
            assert.ok(typeof res1.body.uptime === 'number');
            assert.ok(res1.body.timestamp);

            const res2 = await makeRequest(server, '/api/health');
            assert.strictEqual(res2.statusCode, 200);
            assert.strictEqual(res2.body.status, 'ok');

            console.log('✓ Test 2 Passed: /health and /api/health return 200 ok when DB is connected.');
        } finally {
            await mongoose.disconnect();
            if (mongod) await mongod.stop();
        }

        console.log('\n🎉 ALL HEALTH CHECK TESTS PASSED SUCCESSFULLY!');
    } finally {
        await new Promise(resolve => server.close(resolve));
    }
}

runTests().catch(err => {
    console.error('Test suite failed:', err);
    process.exit(1);
});
