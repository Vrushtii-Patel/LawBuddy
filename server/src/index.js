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
const scanJobService = require('./services/scanJobService');
const comparisonService = require('./services/comparisonService');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

app.use('/api', documentRoutes);
app.use('/api', checklistRoutes);
app.use('/api', chatRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/news', newsRoutes);
app.use('/api', stampDutyRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api', comparisonRoutes);

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

mongoose.connect(process.env.MONGODB_URI, { family: 4 })
  .then(() => {
    console.log('Connected to MongoDB');
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

