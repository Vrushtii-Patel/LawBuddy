const assert = require('assert');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const StampDutyConfig = require('../src/models/StampDutyConfig');
const {
  calculateStampDuty,
  calculateStampDutySync,
  getStampDutyConfigBundle
} = require('../src/services/stampDutyService');

async function runTests() {
  console.log('--- Testing stampDutyService ---');

  let mongod = null;

  try {
    // Test 1: Maharashtra standard residential
    {
      const res = await calculateStampDuty({
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
      const res = await calculateStampDuty({
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
      const res = await calculateStampDuty({
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
      const res = await calculateStampDuty({
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
      const res = await calculateStampDuty({
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
      await assert.rejects(async () => {
        await calculateStampDuty({
          state: 'Delhi',
          agreementValue: 0,
          circleRate: 0
        });
      }, /must be greater than zero/);
      console.log('✓ Test 6: Zero value rejection passed');
    }

    // Test 7: Karnataka Slabs
    {
      const k1 = await calculateStampDuty({ state: 'Karnataka', agreementValue: 1500000 });
      assert.strictEqual(k1.stampDutyRate, 2.0);

      const k2 = await calculateStampDuty({ state: 'Karnataka', agreementValue: 3000000 });
      assert.strictEqual(k2.stampDutyRate, 3.0);

      const k3 = await calculateStampDuty({ state: 'Karnataka', agreementValue: 6000000 });
      assert.strictEqual(k3.stampDutyRate, 5.0);
      console.log('✓ Test 7: Karnataka Slabs (2%, 3%, 5%) passed');
    }

    // Test 8: West Bengal Slabs
    {
      const wb1 = await calculateStampDuty({ state: 'West Bengal', agreementValue: 3000000 });
      assert.strictEqual(wb1.stampDutyRate, 5.0);

      const wb2 = await calculateStampDuty({ state: 'West Bengal', agreementValue: 5000000 });
      assert.strictEqual(wb2.stampDutyRate, 6.0);
      console.log('✓ Test 8: West Bengal Slabs (5%, 6%) passed');
    }

    // Test 9: Config Bundle Structure
    {
      const bundle = await getStampDutyConfigBundle();
      assert(Array.isArray(bundle.states));
      assert(bundle.states.length >= 13);
      assert(bundle.globalRules.propertyTypeAdjustments);
      assert(bundle.globalRules.firstTimeBuyerConcession);
      console.log(`✓ Test 9: Config bundle returns ${bundle.states.length} states and global rules`);
    }

    // Test 10: Unknown / Misspelled state rejection (Item 28 bug fix)
    {
      await assert.rejects(async () => {
        await calculateStampDuty({
          state: 'Maharastra',
          agreementValue: 5000000
        });
      }, /Unknown state "Maharastra"/);

      await assert.rejects(async () => {
        await calculateStampDuty({
          state: '',
          agreementValue: 5000000
        });
      }, /State is required/);

      await assert.rejects(async () => {
        calculateStampDutySync({
          state: 'UnknownStateXYZ',
          agreementValue: 1000000
        });
      }, /Unknown state "UnknownStateXYZ"/);

      console.log('✓ Test 10: Misspelled/unknown states are rejected with clear error instead of silently using "Other"');
    }

    // Test 11: DB Config Priority Over Built-in Defaults (Item 28 bug fix)
    {
      mongod = await MongoMemoryServer.create();
      await mongoose.connect(mongod.getUri());

      // Seed a custom database config for Goa with 3.5% base rate
      await StampDutyConfig.create({
        state: 'Goa',
        baseRate: 3.5,
        genderOverrides: {},
        slabs: [],
        registrationRate: 1.0,
        registrationCap: null,
        lastVerifiedOn: new Date(),
        source: 'Goa Revenue Department (DB Override Test)'
      });

      // Calculate for Goa (which only exists in DB)
      const goaRes = await calculateStampDuty({
        state: 'Goa',
        agreementValue: 2000000,
        gender: 'Male'
      });

      assert.strictEqual(goaRes.state, 'Goa');
      assert.strictEqual(goaRes.stampDutyRate, 3.5);
      assert.strictEqual(goaRes.stampDutyAmount, 70000);
      assert.strictEqual(goaRes.source, 'Goa Revenue Department (DB Override Test)');

      // Update Maharashtra in DB with amended rate (e.g., 7.5%)
      await StampDutyConfig.create({
        state: 'Maharashtra',
        baseRate: 7.5,
        genderOverrides: { Female: 6.5 },
        slabs: [],
        registrationRate: 1.0,
        registrationCap: 35000,
        lastVerifiedOn: new Date(),
        source: 'Amended IGR Maharashtra DB Record'
      });

      const mhDbRes = await calculateStampDuty({
        state: 'Maharashtra',
        agreementValue: 5000000,
        gender: 'Male'
      });

      assert.strictEqual(mhDbRes.stampDutyRate, 7.5, 'DB rate of 7.5% must be used instead of built-in 6.0%');
      assert.strictEqual(mhDbRes.stampDutyAmount, 375000);
      assert.strictEqual(mhDbRes.registrationAmount, 35000);
      assert.strictEqual(mhDbRes.source, 'Amended IGR Maharashtra DB Record');
      console.log('✓ Test 11: Database configs take priority over built-in defaults for existing & newly added states');
    }

    // Test 12: Synchronous Helper & Custom Config Support
    {
      const syncRes = calculateStampDutySync({
        state: 'Delhi',
        agreementValue: 2000000,
        circleRate: 1000000,
        gender: 'Female'
      });
      assert.strictEqual(syncRes.stampDutyRate, 4.0);

      const customRes = calculateStampDutySync({
        state: 'SpecialZone',
        agreementValue: 1000000,
        customConfig: {
          state: 'SpecialZone',
          baseRate: 1.5,
          registrationRate: 0.5
        }
      });
      assert.strictEqual(customRes.stampDutyRate, 1.5);
      assert.strictEqual(customRes.registrationRate, 0.5);
      console.log('✓ Test 12: calculateStampDutySync and customConfig overrides work cleanly');
    }

    console.log('\nAll stampDutyService tests passed successfully (12/12)!');
  } finally {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
    if (mongod) {
      await mongod.stop();
    }
  }
}

runTests().catch(err => {
  console.error(err);
  process.exit(1);
});
