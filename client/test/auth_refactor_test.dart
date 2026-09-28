import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:legal_scanner/models/user_model.dart';
import 'package:legal_scanner/providers/auth_provider.dart';
import 'package:legal_scanner/services/api_service.dart';
import 'package:legal_scanner/utils/password_validator.dart';
import 'package:legal_scanner/screens/signup_screen.dart';
import 'package:legal_scanner/screens/login_screen.dart';
import 'package:legal_scanner/screens/forgot_password_screen.dart';
import 'package:legal_scanner/screens/reset_password_screen.dart';
import 'package:legal_scanner/widgets/password_checklist_widget.dart';
import 'package:pinput/pinput.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PasswordValidator Unit Tests', () {
    test('Valid standard password passes all checks', () {
      final res = PasswordValidator.validate('SecurePass99');
      expect(res.isValid, isTrue);
      expect(res.hasMinLength, isTrue);
      expect(res.hasLetter, isTrue);
      expect(res.hasNumber, isTrue);
      expect(res.isNotTooLong, isTrue);
      expect(res.isNotCommon, isTrue);
      expect(res.errorMessage, isNull);
      expect(res.errorCode, isNull);
    });

    test('Short password (<8 chars) fails hasMinLength', () {
      final res = PasswordValidator.validate('Pass1');
      expect(res.isValid, isFalse);
      expect(res.hasMinLength, isFalse);
      expect(res.errorCode, equals('WEAK_PASSWORD'));
    });

    test('Empty password fails', () {
      final res = PasswordValidator.validate('');
      expect(res.isValid, isFalse);
      expect(res.hasMinLength, isFalse);
      expect(res.errorCode, equals('WEAK_PASSWORD'));
    });

    test('Password without letters fails hasLetter', () {
      final res = PasswordValidator.validate('1234567890');
      expect(res.isValid, isFalse);
      expect(res.hasLetter, isFalse);
      expect(res.errorCode, equals('WEAK_PASSWORD'));
    });

    test('Password without numbers fails hasNumber', () {
      final res = PasswordValidator.validate('LettersOnlyPlease');
      expect(res.isValid, isFalse);
      expect(res.hasNumber, isFalse);
      expect(res.errorCode, equals('WEAK_PASSWORD'));
    });

    test('Common password fails isNotCommon', () {
      final res = PasswordValidator.validate('password123');
      expect(res.isValid, isFalse);
      expect(res.isNotCommon, isFalse);
      expect(res.errorMessage, contains('too common'));
    });

    test('72-byte password passes isNotTooLong', () {
      final exact72 = 'A' * 70 + '12';
      expect(utf8.encode(exact72).length, equals(72));
      final res = PasswordValidator.validate(exact72);
      expect(res.isValid, isTrue);
      expect(res.isNotTooLong, isTrue);
    });

    test('73-byte ASCII password fails isNotTooLong', () {
      final exact73 = 'A' * 71 + '12';
      expect(utf8.encode(exact73).length, equals(73));
      final res = PasswordValidator.validate(exact73);
      expect(res.isValid, isFalse);
      expect(res.isNotTooLong, isFalse);
      expect(res.errorMessage, contains('72 bytes'));
    });

    test('Non-ASCII UTF-8 multibyte password byte-length checks', () {
      // 'कानून' is 15 UTF-8 bytes (5 chars * 3 bytes).
      // 5 repetitions = 75 bytes -> exceeds 72 bytes.
      final longHindi = '${'कानून' * 5}1A';
      expect(utf8.encode(longHindi).length > 72, isTrue);
      final resLong = PasswordValidator.validate(longHindi);
      expect(resLong.isValid, isFalse);
      expect(resLong.isNotTooLong, isFalse);

      // 3 repetitions = 45 bytes + '1A' = 47 bytes -> valid byte length
      final validHindi = '${'कानून' * 3}1A';
      expect(utf8.encode(validHindi).length <= 72, isTrue);
      final resValid = PasswordValidator.validate(validHindi);
      expect(resValid.isValid, isTrue);
      expect(resValid.isNotTooLong, isTrue);
    });
  });

  group('ApiException and Error Codes', () {
    test('ApiException carries code, statusCode and cleanly formats toString', () {
      final ex = ApiException('An account already exists with this email.',
          code: 'ACCOUNT_EXISTS', statusCode: 409);
      expect(ex.message, equals('An account already exists with this email.'));
      expect(ex.code, equals('ACCOUNT_EXISTS'));
      expect(ex.statusCode, equals(409));
      expect(ex.toString(), equals('An account already exists with this email.'));
    });

    test('RateLimitException extends ApiException with default 429', () {
      final ex = RateLimitException('Too many requests. Please wait 30 seconds.');
      expect(ex, isA<ApiException>());
      expect(ex.statusCode, equals(429));
      expect(ex.toString(), equals('Too many requests. Please wait 30 seconds.'));
    });
  });

  group('AuthState and copyWith', () {
    test('AuthState retains and clears error code and message properly', () {
      final state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Invalid OTP',
        errorCode: 'INVALID_OTP',
      );
      expect(state.errorMessage, equals('Invalid OTP'));
      expect(state.errorCode, equals('INVALID_OTP'));

      final clearedState = state.copyWith(clearError: true);
      expect(clearedState.errorMessage, isNull);
      expect(clearedState.errorCode, isNull);
    });

    test('UserModel serialization with new auth fields', () {
      final json = {
        'userId': 'usr_123',
        'full_name': 'Test User',
        'email': 'test@lawbuddy.in',
        'role': 'user',
        'dateOfBirth': '1995-05-20T00:00:00.000Z',
        'preferredLanguage': 'hi',
        'termsAcceptedAt': '2026-09-28T00:00:00.000Z',
        'termsVersion': 'v1.0',
        'created_at': '2026-09-28T00:00:00.000Z',
        'last_login': '2026-09-28T00:00:00.000Z',
      };

      final user = UserModel.fromJson(json);
      expect(user.userId, equals('usr_123'));
      expect(user.fullName, equals('Test User'));
      expect(user.dateOfBirth, isNotNull);
      expect(user.dateOfBirth!.year, equals(1995));
      expect(user.preferredLanguage, equals('hi'));
      expect(user.termsVersion, equals('v1.0'));

      final serialized = user.toJson();
      expect(serialized['preferredLanguage'], equals('hi'));
      expect(serialized['termsVersion'], equals('v1.0'));
    });
  });

  group('Widget UI and Auth Flow Tests', () {
    testWidgets('PasswordChecklistWidget renders all 4 requirement items', (tester) async {
      const validation = PasswordValidationResult(
        hasMinLength: true,
        hasLetter: true,
        hasNumber: false,
        isNotTooLong: true,
        isNotCommon: true,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PasswordChecklistWidget(validation: validation),
            ),
          ),
        ),
      );

      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('At least one letter (a-z, A-Z)'), findsOneWidget);
      expect(find.text('At least one number (0-9)'), findsOneWidget);
      expect(find.text('Maximum 72 bytes'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen renders and displays legacy banner when enabled', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ForgotPasswordScreen(
              prefilledEmail: 'legacy@lawbuddy.in',
              showLegacyBanner: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Reset Your Password'), findsOneWidget);
      expect(find.text('legacy@lawbuddy.in'), findsOneWidget);
      expect(find.text('Your account was created using email OTP. Please set a password to continue.'), findsOneWidget);
    });

    testWidgets('ResetPasswordScreen enters 6-digit pin in Step 1 and reveals new password section in Step 2', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ResetPasswordScreen(
              email: 'user@example.com',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Step 1: Verification code entry
      expect(find.text('Verify Reset Code'), findsOneWidget);
      expect(find.textContaining('user@example.com'), findsOneWidget);
      expect(find.text('Continue to New Password'), findsOneWidget);

      // Enter 6-digit pin
      await tester.enterText(find.byType(Pinput), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Step 2: New Password section is revealed
      expect(find.text('Set New Password'), findsOneWidget);
      expect(find.text('Change Code'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
    });

    testWidgets('SignupScreen renders all 4 fields and detects password confirmation mismatch', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignupScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(4));

      await tester.enterText(textFields.at(0), 'LawBuddy User');
      await tester.enterText(textFields.at(1), 'user@example.com');
      await tester.enterText(textFields.at(2), 'Pass1234');
      await tester.enterText(textFields.at(3), 'DifferentPass567');
      await tester.pump();

      // Submit button must remain disabled when passwords do not match
      final submitButton = find.byType(ElevatedButton);
      final ElevatedButton buttonWidget = tester.widget(submitButton);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('LoginScreen renders prefilled email and password input', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(prefilledEmail: 'prefilled@lawbuddy.in'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('prefilled@lawbuddy.in'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });
  });
}
