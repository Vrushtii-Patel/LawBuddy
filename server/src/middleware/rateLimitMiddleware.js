const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const { sanitizeInput } = require('./authMiddleware');

const isTestEnv = (req) => {
  if (process.env.NODE_ENV === 'test') {
    if (process.env.ENABLE_RATE_LIMIT_IN_TEST === 'true' || req?.headers?.['x-test-rate-limit'] === 'true') {
      return false;
    }
    return true;
  }
  return false;
};

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
  skip: isTestEnv,
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
  skip: isTestEnv,
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
  skip: isTestEnv,
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
  skip: isTestEnv,
  message: 'Too many verification attempts. Please try again later.',
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// IP-based limiter for password login attempts (20 attempts per 15 minutes)
const loginIpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: 'Too many login attempts from this IP. Please try again later.',
  validate: { xForwardedForHeader: false },
  skip: isTestEnv,
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// Email-based limiter for password login attempts (10 attempts per 15 minutes)
const loginEmailLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => {
    const email = getNormalizedEmail(req);
    return email ? `login_${email}` : `ip_${ipKeyGenerator(req)}`;
  },
  validate: { xForwardedForHeader: false },
  skip: isTestEnv,
  message: 'Too many login attempts for this account. Please try again later.',
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// Rate limiter for creating public share links (20 links per 15 minutes per user/IP)
const createShareLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => {
    return req.user?.userId ? `user_share_${req.user.userId}` : `ip_share_${ipKeyGenerator(req)}`;
  },
  validate: { xForwardedForHeader: false },
  skip: isTestEnv,
  message: 'Too many share links created. Please try again later.',
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// Rate limiter for initiating new scan jobs (15 scans per 15 minutes per user/IP)
const scanStartLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: parseInt(process.env.SCAN_RATE_LIMIT_MAX, 10) || 15,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => {
    return req.user?.userId ? `user_scan_${req.user.userId}` : `ip_scan_${ipKeyGenerator(req)}`;
  },
  validate: { xForwardedForHeader: false },
  skip: isTestEnv,
  message: 'Too many document scans submitted in a short period. Please wait a few minutes before scanning another document.',
  handler: (req, res, _next, options) => {
    res.status(options.statusCode).json({
      error: options.message
    });
  }
});

// Rate limiter for retrying failed scan jobs (20 retries per 15 minutes per user/IP)
const scanRetryLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: parseInt(process.env.SCAN_RETRY_RATE_LIMIT_MAX, 10) || 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => {
    return req.user?.userId ? `user_scan_retry_${req.user.userId}` : `ip_scan_retry_${ipKeyGenerator(req)}`;
  },
  validate: { xForwardedForHeader: false },
  skip: isTestEnv,
  message: 'Too many scan retry attempts. Please wait a few minutes before retrying.',
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
  otpVerifyEmailLimiter,
  loginIpLimiter,
  loginEmailLimiter,
  createShareLimiter,
  scanStartLimiter,
  scanRetryLimiter
};
