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
const scanJobService = require('../src/services/scanJobService');
const llmService = require('../src/services/llmService');

const JWT_SECRET = process.env.JWT_SECRET || 'test_secret_key_12345';
process.env.JWT_SECRET = JWT_SECRET;

const app = express();
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ limit: '2mb', extended: true }));
app.use('/api', documentRoutes);

function createAuthToken(userId) {
    return jwt.sign({ userId, email: `${userId}@example.com` }, JWT_SECRET, { expiresIn: '1h' });
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
        // --- 1. AUTHENTICATION ENFORCEMENT ---
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

        await testCase('Reject /scan with invalid token (401)', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scan',
                headers: { 'Authorization': 'Bearer invalid.jwt.token' },
                body: { text: 'Test text' }
            });
            assert.strictEqual(res.statusCode, 401);
        });

        await testCase('Reject /scan-file without token (401)', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scan-file',
                body: { base64Data: 'dummy' }
            });
            assert.strictEqual(res.statusCode, 401);
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

        await testCase('POST /scan with empty body returns 400', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scan',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: {}
            });
            assert.strictEqual(res.statusCode, 400);
            assert.strictEqual(res.body.error, 'Document file or text description is required.');
        });

        await testCase('POST /scan-file with text only (no file/base64) returns 400', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scan-file',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: { text: 'Only text provided' }
            });
            assert.strictEqual(res.statusCode, 400);
            assert.strictEqual(res.body.error, 'Document file is required.');
        });

        // --- 3. MIME TYPE & SOURCE TYPE INFERENCE ---
        console.log('\n--- 3. MIME & sourceType Inference ---');
        await testCase('POST /scans/start with text infers text/plain and Text Description', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: { text: 'This is a sample agreement between parties.' }
            });
            assert.strictEqual(res.statusCode, 201);
            assert.ok(res.body.jobId);
            
            const job = await ScanJob.findOne({ jobId: res.body.jobId });
            assert.ok(job);
            assert.strictEqual(job.mimeType, 'text/plain');
            assert.strictEqual(job.sourceType, 'Text Description');
        });

        await testCase('POST /scans/start with multipart PDF infers application/pdf and PDF Document', async () => {
            const boundary = '----WebKitFormBoundaryRegressionTestPdf';
            const pdfBuffer = Buffer.from('%PDF-1.4 Mock PDF for regression test');
            const payload = createMultipartPayload(boundary, { title: 'Custom Lease' }, [
                { fieldname: 'document', filename: 'lease.pdf', contentType: 'application/pdf', content: pdfBuffer }
            ]);

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
            assert.strictEqual(job.title, 'Custom Lease');
        });

        await testCase('POST /scans/start with multipart PNG image infers Photo Scan', async () => {
            const boundary = '----WebKitFormBoundaryRegressionTestImg';
            const pngMagic = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
            const imgBuffer = Buffer.concat([pngMagic, Buffer.from('mock valid png payload')]);
            const payload = createMultipartPayload(boundary, {}, [
                { fieldname: 'document', filename: 'page1.png', contentType: 'image/png', content: imgBuffer }
            ]);

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
            assert.strictEqual(job.title, 'page1.png');
        });

        await testCase('POST /scans/start with base64Data infers PDF Document', async () => {
            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scans/start',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: {
                    base64Data: 'JVBERi0xLjQKJcTl8uXr...',
                    title: 'Base64 Scan'
                }
            });
            assert.strictEqual(res.statusCode, 201);
            const job = await ScanJob.findOne({ jobId: res.body.jobId });
            assert.ok(job);
            assert.strictEqual(job.mimeType, 'application/pdf');
            assert.strictEqual(job.sourceType, 'PDF Document');
        });

        // --- 4. RESPONSE SHAPING & CLAUSE METRICS ---
        console.log('\n--- 4. Response Shaping & Clause Metrics ---');
        await testCase('POST /scan synchronous response conforms to full schema with cached document', async () => {
            const sampleText = `Sample unique clause text ${Date.now()}`;
            const textBuffer = Buffer.from(sampleText, 'utf8');
            const calculatedHash = crypto.createHash('sha256').update(textBuffer).digest('hex');

            // Seed a cached completed job/document with exact matching hash and versions
            const doc = await Document.create({
                userId: testUser,
                fileHash: calculatedHash,
                title: 'Synchronous Scan Test Doc',
                originalText: sampleText,
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
                promptVersion: llmService.PROMPT_VERSION,
                modelName: llmService.MODEL_NAME,
                analysisVersion: llmService.ANALYSIS_VERSION
            });

            const res = await makeRequest(server, {
                method: 'POST',
                path: '/api/scan',
                headers: { 'Authorization': `Bearer ${validToken}` },
                body: {
                    text: sampleText,
                    title: 'Synchronous Scan Test Doc'
                }
            });

            assert.strictEqual(res.statusCode, 200);
            assert.ok(res.body.jobId);
            assert.strictEqual(res.body.cacheHit, true);
            assert.strictEqual(res.body.highRiskCount, 1);
            assert.strictEqual(res.body.cautionCount, 1);
            assert.strictEqual(res.body.compliantCount, 1);
            assert.strictEqual(res.body.totalClauseCount, 3);
            assert.strictEqual(res.body.riskLevel, 'High Risk');
            assert.ok(Array.isArray(res.body.analysis));
            assert.strictEqual(res.body.analysis.length, 3);
            assert.strictEqual(String(res.body.documentId), String(doc._id));
        });

        // --- 5. OVERSIZED FILES & DISGUISED EXECUTABLES ---
        console.log('\n--- 5. Security & Edge Cases ---');
        await testCase('Reject disguised executable file upload (.exe named as .pdf)', async () => {
            const boundary = '----WebKitFormBoundaryExecutableReject';
            // MZ header for DOS/PE executables
            const exeBuffer = Buffer.from([0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]);
            const payload = createMultipartPayload(boundary, {}, [
                { fieldname: 'document', filename: 'fake.pdf', contentType: 'application/pdf', content: exeBuffer }
            ]);

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
            assert.strictEqual(res.body.error, 'This file type is not supported. Please upload a PDF or supported image.');
        });

        // --- 6. DOCUMENT BIN & RESTORE INTEGRITY ---
        console.log('\n--- 6. Document Bin & Lifecycle Integrity ---');
        await testCase('Document soft-delete, get bin, and restore flow', async () => {
            const doc = await Document.create({
                userId: testUser,
                title: 'Bin Test Document',
                originalText: 'Agreement content',
                sourceType: 'Text Description',
                mimeType: 'text/plain',
                analysisStatus: 'completed'
            });

            // 1. Soft-delete
            const delRes = await makeRequest(server, {
                method: 'DELETE',
                path: `/api/documents/${doc._id}`,
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(delRes.statusCode, 200);
            assert.strictEqual(delRes.body.isDeleted, true);

            // 2. Query active documents (must NOT contain deleted doc)
            const activeDocsRes = await makeRequest(server, {
                method: 'GET',
                path: '/api/documents',
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(activeDocsRes.statusCode, 200);
            const foundInActive = activeDocsRes.body.find(d => d._id === String(doc._id));
            assert.strictEqual(foundInActive, undefined);

            // 3. Query bin
            const binDocsRes = await makeRequest(server, {
                method: 'GET',
                path: '/api/documents/bin',
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(binDocsRes.statusCode, 200);
            const foundInBin = binDocsRes.body.find(d => d._id === String(doc._id));
            assert.ok(foundInBin);

            // 4. Restore document
            const restoreRes = await makeRequest(server, {
                method: 'PATCH',
                path: `/api/documents/${doc._id}/restore`,
                headers: { 'Authorization': `Bearer ${validToken}` }
            });
            assert.strictEqual(restoreRes.statusCode, 200);
            assert.strictEqual(restoreRes.body.document.isDeleted, false);
        });

        // Clean up
        await Document.deleteMany({ userId: testUser });
        await ScanJob.deleteMany({ userId: testUser });

    } finally {
        server.close();
    }

    console.log(`\n===============================================================`);
    console.log(`  BACKEND RESULTS: ${passedCount} PASSED, ${failedCount} FAILED`);
    console.log(`===============================================================\n`);

    if (failedCount > 0) {
        process.exit(1);
    }
}

runRegressionTests().catch(err => {
    console.error('Fatal regression runner error:', err);
    process.exit(1);
});
