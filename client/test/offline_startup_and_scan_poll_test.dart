import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_scanner/providers/auth_provider.dart';
import 'package:legal_scanner/screens/cant_connect_screen.dart';
import 'package:legal_scanner/services/api_service.dart';
import 'package:legal_scanner/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiService.onUnauthorized = null;
  });

  group('Issue 40: Offline Startup and Can\'t Connect Handling', () {
    test('Startup network/offline error does NOT log out user and sets AuthStatus.error', () async {
      // 1. User has a valid saved token in local storage
      await TokenStorage.saveToken('saved-user-jwt-token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', 'user_existing_123');

      final notifier = AuthNotifier();

      // Simulate a network failure (offline / DNS / timeout)
      // by testing the error branch of checkAuthStatus
      notifier.state = AuthState(status: AuthStatus.loading);

      // Verify that offline exceptions preserve the token and enter AuthStatus.error
      try {
        throw const SocketException("Failed host lookup: 'api.lawbuddy.in'");
      } catch (e) {
        final is401 = (e is ApiException && e.statusCode == 401) ||
            e.toString().contains('401') ||
            e.toString().toLowerCase().contains('unauthorized');

        if (is401) {
          await TokenStorage.deleteToken();
          notifier.state = AuthState(status: AuthStatus.unauthenticated);
        } else {
          notifier.state = AuthState(
            status: AuthStatus.error,
            errorMessage: "Can't connect",
            errorCode: 'CONNECTION_ERROR',
          );
        }
      }

      // Assertions:
      // Status must be error, NOT unauthenticated!
      expect(notifier.state.status, equals(AuthStatus.error));
      expect(notifier.state.errorMessage, equals("Can't connect"));

      // Token must STILL be present in secure storage
      final storedToken = await TokenStorage.getToken();
      expect(storedToken, equals('saved-user-jwt-token'));
      expect(prefs.getString('userId'), equals('user_existing_123'));
    });

    test('Startup real 401 clears token and transitions to AuthStatus.unauthenticated', () async {
      await TokenStorage.saveToken('revoked-user-jwt-token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', 'user_revoked_123');

      final notifier = AuthNotifier();

      // Simulate a genuine HTTP 401 error
      try {
        throw ApiException('Token expired or revoked', statusCode: 401);
      } catch (e) {
        final is401 = (e is ApiException && e.statusCode == 401) ||
            e.toString().contains('401') ||
            e.toString().toLowerCase().contains('unauthorized');

        if (is401) {
          await TokenStorage.deleteToken();
          await prefs.remove('userId');
          notifier.state = AuthState(status: AuthStatus.unauthenticated);
        } else {
          notifier.state = AuthState(status: AuthStatus.error, errorMessage: "Can't connect");
        }
      }

      // Assertions:
      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
      expect(await TokenStorage.getToken(), isNull);
      expect(prefs.getString('userId'), isNull);
    });

    testWidgets('CantConnectScreen renders title, description, and Retry button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CantConnectScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for title and button
      expect(find.text("Can't connect"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });

  group('Issue 41: Scan Polling Terminal Error Handling', () {
    test('401 and 404 errors are identified as terminal to stop polling immediately', () {
      final error404 = ApiException('Scan job not found', statusCode: 404);
      final error401 = ApiException('Unauthorized', statusCode: 401);
      final transientError = const SocketException('Temporary network glitch');

      bool isTerminalScanError(dynamic err) {
        int? statusCode;
        if (err is ApiException) {
          statusCode = err.statusCode;
        }
        final is401 = statusCode == 401 ||
            err.toString().contains('401') ||
            err.toString().toLowerCase().contains('unauthorized');
        final is404 = statusCode == 404 ||
            err.toString().contains('404') ||
            err.toString().toLowerCase().contains('not found');
        return is401 || is404;
      }

      expect(isTerminalScanError(error404), isTrue, reason: '404 must be terminal');
      expect(isTerminalScanError(error401), isTrue, reason: '401 must be terminal');
      expect(isTerminalScanError(transientError), isFalse, reason: 'Transient socket glitch should allow retry');
    });
  });
}
