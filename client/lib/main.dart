import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/shared_summary_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'widgets/cookie_consent_banner.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Gracefully handle UI errors without crashing the entire web canvas to a blank white screen
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, color: AppColors.lightPrimary, size: 28),
              const SizedBox(height: 8),
              Text(
                'Temporarily adjusting layout...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: LawBuddyApp()));
}

class LawBuddyApp extends ConsumerWidget {
  const LawBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

    // Check URL query parameters for theme or preview mode
    ThemeMode effectiveThemeMode = themeMode;
    final themeParam = Uri.base.queryParameters['theme']?.toLowerCase();
    if (themeParam == 'dark') {
      effectiveThemeMode = ThemeMode.dark;
    } else if (themeParam == 'light') {
      effectiveThemeMode = ThemeMode.light;
    }

    String? shareParam = Uri.base.queryParameters['share'] ?? Uri.base.queryParameters['shareToken'];
    if (shareParam == null && Uri.base.hasFragment && Uri.base.fragment.contains('share=')) {
      try {
        final frag = Uri.base.fragment;
        final queryPart = frag.contains('?') ? frag.split('?').last : frag;
        final dummyUri = Uri.tryParse('http://dummy/?$queryPart');
        shareParam = dummyUri?.queryParameters['share'] ?? dummyUri?.queryParameters['shareToken'];
      } catch (_) {}
    }

    final screenParam = Uri.base.queryParameters['screen']?.toLowerCase();
    Widget homeWidget;

    if (shareParam != null && shareParam.trim().isNotEmpty) {
      homeWidget = SharedSummaryScreen(shareToken: shareParam.trim());
    } else if (screenParam == 'analysis') {
      homeWidget = const AnalysisScreen(
        documentTitle: 'Agreement for Sale (Extract) - Flat 402',
        originalText: 'Clause 7.2: In the event of milestone payment delay exceeding 15 days, Developer forfeits 100% earnest money.\nClause 14.1: Buyer delay attracts 18% p.a. interest while Developer delay offers Rs 5/sqft compensation.\nClause 3.1: Carpet area specification adhering to RERA standard definitions.',
        analysis: [
          {
            'text': 'Clause 7.2: In the event of milestone payment delay exceeding 15 days, Developer forfeits 100% earnest money.',
            'category': 'High',
            'reason': 'Excessive forfeiture clause exceeds statutory 10% ceiling prescribed under Section 13(1) of RERA Model Rules.'
          },
          {
            'text': 'Clause 14.1: Buyer delay attracts 18% p.a. interest while Developer delay offers Rs 5/sqft compensation.',
            'category': 'Caution',
            'reason': 'Asymmetrical delay penalties violate equality principles under RERA Section 18 standard compensation guidelines.'
          },
          {
            'text': 'Clause 3.1: Carpet area specification adhering to RERA standard definitions.',
            'category': 'Compliant',
            'reason': 'Standard carpet area definition strictly follows statutory RERA guidelines.'
          },
        ],
      );
    } else if (screenParam == 'welcome') {
      homeWidget = const WelcomeScreen();
    } else {
      homeWidget = const AuthGate();
    }
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'LawBuddy',
      locale: Locale(currentLocale.code),
      debugShowCheckedModeBanner: false,
      themeMode: effectiveThemeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: homeWidget,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const CookieConsentBanner(),
          ],
        );
      },
    );
  }
}


class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const WelcomeScreen();
    }
  }
}
