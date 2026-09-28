process.env.NODE_ENV = 'test';
require('dotenv').config();
if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = 'test_jwt_secret_for_auth_refactor_12345';
}
const assert = require('assert');
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { MongoMemoryServer } = require('mongodb-memory-server');

const JWT_SECRET = require('../src/config/jwt');
const User = require('../src/models/User');
const Otp = require('../src/models/Otp');
const authRoutes = require('../src/routes/authRoutes');
const emailService = require('../src/services/emailService');
const { validatePassword } = require('../src/utils/passwordValidator');

// Intercept emails sent during tests to verify counts & arguments
let sentEmails = [];
const originalSendOTP = emailService.sendOTP;
emailService.sendOTP = async (email, otp) => {
  sentEmails.push({ email, otp, timestamp: Date.now() });
  return { success: true, messageId: `mock-${Date.now()}` };
};

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/api/auth', authRoutes);

function makeRequest(server, { method, path, headers = {}, body = null }) {
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

    if (body) {
      const jsonStr = typeof body === 'string' ? body : JSON.stringify(body);
      options.headers['Content-Type'] = 'application/json';
      options.headers['Content-Length'] = Buffer.byteLength(jsonStr);
    }

    const req = http.request(options, (res) => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let json = null;
        try {
          json = JSON.parse(raw);
        } catch (_) {}
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: json,
          raw
        });
      });
    });

    req.on('error', reject);
    if (body) {
      const jsonStr = typeof body === 'string' ? body : JSON.stringify(body);
      req.write(jsonStr);
    }
    req.end();
  });
}

function scanForSensitiveLeaks(obj, path = '') {
  if (!obj || typeof obj !== 'object') return;
  const forbiddenKeys = ['passwordHash', 'tokenVersion', 'otpHash', 'password'];
  for (const key of Object.keys(obj)) {
    const currentPath = path ? `${path}.${key}` : key;
    if (forbiddenKeys.includes(key)) {
      throw new Error(`CRITICAL LEAK: Response body exposed sensitive field "${currentPath}"`);
    }
    if (typeof obj[key] === 'object') {
      scanForSensitiveLeaks(obj[key], currentPath);
    }
  }
}

