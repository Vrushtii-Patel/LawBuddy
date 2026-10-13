const assert = require('assert');
const path = require('path');
const { spawnSync } = require('child_process');

const serverRoot = path.resolve(__dirname, '..');
const entryPoint = path.join(serverRoot, 'src', 'index.js');
const testSecret = 'production-startup-test-secret-123456789';

function runProductionStartup(mongodbUri, allowedOrigins = 'https://lawbuddy.example') {
  const env = {
    ...process.env,
    NODE_ENV: 'production',
    JWT_SECRET: testSecret,
    PORT: '0',
    MONGODB_URI: mongodbUri,
    ALLOWED_ORIGINS: allowedOrigins
  };

  return spawnSync(process.execPath, [entryPoint], {
    cwd: serverRoot,
    env,
    encoding: 'utf8',
    timeout: 8000
  });
}

function outputOf(result) {
  return (result.stdout || '') + (result.stderr || '');
}

// Missing database configuration must fail before the server accepts traffic.
const missingUri = runProductionStartup('');
assert.strictEqual(missingUri.error, undefined, 'Startup process should not time out');
assert.strictEqual(missingUri.status, 1, 'Missing production MONGODB_URI must exit non-zero');
assert.match(outputOf(missingUri), /MONGODB_URI must be configured in production/);
assert.doesNotMatch(outputOf(missingUri), /Server running on port/);
assert.doesNotMatch(outputOf(missingUri), /in-memory MongoDB for development/);

// A malformed/unreachable production URI must fail closed, never fall back to
// mongodb-memory-server, and never begin listening.
const invalidUri = runProductionStartup('not-a-valid-mongodb-uri');
assert.strictEqual(invalidUri.error, undefined, 'Startup process should not time out');
assert.strictEqual(invalidUri.status, 1, 'Failed production DB connection must exit non-zero');
assert.match(outputOf(invalidUri), /Could not connect to the configured production MongoDB database/);
assert.doesNotMatch(outputOf(invalidUri), /in-memory MongoDB for development/);
assert.doesNotMatch(outputOf(invalidUri), /Server running on port/);

console.log('✓ Production startup fails closed when MONGODB_URI is missing.');
console.log('✓ Production startup fails closed on database connection errors without memory fallback.');

const missingOrigins = runProductionStartup('not-a-valid-mongodb-uri', '');
assert.strictEqual(missingOrigins.error, undefined, 'Startup process should not time out');
assert.strictEqual(missingOrigins.status, 1, 'Missing production ALLOWED_ORIGINS must exit non-zero');
assert.match(outputOf(missingOrigins), /ALLOWED_ORIGINS must be configured in production/);
assert.doesNotMatch(outputOf(missingOrigins), /Server running on port/);
console.log('✓ Production startup fails closed when ALLOWED_ORIGINS is missing.');
