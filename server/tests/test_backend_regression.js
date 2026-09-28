const assert = require('assert');
const path = require('path');
const fs = require('fs');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const documentRoutes = require('../src/routes/documentRoutes');
const Document = require('../src/models/Document');
const ScanJob = require('../src/models/ScanJob');
const User = require('../src/models/User');
const scanJobService = require('../src/services/scanJobService');
const llmService = require('../src/services/llmService');
const { PROMPT_VERSION, MODEL_NAME, ANALYSIS_VERSION } = require('../src/config/modelConfig');

const JWT_SECRET = process.env.JWT_SECRET || 'test_secret_key_12345';
process.env.JWT_SECRET = JWT_SECRET;

const app = express();
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ limit: '2mb', extended: true }));
app.use('/api', documentRoutes);

function createAuthToken(userId) {
    return jwt.sign({ userId, email: `${userId}@example.com`, tokenVersion: 0 }, JWT_SECRET, { expiresIn: '1h' });
}

function makeRequest(server, { method, path, headers = {}, body = null, isMultipart = false, formData = null }) {
    return new Promise((resolve, reject) => {
        const address = server.address();
        const port = address.port;

        const options = {
            hostname: '127.0.0.1',
            port: port,
            path: path,
            method: method,
            headers: { ...headers }
        };

        if (body && !isMultipart) {
            const jsonStr = typeof body === 'string' ? body : JSON.stringify(body);
            options.headers['Content-Type'] = 'application/json';
            options.headers['Content-Length'] = Buffer.byteLength(jsonStr);
        }

        const req = http.request(options, (res) => {
            const chunks = [];
            res.on('data', chunk => chunks.push(chunk));
            res.on('end', () => {
                const buffer = Buffer.concat(chunks);
                const text = buffer.toString('utf8');
                let json = null;
                try {
                    json = JSON.parse(text);
                } catch (_) {}
                resolve({
                    statusCode: res.statusCode,
                    headers: res.headers,
                    body: json,
                    rawBody: text,
                    buffer: buffer
                });
            });
        });

        req.on('error', reject);

        if (isMultipart && formData) {
            req.write(formData);
        } else if (body) {
            const jsonStr = typeof body === 'string' ? body : JSON.stringify(body);
            req.write(jsonStr);
        }

        req.end();
    });
}

function createMultipartPayload(boundary, fields, files) {
    const parts = [];

    for (const [key, val] of Object.entries(fields || {})) {
        parts.push(
            `--${boundary}\r\n` +
            `Content-Disposition: form-data; name="${key}"\r\n\r\n` +
            `${val}\r\n`
        );
    }

    for (const file of (files || [])) {
        parts.push(
            `--${boundary}\r\n` +
            `Content-Disposition: form-data; name="${file.fieldname}"; filename="${file.filename}"\r\n` +
            `Content-Type: ${file.contentType}\r\n\r\n`
        );
        parts.push(file.content);
        parts.push('\r\n');
    }

    parts.push(`--${boundary}--\r\n`);

    const buffers = parts.map(p => Buffer.isBuffer(p) ? p : Buffer.from(p, 'utf8'));
    return Buffer.concat(buffers);
}

