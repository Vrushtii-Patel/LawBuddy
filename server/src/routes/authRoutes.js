const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const JWT_SECRET = require('../config/jwt');
const User = require('../models/User');
const Otp = require('../models/Otp');
const emailService = require('../services/emailService');
const { isValidEmail, sanitizeInput, requireAuth } = require('../middleware/authMiddleware');
const { validatePassword } = require('../utils/passwordValidator');
const {
  otpRequestIpLimiter,
  otpRequestEmailLimiter,
  otpVerifyIpLimiter,
  otpVerifyEmailLimiter,
  loginIpLimiter,
  loginEmailLimiter
} = require('../middleware/rateLimitMiddleware');

function generateUserId() {
  return 'usr_' + Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
}

function generateOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

function formatUserResponse(user) {
  const obj = user.toObject ? user.toObject() : { ...user };
  return {
    userId: obj.userId,
    full_name: obj.full_name,
    email: obj.email,
    role: obj.role || 'user',
    emailVerified: Boolean(obj.emailVerified),
    created_at: obj.created_at,
    last_login: obj.last_login,
    profile_photo: obj.profile_photo,
    dateOfBirth: obj.dateOfBirth || null,
    preferredLanguage: obj.preferredLanguage || null,
    termsAcceptedAt: obj.termsAcceptedAt || null,
    termsVersion: obj.termsVersion || null
  };
}

// =========================================================================
// 1) POST /api/auth/signup {full_name, email, password, accepted_terms}
// =========================================================================
router.post('/signup', otpRequestIpLimiter, otpRequestEmailLimiter, async (req, res) => {
  try {
    const { full_name, email, password, accepted_terms } = req.body;

    if (accepted_terms !== true) {
      return res.status(400).json({
        error: 'You must accept the terms of service and privacy policy to sign up.',
        code: 'TERMS_REQUIRED'
      });
    }

    if (!full_name || typeof full_name !== 'string' || sanitizeInput(full_name).length === 0) {
      return res.status(400).json({ error: 'Full name is required' });
    }

    if (!email || typeof email !== 'string' || !isValidEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address' });
    }

    const passValidation = validatePassword(password);
    if (!passValidation.valid) {
      return res.status(400).json({
        error: passValidation.error,
        code: passValidation.code
      });
    }

    const cleanEmail = sanitizeInput(email).toLowerCase();
    const cleanName = sanitizeInput(full_name);

    const existingUser = await User.findOne({ email: cleanEmail });
    if (existingUser && existingUser.emailVerified) {
      return res.status(409).json({
        error: 'Account already exists. Please log in instead.',
        code: 'ACCOUNT_EXISTS'
      });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const otp = generateOtp();
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);

    if (existingUser && !existingUser.emailVerified) {
      existingUser.full_name = cleanName;
      existingUser.passwordHash = passwordHash;
      existingUser.password = undefined;
      existingUser.termsAcceptedAt = new Date();
      existingUser.termsVersion = '1.0';
      existingUser.updated_at = new Date();
      await existingUser.save();
    } else {
      const newUser = new User({
        userId: generateUserId(),
        full_name: cleanName,
        email: cleanEmail,
        passwordHash,
        emailVerified: false,
        termsAcceptedAt: new Date(),
        termsVersion: '1.0',
        created_at: new Date(),
        last_login: new Date(),
        profile_photo: `https://api.dicebear.com/7.x/bottts/svg?seed=${encodeURIComponent(cleanName)}`
      });
      await newUser.save();
    }

    await Otp.deleteMany({ email: cleanEmail, purpose: 'signup' });

    const newOtp = new Otp({
      email: cleanEmail,
      purpose: 'signup',
      otpHash,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000)
    });
    await newOtp.save();

    const emailResult = await emailService.sendOTP(cleanEmail, otp);
    if (!emailResult.success) {
      return res.status(500).json({ error: 'Failed to send OTP email. Please check your email configuration.' });
    }

    res.status(200).json({
      message: 'Verification code sent to your email',
      requiresVerification: true
    });
  } catch (err) {
    console.error('Signup error:', err);
    res.status(500).json({ error: 'Internal server error during registration' });
  }
});

