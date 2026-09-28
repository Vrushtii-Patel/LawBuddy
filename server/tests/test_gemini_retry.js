const assert = require('assert');
const { withRetry, GEMINI_CANDIDATE_MODELS } = require('../src/services/llmService');

async function runTests() {
  console.log('--- Running withRetry Unit & Integration Tests ---');

  // =========================================================================
  // Test 1: Successful on first attempt
  // =========================================================================
  {
    let callCount = 0;
    const result = await withRetry(async (model) => {
      callCount++;
      return `success from ${model}`;
    }, null, 3, 100);

    assert.strictEqual(callCount, 1, 'Should succeed on first call');
    assert.strictEqual(result, `success from ${GEMINI_CANDIDATE_MODELS[0]}`);
    console.log('✓ Test 1 Passed: Immediate success returns result without retry');
  }

  // =========================================================================
  // Test 2: 'retries' parameter controls retry attempts on transient error
  // =========================================================================
  {
    let attemptsOnFirstModel = 0;
    const customRetries = 3; // 1 initial + 3 retries = 4 attempts total on first model
    let callLog = [];

    const result = await withRetry(
      async (model) => {
        callLog.push(model);
        if (model === GEMINI_CANDIDATE_MODELS[0]) {
          attemptsOnFirstModel++;
          if (attemptsOnFirstModel <= customRetries) {
            throw new Error('503 Service Unavailable spike');
          }
          return 'recovered on 4th attempt';
        }
        return `success from ${model}`;
      },
      null,
      customRetries,
      10 // small baseDelay for fast test
    );

    assert.strictEqual(attemptsOnFirstModel, 4, 'Should execute 1 initial attempt + 3 retries on transient error');
    assert.strictEqual(result, 'recovered on 4th attempt');
    console.log('✓ Test 2 Passed: retries parameter accurately controls retry attempt count');
  }

  // =========================================================================
  // Test 3: 'baseDelay' parameter controls exponential backoff
  // =========================================================================
  {
    const recordedDelays = [];
    let lastTime = Date.now();

    await withRetry(
      async (model) => {
        const now = Date.now();
        const elapsed = now - lastTime;
        lastTime = now;
        recordedDelays.push(elapsed);

        if (recordedDelays.length <= 2) {
          throw new Error('503 Transient Error');
        }
        return 'success';
      },
      null,
      2,
      50 // baseDelay = 50ms -> backoff should be ~50ms on retry 1, ~100ms on retry 2
    );

    // recordedDelays[0] is initial call
    // recordedDelays[1] should be >= 40ms (attempt 1 -> 50ms)
    // recordedDelays[2] should be >= 80ms (attempt 2 -> 100ms)
    assert.ok(recordedDelays.length === 3, 'Should have 3 attempts');
    assert.ok(recordedDelays[1] >= 35, `Retry 1 delay should reflect baseDelay (~50ms), got ${recordedDelays[1]}ms`);
    assert.ok(recordedDelays[2] >= 75, `Retry 2 delay should reflect exponential backoff (~100ms), got ${recordedDelays[2]}ms`);
    console.log('✓ Test 3 Passed: baseDelay correctly scales exponential backoff timing');
  }

  // =========================================================================
  // Test 4: Rate limit / 429 / 404 / QuotaFailure immediately fails over to next candidate model
  // =========================================================================
  {
    const modelAttempts = [];

    const result = await withRetry(
      async (model) => {
        modelAttempts.push(model);
        if (model === GEMINI_CANDIDATE_MODELS[0]) {
          throw new Error('429 QuotaFailure ResourceExhausted');
        }
        if (model === GEMINI_CANDIDATE_MODELS[1]) {
          throw new Error('404 Model gemini-3.1-flash-lite is no longer available');
        }
        return `success from ${model}`;
      },
      null,
      3, // retries configured as 3, but 429/404 should NOT retry the same model
      50
    );

    assert.strictEqual(modelAttempts[0], GEMINI_CANDIDATE_MODELS[0], 'First tried model 0');
    assert.strictEqual(modelAttempts[1], GEMINI_CANDIDATE_MODELS[1], 'Model 0 broke retry loop and failed over to model 1');
    assert.strictEqual(modelAttempts[2], GEMINI_CANDIDATE_MODELS[2], 'Model 1 broke retry loop and failed over to model 2');
    assert.strictEqual(result, `success from ${GEMINI_CANDIDATE_MODELS[2]}`);
    console.log('✓ Test 4 Passed: 404/429/Quota immediately bypasses inner retries and fails over in candidate model order');
  }

  // =========================================================================
  // Test 5: Edge cases - retries <= 0 and baseDelay <= 0
  // =========================================================================
  {
    let attempts = 0;
    let failed = false;

    try {
      await withRetry(
        async (model) => {
          attempts++;
          throw new Error('503 Unavailable');
        },
        null,
        0, // 0 retries
        -100 // negative baseDelay
      );
    } catch (err) {
      failed = true;
    }

    assert.strictEqual(failed, true, 'Should throw after all candidates fail');
    // Each model in GEMINI_CANDIDATE_MODELS should be tried exactly once (0 retries)
    assert.strictEqual(attempts, GEMINI_CANDIDATE_MODELS.length, `With retries=0, each model tried exactly once (${GEMINI_CANDIDATE_MODELS.length} attempts total)`);
    console.log('✓ Test 5 Passed: retries <= 0 and negative baseDelay handled safely without infinite loops or errors');
  }

  // =========================================================================
  // Test 6: Fallback function when all Gemini candidate models fail
  // =========================================================================
  {
    const originalOpenRouterKey = process.env.OPENROUTER_API_KEY;
    process.env.OPENROUTER_API_KEY = 'test-key';
    let fallbackCalled = false;

    try {
      const result = await withRetry(
        async (model) => {
          throw new Error('429 Quota exhausted across all models');
        },
        async () => {
          fallbackCalled = true;
          return 'fallback success';
        },
        1,
        0
      );

      assert.strictEqual(fallbackCalled, true, 'Fallback function was invoked');
      assert.strictEqual(result, 'fallback success');
      console.log('✓ Test 6 Passed: OpenRouter fallback executed successfully when all Gemini candidate models fail');
    } finally {
      process.env.OPENROUTER_API_KEY = originalOpenRouterKey;
    }
  }

  console.log('\nALL withRetry TESTS PASSED SUCCESSFULLY (6/6)!');
}

runTests().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
