const mongoose = require('mongoose');
const StampDutyConfig = require('../src/models/StampDutyConfig');
require('dotenv').config();

const DEFAULT_STATE_CONFIGS = [
  {
    state: 'Maharashtra',
    baseRate: 6.0,
    genderOverrides: {
      Female: 5.0,
      Male: null,
      'Joint (Male + Female)': null,
      'Other / Entity': null
    },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: 30000,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Maharashtra Stamp Act (Article 25) & IGR Maharashtra'
  },
  {
    state: 'Karnataka',
    baseRate: 5.0,
    genderOverrides: {},
    slabs: [
      { maxValue: 2000000, rate: 2.0 },
      { maxValue: 4500000, rate: 3.0 },
      { maxValue: null, rate: 5.0 }
    ],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Karnataka Stamp Act & Kaveri Online Services'
  },
  {
    state: 'Delhi',
    baseRate: 6.0,
    genderOverrides: {
      Female: 4.0,
      'Joint (Male + Female)': 5.0,
      Male: 6.0,
      'Other / Entity': 6.0
    },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Delhi Revenue Department (DOR) & IGR Delhi'
  },
  {
    state: 'Gujarat',
    baseRate: 4.9,
    genderOverrides: {
      Female: 0.0,
      Male: null,
      'Joint (Male + Female)': null,
      'Other / Entity': null
    },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Gujarat Stamp Act & IGR Gujarat'
  },
  {
    state: 'Tamil Nadu',
    baseRate: 7.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 4.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Tamil Nadu Registration Department (TNREGINET)'
  },
  {
    state: 'West Bengal',
    baseRate: 5.0,
    genderOverrides: {},
    slabs: [
      { maxValue: 4000000, rate: 5.0 },
      { maxValue: null, rate: 6.0 }
    ],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Directorate of Registration and Stamp Revenue, West Bengal'
  },
  {
    state: 'Uttar Pradesh',
    baseRate: 7.0,
    genderOverrides: {
      Female: 6.0,
      Male: null,
      'Joint (Male + Female)': null,
      'Other / Entity': null
    },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'UP Stamp and Registration Department (IGRSUP)'
  },
  {
    state: 'Haryana',
    baseRate: 7.0,
    genderOverrides: {
      Female: 5.0,
      'Joint (Male + Female)': 6.0,
      Male: 7.0,
      'Other / Entity': 7.0
    },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Haryana Revenue & Disaster Management Department (JAMABANDI)'
  },
  {
    state: 'Telangana',
    baseRate: 6.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Telangana Registration & Stamps Department (CARD)'
  },
  {
    state: 'Rajasthan',
    baseRate: 6.0,
    genderOverrides: {
      Female: 5.0,
      Male: null,
      'Joint (Male + Female)': null,
      'Other / Entity': null
    },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Rajasthan Registration and Stamps Department (EPANJIYAN)'
  },
  {
    state: 'Kerala',
    baseRate: 8.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Kerala Registration Department (PEARL)'
  },
  {
    state: 'Madhya Pradesh',
    baseRate: 7.5,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'MP Commercial Tax Department (SAMPADA)'
  },
  {
    state: 'Punjab',
    baseRate: 7.0,
    genderOverrides: {
      Female: 5.0,
      Male: null,
      'Joint (Male + Female)': null,
      'Other / Entity': null
    },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Department of Revenue & Rehabilitation Punjab'
  },
  {
    state: 'Other',
    baseRate: 5.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Indian Stamp Act (Central Baseline)'
  }
];

async function seedStampDutyConfig() {
  console.log('Seeding Stamp Duty Configuration...');
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/lawbuddy';
  
  const isConnected = mongoose.connection.readyState === 1;
  if (!isConnected) {
    await mongoose.connect(uri);
  }

  for (const config of DEFAULT_STATE_CONFIGS) {
    await StampDutyConfig.findOneAndUpdate(
      { state: config.state },
      { $set: config },
      { upsert: true, returnDocument: 'after', setDefaultsOnInsert: true }
    );
    console.log(`✓ Seeded config for: ${config.state}`);
  }

  console.log('Stamp duty configurations successfully seeded!');
  if (!isConnected) {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  seedStampDutyConfig().catch(err => {
    console.error('Failed to seed stamp duty configs:', err);
    process.exit(1);
  });
}

module.exports = {
  DEFAULT_STATE_CONFIGS,
  seedStampDutyConfig
};
