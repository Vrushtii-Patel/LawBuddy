const jwt = require('jsonwebtoken');

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

function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_super_secret_jwt_key_here');
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_super_secret_jwt_key_here');
      req.user = decoded;
    } catch (err) {
      // invalid token, proceed without req.user
    }
  }
  next();
}

async function requireAdmin(req, res, next) {
  // First ensure user is authenticated
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const token = authHeader.split(' ')[1];
  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_super_secret_jwt_key_here');
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }

  try {
    const User = require('../models/User');
    const user = await User.findOne({ userId: decoded.userId });
    if (!user) {
      return res.status(401).json({ error: 'User account not found' });
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
