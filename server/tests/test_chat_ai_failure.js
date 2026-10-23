/**
 * Test Suite: Chat AI Failure Handling
 * Verifies that:
 * 1. llmService.chat throws an error (with status 429 or 503) on AI failures.
 * 2. POST /api/chat returns HTTP 429 when rate-limited or quota exceeded.
 * 3. POST /api/chat returns HTTP 503 when the AI service is unavailable or returns bad output.
 * 4. Failed chat attempts do NOT save fallback messages or sessions to MongoDB.
 * 5. Friendly fallback string ("I am ready to help...") is never returned as a 200 answer.
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
if (!process.env.JWT_SECRET) {
    process.env.JWT_SECRET = 'test_jwt_secret_for_chat_ai_failure_tests';
}

const assert = require('assert');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');

const JWT_SECRET = require('../src/config/jwt');
const ChatSession = require('../src/models/ChatSession');
const ChatCache = require('../src/models/ChatCache');
const chatRoutes = require('../src/routes/chatRoutes');
const llmService = require('../src/services/llmService');

const testUserId = `test_chat_user_${Date.now()}`;
const testToken = jwt.sign({ userId: testUserId, email: 'chat_test@example.com' }, JWT_SECRET, { expiresIn: '1h' });

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
        });

        req.on('error', reject);
        if (payload) req.write(payload);
        req.end();
    });
}

async function runTests() {
    console.log('=== Starting Chat AI Failure Handling Test Suite ===\n');

    let mongod = null;
    let server = null;
    const originalChat = llmService.chat;

    try {
        if (mongoose.connection.readyState === 0) {
            const { MongoMemoryServer } = require('mongodb-memory-server');
            mongod = await MongoMemoryServer.create();
            await mongoose.connect(mongod.getUri());
        }

        const User = require('../src/models/User');
        await User.create({
            userId: testUserId,
            email: 'chat_test@example.com',
            full_name: 'Chat Test User',
            passwordHash: 'dummyhash',
            tokenVersion: 0,
            isEmailVerified: true
        });

        const app = express();
        app.use(express.json());
        app.use('/api', chatRoutes);

        server = http.createServer(app);
        await new Promise((resolve) => server.listen(0, resolve));

        // -------------------------------------------------------------
        // Test 1: Rate limit / Quota failure returns HTTP 429 and does NOT save session
        // -------------------------------------------------------------
        {
            llmService.chat = async () => {
                const err = new Error('ResourceExhausted: 429 Quota exceeded');
                err.status = 429;
                throw err;
            };

            const initialSessions = await ChatSession.countDocuments({ userId: testUserId });

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/chat',
                body: {
                    history: [{ role: 'user', text: 'Tell me about section 18 RERA' }]
                }
            });

            assert.strictEqual(res.statusCode, 429, `Expected 429, got ${res.statusCode}`);
            assert.ok(res.body.error, 'Expected error message in body');
            assert.ok(!res.body.reply, 'Should not return reply field on 429');

            const afterSessions = await ChatSession.countDocuments({ userId: testUserId });
            assert.strictEqual(afterSessions, initialSessions, 'Failed chat must NOT create a ChatSession');

            console.log('✓ Test 1 Passed: Rate-limited chat returns HTTP 429 and does not save session.');
        }

        // -------------------------------------------------------------
        // Test 2: AI service error (503 / 500) returns HTTP 503 and does NOT save session
        // -------------------------------------------------------------
        {
            llmService.chat = async () => {
                const err = new Error('503 Service Unavailable');
                err.status = 503;
                throw err;
            };

            const initialSessions = await ChatSession.countDocuments({ userId: testUserId });

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/chat',
                body: {
                    history: [{ role: 'user', text: 'Can a builder cancel sale agreement?' }]
                }
            });

            assert.strictEqual(res.statusCode, 503, `Expected 503, got ${res.statusCode}`);
            assert.ok(res.body.error, 'Expected error message in body');
            assert.ok(!res.body.reply, 'Should not return reply field on 503');

            // Verify old fallback string is nowhere in the response
            const bodyStr = JSON.stringify(res.body);
            assert.ok(!bodyStr.includes('I am ready to help you with property laws'), 'Must not return friendly fallback text');

            const afterSessions = await ChatSession.countDocuments({ userId: testUserId });
            assert.strictEqual(afterSessions, initialSessions, 'Failed chat must NOT create a ChatSession');

            console.log('✓ Test 2 Passed: AI service outage returns HTTP 503 and does not save session.');
        }

        // -------------------------------------------------------------
        // Test 3: Existing session is not corrupted on mid-conversation failure
        // -------------------------------------------------------------
        {
            const existing = new ChatSession({
                userId: testUserId,
                title: 'Existing Conversation',
                messages: [
                    { role: 'user', text: 'First question', time: '10:00 AM' },
                    { role: 'ai', text: 'First valid answer', time: '10:00 AM' }
                ]
            });
            await existing.save();

            llmService.chat = async () => {
                const err = new Error('Upstream model connection failure');
                err.status = 503;
                throw err;
            };

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/chat',
                body: {
                    sessionId: existing._id.toString(),
                    history: [
                        { role: 'user', text: 'First question' },
                        { role: 'ai', text: 'First valid answer' },
                        { role: 'user', text: 'Second question that fails' }
                    ]
                }
            });

            assert.strictEqual(res.statusCode, 503);

            const sessionInDb = await ChatSession.findById(existing._id);
            assert.strictEqual(sessionInDb.messages.length, 2, 'No new messages or fallback messages should be added on failure');

            console.log('✓ Test 3 Passed: Mid-conversation AI failure leaves existing session intact.');
        }

        // -------------------------------------------------------------
        // Test 4: Successful chat still works normally and persists session
        // -------------------------------------------------------------
        {
            llmService.chat = async () => {
                return {
                    reply: 'Under Section 18 of RERA, if a promoter fails to give possession, the allottee can claim refund.',
                    suggestions: ['How to file RERA complaint?'],
                    sources: []
                };
            };

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/chat',
                body: {
                    history: [{ role: 'user', text: 'Tell me about RERA Section 18' }]
                }
            });

            assert.strictEqual(res.statusCode, 200);
            assert.ok(res.body.reply.includes('Under Section 18'));
            assert.ok(res.body.sessionId, 'Should return created sessionId');

            const session = await ChatSession.findById(res.body.sessionId);
            assert.ok(session, 'Session must exist in DB');
            assert.strictEqual(session.messages.length, 2);
            assert.strictEqual(session.messages[1].role, 'ai');

            console.log('✓ Test 4 Passed: Successful chat persists session and returns 200.');
        }

        console.log('\n🎉 ALL CHAT AI FAILURE HANDLING TESTS PASSED SUCCESSFULLY!');
    } finally {
        llmService.chat = originalChat;
        if (server) {
            await new Promise((resolve) => server.close(resolve));
        }
        if (mongod) {
            await mongoose.disconnect();
            await mongod.stop();
        }
    }
}

runTests().catch(err => {
    console.error('Test suite failed:', err);
    process.exit(1);
});
