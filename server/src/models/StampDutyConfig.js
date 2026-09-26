const mongoose = require('mongoose');

const slabSchema = new mongoose.Schema({
  maxValue: { type: Number, default: null }, // null indicates unbounded upper slab (> previous slab)
  rate: { type: Number, required: true }
}, { _id: false });

const stampDutyConfigSchema = new mongoose.Schema({
  state: { type: String, required: true, unique: true, index: true },
  baseRate: { type: Number, required: true, default: 5.0 },
  genderOverrides: {
    Female: { type: Number, default: null },
    Male: { type: Number, default: null },
    'Joint (Male + Female)': { type: Number, default: null },
    'Other / Entity': { type: Number, default: null }
  },
  slabs: [slabSchema],
  registrationRate: { type: Number, default: 1.0 },
  registrationCap: { type: Number, default: null }, // null means uncapped (e.g., 30000 in MH)
  lastVerifiedOn: { type: Date, required: true, default: Date.now },
  source: { type: String, default: 'State Revenue Department & Registration Act Guidelines' },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

stampDutyConfigSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  if (typeof next === 'function') next();
});

module.exports = mongoose.model('StampDutyConfig', stampDutyConfigSchema);
