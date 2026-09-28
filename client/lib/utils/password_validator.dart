import 'dart:convert';

class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasLetter;
  final bool hasNumber;
  final bool isNotTooLong;
  final bool isNotCommon;
  final String? errorMessage;
  final String? errorCode;

  const PasswordValidationResult({
    required this.hasMinLength,
    required this.hasLetter,
    required this.hasNumber,
    required this.isNotTooLong,
    required this.isNotCommon,
    this.errorMessage,
    this.errorCode,
  });

  bool get isValid =>
      hasMinLength && hasLetter && hasNumber && isNotTooLong && isNotCommon;
}

class PasswordValidator {
  PasswordValidator._();

  static const Set<String> commonPasswords = {
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
  };

  static PasswordValidationResult validate(String password) {
    if (password.isEmpty) {
      return const PasswordValidationResult(
        hasMinLength: false,
        hasLetter: false,
        hasNumber: false,
        isNotTooLong: true,
        isNotCommon: true,
        errorMessage: 'Password is required',
        errorCode: 'WEAK_PASSWORD',
      );
    }

    final int byteLength = utf8.encode(password).length;
    final bool hasMinLength = password.length >= 8 && byteLength >= 8;
    final bool isNotTooLong = byteLength <= 72;
    final bool hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final bool hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final bool isNotCommon = !commonPasswords.contains(password.toLowerCase());

    String? errorMessage;
    if (!hasMinLength) {
      errorMessage = 'Password must be at least 8 characters long.';
    } else if (!isNotTooLong) {
      errorMessage = 'Password must not exceed 72 bytes.';
    } else if (!hasLetter) {
      errorMessage = 'Password must contain at least one letter.';
    } else if (!hasNumber) {
      errorMessage = 'Password must contain at least one number.';
    } else if (!isNotCommon) {
      errorMessage = 'This password is too common. Please choose a stronger password.';
    }

    return PasswordValidationResult(
      hasMinLength: hasMinLength,
      hasLetter: hasLetter,
      hasNumber: hasNumber,
      isNotTooLong: isNotTooLong,
      isNotCommon: isNotCommon,
      errorMessage: errorMessage,
      errorCode: errorMessage != null ? 'WEAK_PASSWORD' : null,
    );
  }
}
