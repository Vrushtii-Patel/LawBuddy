const assert = require('assert');
const http = require('http');

// Set test environment variables before requiring index
process.env.NODE_ENV = 'test';
process.env.ALLOWED_ORIGINS = 'https://allowed.lawbuddy.example';
process.env.JWT_SECRET = 'test-jwt-secret-key-for-unit-tests-12345';

const { app } = require('../src/index');

function makeRequest(server, options, body = null) {
  return new Promise((resolve, reject) => {
    const addr = server.address();
    const reqOptions = {
      hostname: '127.0.0.1',
      port: addr.port,
      path: options.path || '/',
      method: options.method || 'GET',
      headers: options.headers || {}
    };

    const req = http.request(reqOptions, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
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
          body: parsed,
          rawData: data
        });
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(body);
    }
    req.end();
  });
}

async function runTests() {
  console.log('=== Starting Server Safety Nets Test Suite ===\n');

  // 1. Verify trust proxy is configured on the Express app
  console.log('--- Test 1: Trust Proxy Setting ---');
  const trustProxy = app.get('trust proxy');
  assert.ok(trustProxy !== false && trustProxy !== undefined, 'trust proxy must be enabled');
  assert.strictEqual(trustProxy, 1, 'trust proxy defaults to 1 hop');
  console.log('✓ Test 1 Passed: trust proxy is enabled (value: 1).');

  // 2. Verify process rejection and exception handlers
  console.log('\n--- Test 2: Process Event Handlers ---');
  const rejectionListeners = process.listeners('unhandledRejection');
  assert.ok(rejectionListeners.length > 0, 'process must have unhandledRejection listener');
  const exceptionListeners = process.listeners('uncaughtException');
  assert.ok(exceptionListeners.length > 0, 'process must have uncaughtException listener');
  console.log('✓ Test 2 Passed: unhandledRejection and uncaughtException listeners are registered.');

  // Create an HTTP server from the app to test HTTP middleware responses
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));

  try {
    // 3. Blocked CORS origin returns HTTP 403 with JSON (not HTML)
    console.log('\n--- Test 3: Blocked CORS Origin Returns JSON ---');
    const corsRes = await makeRequest(server, {
      path: '/api/health',
      method: 'GET',
      headers: {
        'Origin': 'https://malicious-disallowed-site.com'
      }
    });

    assert.strictEqual(corsRes.statusCode, 403, 'Blocked origin should return 403');
    assert.strictEqual(corsRes.headers['content-type']?.includes('application/json'), true, 'Content-Type must be JSON');
    assert.strictEqual(typeof corsRes.body, 'object', 'Response body must be JSON object');
    assert.strictEqual(corsRes.body.error, 'Not allowed by CORS');
    assert.strictEqual(corsRes.rawData.includes('<!DOCTYPE'), false, 'Response must not be HTML');
    console.log('✓ Test 3 Passed: Blocked CORS origin returns HTTP 403 JSON error without HTML.');

    // 4. Malformed JSON payload returns HTTP 400 with JSON (not HTML)
    console.log('\n--- Test 4: Malformed JSON Body Returns JSON ---');
    const malformedJsonRes = await makeRequest(server, {
      path: '/api/auth/login',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Origin': 'https://allowed.lawbuddy.example'
      }
    }, '{"email": "bad-json, incomplete');

    assert.strictEqual(malformedJsonRes.statusCode, 400, 'Malformed JSON should return 400');
    assert.strictEqual(malformedJsonRes.headers['content-type']?.includes('application/json'), true, 'Content-Type must be JSON');
    assert.strictEqual(typeof malformedJsonRes.body, 'object', 'Response body must be JSON object');
    assert.strictEqual(malformedJsonRes.body.error, 'Malformed JSON payload in request body.');
    assert.strictEqual(malformedJsonRes.rawData.includes('<!DOCTYPE'), false, 'Response must not be HTML');
    console.log('✓ Test 4 Passed: Malformed JSON body returns HTTP 400 JSON error without HTML.');

    // 5. Undefined route returns HTTP 404 with JSON (not HTML)
    console.log('\n--- Test 5: Unknown Route Returns JSON 404 ---');
    const notFoundRes = await makeRequest(server, {
      path: '/api/nonexistent-endpoint',
      method: 'GET',
      headers: {
        'Origin': 'https://allowed.lawbuddy.example'
      }
    });

    assert.strictEqual(notFoundRes.statusCode, 404, 'Unknown route should return 404');
    assert.strictEqual(notFoundRes.headers['content-type']?.includes('application/json'), true, 'Content-Type must be JSON');
    assert.strictEqual(typeof notFoundRes.body, 'object', 'Response body must be JSON object');
    assert.strictEqual(notFoundRes.body.error, 'Route not found');
    assert.strictEqual(notFoundRes.rawData.includes('<!DOCTYPE'), false, 'Response must not be HTML');
    console.log('✓ Test 5 Passed: Unknown route returns HTTP 404 JSON error without HTML.');

    console.log('\n🎉 ALL SERVER SAFETY NETS TESTS PASSED (100%)!\n');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

runTests().catch((err) => {
  console.error('Server safety nets test failed:', err);
  process.exit(1);
});
