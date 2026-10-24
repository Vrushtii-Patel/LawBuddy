import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_scanner/main.dart';
import 'package:legal_scanner/providers/theme_provider.dart';
import 'package:legal_scanner/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Issue 39: Theme-aware ErrorWidget and Theme Toggle Priority', () {
    testWidgets('GlobalErrorWidget renders cleanly in Light Mode with appropriate colors', (tester) async {
      final details = FlutterErrorDetails(
        exception: Exception('Simulated layout error'),
        stack: StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: GlobalErrorWidget(details: details),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlobalErrorWidget), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.refresh_rounded));
      expect(icon.color, equals(AppColors.lightPrimary));
    });

    testWidgets('GlobalErrorWidget renders cleanly in Dark Mode with high-contrast accent', (tester) async {
      final details = FlutterErrorDetails(
        exception: Exception('Simulated layout error in dark mode'),
        stack: StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: GlobalErrorWidget(details: details),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GlobalErrorWidget), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.refresh_rounded));
      expect(icon.color, equals(AppColors.lavenderHaze));
    });

    testWidgets('Theme toggle updates state and persists across rebuilds without being overridden', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: LawBuddyApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final element = tester.element(find.byType(LawBuddyApp));
      final container = ProviderScope.containerOf(element);

      // Initial theme mode can be toggled by user
      container.read(themeProvider.notifier).setTheme(ThemeMode.dark);
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(themeProvider), equals(ThemeMode.dark));

      // User toggles theme to light mode
      container.read(themeProvider.notifier).toggleTheme();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(themeProvider), equals(ThemeMode.light));

      // Trigger another frame / rebuild
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(themeProvider), equals(ThemeMode.light));
    });
  });
}
