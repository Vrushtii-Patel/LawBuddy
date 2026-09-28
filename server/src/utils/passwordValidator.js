const COMMON_PASSWORDS = new Set([
  'password',
  'password1',
  'password123',
  '12345678',
  '123456789',
  '1234567890',
  'qwerty123',
  'admin123',
  'welcome123',
  'iloveyou1',
  'letmein123',
  'changeme1',
  'pass1234',
  'lawbuddy123'
]);

function validatePassword(password) {
  if (!password || typeof password !== 'string') {
    return {
      valid: false,
      code: 'WEAK_PASSWORD',
      error: 'Password is required'
    };
  }

  const byteLength = Buffer.byteLength(password, 'utf8');
  if (byteLength < 8) {
    return {
      valid: false,
      code: 'WEAK_PASSWORD',
      error: 'Password must be at least 8 characters long'
    };
  }

  if (byteLength > 72) {
    return {
      valid: false,
      code: 'WEAK_PASSWORD',
      error: 'Password must not exceed 72 bytes'
    };
  }

  if (!/[a-zA-Z]/.test(password)) {
    return {
      valid: false,
      code: 'WEAK_PASSWORD',
      error: 'Password must contain at least one letter'
    };
  }

  if (!/[0-9]/.test(password)) {
    return {
      valid: false,
      code: 'WEAK_PASSWORD',
      error: 'Password must contain at least one number'
    };
  }

  if (COMMON_PASSWORDS.has(password.toLowerCase())) {
    return {
      valid: false,
      code: 'WEAK_PASSWORD',
      error: 'This password is too common. Please choose a more secure password.'
    };
  }

  return { valid: true };
}

module.exports = {
  validatePassword,
  COMMON_PASSWORDS
};
