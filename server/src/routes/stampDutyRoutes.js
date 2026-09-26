const express = require('express');
const router = express.Router();
const StampDuty = require('../models/StampDuty');
const { requireAuth } = require('../middleware/authMiddleware');
const { calculateStampDuty } = require('../services/stampDutyService');

// POST /api/stamp-duty/calculate - Authoritative calculation without saving
router.post('/stamp-duty/calculate', (req, res) => {
    try {
        const {
            state,
            propertyType,
            agreementValue,
            propertyValue,
            circleRate,
            applicableValue,
            applicableMarketValue,
            gender,
            firstTimeBuyer
        } = req.body;

        const effectiveAgreementValue = agreementValue ?? propertyValue ?? applicableMarketValue ?? applicableValue ?? 0;

        const calculation = calculateStampDuty({
            state,
            propertyType,
            agreementValue: effectiveAgreementValue,
            circleRate: circleRate ?? 0,
            gender,
            firstTimeBuyer
        });

        res.json({ calculation });
    } catch (error) {
        res.status(400).json({ error: error.message || 'Invalid input for stamp duty calculation' });
    }
});

// POST /api/stamp-duty - Authoritatively recalculates and saves the verified calculation record to MongoDB
router.post('/stamp-duty', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const {
            propertyType,
            state,
            agreementValue,
            propertyValue,
            circleRate,
            applicableMarketValue,
            applicableValue,
            gender,
            firstTimeBuyer
        } = req.body;

        const effectiveAgreementValue = agreementValue ?? propertyValue ?? applicableMarketValue ?? applicableValue ?? 0;

        // Authoritative server-side calculation: computes exact rates and amounts,
        // preventing client tampering or math bugs from persisting invalid records.
        const calculated = calculateStampDuty({
            state,
            propertyType,
            agreementValue: effectiveAgreementValue,
            circleRate: circleRate ?? 0,
            gender,
            firstTimeBuyer
        });

        const record = new StampDuty({
            userId,
            propertyType: calculated.propertyType,
            state: calculated.state,
            agreementValue: calculated.agreementValue,
            circleRate: calculated.circleRate,
            applicableMarketValue: calculated.applicableMarketValue,
            gender: calculated.gender,
            firstTimeBuyer: calculated.firstTimeBuyer,
            stampDutyRate: calculated.stampDutyRate,
            stampDutyAmount: calculated.stampDutyAmount,
            registrationRate: calculated.registrationRate,
            registrationAmount: calculated.registrationAmount,
            totalPayable: calculated.totalPayable,
            createdAt: new Date()
        });

        const savedRecord = await record.save();
        res.status(201).json({ message: 'Calculation verified and saved to database', calculation: savedRecord });
    } catch (error) {
        console.error('Error saving stamp duty calculation:', error);
        if (error.message && error.message.includes('greater than zero')) {
            return res.status(400).json({ error: error.message });
        }
        res.status(500).json({ error: 'Failed to save calculation. Please try again.' });
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
        res.status(500).json({ error: 'Failed to fetch stamp duty history.' });
    }
});

module.exports = router;