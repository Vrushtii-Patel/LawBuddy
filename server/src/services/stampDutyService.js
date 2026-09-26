/**
 * Server-side authoritative Stamp Duty & Registration Fee calculation service.
 * Prevents client-side tampering and ensures financial record accuracy.
 */

const VALID_PROPERTY_TYPES = ['Residential', 'Commercial', 'Agricultural', 'Other'];

const VALID_GENDERS = [
  'Male',
  'Female',
  'Joint (Male + Female)',
  'Other / Entity'
];

/**
 * Calculates official stamp duty, registration fee, and total payable amount.
 *
 * @param {Object} params
 * @param {string} params.state - Indian state/UT
 * @param {string} [params.propertyType='Residential'] - Type of property
 * @param {number} [params.agreementValue=0] - Declared agreement / consideration value
 * @param {number} [params.circleRate=0] - Government circle rate / ready reckoner value
 * @param {string} [params.gender='Male'] - Buyer gender category
 * @param {string|boolean} [params.firstTimeBuyer='No'] - First-time home buyer status ('Yes'/'No' or bool)
 * @returns {Object} Full breakdown of rates and amounts
 */
function calculateStampDuty({
  state,
  propertyType = 'Residential',
  agreementValue = 0,
  circleRate = 0,
  gender = 'Male',
  firstTimeBuyer = 'No'
}) {
  const normState = (state || '').trim();
  const normPropertyType = VALID_PROPERTY_TYPES.includes(propertyType) ? propertyType : 'Residential';
  const normGender = VALID_GENDERS.includes(gender) ? gender : 'Male';
  const isFirstTime = firstTimeBuyer === 'Yes' || firstTimeBuyer === true || firstTimeBuyer === 'true';

  const propVal = Math.max(0, Number(agreementValue) || 0);
  const circleVal = Math.max(0, Number(circleRate) || 0);

  // Applicable value is the higher of Agreement Value or Circle Rate
  const applicableMarketValue = Math.max(propVal, circleVal);

  if (applicableMarketValue <= 0) {
    throw new Error('Property value or circle rate must be greater than zero.');
  }

  // Base Stamp Duty Rate determination per state
  let baseRate = 5.0; // Default fallback

  switch (normState) {
    case 'Maharashtra':
      baseRate = 6.0;
      if (normGender === 'Female') baseRate -= 1.0;
      break;

    case 'Karnataka':
      if (applicableMarketValue <= 2000000) {
        baseRate = 2.0;
      } else if (applicableMarketValue <= 4500000) {
        baseRate = 3.0;
      } else {
        baseRate = 5.0;
      }
      break;

    case 'Delhi':
      if (normGender === 'Female') {
        baseRate = 4.0;
      } else if (normGender === 'Joint (Male + Female)') {
        baseRate = 5.0;
      } else {
        baseRate = 6.0;
      }
      break;

    case 'Gujarat':
      baseRate = normGender === 'Female' ? 0.0 : 4.9;
      break;

    case 'Tamil Nadu':
      baseRate = 7.0;
      break;

    case 'West Bengal':
      baseRate = applicableMarketValue > 4000000 ? 6.0 : 5.0;
      break;

    case 'Uttar Pradesh':
      baseRate = 7.0;
      if (normGender === 'Female') baseRate -= 1.0;
      break;

    case 'Haryana':
      if (normGender === 'Female') {
        baseRate = 5.0;
      } else if (normGender === 'Joint (Male + Female)') {
        baseRate = 6.0;
      } else {
        baseRate = 7.0;
      }
      break;

    case 'Telangana':
      baseRate = 6.0;
      break;

    case 'Rajasthan':
      baseRate = 6.0;
      if (normGender === 'Female') baseRate -= 1.0;
      break;

    case 'Kerala':
      baseRate = 8.0;
      break;

    case 'Madhya Pradesh':
      baseRate = 7.5;
      break;

    case 'Punjab':
      baseRate = normGender === 'Female' ? 5.0 : 7.0;
      break;

    default:
      baseRate = 5.0;
      break;
  }

  // Property Type Adjustments
  if (normPropertyType === 'Commercial') {
    baseRate += 1.0;
  } else if (normPropertyType === 'Agricultural') {
    baseRate = Math.min(10.0, Math.max(1.0, baseRate * 0.7));
  }

  // First-time buyer concession (0.5% rebate where applicable, minimum floor 1.0%)
  if (isFirstTime && baseRate > 2.0) {
    baseRate = Math.min(15.0, Math.max(1.0, baseRate - 0.5));
  }

  // Registration fee calculation (Standard: 1% capped at 30,000 in Maharashtra, 4% in Tamil Nadu)
  let registrationRate = 1.0;
  let registrationAmount = applicableMarketValue * (registrationRate / 100.0);

  if (normState === 'Maharashtra' && registrationAmount > 30000) {
    registrationAmount = 30000;
  } else if (normState === 'Tamil Nadu') {
    registrationRate = 4.0;
    registrationAmount = applicableMarketValue * (registrationRate / 100.0);
  }

  const stampDutyRate = Math.round(baseRate * 100) / 100;
  const stampDutyAmount = Math.round((applicableMarketValue * (stampDutyRate / 100.0)) * 100) / 100;
  registrationAmount = Math.round(registrationAmount * 100) / 100;
  const totalPayable = Math.round((stampDutyAmount + registrationAmount) * 100) / 100;

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
    registrationRate,
    registrationAmount,
    totalPayable
  };
}

module.exports = {
  calculateStampDuty,
  VALID_PROPERTY_TYPES,
  VALID_GENDERS
};