// =========================================================================
// 2) POST /api/auth/verify-email {email, otp} (purpose 'signup')
// =========================================================================
router.post('/verify-email', otpVerifyIpLimiter, otpVerifyEmailLimiter, async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || typeof email !== 'string' || !otp || typeof otp !== 'string') {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    const cleanEmail = sanitizeInput(email).toLowerCase();

    const otpRecord = await Otp.findOne({ email: cleanEmail, purpose: 'signup' });
    if (!otpRecord) {
      return res.status(400).json({ error: 'OTP expired or not found. Please request a new one.' });
    }

    if (otpRecord.attempts >= 5) {
      await Otp.deleteMany({ email: cleanEmail, purpose: 'signup' });
      return res.status(429).json({ error: 'Maximum attempts reached. Please request a new OTP.' });
    }

    if (new Date() > otpRecord.expiresAt) {
      await Otp.deleteMany({ email: cleanEmail, purpose: 'signup' });
      return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
    }

    const isMatch = await bcrypt.compare(otp, otpRecord.otpHash);
    if (!isMatch) {
      otpRecord.attempts += 1;
      if (otpRecord.attempts >= 5) {
        await Otp.deleteMany({ email: cleanEmail, purpose: 'signup' });
        return res.status(429).json({ error: 'Maximum attempts reached. Please request a new OTP.' });
      }
      await otpRecord.save();
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    await Otp.deleteMany({ email: cleanEmail, purpose: 'signup' });

    const user = await User.findOne({ email: cleanEmail });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    user.emailVerified = true;
    user.last_login = new Date();
    await user.save();

    const token = jwt.sign(
      { userId: user.userId, email: user.email, role: user.role || 'user', tokenVersion: user.tokenVersion || 0 },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(200).json({
      message: 'Email verified successfully',
      token,
      user: formatUserResponse(user)
    });
  } catch (err) {
    console.error('Verify email error:', err);
    res.status(500).json({ error: 'Internal server error during verification' });
  }
});

// =========================================================================
// 3) POST /api/auth/login {email, password}
// =========================================================================
router.post('/login', loginIpLimiter, loginEmailLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || typeof email !== 'string' || !password || typeof password !== 'string') {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const cleanEmail = sanitizeInput(email).toLowerCase();
    const user = await User.findOne({ email: cleanEmail });

    if (!user) {
      // Prevent timing attacks by running a dummy bcrypt comparison
      await bcrypt.compare(password, '$2a$12$e8ul2v8.Hw/Lz5l7jJ84n.q1sF9y6GkH/J4u2v8.Hw/Lz5l7jJ84n');
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    if (!user.passwordHash && !user.password) {
      return res.status(403).json({
        error: 'Password has not been set for this account. Please reset your password to log in.',
        code: 'PASSWORD_NOT_SET'
      });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash || user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    if (!user.emailVerified) {
      return res.status(403).json({
        error: 'Please verify your email address before logging in.',
        code: 'EMAIL_NOT_VERIFIED'
      });
    }

    user.last_login = new Date();
    await user.save();

    const token = jwt.sign(
      { userId: user.userId, email: user.email, role: user.role || 'user', tokenVersion: user.tokenVersion || 0 },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(200).json({
      message: 'Login successful',
      token,
      user: formatUserResponse(user)
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Internal server error during login' });
  }
});

// =========================================================================
// 4) POST /api/auth/forgot-password {email}
// =========================================================================
router.post('/forgot-password', otpRequestIpLimiter, otpRequestEmailLimiter, async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'Email is required' });
    }

    const cleanEmail = sanitizeInput(email).toLowerCase();
    const user = await User.findOne({ email: cleanEmail });

    if (user) {
      const otp = generateOtp();
      const salt = await bcrypt.genSalt(10);
      const otpHash = await bcrypt.hash(otp, salt);

      await Otp.deleteMany({ email: cleanEmail, purpose: 'reset' });

      const newOtp = new Otp({
        email: cleanEmail,
        purpose: 'reset',
        otpHash,
        expiresAt: new Date(Date.now() + 5 * 60 * 1000)
      });
      await newOtp.save();

      await emailService.sendOTP(cleanEmail, otp);
    }

    res.status(200).json({
      message: 'If an account exists with this email, a password reset code has been sent.'
    });
  } catch (err) {
    console.error('Forgot password error:', err);
    res.status(500).json({ error: 'Internal server error during forgot password' });
  }
});

