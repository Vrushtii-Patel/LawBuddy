require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const documentRoutes = require('./routes/documentRoutes');
const checklistRoutes = require('./routes/checklistRoutes');
const chatRoutes = require('./routes/chatRoutes');
const authRoutes = require('./routes/authRoutes');
const newsRoutes = require('./routes/newsRoutes');
const stampDutyRoutes = require('./routes/stampDutyRoutes');
const adminRoutes = require('./routes/adminRoutes');
const comparisonRoutes = require('./routes/comparisonRoutes');
const shareRoutes = require('./routes/shareRoutes');
const scanJobService = require('./services/scanJobService');
const comparisonService = require('./services/comparisonService');

// =========================================================================
// PROCESS SAFETY NETS & REJECTION HANDLERS
// =========================================================================
process.on('unhandledRejection', (reason, promise) => {
  console.error('[Process] Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[Process] Uncaught Exception:', err);
  if (process.env.NODE_ENV === 'production') {
    process.exit(1);
  }
});

let server = null;

function gracefulShutdown(signal) {
  console.log(`[Process] Received ${signal}. Starting graceful shutdown...`);
  if (server) {
    server.close(() => {
      console.log('[Process] HTTP server closed.');
      mongoose.connection.close(false).then(() => {
        console.log('[Process] MongoDB connection closed.');
        process.exit(0);
      }).catch(err => {
        console.error('[Process] Error closing MongoDB connection:', err);
        process.exit(1);
      });
    });
  } else {
    process.exit(0);
  }
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

const app = express();
const PORT = process.env.PORT || 3000;

// Trust reverse proxy (e.g. Nginx, Cloudflare, Render, AWS ALB, Heroku) so express-rate-limit
// and req.ip correctly identify client IP addresses rather than the proxy's IP.
const trustProxyConfig = process.env.TRUST_PROXY;
if (trustProxyConfig) {
  const numeric = Number(trustProxyConfig);
  app.set('trust proxy', isNaN(numeric) ? (trustProxyConfig === 'true' ? true : trustProxyConfig) : numeric);
} else {
  app.set('trust proxy', 1);
}

// CORS: restrict to known origins when ALLOWED_ORIGINS is set (comma-separated,
// e.g. "https://yourapp.com,https://admin.yourapp.com"). Native mobile clients
// don't send an Origin header, so this only affects browser/web-build requests.
// Falls back to allowing all origins only outside production, so local dev keeps working.
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

if (allowedOrigins.length === 0) {
  console.warn('ALLOWED_ORIGINS not set — CORS is open to all origins. Set it before deploying publicly.');
}

app.use(cors({
  origin: allowedOrigins.length === 0
    ? true
    : (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, server-to-server)
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('Not allowed by CORS'));
    }
}));
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ limit: '2mb', extended: true }));

