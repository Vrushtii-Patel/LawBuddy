const jwt = require('jsonwebtoken');
const JWT_SECRET = require('../config/jwt');
const User = require('../models/User');

function isValidEmail(email) {
  if (!email || typeof email !== 'string') return false;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email.trim());
}

function isValidPhone(phone) {
  if (!phone || typeof phone !== 'string') return false;
  const cleanPhone = phone.replace(/[\s\-\(\)]/g, '');
  const phoneRegex = /^\+?[0-9]{10,15}$/;
  return phoneRegex.test(cleanPhone);
}

function sanitizeInput(str) {
  if (typeof str !== 'string') return str;
  return str.trim();
}

async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const token = authHeader.split(' ')[1];
  let decoded;
  try {
    decoded = jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }

  try {
    const user = await User.findOne({ userId: decoded.userId });
    if (!user) {
      return res.status(401).json({ error: 'User account not found' });
    }

    const payloadTokenVersion = decoded.tokenVersion !== undefined ? decoded.tokenVersion : 0;
    const currentTokenVersion = user.tokenVersion || 0;
    if (payloadTokenVersion !== currentTokenVersion) {
      return res.status(401).json({ error: 'Token has been revoked. Please log in again.' });
    }

    req.user = {
      userId: user.userId,
      email: user.email,
      role: user.role || 'user',
      tokenVersion: currentTokenVersion
    };
    next();
  } catch (err) {
    console.error('requireAuth authorization error:', err);
    return res.status(500).json({ error: 'Internal server error during authentication' });
  }
}

async function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      const user = await User.findOne({ userId: decoded.userId });
      if (user) {
        const payloadTokenVersion = decoded.tokenVersion !== undefined ? decoded.tokenVersion : 0;
        const currentTokenVersion = user.tokenVersion || 0;
        if (payloadTokenVersion === currentTokenVersion) {
          req.user = {
            userId: user.userId,
            email: user.email,
            role: user.role || 'user',
            tokenVersion: currentTokenVersion
          };
        }
      }
    } catch (err) {
      // invalid or expired token, proceed without req.user
    }
  }
  next();
}

async function requireAdmin(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const token = authHeader.split(' ')[1];
  let decoded;
  try {
    decoded = jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }

  try {
    const user = await User.findOne({ userId: decoded.userId });
    if (!user) {
      return res.status(401).json({ error: 'User account not found' });
    }

    const payloadTokenVersion = decoded.tokenVersion !== undefined ? decoded.tokenVersion : 0;
    const currentTokenVersion = user.tokenVersion || 0;
    if (payloadTokenVersion !== currentTokenVersion) {
      return res.status(401).json({ error: 'Token has been revoked. Please log in again.' });
    }

    if (user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: Admin access required' });
    }

    req.user = user;
    next();
  } catch (err) {
    console.error('requireAdmin authorization error:', err);
    return res.status(500).json({ error: 'Internal server error during authorization' });
  }
}

module.exports = {
  isValidEmail,
  isValidPhone,
  sanitizeInput,
  requireAuth,
  optionalAuth,
  requireAdmin
};