async function runRegressionTests() {
    console.log('===============================================================');
    console.log('  LAWBUDDY BACKEND REGRESSION TEST SUITE (DOCUMENT ROUTES)   ');
    console.log('===============================================================\n');

    const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/lawbuddy';
    try {
        if (mongoose.connection.readyState !== 1) {
            await mongoose.connect(uri, { family: 4, serverSelectionTimeoutMS: 2500 });
            console.log('✓ Connected to MongoDB for regression testing.\n');
        }
    } catch (err) {
        console.warn('MongoDB connect notice:', err.message);
    }

    const server = http.createServer(app);
    await new Promise(res => server.listen(0, '127.0.0.1', res));

    const testUser = `reg_user_${Date.now()}`;
    await User.create({
        userId: testUser,
        full_name: 'Regression Test User',
        email: `${testUser}@example.com`,
        isVerified: true,
        tokenVersion: 0
    });
    const validToken = createAuthToken(testUser);

    let passedCount = 0;
    let failedCount = 0;

    async function testCase(name, fn) {
        try {
            await fn();
            console.log(`[PASS] ${name}`);
            passedCount++;
        } catch (err) {
            console.error(`[FAIL] ${name}`);
            console.error(`       Error: ${err.message}`);
            if (err.stack) console.error(`       ${err.stack.split('\n')[1]}`);
            failedCount++;
        }
    }

    try {
        // --- 1. AUTHENTICATION ENFORCEMENT & DEPRECATION ---
        console.log('--- 1. Authentication & Security ---');
        await testCase('Reject /scans/start without token (401)', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                body: { text: 'Test text' }
            });
            assert.strictEqual(res.statusCode, 401);
            assert.ok(res.body.error);
        });

        await testCase('Deprecated /scan returns 410 Gone with migration message', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scan',
                body: { text: 'Test text' }
            });
            assert.strictEqual(res.statusCode, 410);
            assert.ok(res.body.error.includes('deprecated'));
        });

        await testCase('Deprecated /scan-file returns 410 Gone with migration message', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scan-file',
                body: { base64Data: 'dummy' }
            });
            assert.strictEqual(res.statusCode, 410);
            assert.ok(res.body.error.includes('deprecated'));
        });

        await testCase('Reject /documents without token (401)', async () => {
            const res = await makeRequest(server, { method: 'GET', path: '/api/documents' });
            assert.strictEqual(res.statusCode, 401);
        });

        // --- 2. INPUT VALIDATION ---
        console.log('\n--- 2. Input Validation ---');
        await testCase('POST /scans/start with empty body returns 400', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: {}
            });
            assert.strictEqual(res.statusCode, 400);
            assert.strictEqual(res.body.error, 'Document file or text description is required.');
        });

        // --- 3. MIME TYPE & SOURCE TYPE INFERENCE ---
        console.log('\n--- 3. MIME & sourceType Inference ---');
        await testCase('POST /scans/start with text infers text/plain and Text Description', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: { text: 'Sale deed clause description test' }
            });
            assert.strictEqual(res.statusCode, 201);
            assert.ok(res.body.jobId);
            const job = await ScanJob.findOne({ jobId: res.body.jobId });
            assert.ok(job);
            assert.strictEqual(job.mimeType, 'text/plain');
            assert.strictEqual(job.sourceType, 'Text Description');
        });

        await testCase('POST /scans/start with multipart PDF infers application/pdf and PDF Document', async () => {
            const boundary = '----WebKitFormBoundary' + Date.now().toString(16);
            const pdfBuffer = Buffer.from('%PDF-1.4 sample pdf content for regression test');

            const payload = createMultipartPayload(
                boundary,
                { title: 'Registered Conveyance' },
                [{ fieldname: 'document', filename: 'conveyance.pdf', contentType: 'application/pdf', content: pdfBuffer }]
            );

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: {
                    'Authorization': `Bearer ${validToken}`,
                    'Content-Type': `multipart/form-data; boundary=${boundary}`,
                    'Content-Length': payload.length
                },
                isMultipart: true,
                formData: payload
            });

            assert.strictEqual(res.statusCode, 201);
            const job = await ScanJob.findOne({ jobId: res.body.jobId });
            assert.ok(job);
            assert.strictEqual(job.mimeType, 'application/pdf');
            assert.strictEqual(job.sourceType, 'PDF Document');
        });

        await testCase('POST /scans/start with multipart PNG image infers Photo Scan', async () => {
            const boundary = '----WebKitFormBoundary' + Date.now().toString(16);
            const pngHeader = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
            const imageBuffer = Buffer.concat([pngHeader, Buffer.from('sample png image data')]);

            const payload = createMultipartPayload(
                boundary,
                { title: 'Agreement Photo' },
                [{ fieldname: 'document', filename: 'page1.png', contentType: 'image/png', content: imageBuffer }]
            );

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: {
                    'Authorization': `Bearer ${validToken}`,
                    'Content-Type': `multipart/form-data; boundary=${boundary}`,
                    'Content-Length': payload.length
                },
                isMultipart: true,
                formData: payload
            });

            assert.strictEqual(res.statusCode, 201);
            const job = await ScanJob.findOne({ jobId: res.body.jobId });
            assert.ok(job);
            assert.strictEqual(job.mimeType, 'image/png');
            assert.strictEqual(job.sourceType, 'Photo Scan');
        });

        await testCase('POST /scans/start with base64Data infers PDF Document', async () => {
            const base64Content = Buffer.from('%PDF-1.4 Base64 encoded document').toString('base64');
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: {
                    base64Data: base64Content,
                    title: 'Base64 Upload'
                }
            });

            assert.strictEqual(res.statusCode, 201);
            const job = await ScanJob.findOne({ jobId: res.body.jobId });
            assert.ok(job);
            assert.strictEqual(job.mimeType, 'application/pdf');
            assert.strictEqual(job.sourceType, 'PDF Document');
        });

        // --- 4. RESPONSE SHAPING & ASYNC PIPELINE INTEGRATION ---
        console.log('\n--- 4. Async Scan Pipeline & Cache Hit ---');
        await testCase('POST /scans/start returns cached document for matching prompt & model version', async () => {
            const sampleText = `Sample unique clause text ${Date.now()}`;
            const normText = llmService.normalizeDocumentText(sampleText);
            const calculatedHash = crypto.createHash('sha256').update(normText).digest('hex');

            // Seed a cached completed job/document with exact matching hash and versions
            const doc = await Document.create({
                userId: testUser,
                fileHash: calculatedHash,
                title: 'Async Scan Cache Test Doc',
                originalText: normText,
                sourceType: 'Text Description',
                mimeType: 'text/plain',
                analysisStatus: 'completed',
                riskLevel: 'High Risk',
                highRiskCount: 1,
                cautionCount: 1,
                compliantCount: 1,
                analysis: [
                    { clauseId: 'c1', title: 'Penalty', text: 'High risk penalty', riskLevel: 'HIGH_RISK' },
                    { clauseId: 'c2', title: 'Caution', text: 'Caution term', riskLevel: 'CAUTION' },
                    { clauseId: 'c3', title: 'Standard', text: 'Standard term', riskLevel: 'COMPLIANT' }
                ],
                promptVersion: PROMPT_VERSION,
                modelName: MODEL_NAME,
                analysisVersion: ANALYSIS_VERSION
            });

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: {
                    text: sampleText,
                    title: 'Async Scan Cache Test Doc'
                }
            });

            assert.strictEqual(res.statusCode, 201);
            assert.ok(res.body.jobId);
            assert.strictEqual(res.body.status, 'COMPLETED');
            assert.strictEqual(String(res.body.documentId), String(doc._id));
        });


        // --- 5. OVERSIZED FILES & DISGUISED EXECUTABLES ---
        console.log('\n--- 5. Security & Edge Cases ---');
        await testCase('Reject disguised executable file upload (.exe named as .pdf)', async () => {
            const boundary = '----WebKitFormBoundary' + Date.now().toString(16);
            const mzHeader = Buffer.from([0x4D, 0x5A]); // 'MZ' executable signature
            const fakePdf = Buffer.concat([mzHeader, Buffer.from(' disguised windows executable payload')]);

            const payload = createMultipartPayload(
                boundary,
                { title: 'Malicious PDF' },
                [{ fieldname: 'document', filename: 'invoice.pdf', contentType: 'application/pdf', content: fakePdf }]
            );

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: {
                    'Authorization': `Bearer ${validToken}`,
                    'Content-Type': `multipart/form-data; boundary=${boundary}`,
                    'Content-Length': payload.length
                },
                isMultipart: true,
                formData: payload
            });

            assert.strictEqual(res.statusCode, 400);
            assert.ok(res.body.error);
        });

        // --- 6. DOCUMENT BIN & LIFECYCLE ---
        console.log('\n--- 6. Document Bin & Lifecycle Integrity ---');
        await testCase('Document soft-delete, get bin, and restore flow', async () => {
            const testDoc = await Document.create({
                userId: testUser,
                title: 'Doc to be soft-deleted',
                originalText: 'Some legal terms',
                sourceType: 'Text Description',
                mimeType: 'text/plain',
                analysisStatus: 'completed'
            });

            // 1. Soft-delete
            const deleteRes = await makeRequest(server, {
                method: 'DELETE',
                path: `/api/documents/${testDoc._id}`,
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(deleteRes.statusCode, 200);

            // 2. Query documents list - should NOT include deleted doc
            const listRes = await makeRequest(server, {
                method: 'GET',
                path: '/api/documents',
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(listRes.statusCode, 200);
            assert.strictEqual(listRes.body.some(d => d._id === String(testDoc._id)), false);

            // 3. Query bin - SHOULD include deleted doc
            const binRes = await makeRequest(server, {
                method: 'GET',
                path: '/api/documents/bin',
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(binRes.statusCode, 200);
            assert.strictEqual(binRes.body.some(d => d._id === String(testDoc._id)), true);

            // 4. Restore doc
            const restoreRes = await makeRequest(server, {
                method: 'PATCH',
                path: `/api/documents/${testDoc._id}/restore`,
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(restoreRes.statusCode, 200);

            // 5. Query documents list - should be visible again
            const listAgainRes = await makeRequest(server, {
                method: 'GET',
                path: '/api/documents',
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(listAgainRes.statusCode, 200);
            assert.strictEqual(listAgainRes.body.some(d => d._id === String(testDoc._id)), true);
        });

    } finally {
        // Clean up test documents & user
        await Document.deleteMany({ userId: testUser });
        await ScanJob.deleteMany({ userId: testUser });
        await User.deleteMany({ userId: testUser });
        server.close();
    }

    console.log('\n===============================================================');
    console.log(`  BACKEND RESULTS: ${passedCount} PASSED, ${failedCount} FAILED`);
    console.log('===============================================================\n');

    if (failedCount > 0) {
        process.exit(1);
    }
    process.exit(0);
}


runRegressionTests().catch(err => {
    console.error('Fatal test runner error:', err);
    process.exit(1);
});