app.use('/api', documentRoutes);
app.use('/api', checklistRoutes);
app.use('/api', chatRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/news', newsRoutes);
app.use('/api', stampDutyRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api', comparisonRoutes);
app.use('/api', shareRoutes);

// Health check endpoint (reports process uptime and database connection status)
app.get(['/health', '/api/health'], (req, res) => {
  const dbState = mongoose.connection.readyState;
  const dbStatusMap = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting'
  };
  const isHealthy = dbState === 1;
  const status = isHealthy ? 'ok' : 'degraded';

  res.status(isHealthy ? 200 : 503).json({
    status,
    database: dbStatusMap[dbState] || 'unknown',
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

// Catch-all 404 handler for undefined API routes
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global JSON error handler
// Ensures that CORS rejections, body-parser syntax errors, and unhandled route errors
// always return well-formed JSON instead of HTML error pages.
app.use((err, req, res, next) => {
  if (res.headersSent) {
    return next(err);
  }

  // Handle CORS errors (from cors middleware callback)
  if (err.message === 'Not allowed by CORS') {
    return res.status(403).json({ error: 'Not allowed by CORS' });
  }

  // Handle malformed JSON body errors from express.json()
  if (err instanceof SyntaxError && (err.status === 400 || err.statusCode === 400) && 'body' in err) {
    return res.status(400).json({ error: 'Malformed JSON payload in request body.' });
  }

  // Handle payload too large
  if (err.status === 413 || err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Request payload is too large.' });
  }

  const statusCode = (typeof err.status === 'number' && err.status >= 400 && err.status < 600)
    ? err.status
    : (typeof err.statusCode === 'number' && err.statusCode >= 400 && err.statusCode < 600)
      ? err.statusCode
      : 500;

  const message = statusCode >= 500 && process.env.NODE_ENV === 'production'
    ? 'An unexpected server error occurred.'
    : (err.message || 'An unexpected error occurred.');

  console.error(`[Unhandled Error] ${req.method} ${req.originalUrl || req.url}:`, err);
  res.status(statusCode).json({ error: message });
});

async function startServer() {
  const isProduction = process.env.NODE_ENV === 'production';
  const configuredUri = process.env.MONGODB_URI;
  const uri = configuredUri || 'mongodb://127.0.0.1:27017/lawbuddy';

  if (isProduction && !configuredUri) {
    throw new Error('MONGODB_URI must be configured in production.');
  }
  if (isProduction && allowedOrigins.length === 0) {
    throw new Error('ALLOWED_ORIGINS must be configured in production.');
  }

  try {
    await mongoose.connect(uri, { family: 4, serverSelectionTimeoutMS: 10000 });
    console.log('Connected to MongoDB.');
  } catch (err) {
    if (isProduction) {
      throw new Error('Could not connect to the configured production MongoDB database.');
    }

    console.warn('Local MongoDB connection failed. Starting in-memory MongoDB for development...');
    try {
      const { MongoMemoryServer } = require('mongodb-memory-server');
      const mongod = await MongoMemoryServer.create();
      await mongoose.connect(mongod.getUri());
      console.log('Connected to in-memory MongoDB for development.');
    } catch (memErr) {
      throw new Error(`Could not connect to local MongoDB or start the development in-memory database: ${memErr.message}`);
    }
  }

  const documentCleanupService = require('./services/documentCleanupService');

  // Ensure schema indexes exist without dropping indexes managed outside Mongoose.
  try {
    const Checklist = require('./models/Checklist');
    await Checklist.createIndexes();
  } catch (idxErr) {
    console.warn('Checklist createIndexes note:', idxErr.message);
  }

  try {
    const Document = require('./models/Document');
    await Document.createIndexes();
  } catch (docIdxErr) {
    console.warn('Document createIndexes note:', docIdxErr.message);
  }

  // Startup auto-purge of expired binned documents and checklists (> 30 days).
  Promise.all([
    documentCleanupService.purgeExpiredBinnedDocuments(),
    documentCleanupService.purgeExpiredBinnedChecklists()
  ]).then(([docCount, chkCount]) => {
    if (docCount > 0 || chkCount > 0) {
      console.log(`✓ Auto-purged ${docCount} expired document(s) and ${chkCount} expired checklist(s) from Recycle Bin on startup.`);
    }
  }).catch(purgeErr => {
    console.warn('Startup bin auto-purge warning:', purgeErr.message);
  });

  // Hourly background timer for opportunistic auto-purge.
  const autoPurgeInterval = setInterval(() => {
    Promise.all([
      documentCleanupService.purgeExpiredBinnedDocuments(),
      documentCleanupService.purgeExpiredBinnedChecklists(),
      documentCleanupService.sweepAbandonedJobs()
    ]).catch(err => {
      console.warn('[Periodic Auto-Purge] Error:', err.message);
    });
  }, 60 * 60 * 1000);
  if (autoPurgeInterval.unref) autoPurgeInterval.unref();

  // Sweep abandoned/failed jobs before attempting recovery.
  try {
    const swept = await documentCleanupService.sweepAbandonedJobs();
    if (swept.scanJobs || swept.orphanedCompletedJobs || swept.comparisons || swept.files) {
      console.log(`✓ Job sweep on startup: ${swept.scanJobs} failed/stuck scan job(s), ${swept.orphanedCompletedJobs} orphaned completed job(s), ${swept.comparisons} comparison(s), ${swept.files} file(s) removed.`);
    }
  } catch (sweepErr) {
    console.warn('Startup job sweep warning:', sweepErr.message);
  }

  scanJobService.recoverUnfinishedScanJobs().catch(recErr => {
    console.warn('Startup scan recovery warning:', recErr.message);
  });
  comparisonService.recoverUnfinishedComparisons().catch(compErr => {
    console.warn('Startup comparison recovery warning:', compErr.message);
  });

  // Only accept traffic once the database connection is established.
  server = app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
  return server;
}

module.exports = { app, startServer };

if (require.main === module) {
  startServer().catch(err => {
    console.error('Fatal startup error:', err.message);
    process.exit(1);
  });
}
