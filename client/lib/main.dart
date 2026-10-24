import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/how_it_works_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/shared_summary_screen.dart';
import 'screens/cant_connect_screen.dart';
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
    debugPrint('[LawBuddy UI Error] ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('[LawBuddy Stack Trace]\n${details.stack}');
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[LawBuddy Widget Error] ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('[LawBuddy Widget Stack]\n${details.stack}');
    }
    return GlobalErrorWidget(details: details);
  };

  runApp(const ProviderScope(child: LawBuddyApp()));
}

/// Theme-aware fallback widget displayed if a widget fails to build,
/// preventing a full blank white screen crash while honoring dark/light mode.
class GlobalErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const GlobalErrorWidget({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark ||
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

    final iconColor = isDark ? AppColors.lavenderHaze : AppColors.lightPrimary;
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: iconColor, size: 28),
              const SizedBox(height: 8),
              Text(
                LocaleNotifier.translateCurrent('app.layoutAdjusting'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.redAccent,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LawBuddyApp extends ConsumerStatefulWidget {
  const LawBuddyApp({super.key});

  @override
  ConsumerState<LawBuddyApp> createState() => _LawBuddyAppState();
}

class _LawBuddyAppState extends ConsumerState<LawBuddyApp> {
  bool _initialUrlThemeApplied = false;

  @override
  void initState() {
    super.initState();
    _applyInitialUrlTheme();
  }

  void _applyInitialUrlTheme() {
    if (_initialUrlThemeApplied) return;
    _initialUrlThemeApplied = true;

    try {
      final themeParam = Uri.base.queryParameters['theme']?.toLowerCase();
      if (themeParam == 'dark') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(themeProvider.notifier).setTheme(ThemeMode.dark);
          }
        });
      } else if (themeParam == 'light') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);

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
    final fragment = Uri.base.hasFragment ? Uri.base.fragment.toLowerCase() : '';
    final path = Uri.base.path.toLowerCase();
    final isHowItWorksUrl = screenParam == 'how-it-works' ||
        screenParam == 'howitworks' ||
        path.endsWith('/how-it-works') ||
        path.endsWith('/howitworks') ||
        fragment == '/how-it-works' ||
        fragment.startsWith('/how-it-works') ||
        fragment == 'how-it-works';

    Widget homeWidget;

    if (shareParam != null && shareParam.trim().isNotEmpty) {
      homeWidget = SharedSummaryScreen(shareToken: shareParam.trim());
    } else if (screenParam == 'analysis' && kDebugMode) {
      // Demo screen with hardcoded fake clause data, for local design/dev
      // preview only — gated to debug builds so it isn't reachable via URL
      // on a production web deploy.
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
    } else if (isHowItWorksUrl) {
      homeWidget = const HowItWorksScreen();
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
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: homeWidget,
      routes: {
        '/how-it-works': (context) => const HowItWorksScreen(),
        '/welcome': (context) => const WelcomeScreen(),
      },
      onGenerateRoute: (settings) {
        final name = (settings.name ?? '').toLowerCase();
        if (name == '/how-it-works' || name == 'how-it-works' || name == '/howitworks') {
          return MaterialPageRoute(
            builder: (_) => const HowItWorksScreen(),
            settings: settings,
          );
        }
        return null;
      },
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              child,
              const CookieConsentBanner(),
            ],
          ),
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
        return const WelcomeScreen();
      case AuthStatus.error:
        return const CantConnectScreen();
    }
  }
}