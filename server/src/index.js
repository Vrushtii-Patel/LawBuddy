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

async function startServer() {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });

  const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/lawbuddy';
  try {
    await mongoose.connect(uri, { family: 4, serverSelectionTimeoutMS: 2500 });
    console.log('Connected to MongoDB at', uri);
  } catch (err) {
    console.warn('Local MongoDB connection failed. Starting in-memory MongoDB for development...');
    try {
      const { MongoMemoryServer } = require('mongodb-memory-server');
      const mongod = await MongoMemoryServer.create();
      const memUri = mongod.getUri();
      await mongoose.connect(memUri);
      console.log('Connected to In-Memory MongoDB at', memUri);
    } catch (memErr) {
      console.error('Failed to start in-memory MongoDB:', memErr.message);
    }
  }

  // Ensure clean collection indexes & background recovery
  try {
    const Checklist = require('./models/Checklist');
    await Checklist.syncIndexes();
  } catch (idxErr) {
    console.warn('Checklist syncIndexes note:', idxErr.message);
  }

  scanJobService.recoverUnfinishedScanJobs().catch(recErr => {
    console.warn('Startup scan recovery warning:', recErr.message);
  });
  comparisonService.recoverUnfinishedComparisons().catch(compErr => {
    console.warn('Startup comparison recovery warning:', compErr.message);
  });
}

startServer();