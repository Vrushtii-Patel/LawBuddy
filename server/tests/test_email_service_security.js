const assert = require('assert');
const nodemailer = require('nodemailer');
const emailService = require('../src/services/emailService');

async function runTests() {
  console.log('--- Running emailService Security Tests ---');

  const originalEnv = { ...process.env };
  const originalCreateTransport = nodemailer.createTransport;

  function captureLogs(fn) {
    const logs = [];
    const originalLog = console.log;
    const originalError = console.error;
    const originalWarn = console.warn;

    console.log = (...args) => logs.push(args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' '));
    console.error = (...args) => logs.push(args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' '));
    console.warn = (...args) => logs.push(args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' '));

    return fn().finally(() => {
      console.log = originalLog;
      console.error = originalError;
      console.warn = originalWarn;
    }).then(result => ({ result, logs: logs.join('\n') }));
  }

  const testEmail = 'user@example.com';
  const secretOTP = '739201';

  try {
    // =========================================================================
    // Scenario A: SMTP Configured + Successful Send
    // =========================================================================
    {
      process.env.NODE_ENV = 'production';
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.SMTP_USER = 'test@test.com';
      process.env.SMTP_PASS = 'secretpass';
      process.env.SMTP_FROM = 'LawBuddy <test@test.com>';

      nodemailer.createTransport = () => ({
        sendMail: async (mailOptions) => {
          assert.strictEqual(mailOptions.to, testEmail);
          assert.ok(mailOptions.html.includes(secretOTP));
          return { messageId: '<test-message-id-123>' };
        }
      });

      const { result, logs } = await captureLogs(async () => {
        return await emailService.sendOTP(testEmail, secretOTP);
      });

      assert.strictEqual(result.success, true, 'Scenario A: expected success: true');
      assert.strictEqual(result.messageId, '<test-message-id-123>');
      assert.strictEqual(logs.includes(secretOTP), false, 'Scenario A: OTP must NOT be logged');
      console.log('✓ Scenario A PASSED: SMTP configured + successful send (success: true, OTP not logged)');
    }

    // =========================================================================
    // Scenario B: SMTP Configured + Simulated SMTP Failure
    // =========================================================================
    {
      process.env.NODE_ENV = 'production';
      process.env.SMTP_HOST = 'smtp.test.com';
      process.env.SMTP_USER = 'test@test.com';
      process.env.SMTP_PASS = 'secretpass';
      process.env.SMTP_FROM = 'LawBuddy <test@test.com>';

      nodemailer.createTransport = () => ({
        sendMail: async () => {
          throw new Error('Connection timeout to SMTP server');
        }
      });

      const { result, logs } = await captureLogs(async () => {
        return await emailService.sendOTP(testEmail, secretOTP);
      });

      assert.strictEqual(result.success, false, 'Scenario B: expected success: false');
      assert.strictEqual(logs.includes(secretOTP), false, 'Scenario B: OTP must NOT be logged on SMTP failure');
      assert.ok(logs.includes('Failed to send OTP email: Connection timeout to SMTP server'), 'Scenario B: safe error logged');
      console.log('✓ Scenario B PASSED: SMTP configured + failure (success: false, OTP not in logs/error)');
    }

    // =========================================================================
    // Scenario C: SMTP Unconfigured + Development Fallback Explicitly Enabled
    // =========================================================================
    {
      delete process.env.SMTP_HOST;
      delete process.env.SMTP_USER;
      delete process.env.SMTP_PASS;
      process.env.NODE_ENV = 'development';
      process.env.OTP_CONSOLE_FALLBACK = 'true';

      const { result, logs } = await captureLogs(async () => {
        return await emailService.sendOTP(testEmail, secretOTP);
      });

      assert.strictEqual(result.success, true, 'Scenario C: expected success: true in dev fallback');
      assert.strictEqual(result.messageId, 'dev-mode-otp');
      assert.ok(logs.includes(secretOTP), 'Scenario C: OTP is printed in dev console fallback');
      console.log('✓ Scenario C PASSED: SMTP unconfigured + dev fallback enabled (success: true, dev log printed)');
    }

    // =========================================================================
    // Scenario D: SMTP Unconfigured + NODE_ENV=production (even if OTP_CONSOLE_FALLBACK=true)
    // =========================================================================
    {
      delete process.env.SMTP_HOST;
      delete process.env.SMTP_USER;
      delete process.env.SMTP_PASS;
      process.env.NODE_ENV = 'production';
      process.env.OTP_CONSOLE_FALLBACK = 'true';

      const { result, logs } = await captureLogs(async () => {
        return await emailService.sendOTP(testEmail, secretOTP);
      });

      assert.strictEqual(result.success, false, 'Scenario D: expected success: false in production');
      assert.strictEqual(logs.includes(secretOTP), false, 'Scenario D: OTP must NEVER be logged in production');
      assert.ok(logs.includes('SMTP is not configured'), 'Scenario D: safe warning logged');
      console.log('✓ Scenario D PASSED: SMTP unconfigured + production (success: false, OTP refused and never logged)');
    }

    // =========================================================================
    // Scenario E: SMTP Unconfigured + Dev Mode but OTP_CONSOLE_FALLBACK not enabled
    // =========================================================================
    {
      delete process.env.SMTP_HOST;
      delete process.env.SMTP_USER;
      delete process.env.SMTP_PASS;
      process.env.NODE_ENV = 'development';
      delete process.env.OTP_CONSOLE_FALLBACK;

      const { result, logs } = await captureLogs(async () => {
        return await emailService.sendOTP(testEmail, secretOTP);
      });

      assert.strictEqual(result.success, false, 'Scenario E: expected success: false without fallback flag');
      assert.strictEqual(logs.includes(secretOTP), false, 'Scenario E: OTP must NOT be logged without explicit flag');
      console.log('✓ Scenario E PASSED: SMTP unconfigured + no fallback flag (success: false, OTP not logged)');
    }

    console.log('\nALL 5 EMAIL SECURITY TEST SCENARIOS PASSED SUCCESSFULLY!');
  } finally {
    process.env = originalEnv;
    nodemailer.createTransport = originalCreateTransport;
  }
}

runTests().catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