// =========================================================================
// 5) POST /api/auth/reset-password {email, otp, new_password} (purpose 'reset')
// =========================================================================
router.post('/reset-password', otpVerifyIpLimiter, otpVerifyEmailLimiter, async (req, res) => {
  try {
    const { email, otp, new_password } = req.body;

    if (!email || typeof email !== 'string' || !otp || typeof otp !== 'string' || !new_password || typeof new_password !== 'string') {
      return res.status(400).json({ error: 'Email, OTP, and new password are required' });
    }

    const cleanEmail = sanitizeInput(email).toLowerCase();

    const passValidation = validatePassword(new_password);
    if (!passValidation.valid) {
      return res.status(400).json({
        error: passValidation.error,
        code: passValidation.code
      });
    }

    const otpRecord = await Otp.findOne({ email: cleanEmail, purpose: 'reset' });
    if (!otpRecord) {
      return res.status(400).json({ error: 'OTP expired or not found. Please request a new one.' });
    }

    if (otpRecord.attempts >= 5) {
      await Otp.deleteMany({ email: cleanEmail, purpose: 'reset' });
      return res.status(429).json({ error: 'Maximum attempts reached. Please request a new OTP.' });
    }

    if (new Date() > otpRecord.expiresAt) {
      await Otp.deleteMany({ email: cleanEmail, purpose: 'reset' });
      return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
    }

    const isMatch = await bcrypt.compare(otp, otpRecord.otpHash);
    if (!isMatch) {
      otpRecord.attempts += 1;
      if (otpRecord.attempts >= 5) {
        await Otp.deleteMany({ email: cleanEmail, purpose: 'reset' });
        return res.status(429).json({ error: 'Maximum attempts reached. Please request a new OTP.' });
      }
      await otpRecord.save();
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    await Otp.deleteMany({ email: cleanEmail });

    const user = await User.findOne({ email: cleanEmail });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const passwordHash = await bcrypt.hash(new_password, 12);
    user.passwordHash = passwordHash;
    user.password = undefined;
    user.emailVerified = true;
    user.tokenVersion = (user.tokenVersion || 0) + 1;
    user.updated_at = new Date();
    await user.save();

    res.status(200).json({
      message: 'Password reset successfully. You can now log in with your new password.'
    });
  } catch (err) {
    console.error('Reset password error:', err);
    res.status(500).json({ error: 'Internal server error during password reset' });
  }
});

// =========================================================================
// 6) POST /api/auth/resend-otp {email, purpose}
// =========================================================================
router.post('/resend-otp', otpRequestIpLimiter, otpRequestEmailLimiter, async (req, res) => {
  try {
    const { email, purpose } = req.body;

    if (!email || typeof email !== 'string' || !purpose || !['signup', 'reset'].includes(purpose)) {
      return res.status(400).json({ error: 'Email and a valid purpose (signup or reset) are required' });
    }

    const cleanEmail = sanitizeInput(email).toLowerCase();

    const otpRec = await Otp.findOne({ email: cleanEmail, purpose });
    if (otpRec) {
      const now = new Date();
      const diff = (now - new Date(otpRec.createdAt).getTime()) / 1000;
      if (diff < 30) {
        return res.status(429).json({ error: 'Please wait 30 seconds before resending OTP' });
      }
    }

    const user = await User.findOne({ email: cleanEmail });

    let shouldSend = false;
    if (purpose === 'signup' && user && !user.emailVerified) {
      shouldSend = true;
    } else if (purpose === 'reset' && user) {
      shouldSend = true;
    }

    if (shouldSend) {
      const otp = generateOtp();
      const salt = await bcrypt.genSalt(10);
      const otpHash = await bcrypt.hash(otp, salt);

      await Otp.deleteMany({ email: cleanEmail, purpose });

      const newOtp = new Otp({
        email: cleanEmail,
        purpose,
        otpHash,
        expiresAt: new Date(Date.now() + 5 * 60 * 1000)
      });
      await newOtp.save();

      await emailService.sendOTP(cleanEmail, otp);
    }

    res.status(200).json({
      message: 'If eligible, a new verification code has been sent to your email.'
    });
  } catch (err) {
    console.error('Resend OTP error:', err);
    res.status(500).json({ error: 'Internal server error while resending OTP' });
  }
});

// =========================================================================
// 7) Deprecated routes (respond 410)
// =========================================================================
router.post('/send-otp', (req, res) => {
  res.status(410).json({ error: 'Please update the app.' });
});

router.post('/verify-otp', (req, res) => {
  res.status(410).json({ error: 'Please update the app.' });
});

// =========================================================================
// 8) GET /api/auth/me
// =========================================================================
router.get('/me', requireAuth, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.user.userId });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json({
      user: formatUserResponse(user)
    });
  } catch (err) {
    console.error('Fetch profile error:', err);
    res.status(500).json({ error: 'Internal server error fetching user profile' });
  }
});

