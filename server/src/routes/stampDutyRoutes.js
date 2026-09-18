const express = require('express');
const router = express.Router();
const StampDuty = require('../models/StampDuty');
const { requireAuth } = require('../middleware/authMiddleware');

// POST /api/stamp-duty - Save a calculation record to MongoDB
router.post('/stamp-duty', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const {
            propertyType,
            state,
            agreementValue,
            circleRate,
            applicableMarketValue,
            gender,
            firstTimeBuyer,
            stampDutyRate,
            stampDutyAmount,
            registrationRate,
            registrationAmount,
            totalPayable
        } = req.body;

        const record = new StampDuty({
            userId,
            propertyType,
            state,
            agreementValue,
            circleRate: circleRate || 0,
            applicableMarketValue,
            gender,
            firstTimeBuyer,
            stampDutyRate,
            stampDutyAmount,
            registrationRate,
            registrationAmount,
            totalPayable,
            createdAt: new Date()
        });

        const savedRecord = await record.save();
        res.status(201).json({ message: 'Calculation saved to database', calculation: savedRecord });
    } catch (error) {
        console.error('Error saving stamp duty calculation:', error);
        res.status(500).json({ error: 'Failed to save calculation', details: error.message });
    }
});

// GET /api/stamp-duty - Fetch past calculation history for the user from MongoDB
router.get('/stamp-duty', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const history = await StampDuty.find({ userId }).sort({ createdAt: -1 }).limit(10);
        res.json(history);
    } catch (error) {
        console.error('Error fetching stamp duty history:', error);
        res.status(500).json({ error: 'Failed to fetch stamp duty history', details: error.message });
    }
});

module.exports = router;