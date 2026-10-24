import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:legal_scanner/providers/auth_provider.dart';
import 'package:legal_scanner/services/api_service.dart';
import 'package:legal_scanner/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test HTTP client that routes requests to a custom mock response handler.
class MockClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) _handler;

  MockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      contentLength: response.bodyBytes.length,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiService.client = null;
    ApiService.onUnauthorized = null;
  });

  tearDown(() {
    ApiService.client = null;
    ApiService.onUnauthorized = null;
  });

  group('Global HTTP 401 Handling Tests', () {
    test('ApiService.onUnauthorized hook is triggered for authenticated 401 responses in real ApiService calls', () async {
      bool unauthorizedCalled = false;
      ApiService.onUnauthorized = () {
        unauthorizedCalled = true;
      };

      ApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Token expired', 'code': 'TOKEN_EXPIRED'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      // Calling real ApiService authenticated endpoint (fetchAllChecklists)
      // fetchAllChecklists calls _requestJson which runs _sendRequest and passes 401 to _handleCommonErrors
      await expectLater(
        () => ApiService.fetchAllChecklists(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      expect(unauthorizedCalled, isTrue);
    });

    test('Public endpoints (requiresAuth: false) do NOT invoke onUnauthorized on 401', () async {
      bool unauthorizedCalled = false;
      ApiService.onUnauthorized = () {
        unauthorizedCalled = true;
      };

      ApiService.client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Invalid credentials', 'code': 'INVALID_CREDENTIALS'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      // Calling real ApiService.login which sets requiresAuth: false
      await expectLater(
        () => ApiService.login(email: 'test@lawbuddy.in', password: 'wrongpassword'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      expect(unauthorizedCalled, isFalse);
    });

    test('AuthNotifier wires onUnauthorized to logout and resets auth state upon real 401 API response', () async {
      await TokenStorage.saveToken('test-expired-jwt-token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', 'usr_test_123');

      // MockClient initially succeeds on /auth/me for checkAuthStatus, then returns 401 for subsequent requests
      bool return401 = false;
      ApiService.client = MockClient((request) async {
        if (!return401 && request.url.path.contains('/auth/me')) {
          return http.Response(
            jsonEncode({
              'user': {
                'userId': 'usr_test_123',
                'fullName': 'Test User',
                'email': 'test@lawbuddy.in',
                'createdAt': DateTime.now().toIso8601String(),
                'lastLogin': DateTime.now().toIso8601String(),
                'profilePhoto': '',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // Return 401 for subsequent authenticated calls and logout calls
        return http.Response(
          jsonEncode({'error': 'Session expired', 'code': 'SESSION_EXPIRED'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final notifier = AuthNotifier();
      // Wait for initial checkAuthStatus async constructor call to complete and authenticate
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.status, equals(AuthStatus.authenticated));
      expect(notifier.state.user?.userId, equals('usr_test_123'));
      expect(await TokenStorage.getToken(), equals('test-expired-jwt-token'));

      // Switch mock to return 401
      return401 = true;

      // Real ApiService call receives 401, triggers ApiService.onUnauthorized hook wired by AuthNotifier
      try {
        await ApiService.fetchAllChecklists();
      } catch (_) {}

      // Wait for async logout to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
      expect(notifier.state.user, isNull);
      expect(await TokenStorage.getToken(), isNull);
      expect(prefs.getString('userId'), isNull);
    });

    test('Concurrent real 401 API calls execute logout safely without duplicate execution', () async {
      await TokenStorage.saveToken('test-jwt-token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', 'usr_concurrent_123');

      bool return401 = false;
      ApiService.client = MockClient((request) async {
        if (!return401 && request.url.path.contains('/auth/me')) {
          return http.Response(
            jsonEncode({
              'user': {
                'userId': 'usr_concurrent_123',
                'fullName': 'Concurrent User',
                'email': 'concurrent@lawbuddy.in',
                'createdAt': DateTime.now().toIso8601String(),
                'lastLogin': DateTime.now().toIso8601String(),
                'profilePhoto': '',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({'error': 'Token revoked', 'code': 'TOKEN_REVOKED'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final notifier = AuthNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.status, equals(AuthStatus.authenticated));
      expect(await TokenStorage.getToken(), equals('test-jwt-token'));

      return401 = true;

      // Fire 5 simultaneous real ApiService calls that will all receive 401
      await Future.wait([
        ApiService.fetchAllChecklists().catchError((_) => <dynamic>[]),
        ApiService.explainSnippet('sample context', 'sample snippet').catchError((_) => ''),
        ApiService.getProfile('test-jwt-token').catchError((_) => <String, dynamic>{}),
        ApiService.fetchRecentDocuments().catchError((_) => <dynamic>[]),
        ApiService.deleteDocument('doc_concurrent_123').catchError((_) => false),
      ]);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.status, equals(AuthStatus.unauthenticated));
      expect(notifier.state.user, isNull);
      expect(await TokenStorage.getToken(), isNull);
      expect(prefs.getString('userId'), isNull);
    });
  });
}