async function runTests() {
  console.log('\n=============================================================');
  console.log('  LAWBUDDY AUTH REFACTOR — INTEGRATION & UNIT TEST SUITE');
  console.log('=============================================================\n');

  const mongod = await MongoMemoryServer.create();
  const uri = mongod.getUri();
  await mongoose.connect(uri);

  const server = http.createServer(app);
  await new Promise(resolve => server.listen(0, resolve));

  try {
    // -----------------------------------------------------------------------
    // SECTION 1: PASSWORD VALIDATOR UNIT TESTS
    // -----------------------------------------------------------------------
    console.log('--- SECTION 1: Password Validator Unit Tests ---');
    
    assert.strictEqual(validatePassword('').valid, false, 'Empty password rejected');
    assert.strictEqual(validatePassword('short1A').valid, false, 'Password < 8 chars rejected');
    assert.strictEqual(validatePassword('nouppernonumber').valid, false, 'Password with no numbers rejected');
    assert.strictEqual(validatePassword('1234567890').valid, false, 'Password with no letters rejected');
    assert.strictEqual(validatePassword('password123').valid, false, 'Common password rejected');
    assert.strictEqual(validatePassword('A'.repeat(73) + '1').valid, false, 'Password > 72 bytes rejected');
    assert.strictEqual(validatePassword('ValidPass123!').valid, true, 'Valid password accepted');
    assert.strictEqual(validatePassword('a'.repeat(71) + '1').valid, true, '72-byte valid password accepted');
    console.log('✓ Password rules (length, letter, number, byte limit, common blacklist) verified.');

    // -----------------------------------------------------------------------
    // SECTION 2: SIGNUP ENDPOINT TESTS
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 2: Signup Endpoint Tests ---');
    sentEmails = [];

    // 2.1 Terms required
    let res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Terms Test', email: 'terms_test@example.com', password: 'StrongPassword1', accepted_terms: false }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'TERMS_REQUIRED');
    console.log('✓ Signup with terms=false rejected with TERMS_REQUIRED.');

    // 2.2 Weak password
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Weak Pass Test', email: 'weak_test@example.com', password: '123', accepted_terms: true }
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.code, 'WEAK_PASSWORD');
    console.log('✓ Signup with weak password rejected with WEAK_PASSWORD.');

    // 2.3 Valid signup
    sentEmails = [];
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Alice Smith', email: 'alice_signup@example.com', password: 'StrongPassword1', accepted_terms: true }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.requiresVerification, true);
    scanForSensitiveLeaks(res.body);

    const userInDb = await User.findOne({ email: 'alice_signup@example.com' });
    assert.ok(userInDb, 'User created in DB');
    assert.strictEqual(userInDb.emailVerified, false, 'User is initially unverified');
    assert.ok(userInDb.passwordHash, 'Password hash stored');
    assert.strictEqual(sentEmails.length, 1, 'Exactly 1 OTP email sent');
    console.log('✓ Valid signup creates unverified user and sends 1 signup OTP.');

    // 2.4 Duplicate signup when unverified (overwrites hash, resends OTP, no duplicate doc)
    sentEmails = [];
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Alice Updated', email: 'alice_signup@example.com', password: 'NewStrongPassword2', accepted_terms: true }
    });
    assert.strictEqual(res.status, 200);
    const userCount = await User.countDocuments({ email: 'alice_signup@example.com' });
    assert.strictEqual(userCount, 1, 'No duplicate user doc created');
    const updatedUserInDb = await User.findOne({ email: 'alice_signup@example.com' });
    assert.strictEqual(updatedUserInDb.full_name, 'Alice Updated');
    assert.strictEqual(sentEmails.length, 1, 'Resent 1 new OTP email');
    console.log('✓ Signup for unverified email overwrites details and resends OTP without creating duplicate.');

    // -----------------------------------------------------------------------
    // SECTION 3: EMAIL VERIFICATION TESTS
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 3: Email Verification Tests ---');

    // Create a specific user for verification failure testing
    const lockoutEmail = 'lockout_test@example.com';
    sentEmails = [];
    await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Lockout User', email: lockoutEmail, password: 'LockoutPassword1', accepted_terms: true }
    });
    const lockoutOtp = sentEmails[0].otp;

    // 3.1 Wrong OTP attempt counter & lockout at 5th attempt
    for (let i = 1; i <= 4; i++) {
      res = await makeRequest(server, {
        method: 'POST',
        path: '/api/auth/verify-email',
        body: { email: lockoutEmail, otp: '000000' }
      });
      assert.strictEqual(res.status, 400);
      assert.strictEqual(res.body.error, 'Invalid OTP');
    }
    // 5th attempt -> 429 and deleted
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/verify-email',
      body: { email: lockoutEmail, otp: '000000' }
    });
    assert.strictEqual(res.status, 429);
    const otpAfterLockout = await Otp.findOne({ email: lockoutEmail, purpose: 'signup' });
    assert.strictEqual(otpAfterLockout, null, 'OTP deleted after 5 failed attempts');
    console.log('✓ Wrong OTP increments attempts; 5th failed attempt returns 429 and deletes OTP.');

    // 3.2 Expired OTP rejection
    const expireTestEmail = 'expire_test@example.com';
    sentEmails = [];
    await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Expire User', email: expireTestEmail, password: 'ExpirePassword1', accepted_terms: true }
    });
    const expireOtp = sentEmails[0].otp;

    await Otp.updateOne({ email: expireTestEmail, purpose: 'signup' }, { expiresAt: new Date(Date.now() - 1000) });
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/verify-email',
      body: { email: expireTestEmail, otp: expireOtp }
    });
    assert.strictEqual(res.status, 400);
    assert.ok(res.body.error.toLowerCase().includes('expired'));
    console.log('✓ Expired OTP is cleanly rejected.');

    // 3.3 Valid verification for alice_signup
    const aliceValidOtp = (await Otp.findOne({ email: 'alice_signup@example.com', purpose: 'signup' })) ? sentEmails[sentEmails.length - 1].otp : null;
    // Get latest OTP from DB hash match or resend
    sentEmails = [];
    const verifyUserEmail = 'verified_alice@example.com';
    await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Alice Verified', email: verifyUserEmail, password: 'NewStrongPassword2', accepted_terms: true }
    });
    const validVerifyOtp = sentEmails[0].otp;

    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/verify-email',
      body: { email: verifyUserEmail, otp: validVerifyOtp }
    });
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.token, 'Token returned on successful verification');
    assert.strictEqual(res.body.user.emailVerified, true);
    scanForSensitiveLeaks(res.body);

    const verifiedUser = await User.findOne({ email: verifyUserEmail });
    assert.strictEqual(verifiedUser.emailVerified, true);
    console.log('✓ Correct OTP verifies email, returns JWT and user payload without sensitive leaks.');

    // 3.4 Signup on already verified email -> 409 ACCOUNT_EXISTS, NO OTP sent
    sentEmails = [];
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Alice Duplicate', email: verifyUserEmail, password: 'SomePassword99', accepted_terms: true }
    });
    assert.strictEqual(res.status, 409);
    assert.strictEqual(res.body.code, 'ACCOUNT_EXISTS');
    assert.strictEqual(sentEmails.length, 0, 'No OTP sent for verified user signup attempt');
    console.log('✓ Signup for existing verified account returns 409 ACCOUNT_EXISTS with NO OTP sent.');

    // -----------------------------------------------------------------------
    // SECTION 4: LOGIN ENDPOINT TESTS
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 4: Login Endpoint Tests ---');
    sentEmails = [];

    // 4.1 Success login
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: verifyUserEmail, password: 'NewStrongPassword2' }
    });
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.token);
    assert.strictEqual(res.body.user.email, verifyUserEmail);
    assert.strictEqual(sentEmails.length, 0, 'Login NEVER sends OTP');
    scanForSensitiveLeaks(res.body);
    const aliceToken = res.body.token;
    console.log('✓ Valid login returns JWT and user payload; sends zero OTPs.');

    // 4.2 Wrong password vs Unknown email -> Identical 401 response
    const wrongPassRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: verifyUserEmail, password: 'WrongPassword99' }
    });
    const unknownEmailRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: 'nonexistent@example.com', password: 'SomePassword123' }
    });
    assert.strictEqual(wrongPassRes.status, 401);
    assert.strictEqual(unknownEmailRes.status, 401);
    assert.strictEqual(wrongPassRes.body.error, 'Invalid email or password');
    assert.strictEqual(unknownEmailRes.body.error, 'Invalid email or password');
    console.log('✓ Unknown email and incorrect password return identical 401 response.');

    // 4.3 Unverified user login -> 403 EMAIL_NOT_VERIFIED
    const unverifiedUser = new User({
      userId: 'usr_unverified_test_1',
      full_name: 'Bob Unverified',
      email: 'bob_unverified@example.com',
      passwordHash: await bcrypt.hash('BobPassword123', 12),
      emailVerified: false
    });
    await unverifiedUser.save();

    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: 'bob_unverified@example.com', password: 'BobPassword123' }
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'EMAIL_NOT_VERIFIED');
    assert.strictEqual(res.body.token, undefined);
    console.log('✓ Login for unverified account returns 403 EMAIL_NOT_VERIFIED with no token issued.');

    // 4.4 Legacy user with no password -> 403 PASSWORD_NOT_SET
    const legacyUser = new User({
      userId: 'usr_legacy_test_1',
      full_name: 'Carol Legacy',
      email: 'carol_legacy@example.com',
      emailVerified: true
    });
    await legacyUser.save();

    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: 'carol_legacy@example.com', password: 'AnyPassword123' }
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.code, 'PASSWORD_NOT_SET');
    console.log('✓ Legacy user without passwordHash returns 403 PASSWORD_NOT_SET.');

    // -----------------------------------------------------------------------
    // SECTION 5: FORGOT & RESET PASSWORD FLOW
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 5: Forgot & Reset Password Flow ---');
    sentEmails = [];

    // 5.1 Forgot password returns same generic message for existing & unknown email
    const forgotExisting = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/forgot-password',
      body: { email: verifyUserEmail }
    });
    const forgotUnknown = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/forgot-password',
      body: { email: 'unknown_pw@example.com' }
    });
    assert.strictEqual(forgotExisting.status, 200);
    assert.strictEqual(forgotUnknown.status, 200);
    assert.strictEqual(forgotExisting.body.message, forgotUnknown.body.message);
    assert.strictEqual(sentEmails.length, 1, 'Only sent OTP for existing user');
    const resetOtp = sentEmails[0].otp;
    console.log('✓ Forgot-password returns identical generic 200 for existing and unknown accounts.');

    // 5.2 Purpose isolation: Try using reset OTP for verify-email -> Must fail
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/verify-email',
      body: { email: verifyUserEmail, otp: resetOtp }
    });
    assert.strictEqual(res.status, 400, 'Reset OTP cannot be used for signup verification');

    // 5.3 Reset password flow
    res = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/reset-password',
      body: { email: verifyUserEmail, otp: resetOtp, new_password: 'BrandNewPassword3' }
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.token, undefined, 'No token issued in reset response');
    console.log('✓ Reset password succeeds with valid OTP and updates credentials.');

    // 5.4 Old password fails, new password succeeds
    const oldLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: verifyUserEmail, password: 'NewStrongPassword2' }
    });
    assert.strictEqual(oldLoginRes.status, 401, 'Old password rejected');

    const newLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: verifyUserEmail, password: 'BrandNewPassword3' }
    });
    assert.strictEqual(newLoginRes.status, 200, 'New password accepted');

    // 5.5 Previous JWT is invalidated after reset due to tokenVersion increment
    const oldJwtAuthCheck = await makeRequest(server, {
      method: 'GET',
      path: '/api/auth/me',
      headers: { Authorization: `Bearer ${aliceToken}` }
    });
    assert.strictEqual(oldJwtAuthCheck.status, 401, 'Prior token rejected after password reset');
    console.log('✓ Token revocation after reset: old token invalidated, old password rejected, new password logs in.');

    // 5.6 Legacy user password reset & login
    sentEmails = [];
    await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/forgot-password',
      body: { email: 'carol_legacy@example.com' }
    });
    assert.strictEqual(sentEmails.length, 1);
    const carolOtp = sentEmails[0].otp;

    const carolResetRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/reset-password',
      body: { email: 'carol_legacy@example.com', otp: carolOtp, new_password: 'CarolPassword123' }
    });
    assert.strictEqual(carolResetRes.status, 200);

    const carolLoginRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: 'carol_legacy@example.com', password: 'CarolPassword123' }
    });
    assert.strictEqual(carolLoginRes.status, 200, 'Legacy user successfully logged in after setting password');
    console.log('✓ Legacy user can successfully reset password and log in.');

    // -----------------------------------------------------------------------
    // SECTION 6: JWT BACKWARD COMPATIBILITY & LOGOUT
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 6: JWT Backward Compatibility & Logout ---');

    // 6.1 Legacy JWT without tokenVersion claim works for user at tokenVersion 0
    const legacyJwt = jwt.sign(
      { userId: carolLoginRes.body.user.userId, email: 'carol_legacy@example.com', role: 'user' },
      JWT_SECRET,
      { expiresIn: '7d' }
    );
    // Carol's tokenVersion was incremented to 1 during reset, let's reset to 0 to test legacy claims
    await User.updateOne({ email: 'carol_legacy@example.com' }, { tokenVersion: 0 });
    const legacyJwtRes = await makeRequest(server, {
      method: 'GET',
      path: '/api/auth/me',
      headers: { Authorization: `Bearer ${legacyJwt}` }
    });
    assert.strictEqual(legacyJwtRes.status, 200, 'Legacy JWT with no tokenVersion claim is accepted at tokenVersion 0');
    console.log('✓ Legacy JWT without tokenVersion claim works seamlessly for users at version 0.');

    // 6.2 Logout increments tokenVersion and invalidates the session
    const currentCarolToken = carolLoginRes.body.token;
    await User.updateOne({ email: 'carol_legacy@example.com' }, { tokenVersion: 1 }); // restore version 1 matching carolLoginRes token
    
    const logoutRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/logout',
      headers: { Authorization: `Bearer ${currentCarolToken}` }
    });
    assert.strictEqual(logoutRes.status, 200);

    const afterLogoutMe = await makeRequest(server, {
      method: 'GET',
      path: '/api/auth/me',
      headers: { Authorization: `Bearer ${currentCarolToken}` }
    });
    assert.strictEqual(afterLogoutMe.status, 401, 'Token revoked after logout');
    console.log('✓ Logout endpoint increments tokenVersion and revokes active token.');

    // -----------------------------------------------------------------------
    // SECTION 7: PROFILE UPDATE & DEPRECATED ROUTES
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 7: Profile Update & Deprecated Routes ---');

    // Log in alice to get fresh token
    const aliceLogin = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/login',
      body: { email: verifyUserEmail, password: 'BrandNewPassword3' }
    });
    const activeAliceToken = aliceLogin.body.token;

    // 7.1 Profile update with valid fields
    const profileUpdateRes = await makeRequest(server, {
      method: 'PUT',
      path: '/api/auth/profile',
      headers: { Authorization: `Bearer ${activeAliceToken}` },
      body: {
        full_name: 'Alice Wonderland',
        preferredLanguage: 'hi',
        dateOfBirth: '1995-05-15',
        profile_photo: 'https://example.com/alice.png',
        email: 'hacked@example.com', // Prohibited
        role: 'admin' // Prohibited
      }
    });
    assert.strictEqual(profileUpdateRes.status, 200);
    assert.strictEqual(profileUpdateRes.body.user.full_name, 'Alice Wonderland');
    assert.strictEqual(profileUpdateRes.body.user.preferredLanguage, 'hi');
    assert.strictEqual(profileUpdateRes.body.user.email, verifyUserEmail, 'Email untouched');
    assert.strictEqual(profileUpdateRes.body.user.role, 'user', 'Role untouched');
    scanForSensitiveLeaks(profileUpdateRes.body);
    console.log('✓ Profile update modifies allowed fields and ignores email/role tampering.');

    // 7.2 Invalid dateOfBirth validation
    const futureDobRes = await makeRequest(server, {
      method: 'PUT',
      path: '/api/auth/profile',
      headers: { Authorization: `Bearer ${activeAliceToken}` },
      body: { dateOfBirth: '2099-01-01' }
    });
    assert.strictEqual(futureDobRes.status, 400);

    const oldDobRes = await makeRequest(server, {
      method: 'PUT',
      path: '/api/auth/profile',
      headers: { Authorization: `Bearer ${activeAliceToken}` },
      body: { dateOfBirth: '1899-12-31' }
    });
    assert.strictEqual(oldDobRes.status, 400);
    console.log('✓ Invalid dateOfBirth (future date or pre-1900) correctly rejected.');

    // 7.3 Deprecated routes return 410
    const sendOtp410 = await makeRequest(server, { method: 'POST', path: '/api/auth/send-otp', body: {} });
    const verifyOtp410 = await makeRequest(server, { method: 'POST', path: '/api/auth/verify-otp', body: {} });
    assert.strictEqual(sendOtp410.status, 410);
    assert.strictEqual(verifyOtp410.status, 410);
    assert.strictEqual(sendOtp410.body.error, 'Please update the app.');
    console.log('✓ Deprecated /send-otp and /verify-otp return 410 Gone.');

    // -----------------------------------------------------------------------
    // SECTION 8: RESEND OTP TESTS (PURPOSE & COOLDOWN)
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 8: Resend OTP Tests ---');
    sentEmails = [];

    // Create an unverified user for resend signup testing
    const resendSignupEmail = 'resend_unverified@example.com';
    await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/signup',
      body: { full_name: 'Resend User', email: resendSignupEmail, password: 'ResendPassword1', accepted_terms: true }
    });
    sentEmails = [];

    // Cooldown test: immediately resending fails with 429
    const cooldownRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/resend-otp',
      body: { email: resendSignupEmail, purpose: 'signup' }
    });
    assert.strictEqual(cooldownRes.status, 429, '30s cooldown enforced');
    assert.ok(cooldownRes.body.error.includes('30 seconds'));

    // Move createdAt back 35 seconds to bypass cooldown
    await Otp.updateOne(
      { email: resendSignupEmail, purpose: 'signup' },
      { createdAt: new Date(Date.now() - 35 * 1000) }
    );

    // Resend for unverified account succeeds
    const resendSuccess = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/resend-otp',
      body: { email: resendSignupEmail, purpose: 'signup' }
    });
    assert.strictEqual(resendSuccess.status, 200);
    assert.strictEqual(sentEmails.length, 1, 'OTP sent for unverified signup resend');
    console.log('✓ Resend-otp enforces 30s cooldown and resends OTP for unverified signup.');

    // Resend signup for verified account sends NO email (generic 200)
    sentEmails = [];
    const resendVerifiedRes = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/resend-otp',
      body: { email: verifyUserEmail, purpose: 'signup' }
    });
    assert.strictEqual(resendVerifiedRes.status, 200);
    assert.strictEqual(sentEmails.length, 0, 'No email sent for verified user signup resend');

    // Resend reset for unknown account sends NO email (generic 200)
    sentEmails = [];
    const resendUnknownReset = await makeRequest(server, {
      method: 'POST',
      path: '/api/auth/resend-otp',
      body: { email: 'unknown_resend@example.com', purpose: 'reset' }
    });
    assert.strictEqual(resendUnknownReset.status, 200);
    assert.strictEqual(sentEmails.length, 0, 'No email sent for unknown reset resend');
    console.log('✓ Resend-otp returns generic 200 and only delivers emails to eligible accounts.');

    // -----------------------------------------------------------------------
    // SECTION 9: MISSING INPUT & ERROR RESILIENCE TESTS
    // -----------------------------------------------------------------------
    console.log('\n--- SECTION 9: Missing Input & Error Resilience Tests ---');

    // Testing empty / null / undefined email inputs against all routes to verify no 500 crashes
    const emptyEmailSignup = await makeRequest(server, { method: 'POST', path: '/api/auth/signup', body: {} });
    assert.strictEqual(emptyEmailSignup.status, 400);

    const emptyEmailLogin = await makeRequest(server, { method: 'POST', path: '/api/auth/login', body: {} });
    assert.strictEqual(emptyEmailLogin.status, 400);

    const emptyEmailForgot = await makeRequest(server, { method: 'POST', path: '/api/auth/forgot-password', body: {} });
    assert.strictEqual(emptyEmailForgot.status, 400);

    const emptyEmailVerify = await makeRequest(server, { method: 'POST', path: '/api/auth/verify-email', body: {} });
    assert.strictEqual(emptyEmailVerify.status, 400);

    const emptyEmailReset = await makeRequest(server, { method: 'POST', path: '/api/auth/reset-password', body: {} });
    assert.strictEqual(emptyEmailReset.status, 400);

    const emptyEmailResend = await makeRequest(server, { method: 'POST', path: '/api/auth/resend-otp', body: {} });
    assert.strictEqual(emptyEmailResend.status, 400);

    console.log('✓ All authentication endpoints cleanly handle missing/null inputs with 400 without crashing (0 500s).');

    console.log('\n=============================================================');
    console.log('  🎉 ALL AUTH REFACTOR INTEGRATION TESTS PASSED (100%)');
    console.log('=============================================================\n');

  } finally {
    await new Promise(resolve => server.close(resolve));
    await mongoose.disconnect();
    await mongod.stop();
    emailService.sendOTP = originalSendOTP;
  }
}

if (require.main === module) {
  runTests().catch(err => {
    console.error('Test failed with error:', err);
    process.exit(1);
  });
}

module.exports = runTests;
