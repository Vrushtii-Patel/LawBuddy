/**
 * Test Suite: Chat History Sanitization & Multi-Turn Alternation Guard
 * Verifies that:
 * 1. History is validated and length-capped.
 * 2. Consecutive same-role turns (e.g. user after user) are cleanly merged into single turns.
 * 3. Consecutive AI/model turns are cleanly merged.
 * 4. Invalid or error roles (e.g. 'error') are stripped out.
 * 5. History starting with 'ai' drops leading non-user turns so it always starts with 'user'.
 * 6. History ending with 'ai' is rejected with 400 (latest message must be from user).
 * 7. POST /api/chat handles consecutive user turns seamlessly.
 * 8. Real Gemini API test: Sending consecutive user turns (post-failure scenario) succeeds with real API.
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
if (!process.env.JWT_SECRET) {
    process.env.JWT_SECRET = 'test_jwt_secret_chat_history_sanitizer';
}

const assert = require('assert');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const JWT_SECRET = require('../src/config/jwt');
const { sanitizeChatHistory, ChatHistoryError, MAX_HISTORY_TURNS, MAX_MESSAGE_CHARS } = require('../src/utils/chatHistorySanitizer');
const chatRoutes = require('../src/routes/chatRoutes');
const llmService = require('../src/services/llmService');
const User = require('../src/models/User');
const ChatSession = require('../src/models/ChatSession');

const testUserId = `test_chat_hist_user_${Date.now()}`;
const testToken = jwt.sign({ userId: testUserId, email: 'hist_test@example.com' }, JWT_SECRET, { expiresIn: '1h' });

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
    console.log('=== Starting Chat History Sanitization & Alternation Test Suite ===\n');

    // =========================================================================
    // SECTION 1: Unit Tests for sanitizeChatHistory
    // =========================================================================

    // 1.1 Non-array or empty input throws ChatHistoryError
    assert.throws(() => sanitizeChatHistory(null), ChatHistoryError);
    assert.throws(() => sanitizeChatHistory([]), ChatHistoryError);
    assert.throws(() => sanitizeChatHistory('not an array'), ChatHistoryError);
    assert.throws(() => sanitizeChatHistory([{ role: 'user', text: '   ' }]), ChatHistoryError);
    console.log('✓ Test 1.1 Passed: Empty and invalid inputs correctly rejected.');

    // 1.2 Two consecutive user turns (post-failure scenario) merged into one
    {
        const input = [
            { role: 'user', text: 'First query that failed' },
            { role: 'user', text: 'Second query user typed next' }
        ];
        const out = sanitizeChatHistory(input);
        assert.strictEqual(out.length, 1, 'Should merge into a single turn');
        assert.strictEqual(out[0].role, 'user');
        assert.strictEqual(out[0].text, 'First query that failed\n\nSecond query user typed next');
        console.log('✓ Test 1.2 Passed: Consecutive user turns merged into single turn.');
    }

    // 1.3 Multi-turn with consecutive same-role turns strictly alternates
    {
        const input = [
            { role: 'user', text: 'Question 1' },
            { role: 'ai', text: 'Answer 1 Part A' },
            { role: 'model', text: 'Answer 1 Part B' },
            { role: 'user', text: 'Question 2 Attempt 1' },
            { role: 'user', text: 'Question 2 Attempt 2' }
        ];
        const out = sanitizeChatHistory(input);
        assert.strictEqual(out.length, 3, 'Should produce user -> ai -> user');
        assert.strictEqual(out[0].role, 'user');
        assert.strictEqual(out[0].text, 'Question 1');
        assert.strictEqual(out[1].role, 'ai');
        assert.strictEqual(out[1].text, 'Answer 1 Part A\n\nAnswer 1 Part B');
        assert.strictEqual(out[2].role, 'user');
        assert.strictEqual(out[2].text, 'Question 2 Attempt 1\n\nQuestion 2 Attempt 2');
        console.log('✓ Test 1.3 Passed: Mixed consecutive same-role turns strictly alternate.');
    }

    // 1.4 Drops leading AI/model messages (Gemini requires first content to be user)
    {
        const input = [
            { role: 'ai', text: 'Hello, I am LawBuddy legal assistant!' },
            { role: 'user', text: 'What is RERA Section 18?' }
        ];
        const out = sanitizeChatHistory(input);
        assert.strictEqual(out.length, 1);
        assert.strictEqual(out[0].role, 'user');
        assert.strictEqual(out[0].text, 'What is RERA Section 18?');
        console.log('✓ Test 1.4 Passed: Leading AI messages stripped so history starts with user.');
    }

    // 1.5 Filters out invalid roles like 'error' and 'system'
    {
        const input = [
            { role: 'user', text: 'Question 1' },
            { role: 'error', text: 'Assistant unavailable. Please try again.' },
            { role: 'user', text: 'Question 2' }
        ];
        const out = sanitizeChatHistory(input);
        assert.strictEqual(out.length, 1);
        assert.strictEqual(out[0].role, 'user');
        assert.strictEqual(out[0].text, 'Question 1\n\nQuestion 2');
        console.log('✓ Test 1.5 Passed: Client-side error roles stripped and surrounding user queries merged.');
    }

    // 1.6 History ending in AI message is rejected
    {
        const input = [
            { role: 'user', text: 'Question 1' },
            { role: 'ai', text: 'Answer 1' }
        ];
        assert.throws(() => sanitizeChatHistory(input), (err) => {
            return err instanceof ChatHistoryError && err.message.includes('latest message in history must be from the user');
        });
        console.log('✓ Test 1.6 Passed: History ending in AI message cleanly rejected with 400.');
    }

    // 1.7 Length limits: individual message capping and max turn windowing
    {
        const longText = 'x'.repeat(15000);
        const input = [{ role: 'user', text: longText }];
        const out = sanitizeChatHistory(input);
        assert.strictEqual(out[0].text.length, MAX_MESSAGE_CHARS, 'Oversized message must be truncated');

        // Test turn limit windowing
        const manyTurns = [];
        for (let i = 0; i < 50; i++) {
            manyTurns.push({ role: 'user', text: `U${i}` });
            manyTurns.push({ role: 'ai', text: `A${i}` });
        }
        manyTurns.push({ role: 'user', text: 'Latest query' });

        const windowed = sanitizeChatHistory(manyTurns, { maxTurns: 10 });
        assert.ok(windowed.length <= 10, 'Should not exceed maxTurns');
        assert.strictEqual(windowed[0].role, 'user', 'Windowed history must start with user');
        assert.strictEqual(windowed[windowed.length - 1].text, 'Latest query', 'Must retain latest user query');
        console.log('✓ Test 1.7 Passed: Individual message length capped and turn windowing enforced.');
    }

    // =========================================================================
    // SECTION 2: Integration Tests with Express API Routes
    // =========================================================================
    let mongod = null;
    let server = null;

    try {
        if (mongoose.connection.readyState === 0) {
            const { MongoMemoryServer } = require('mongodb-memory-server');
            mongod = await MongoMemoryServer.create();
            await mongoose.connect(mongod.getUri());
        }

        await User.create({
            userId: testUserId,
            email: 'hist_test@example.com',
            full_name: 'History Test User',
            passwordHash: 'dummyhash',
            tokenVersion: 0,
            isEmailVerified: true
        });

        const app = express();
        app.use(express.json());
        app.use('/api', chatRoutes);

        server = http.createServer(app);
        await new Promise((resolve) => server.listen(0, resolve));

        // 2.1 Sending history that ends in AI returns 400
        {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/chat',
                body: {
                    history: [
                        { role: 'user', text: 'Hi' },
                        { role: 'ai', text: 'Hello' }
                    ]
                }
            });
            assert.strictEqual(res.statusCode, 400);
            assert.ok(res.body.error.includes('latest message in history must be from the user'));
            console.log('✓ Test 2.1 Passed: Route returns 400 when history ends in AI turn.');
        }

        // 2.2 Sending consecutive user messages (after a failed message) succeeds and merges cleanly
        {
            const originalChat = llmService.chat;
            let receivedHistory = null;
            llmService.chat = async (hist) => {
                receivedHistory = hist;
                return {
                    reply: 'Merged reply successfully generated',
                    suggestions: [],
                    sources: []
                };
            };

            try {
                const res = await makeRequest(server, {
                    method: 'POST',
                    path: '/api/chat',
                    body: {
                        history: [
                            { role: 'user', text: 'Previous query whose reply failed' },
                            { role: 'user', text: 'New retry query' }
                        ]
                    }
                });

                assert.strictEqual(res.statusCode, 200);
                assert.ok(receivedHistory, 'Chat service should be invoked');
                assert.strictEqual(receivedHistory.length, 1, 'Consecutive user messages must reach LLM service merged as 1 turn');
                assert.ok(receivedHistory[0].text.includes('Previous query'));
                assert.ok(receivedHistory[0].text.includes('New retry query'));

                const session = await ChatSession.findById(res.body.sessionId);
                assert.ok(session);
                assert.strictEqual(session.messages.length, 2);
                assert.strictEqual(session.messages[0].role, 'user');
                assert.strictEqual(session.messages[0].text, 'Previous query whose reply failed\n\nNew retry query');
                assert.strictEqual(session.messages[1].role, 'ai');
                console.log('✓ Test 2.2 Passed: Route merges consecutive user turns and saves merged message to session.');
            } finally {
                llmService.chat = originalChat;
            }
        }

        // =========================================================================
        // SECTION 3: Real Gemini API Test with Consecutive User Turns (Issue 31 requirement)
        // =========================================================================
        if (process.env.GEMINI_API_KEY && !process.env.GEMINI_API_KEY.startsWith('dummy')) {
            console.log('\n--- Running Real Gemini API Test for Consecutive User Turns ---');
            const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
            const model = genAI.getGenerativeModel({ model: 'gemini-3.5-flash-lite' });

            // Raw consecutive turns that Gemini would normally reject or choke on:
            const rawHistory = [
                { role: 'ai', text: 'Welcome to LawBuddy.' }, // leading AI
                { role: 'user', text: 'I am checking RERA rules.' },
                { role: 'user', text: 'Can a builder delay possession indefinitely without penalty? Answer in one sentence.' }
            ];

            const sanitized = sanitizeChatHistory(rawHistory);
            assert.strictEqual(sanitized.length, 1, 'Raw history with leading AI and 2 user queries should sanitize to 1 merged user turn');

            const formattedHistory = sanitized.slice(0, -1).map(msg => ({
                role: msg.role === 'user' ? 'user' : 'model',
                parts: [{ text: msg.text }]
            }));

            const chatSession = model.startChat({ history: formattedHistory });
            const prompt = sanitized[sanitized.length - 1].text;
            const realResult = await chatSession.sendMessage(prompt);
            const replyText = realResult.response.text();

            assert.ok(replyText && replyText.trim().length > 0, 'Real API must return valid text');
            console.log(`✓ Test 3 Passed: Real Gemini API successfully processed sanitized history!`);
            console.log(`  Sample Response: "${replyText.trim().replace(/\n/g, ' ').substring(0, 80)}..."`);
        } else {
            console.log('Note: GEMINI_API_KEY not configured, skipped real-API execution.');
        }

        console.log('\n🎉 ALL CHAT HISTORY SANITIZATION & ALTERNATION TESTS PASSED (100%)!');
    } finally {
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
