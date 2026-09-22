const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const { sanitizeInput } = require('./authMiddleware');

function getNormalizedEmail(req) {
  const raw = req.body?.email || req.body?.identifier || '';
  if (typeof raw === 'string' && raw.trim().length > 0) {
    return sanitizeInput(raw).toLowerCase();
  }
  return null;
}

// IP-based limiter for OTP generation/request routes (10 requests per 15 minutes)
const otpRequestIpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: 'Too many OTP requests from this IP. Please try again later.',
  validate: { xForwardedForHeader: false },
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// Email/Identifier-based limiter for OTP generation/request routes (3 requests per 15 minutes)
const otpRequestEmailLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 3,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => {
    const email = getNormalizedEmail(req);
    return email ? `email_${email}` : `ip_${ipKeyGenerator(req)}`;
  },
  validate: { xForwardedForHeader: false },
  message: 'Too many OTP requests. Please try again later.',
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// IP-based limiter for OTP verification attempts (20 attempts per 15 minutes)
const otpVerifyIpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: 'Too many verification attempts from this IP. Please try again later.',
  validate: { xForwardedForHeader: false },
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// Email/Identifier-based limiter for OTP verification attempts (10 attempts per 15 minutes)
const otpVerifyEmailLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => {
    const email = getNormalizedEmail(req);
    return email ? `verify_${email}` : `ip_${ipKeyGenerator(req)}`;
  },
  validate: { xForwardedForHeader: false },
  message: 'Too many verification attempts. Please try again later.',
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

module.exports = {
  otpRequestIpLimiter,
  otpRequestEmailLimiter,
  otpVerifyIpLimiter,
  otpVerifyEmailLimiter
};