// =========================================================================
// 9) POST /api/auth/logout
// =========================================================================
router.post('/logout', requireAuth, async (req, res) => {
  try {
    if (req.user && req.user.userId) {
      await User.updateOne({ userId: req.user.userId }, { $inc: { tokenVersion: 1 } });
    }
    res.status(200).json({ message: 'Logged out successfully' });
  } catch (err) {
    console.error('Logout error:', err);
    res.status(500).json({ error: 'Internal server error during logout' });
  }
});

// =========================================================================
// 10) Profile Update: PUT /api/auth/profile & PUT /api/auth/me
// =========================================================================
async function handleUpdateProfile(req, res) {
  try {
    const user = await User.findOne({ userId: req.user.userId });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const { full_name, profile_photo, preferredLanguage, dateOfBirth } = req.body;

    if (full_name !== undefined) {
      const cleanName = sanitizeInput(full_name);
      if (!cleanName || typeof cleanName !== 'string' || cleanName.length === 0) {
        return res.status(400).json({ error: 'Full name cannot be empty' });
      }
      user.full_name = cleanName;
    }

    if (profile_photo !== undefined) {
      if (typeof profile_photo !== 'string') {
        return res.status(400).json({ error: 'Invalid profile photo URL' });
      }
      user.profile_photo = sanitizeInput(profile_photo);
    }

    if (preferredLanguage !== undefined) {
      if (typeof preferredLanguage !== 'string') {
        return res.status(400).json({ error: 'Invalid preferred language' });
      }
      user.preferredLanguage = sanitizeInput(preferredLanguage);
    }

    if (dateOfBirth !== undefined && dateOfBirth !== null && dateOfBirth !== '') {
      const dob = new Date(dateOfBirth);
      if (isNaN(dob.getTime())) {
        return res.status(400).json({ error: 'Invalid date of birth format' });
      }
      const year = dob.getFullYear();
      const now = new Date();
      if (year < 1900 || dob >= now) {
        return res.status(400).json({ error: 'Date of birth must be a valid past date after year 1900' });
      }
      user.dateOfBirth = dob;
    }

    user.updated_at = new Date();
    await user.save();

    res.status(200).json({
      message: 'Profile updated successfully',
      user: formatUserResponse(user)
    });
  } catch (err) {
    console.error('Update profile error:', err);
    res.status(500).json({ error: 'Internal server error updating profile' });
  }
}

router.put('/profile', requireAuth, handleUpdateProfile);
router.patch('/profile', requireAuth, handleUpdateProfile);
router.put('/me', requireAuth, handleUpdateProfile);

module.exports = router;