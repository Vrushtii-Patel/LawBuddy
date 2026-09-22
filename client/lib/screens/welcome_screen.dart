import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'welcome/welcome_widgets.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _howItWorksKey = GlobalKey();
  final GlobalKey _riskSystemKey = GlobalKey();

  late final AnimationController _heroEntryController;
  late final Animation<double> _headlineLine1;
  late final Animation<double> _headlineLine2;
  late final Animation<double> _headlineLine3;
  late final Animation<double> _sideWordsAnim;
  final ValueNotifier<Offset> _mousePosNotifier = ValueNotifier<Offset>(const Offset(600, 300));

  @override
  void initState() {
    super.initState();
    _heroEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _headlineLine1 = CurvedAnimation(
      parent: _heroEntryController,
      curve: const Interval(0.05, 0.45, curve: Curves.easeOutCubic),
    );
    _headlineLine2 = CurvedAnimation(
      parent: _heroEntryController,
      curve: const Interval(0.20, 0.60, curve: Curves.easeOutCubic),
    );
    _headlineLine3 = CurvedAnimation(
      parent: _heroEntryController,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    );
    _sideWordsAnim = CurvedAnimation(
      parent: _heroEntryController,
      curve: const Interval(0.50, 0.95, curve: Curves.easeOutCubic),
    );

    _heroEntryController.forward();
  }

  @override
  void dispose() {
    _heroEntryController.dispose();
    _scrollController.dispose();
    _mousePosNotifier.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 700 && size.width < 1024;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: MouseRegion(
        onHover: (event) {
          if (isDesktop) {
            _mousePosNotifier.value = event.position;
          }
        },
        child: Container(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                // Top Navigation Header
                WelcomeHeader(
                  isDark: isDark,
                  isDesktop: isDesktop,
                  onLogoTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                    );
                  },
                  onFeaturesTap: () => _scrollToSection(_featuresKey),
                  onHowItWorksTap: () => _scrollToSection(_howItWorksKey),
                  onRiskSystemTap: () => _scrollToSection(_riskSystemKey),
                  onLoginTap: _navigateToLogin,
                ),

                // 1. Cinematic Hero Section
                WelcomeHeroSection(
                  isDark: isDark,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  scrollController: _scrollController,
                  headlineLine1: _headlineLine1,
                  headlineLine2: _headlineLine2,
                  headlineLine3: _headlineLine3,
                  sideWordsAnim: _sideWordsAnim,
                  onGetStarted: _navigateToSignup,
                  onSignIn: _navigateToLogin,
                ),

                const SizedBox(height: 24),

                // 2. Dual-Direction Moving Marquee Strip
                DualDirectionMarquee(isDark: isDark),

                const SizedBox(height: 64),

                // 3. Core Features Section
                WelcomeFeaturesSection(
                  key: _featuresKey,
                  isDark: isDark,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),

                const SizedBox(height: 80),

                // 4. How It Works Section (4-Step Flow)
                WelcomeHowItWorksSection(
                  key: _howItWorksKey,
                  isDark: isDark,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),

                const SizedBox(height: 80),

                // 5. Risk Assessment Preview & Mock Document Showcase
                WelcomeRiskSystemSection(
                  key: _riskSystemKey,
                  isDark: isDark,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),

                const SizedBox(height: 80),

                // 6. Bottom CTA Callout Card
                WelcomeCtaBanner(
                  isDark: isDark,
                  isDesktop: isDesktop,
                  onExploreFeatures: () => _scrollToSection(_featuresKey),
                  onAnalyzeDoc: _navigateToSignup,
                ),

                const SizedBox(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
