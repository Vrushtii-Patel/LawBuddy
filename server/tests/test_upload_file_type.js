const assert = require('assert');
const { validateFileSignature, uploadDocument } = require('../src/middleware/uploadMiddleware');

function runTests() {
  console.log('=== Starting Upload File Type & Signature Validation Test Suite ===\n');

  const validPdf = Buffer.from('%PDF-1.7\nSample PDF body');
  const validJpeg = Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);
  const validPng = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]);
  const validWebp = Buffer.concat([
    Buffer.from([0x52, 0x49, 0x46, 0x46]), // 'RIFF'
    Buffer.alloc(4),
    Buffer.from([0x57, 0x45, 0x42, 0x50])  // 'WEBP'
  ]);

  // Buffer with %PDF somewhere in the first 1 KB (e.g. offset 50), but not at offset 0
  const bufferWithPdfInside = Buffer.concat([
    Buffer.alloc(50, 0xAA),
    Buffer.from('%PDF-1.4 header buried in data'),
    Buffer.alloc(100, 0xBB)
  ]);

  // --- SECTION 1: Reject octet-stream ---
  console.log('--- Section 1: Reject octet-stream ---');
  assert.strictEqual(
    validateFileSignature(validPdf, 'application/octet-stream', '.pdf'),
    false,
    'PDF with application/octet-stream must be rejected'
  );
  assert.strictEqual(
    validateFileSignature(validJpeg, 'application/octet-stream', '.jpg'),
    false,
    'JPEG with application/octet-stream must be rejected'
  );
  assert.strictEqual(
    validateFileSignature(validPdf, 'binary/octet-stream', '.pdf'),
    false,
    'binary/octet-stream must be rejected'
  );
  console.log('✓ Section 1 Passed: octet-stream MIME types are strictly rejected.');

  // --- SECTION 2: JPEG bytes named .pdf ---
  console.log('\n--- Section 2: JPEG bytes named .pdf ---');
  assert.strictEqual(
    validateFileSignature(validJpeg, 'application/octet-stream', '.pdf'),
    false,
    'JPEG bytes named .pdf with application/octet-stream must be rejected'
  );
  assert.strictEqual(
    validateFileSignature(validJpeg, 'application/pdf', '.pdf'),
    false,
    'JPEG bytes named .pdf with application/pdf must be rejected'
  );
  assert.strictEqual(
    validateFileSignature(validJpeg, '', '.pdf'),
    false,
    'JPEG bytes named .pdf without MIME must be rejected'
  );
  console.log('✓ Section 2 Passed: JPEG bytes named .pdf are strictly rejected.');

  // --- SECTION 3: %PDF anywhere in first 1 KB cannot pass as image or PDF ---
  console.log('\n--- Section 3: %PDF buried in buffer ---');
  assert.strictEqual(
    validateFileSignature(bufferWithPdfInside, 'image/jpeg', '.jpg'),
    false,
    'Buried %PDF claiming to be JPEG must be rejected'
  );
  assert.strictEqual(
    validateFileSignature(bufferWithPdfInside, 'image/png', '.png'),
    false,
    'Buried %PDF claiming to be PNG must be rejected'
  );
  assert.strictEqual(
    validateFileSignature(bufferWithPdfInside, 'application/pdf', '.pdf'),
    false,
    'Buried %PDF not at very start must be rejected as PDF'
  );
  console.log('✓ Section 3 Passed: Non-start %PDF cannot pass as image or PDF.');

  // --- SECTION 4: Real PDF requires %PDF at the very start (offset 0) ---
  console.log('\n--- Section 4: %PDF at the very start ---');
  assert.strictEqual(
    validateFileSignature(validPdf, 'application/pdf', '.pdf'),
    true,
    'Valid PDF with %PDF at offset 0 must pass'
  );
  assert.strictEqual(
    validateFileSignature(validPdf, 'image/jpeg', '.jpg'),
    false,
    'Valid PDF claiming to be JPEG must be rejected'
  );
  console.log('✓ Section 4 Passed: PDF requires %PDF at very start and type matching.');

  // --- SECTION 5: Valid Images and Type Matching ---
  console.log('\n--- Section 5: Valid images and type matching ---');
  assert.strictEqual(validateFileSignature(validJpeg, 'image/jpeg', '.jpg'), true, 'Valid JPEG .jpg');
  assert.strictEqual(validateFileSignature(validJpeg, 'image/jpeg', '.jpeg'), true, 'Valid JPEG .jpeg');
  assert.strictEqual(validateFileSignature(validPng, 'image/png', '.png'), true, 'Valid PNG .png');
  assert.strictEqual(validateFileSignature(validWebp, 'image/webp', '.webp'), true, 'Valid WebP .webp');

  // Cross-type mismatches
  assert.strictEqual(validateFileSignature(validPng, 'image/jpeg', '.jpg'), false, 'PNG bytes claiming to be JPG');
  assert.strictEqual(validateFileSignature(validJpeg, 'image/png', '.png'), false, 'JPEG bytes claiming to be PNG');
  assert.strictEqual(validateFileSignature(validWebp, 'image/jpeg', '.jpg'), false, 'WebP bytes claiming to be JPG');
  console.log('✓ Section 5 Passed: All valid image types pass and cross-type mismatches are rejected.');

  // --- SECTION 6: Edge Cases & Malformed Inputs ---
  console.log('\n--- Section 6: Edge cases & malformed inputs ---');
  assert.strictEqual(validateFileSignature(null), false, 'null buffer rejected');
  assert.strictEqual(validateFileSignature(Buffer.alloc(0)), false, 'empty buffer rejected');
  assert.strictEqual(validateFileSignature(Buffer.from([0x01, 0x02, 0x03])), false, 'short buffer rejected');
  assert.strictEqual(validateFileSignature(Buffer.from('not a valid file header at all'), 'application/pdf', '.pdf'), false, 'random string rejected');
  console.log('✓ Section 6 Passed: Malformed and edge case inputs rejected.');

  console.log('\n🎉 ALL FILE SIGNATURE AND TYPE CHECK TESTS PASSED (100%)!\n');
}

runTests();
