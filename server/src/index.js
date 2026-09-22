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

const app = express();
const PORT = process.env.PORT || 3000;

// CORS: restrict to known origins when ALLOWED_ORIGINS is set (comma-separated,
// e.g. "https://yourapp.com,https://admin.yourapp.com"). Native mobile clients
// don't send an Origin header, so this only affects browser/web-build requests.
// Falls back to allowing all origins if unset, so local dev keeps working.
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

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

mongoose.connect(process.env.MONGODB_URI, { family: 4 })
  .then(() => {
    console.log('Connected to MongoDB');
    // Ensure clean collection indexes
    const Checklist = require('./models/Checklist');
    Checklist.syncIndexes().catch(idxErr => {
      console.warn('Checklist syncIndexes note:', idxErr.message);
    });
    // Startup Recovery: Resume any unfinished ScanJobs
    scanJobService.recoverUnfinishedScanJobs().catch(recErr => {
      console.warn('Startup scan recovery warning:', recErr.message);
    });
    // Startup Recovery: Resume any unfinished DocumentComparisons
    comparisonService.recoverUnfinishedComparisons().catch(compErr => {
      console.warn('Startup comparison recovery warning:', compErr.message);
    });
  })
  .catch((err) => {
    console.warn('MongoDB connection failed (running without DB connection):', err.message);
  });