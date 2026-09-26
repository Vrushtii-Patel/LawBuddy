/**
 * Server-side Stamp Duty & Registration Fee calculation service.
 * Supports configurable rules per state and global property/first-time buyer adjustments.
 */

const StampDutyConfig = require('../models/StampDutyConfig');

const VALID_PROPERTY_TYPES = ['Residential', 'Commercial', 'Agricultural', 'Other'];

const VALID_GENDERS = [
  'Male',
  'Female',
  'Joint (Male + Female)',
  'Other / Entity'
];

const GLOBAL_STAMP_DUTY_RULES = {
  propertyTypeAdjustments: {
    Commercial: { type: 'add', value: 1.0 },
    Agricultural: { type: 'multiply', multiplier: 0.7, minRate: 1.0, maxRate: 10.0 },
    Residential: { type: 'none', value: 0.0 },
    Other: { type: 'none', value: 0.0 }
  },
  firstTimeBuyerConcession: {
    discount: 0.5,
    thresholdRate: 2.0, // applied if baseRate > 2.0
    minRate: 1.0,
    maxRate: 15.0
  }
};

const DEFAULT_STATE_CONFIGS_MAP = {
  'Maharashtra': {
    state: 'Maharashtra',
    baseRate: 6.0,
    genderOverrides: { Female: 5.0, Male: null, 'Joint (Male + Female)': null, 'Other / Entity': null },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: 30000,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Maharashtra Stamp Act (Article 25) & IGR Maharashtra'
  },
  'Karnataka': {
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
  'Delhi': {
    state: 'Delhi',
    baseRate: 6.0,
    genderOverrides: { Female: 4.0, 'Joint (Male + Female)': 5.0, Male: 6.0, 'Other / Entity': 6.0 },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Delhi Revenue Department (DOR) & IGR Delhi'
  },
  'Gujarat': {
    state: 'Gujarat',
    baseRate: 4.9,
    genderOverrides: { Female: 0.0, Male: null, 'Joint (Male + Female)': null, 'Other / Entity': null },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Gujarat Stamp Act & IGR Gujarat'
  },
  'Tamil Nadu': {
    state: 'Tamil Nadu',
    baseRate: 7.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 4.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Tamil Nadu Registration Department (TNREGINET)'
  },
  'West Bengal': {
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
  'Uttar Pradesh': {
    state: 'Uttar Pradesh',
    baseRate: 7.0,
    genderOverrides: { Female: 6.0, Male: null, 'Joint (Male + Female)': null, 'Other / Entity': null },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'UP Stamp and Registration Department (IGRSUP)'
  },
  'Haryana': {
    state: 'Haryana',
    baseRate: 7.0,
    genderOverrides: { Female: 5.0, 'Joint (Male + Female)': 6.0, Male: 7.0, 'Other / Entity': 7.0 },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Haryana Revenue & Disaster Management Department (JAMABANDI)'
  },
  'Telangana': {
    state: 'Telangana',
    baseRate: 6.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Telangana Registration & Stamps Department (CARD)'
  },
  'Rajasthan': {
    state: 'Rajasthan',
    baseRate: 6.0,
    genderOverrides: { Female: 5.0, Male: null, 'Joint (Male + Female)': null, 'Other / Entity': null },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Rajasthan Registration and Stamps Department (EPANJIYAN)'
  },
  'Kerala': {
    state: 'Kerala',
    baseRate: 8.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Kerala Registration Department (PEARL)'
  },
  'Madhya Pradesh': {
    state: 'Madhya Pradesh',
    baseRate: 7.5,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'MP Commercial Tax Department (SAMPADA)'
  },
  'Punjab': {
    state: 'Punjab',
    baseRate: 7.0,
    genderOverrides: { Female: 5.0, Male: null, 'Joint (Male + Female)': null, 'Other / Entity': null },
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Department of Revenue & Rehabilitation Punjab'
  },
  'Other': {
    state: 'Other',
    baseRate: 5.0,
    genderOverrides: {},
    slabs: [],
    registrationRate: 1.0,
    registrationCap: null,
    lastVerifiedOn: new Date('2026-08-01T00:00:00.000Z'),
    source: 'Indian Stamp Act (Central Baseline)'
  }
};

/**
 * Resolves the configuration bundle for all states and global rules.
 */
async function getStampDutyConfigBundle() {
  try {
    const mongoose = require('mongoose');
    if (mongoose.connection && mongoose.connection.readyState === 1) {
      const dbConfigs = await StampDutyConfig.find({}).sort({ state: 1 });
      if (dbConfigs && dbConfigs.length > 0) {
        return {
          states: dbConfigs,
          globalRules: GLOBAL_STAMP_DUTY_RULES
        };
      }
    }
  } catch (err) {
    console.warn('Could not fetch StampDutyConfig from DB, using fallback defaults:', err.message);
  }

  return {
    states: Object.values(DEFAULT_STATE_CONFIGS_MAP),
    globalRules: GLOBAL_STAMP_DUTY_RULES
  };
}

/**
 * Calculates official stamp duty, registration fee, and total payable amount.
 * Evaluates rules engine according to state config and global rules.
 *
 * @param {Object} params
 * @param {string} params.state - Indian state/UT
 * @param {string} [params.propertyType='Residential'] - Type of property
 * @param {number} [params.agreementValue=0] - Declared agreement / consideration value
 * @param {number} [params.circleRate=0] - Government circle rate / ready reckoner value
 * @param {string} [params.gender='Male'] - Buyer gender category
 * @param {string|boolean} [params.firstTimeBuyer='No'] - First-time home buyer status ('Yes'/'No' or bool)
 * @param {Object} [params.customConfig=null] - Optional specific state config override
 * @returns {Object} Full breakdown of rates and amounts
 */
function calculateStampDuty({
  state,
  propertyType = 'Residential',
  agreementValue = 0,
  circleRate = 0,
  gender = 'Male',
  firstTimeBuyer = 'No',
  customConfig = null
}) {
  const normState = (state || '').trim();
  const normPropertyType = VALID_PROPERTY_TYPES.includes(propertyType) ? propertyType : 'Residential';
  const normGender = VALID_GENDERS.includes(gender) ? gender : 'Male';
  const isFirstTime = firstTimeBuyer === 'Yes' || firstTimeBuyer === true || firstTimeBuyer === 'true';

  const propVal = Math.max(0, Number(agreementValue) || 0);
  const circleVal = Math.max(0, Number(circleRate) || 0);

  // Applicable market value is the higher of Property Value or Circle Rate
  const applicableMarketValue = Math.max(propVal, circleVal);

  if (applicableMarketValue <= 0) {
    throw new Error('Property value or circle rate must be greater than zero.');
  }

  // 1. Resolve State Configuration
  const stateConfig = customConfig || DEFAULT_STATE_CONFIGS_MAP[normState] || DEFAULT_STATE_CONFIGS_MAP['Other'];

  // 2. Resolve Base Rate (from Slabs, Gender Overrides, or Default Base Rate)
  let baseRate = stateConfig.baseRate !== undefined ? Number(stateConfig.baseRate) : 5.0;

  if (Array.isArray(stateConfig.slabs) && stateConfig.slabs.length > 0) {
    // Slabs evaluation in ascending order
    for (const slab of stateConfig.slabs) {
      if (slab.maxValue == null || applicableMarketValue <= Number(slab.maxValue)) {
        baseRate = Number(slab.rate);
        break;
      }
    }
  } else if (stateConfig.genderOverrides) {
    const overrides = stateConfig.genderOverrides instanceof Map 
      ? Object.fromEntries(stateConfig.genderOverrides) 
      : stateConfig.genderOverrides;

    if (overrides[normGender] !== undefined && overrides[normGender] !== null) {
      baseRate = Number(overrides[normGender]);
    }
  }

  // 3. Apply Global Property Type Adjustments
  const propAdj = GLOBAL_STAMP_DUTY_RULES.propertyTypeAdjustments[normPropertyType];
  if (propAdj) {
    if (propAdj.type === 'add') {
      baseRate += propAdj.value;
    } else if (propAdj.type === 'multiply') {
      baseRate = Math.min(propAdj.maxRate, Math.max(propAdj.minRate, baseRate * propAdj.multiplier));
    }
  }

  // 4. Apply Global First-Time Buyer Concession
  const ftRule = GLOBAL_STAMP_DUTY_RULES.firstTimeBuyerConcession;
  if (isFirstTime && baseRate > ftRule.thresholdRate) {
    baseRate = Math.min(ftRule.maxRate, Math.max(ftRule.minRate, baseRate - ftRule.discount));
  }

  // 5. Calculate Registration Rate & Amount
  const regRate = stateConfig.registrationRate !== undefined ? Number(stateConfig.registrationRate) : 1.0;
  let regAmount = applicableMarketValue * (regRate / 100.0);

  if (stateConfig.registrationCap !== null && stateConfig.registrationCap !== undefined) {
    const cap = Number(stateConfig.registrationCap);
    if (cap > 0 && regAmount > cap) {
      regAmount = cap;
    }
  }

  const stampDutyRate = Math.round(baseRate * 100) / 100;
  const stampDutyAmount = Math.round((applicableMarketValue * (stampDutyRate / 100.0)) * 100) / 100;
  regAmount = Math.round(regAmount * 100) / 100;
  const totalPayable = Math.round((stampDutyAmount + regAmount) * 100) / 100;

  return {
    state: normState || 'Other',
    propertyType: normPropertyType,
    agreementValue: propVal,
    circleRate: circleVal,
    applicableMarketValue,
    gender: normGender,
    firstTimeBuyer: isFirstTime ? 'Yes' : 'No',
    stampDutyRate,
    stampDutyAmount,
    registrationRate: regRate,
    registrationAmount: regAmount,
    totalPayable,
    lastVerifiedOn: stateConfig.lastVerifiedOn,
    source: stateConfig.source
  };
}

module.exports = {
  calculateStampDuty,
  getStampDutyConfigBundle,
  GLOBAL_STAMP_DUTY_RULES,
  DEFAULT_STATE_CONFIGS_MAP,
  VALID_PROPERTY_TYPES,
  VALID_GENDERS
};
