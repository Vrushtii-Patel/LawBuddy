import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:legal_scanner/providers/auth_provider.dart';
import 'package:legal_scanner/services/token_storage.dart';
import 'package:legal_scanner/screens/home_screen.dart';
import 'package:legal_scanner/screens/welcome_screen.dart';
import 'package:legal_scanner/widgets/user_profile_button.dart';
import 'package:legal_scanner/widgets/cookie_consent_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Logout & Auth Redirection Tests', () {
    test('AuthNotifier.logout() purges token and sets status to unauthenticated immediately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await TokenStorage.saveToken('mock_jwt_token_12345');
      final savedToken = await TokenStorage.getToken();
      expect(savedToken, 'mock_jwt_token_12345');

      final notifier = container.read(authProvider.notifier);
      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);

      final tokenAfterLogout = await TokenStorage.getToken();
      expect(tokenAfterLogout, isNull);
    });

    testWidgets('handleAppLogout safely redirects root navigator to WelcomeScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await TokenStorage.saveToken('test_token');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => handleAppLogout(context, ref),
                    child: const Text('Sign Out Button'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Sign Out Button'), findsOneWidget);

      await tester.tap(find.text('Sign Out Button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Root navigator should now display WelcomeScreen
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Sign Out Button'), findsNothing);
    });

    testWidgets('HomeScreen immediately redirects to WelcomeScreen when auth state becomes unauthenticated', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(
            AuthState(
              status: AuthStatus.unauthenticated,
              user: null,
            ),
          )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const HomeScreen(),
          ),
        ),
      );

      // Trigger frame callback and animation transition
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Verify HomeScreen redirects to WelcomeScreen when unauthenticated
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  void clearError() {}

  @override
  Future<void> checkAuthStatus() async {}

  @override
  Future<bool> login({required String email, required String password}) async => true;

  @override
  Future<bool> signup({
    required String email,
    required String password,
    required String fullName,
    required bool acceptedTerms,
  }) async => true;

  @override
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.unauthenticated, clearUser: true);
  }

  @override
  Future<bool> forgotPassword({required String email}) async => true;

  @override
  Future<bool> resetPassword({required String email, required String otp, required String newPassword}) async => true;

  @override
  Future<bool> verifyEmail({required String email, required String otp}) async => true;

  @override
  Future<bool> resendOtp({required String email, required String purpose}) async => true;

  @override
  Future<bool> updateProfile({
    String? fullName,
    String? profilePhoto,
    String? preferredLanguage,
    String? dateOfBirth,
  }) async => true;

  @override
  void updateUserName(String newName) {}
}
