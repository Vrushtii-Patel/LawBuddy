const assert = require('assert');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

process.env.NODE_ENV = 'test';
if (!process.env.JWT_SECRET) {
    process.env.JWT_SECRET = 'share-security-test-secret-key-12345';
}

const JWT_SECRET = require('../src/config/jwt');
const SharedAnalysis = require('../src/models/SharedAnalysis');
const Document = require('../src/models/Document');
const User = require('../src/models/User');
const shareRoutes = require('../src/routes/shareRoutes');
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

async function runTests() {
    console.log('=== Starting Share Link Security & Revocation Test Suite ===\n');

    let mongod = null;
    let server = null;

    try {
        mongod = await MongoMemoryServer.create();
        await mongoose.connect(mongod.getUri());

        const app = express();
        app.use(express.json({ limit: '2mb' }));
        app.use('/api', shareRoutes);
        app.use('/api', documentRoutes);

        server = http.createServer(app);
        await new Promise(resolve => server.listen(0, resolve));

        const userA = 'user_alice_123';
        const userB = 'user_bob_456';
        await User.create([
            { userId: userA, full_name: 'Alice User', email: 'alice@example.com' },
            { userId: userB, full_name: 'Bob User', email: 'bob@example.com' }
        ]);
        const tokenA = makeToken(userA);
        const tokenB = makeToken(userB);

        // --- TEST 1: Unauthenticated request to POST /api/shares is rejected with 401 ---
        console.log('--- Test 1: Unauthenticated share creation rejected ---');
        {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/shares',
                headers: { 'Content-Type': 'application/json' }
            }, {
                title: 'Unauthenticated Agreement',
                analysis: [{ clauseId: '1', text: 'Spam text' }]
            });

            assert.strictEqual(res.statusCode, 401, 'Anonymous request must be rejected with 401');
            console.log('✓ Test 1 Passed: Anonymous users cannot create share links (401 returned).');
        }

        // --- TEST 2: Authenticated user creates a valid share link ---
        console.log('\n--- Test 2: Authenticated share creation ---');
        let createdShareToken = null;
        {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/shares',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenA}`
                }
            }, {
                title: 'Alice Lease Agreement',
                riskLevel: 'High Risk',
                analysis: [
                    { clauseId: 'C1', title: 'Late Fee', text: '10% per day', riskLevel: 'HIGH_RISK' },
                    { clauseId: 'C2', title: 'Maintenance', text: 'Landlord handles', riskLevel: 'COMPLIANT' }
                ]
            });

            assert.strictEqual(res.statusCode, 201, 'Authenticated share creation must succeed with 201');
            assert.strictEqual(res.body.success, true);
            assert.ok(res.body.shareToken, 'Must return shareToken');
            createdShareToken = res.body.shareToken;

            // Verify in DB that userId is saved
            const saved = await SharedAnalysis.findOne({ shareToken: createdShareToken });
            assert.strictEqual(saved.userId, userA);
            assert.strictEqual(saved.totalClauseCount, 2);
            assert.strictEqual(saved.highRiskCount, 1);
            assert.strictEqual(saved.compliantCount, 1);
            console.log('✓ Test 2 Passed: Authenticated user creates share; userId & counts stored correctly.');
        }

        // --- TEST 3: Payload size capping (> 150 clauses rejected) ---
        console.log('\n--- Test 3: Excessive clause count capped / rejected ---');
        {
            const excessiveClauses = [];
            for (let i = 0; i < 155; i++) {
                excessiveClauses.push({ clauseId: `C${i}`, text: `Clause text ${i}` });
            }

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/shares',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenA}`
                }
            }, {
                title: 'Abusive Massive Agreement',
                analysis: excessiveClauses
            });

            assert.strictEqual(res.statusCode, 400, 'Payload exceeding 150 clauses must be rejected with 400');
            assert.match(res.body.error, /150/);
            console.log('✓ Test 3 Passed: Payloads with > 150 clauses are strictly rejected with 400.');
        }

        // --- TEST 4: Listing active shares for user ---
        console.log('\n--- Test 4: List active shares endpoint ---');
        {
            const res = await makeRequest(server, {
                method: 'GET',
                path: '/api/shares',
                headers: { 'Authorization': `Bearer ${tokenA}` }
            });

            assert.strictEqual(res.statusCode, 200);
            assert.ok(Array.isArray(res.body));
            assert.strictEqual(res.body.length, 1);
            assert.strictEqual(res.body[0].shareToken, createdShareToken);

            // User B should see 0 shares
            const resB = await makeRequest(server, {
                method: 'GET',
                path: '/api/shares',
                headers: { 'Authorization': `Bearer ${tokenB}` }
            });
            assert.strictEqual(resB.statusCode, 200);
            assert.strictEqual(resB.body.length, 0);
            console.log('✓ Test 4 Passed: GET /api/shares returns only shares belonging to authenticated user.');
        }

        // --- TEST 5: Public retrieval of share link ---
        console.log('\n--- Test 5: Public read-only retrieval of active share ---');
        {
            const res = await makeRequest(server, {
                method: 'GET',
                path: `/api/shares/${createdShareToken}`
            });

            assert.strictEqual(res.statusCode, 200);
            assert.strictEqual(res.body.title, 'Alice Lease Agreement');
            assert.strictEqual(res.body.highRiskCount, 1);
            assert.strictEqual(res.body.totalClauseCount, 2);
            assert.strictEqual(res.body.userId, undefined, 'userId must not leak in public view');
            assert.strictEqual(res.body._id, undefined, 'Internal database ID must not leak');
            console.log('✓ Test 5 Passed: Public can retrieve active share without credentials.');
        }

        // --- TEST 6: Revoke share endpoint ---
        console.log('\n--- Test 6: Revoke share endpoint ---');
        {
            // User B cannot revoke User A's share
            const resUnauthorized = await makeRequest(server, {
                method: 'DELETE',
                path: `/api/shares/${createdShareToken}`,
                headers: { 'Authorization': `Bearer ${tokenB}` }
            });
            assert.strictEqual(resUnauthorized.statusCode, 404, 'User B cannot revoke User A share');

            // User A revokes their own share
            const resRevoke = await makeRequest(server, {
                method: 'DELETE',
                path: `/api/shares/${createdShareToken}`,
                headers: { 'Authorization': `Bearer ${tokenA}` }
            });
            assert.strictEqual(resRevoke.statusCode, 200);
            assert.strictEqual(resRevoke.body.message, 'Share link revoked successfully');

            // Public link is now immediately dead (404)
            const resAfterRevoke = await makeRequest(server, {
                method: 'GET',
                path: `/api/shares/${createdShareToken}`
            });
            assert.strictEqual(resAfterRevoke.statusCode, 404, 'Revoked share must return 404');
            console.log('✓ Test 6 Passed: Owner can revoke share; public retrieval immediately returns 404.');
        }

        // --- TEST 7: Linking share to a document and revoking on document deletion ---
        console.log('\n--- Test 7: Shares revoked when parent document is binned/deleted ---');
        {
            // Create a document for User A
            const doc = await Document.create({
                userId: userA,
                fileHash: 'test_hash_doc_123',
                title: 'Confidential Employment Contract',
                originalText: 'Confidential text that should not leak once deleted.',
                riskLevel: 'Low Risk',
                isDeleted: false
            });

            // Create a share linked to this documentId
            const createRes = await makeRequest(server, {
                method: 'POST',
                path: '/api/shares',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenA}`
                }
            }, {
                documentId: doc._id.toString(),
                title: doc.title,
                riskLevel: doc.riskLevel,
                analysis: [{ clauseId: 'DOC1', text: 'Private NDA clause' }]
            });

            assert.strictEqual(createRes.statusCode, 201);
            const docShareToken = createRes.body.shareToken;

            // Public retrieval works while document is active
            const publicResActive = await makeRequest(server, {
                method: 'GET',
                path: `/api/shares/${docShareToken}`
            });
            assert.strictEqual(publicResActive.statusCode, 200);
            assert.strictEqual(publicResActive.body.title, 'Confidential Employment Contract');

            // Soft-delete the document (move to Recycle Bin)
            const deleteDocRes = await makeRequest(server, {
                method: 'DELETE',
                path: `/api/documents/${doc._id}`,
                headers: { 'Authorization': `Bearer ${tokenA}` }
            });
            assert.strictEqual(deleteDocRes.statusCode, 200);

            // Public share link must now be revoked and return 404 immediately
            const publicResAfterBin = await makeRequest(server, {
                method: 'GET',
                path: `/api/shares/${docShareToken}`
            });
            assert.strictEqual(publicResAfterBin.statusCode, 404, 'Share link must return 404 once document is moved to Recycle Bin');
            console.log('✓ Test 7 Passed: Moving document to Recycle Bin revokes its public share link immediately.');
        }

        console.log('\n🎉 ALL SHARE SECURITY AND DOCUMENT DELETION TESTS PASSED (100%)!\n');
    } finally {
        if (server) await new Promise(resolve => server.close(resolve));
        if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
        if (mongod) await mongod.stop();
    }
}

runTests().catch(err => {
    console.error('Test suite failed:', err);
    process.exit(1);
});
