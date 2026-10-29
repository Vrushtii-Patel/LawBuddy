import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_scanner/main.dart';
import 'package:legal_scanner/widgets/cookie_consent_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Issue 42: Cookie Banner Placement Inside Navigator', () {
    testWidgets('CookieConsentWrapper places CookieConsentBanner inside Navigator context', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool foundNavigatorInsideChild = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CookieConsentWrapper(
              child: Builder(
                builder: (context) {
                  foundNavigatorInsideChild = Navigator.maybeOf(context) != null;
                  return const Scaffold(
                    body: Center(child: Text('Protected Route')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(foundNavigatorInsideChild, isTrue);
      expect(find.byType(CookieConsentBanner), findsOneWidget);
      expect(find.text('Privacy preferences'), findsOneWidget);
    });

    testWidgets('Opening Privacy Preferences dialog renders modal on top of CookieConsentBanner', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CookieConsentWrapper(
              child: Scaffold(
                body: Center(child: Text('Home Content')),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Customize to trigger dialog
      expect(find.text('Customize'), findsOneWidget);
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      // Dialog is rendered
      expect(find.text('Privacy & Storage Preferences'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Verify ModalBarrier is present in the tree
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('LawBuddyApp configures CookieConsentWrapper for Navigator routes', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: LawBuddyApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // CookieConsentWrapper is found as part of the route hierarchy
      expect(find.byType(CookieConsentWrapper), findsWidgets);
      expect(find.byType(CookieConsentBanner), findsOneWidget);
    });
  });
}
