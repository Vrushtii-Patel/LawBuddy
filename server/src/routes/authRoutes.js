const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Otp = require('../models/Otp');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const JWT_SECRET = require('../config/jwt');
const { sendOTP } = require('../services/emailService');
const { isValidEmail, sanitizeInput, requireAuth } = require('../middleware/authMiddleware');
const {
  otpRequestIpLimiter,
  otpRequestEmailLimiter,
  otpVerifyIpLimiter,
  otpVerifyEmailLimiter
} = require('../middleware/rateLimitMiddleware');

function generateUserId() {
  return 'usr_' + Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
}

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function handleSendOtp(email, isSignup, res) {
  try {
    email = sanitizeInput(email).toLowerCase();

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address' });
    }

    const existingUser = await User.findOne({ email });

    if (isSignup && existingUser) {
      return res.status(400).json({ error: 'Account already exists. Please log in.' });
    }

    if (!isSignup && !existingUser) {
      return res.status(404).json({ error: 'Account not found. Please sign up for a new account.' });
    }

    // Generate OTP
    const otp = generateOtp();
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);

    // Delete any existing OTP for this email
    await Otp.deleteMany({ email });

    // Store new OTP
    const newOtp = new Otp({
      email,
      otpHash,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000) // 5 minutes
    });
    await newOtp.save();

    // Send Email
    const emailResult = await sendOTP(email, otp);
    if (!emailResult.success) {
      return res.status(500).json({ error: 'Failed to send OTP email. Please check your email configuration.' });
    }

    res.status(200).json({ message: 'OTP sent successfully' });
  } catch (err) {
    console.error('Send OTP error:', err);
    res.status(500).json({ error: 'Internal server error while sending OTP' });
  }
}

// POST /api/auth/send-otp
router.post('/send-otp', otpRequestIpLimiter, otpRequestEmailLimiter, async (req, res) => {
  const { email, type } = req.body;
  if (!email || !type) return res.status(400).json({ error: 'Email and type (login/signup) are required' });
  return await handleSendOtp(email, type === 'signup', res);
});

// Alias routes for frontend convenience
router.post('/signup', otpRequestIpLimiter, otpRequestEmailLimiter, async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email is required' });
  return await handleSendOtp(email, true, res);
});

router.post('/login', otpRequestIpLimiter, otpRequestEmailLimiter, async (req, res) => {
  const { identifier } = req.body;
  if (!identifier) return res.status(400).json({ error: 'Email is required' });
  return await handleSendOtp(identifier, false, res);
});

// POST /api/auth/resend-otp
router.post('/resend-otp', otpRequestIpLimiter, otpRequestEmailLimiter, async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email is required' });

    const cleanEmail = sanitizeInput(email).toLowerCase();

    const otpRec = await Otp.findOne({ email: cleanEmail });
    if (otpRec) {
      const now = new Date();
      const diff = (now - otpRec.createdAt) / 1000;
      if (diff < 30) {
        return res.status(429).json({ error: 'Please wait 30 seconds before resending OTP' });
      }
    }

    const otp = generateOtp();
    const salt = await bcrypt.genSalt(10);
    const otpHash = await bcrypt.hash(otp, salt);

    await Otp.deleteMany({ email: cleanEmail });

    const newOtp = new Otp({
      email: cleanEmail,
      otpHash,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000)
    });
    await newOtp.save();

    const emailResult = await sendOTP(cleanEmail, otp);
    if (!emailResult.success) {
      return res.status(500).json({ error: 'Failed to send OTP email' });
    }

    res.status(200).json({ message: 'OTP resent successfully' });
  } catch (err) {
    console.error('Resend OTP error:', err);
    res.status(500).json({ error: 'Internal server error while resending OTP' });
  }
});

// POST /api/auth/verify-otp
router.post('/verify-otp', otpVerifyIpLimiter, otpVerifyEmailLimiter, async (req, res) => {
  try {
    let { email, otp, full_name, type } = req.body;
    email = sanitizeInput(email).toLowerCase();

    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required' });
    }

    const otpRecord = await Otp.findOne({ email });
    if (!otpRecord) {
      return res.status(400).json({ error: 'OTP expired or not found. Please request a new one.' });
    }

    if (otpRecord.attempts >= 5) {
      await Otp.deleteMany({ email });
      return res.status(429).json({ error: 'Maximum attempts reached. Please request a new OTP.' });
    }

    if (new Date() > otpRecord.expiresAt) {
      await Otp.deleteMany({ email });
      return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
    }

    const isMatch = await bcrypt.compare(otp, otpRecord.otpHash);
    if (!isMatch) {
      otpRecord.attempts += 1;
      if (otpRecord.attempts >= 5) {
        await Otp.deleteMany({ email });
        return res.status(429).json({ error: 'Maximum attempts reached. Please request a new OTP.' });
      }
      await otpRecord.save();
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    // OTP is valid, delete it
    await Otp.deleteMany({ email });

    let user = await User.findOne({ email });

    if (type === 'signup' || (!user && full_name)) {
      if (user) {
        return res.status(400).json({ error: 'User already exists' });
      }
      user = new User({
        userId: generateUserId(),
        full_name: sanitizeInput(full_name),
        email,
        emailVerified: true,
        created_at: new Date(),
        last_login: new Date(),
        profile_photo: `https://api.dicebear.com/7.x/bottts/svg?seed=${encodeURIComponent(full_name)}`
      });
      await user.save();
    } else {
      if (!user) {
        return res.status(404).json({ error: 'User not found. Please sign up.' });
      }
      user.last_login = new Date();
      user.emailVerified = true;
      await user.save();
    }

    // Generate JWT
    const token = jwt.sign(
      { userId: user.userId, email: user.email, role: user.role || 'user' },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(200).json({
      message: 'Authentication successful',
      token,
      user: {
        userId: user.userId,
        full_name: user.full_name,
        email: user.email,
        role: user.role || 'user',
        emailVerified: user.emailVerified,
        created_at: user.created_at,
        last_login: user.last_login,
        profile_photo: user.profile_photo
      }
    });
  } catch (err) {
    console.error('Verify OTP error:', err);
    res.status(500).json({ error: 'Internal server error during verification' });
  }
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
  res.status(200).json({ message: 'Logged out successfully' });
});

// GET /api/auth/me
router.get('/me', requireAuth, async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.user.userId });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json({
      user: {
        userId: user.userId,
        full_name: user.full_name,
        email: user.email,
        role: user.role || 'user',
        emailVerified: user.emailVerified,
        created_at: user.created_at,
        last_login: user.last_login,
        profile_photo: user.profile_photo
      }
    });
  } catch (err) {
    console.error('Fetch profile error:', err);
    res.status(500).json({ error: 'Internal server error fetching user profile' });
  }
});

module.exports = router;