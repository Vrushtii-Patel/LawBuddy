const assert = require('assert');
const { calculateStampDuty } = require('./src/services/stampDutyService');

console.log('--- Testing stampDutyService ---');

// Test 1: Maharashtra standard residential
{
  const res = calculateStampDuty({
    state: 'Maharashtra',
    propertyType: 'Residential',
    agreementValue: 5000000,
    circleRate: 4000000,
    gender: 'Male',
    firstTimeBuyer: 'No'
  });
  assert.strictEqual(res.applicableMarketValue, 5000000);
  assert.strictEqual(res.stampDutyRate, 6.0);
  assert.strictEqual(res.stampDutyAmount, 300000);
  // Reg rate is 1% capped at 30k for MH
  assert.strictEqual(res.registrationAmount, 30000);
  assert.strictEqual(res.totalPayable, 330000);
  console.log('✓ Test 1: Maharashtra Male passed');
}

// Test 2: Maharashtra female concession & first-time buyer
{
  const res = calculateStampDuty({
    state: 'Maharashtra',
    propertyType: 'Residential',
    agreementValue: 5000000,
    gender: 'Female',
    firstTimeBuyer: 'Yes'
  });
  // base = 6 - 1 (female) = 5.0; first-time buyer -0.5 = 4.5
  assert.strictEqual(res.stampDutyRate, 4.5);
  assert.strictEqual(res.stampDutyAmount, 225000);
  assert.strictEqual(res.registrationAmount, 30000);
  assert.strictEqual(res.totalPayable, 255000);
  console.log('✓ Test 2: Maharashtra Female + First Time Buyer passed');
}

// Test 3: Gujarat female 100% exemption
{
  const res = calculateStampDuty({
    state: 'Gujarat',
    propertyType: 'Residential',
    agreementValue: 3000000,
    gender: 'Female',
    firstTimeBuyer: 'No'
  });
  assert.strictEqual(res.stampDutyRate, 0);
  assert.strictEqual(res.stampDutyAmount, 0);
  assert.strictEqual(res.registrationAmount, 30000);
  assert.strictEqual(res.totalPayable, 30000);
  console.log('✓ Test 3: Gujarat Female 100% exemption passed');
}

// Test 4: Higher circle rate than agreement value
{
  const res = calculateStampDuty({
    state: 'Delhi',
    propertyType: 'Residential',
    agreementValue: 2000000,
    circleRate: 3500000,
    gender: 'Male',
    firstTimeBuyer: 'No'
  });
  assert.strictEqual(res.applicableMarketValue, 3500000);
  assert.strictEqual(res.stampDutyRate, 6.0);
  assert.strictEqual(res.stampDutyAmount, 210000);
  assert.strictEqual(res.registrationAmount, 35000);
  assert.strictEqual(res.totalPayable, 245000);
  console.log('✓ Test 4: Higher circle rate passed');
}

// Test 5: Tamil Nadu 4% registration rate
{
  const res = calculateStampDuty({
    state: 'Tamil Nadu',
    propertyType: 'Residential',
    agreementValue: 1000000,
    gender: 'Male',
    firstTimeBuyer: 'No'
  });
  assert.strictEqual(res.stampDutyRate, 7.0);
  assert.strictEqual(res.stampDutyAmount, 70000);
  assert.strictEqual(res.registrationRate, 4.0);
  assert.strictEqual(res.registrationAmount, 40000);
  assert.strictEqual(res.totalPayable, 110000);
  console.log('✓ Test 5: Tamil Nadu passed');
}

// Test 6: Zero/negative value throws error
{
  assert.throws(() => {
    calculateStampDuty({
      state: 'Delhi',
      agreementValue: 0,
      circleRate: 0
    });
  }, /must be greater than zero/);
  console.log('✓ Test 6: Zero value rejection passed');
}

console.log('All stampDutyService tests passed successfully!');
