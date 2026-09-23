import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _focusNode = FocusNode();
  
  bool _isEmailMode = true;
  bool _isHoveredButton = false;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _focusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (!_isEmailMode) {
        final loc = ref.read(localeProvider.notifier);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('auth.mobileOtpComingSoon'))),
        );
        return;
      }

      final String identifier = _identifierController.text.trim();

      final success = await ref.read(authProvider.notifier).sendOtp(
        email: identifier,
        type: 'login',
      );

      if (success && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => OtpScreen(email: identifier, type: 'login'),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else if (mounted) {
        final error = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Login failed. Please try again.'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkError : AppColors.lightError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 920;

    final Color bgSurface = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color cardSurface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color primaryColor = AppColors.lightPrimary;
    final Color accentColor = isDark ? AppColors.darkAccent : AppColors.lightAccent;
    final Color elevatedSurface = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;

    return Scaffold(
      backgroundColor: bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            // Top Navigation Bar
            _buildTopBar(context, primaryText, cardBorder, isDark, tr),
            const SizedBox(height: 4),

            // Main Content Body
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48.0 : 20.0,
                    vertical: isDesktop ? 32.0 : 20.0,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 1040 : 460,
                        ),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Left: LawBuddy Brand Storytelling
                                  Expanded(
                                    flex: 11,
                                    child: _buildBrandingShowcase(
                                      primaryText,
                                      secondaryText,
                                      cardSurface,
                                      cardBorder,
                                      elevatedSurface,
                                      accentColor,
                                      isDark,
                                      tr,
                                    ),
                                  ),
                                  const SizedBox(width: 56),

                                  // Right: Refined Login Card
                                  Expanded(
                                    flex: 10,
                                    child: _buildAuthCard(
                                      context,
                                      cardSurface,
                                      cardBorder,
                                      primaryText,
                                      secondaryText,
                                      primaryColor,
                                      accentColor,
                                      elevatedSurface,
                                      isDark,
                                      true,
                                      tr,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildMobileBrandHeader(primaryText, secondaryText, accentColor, isDark, tr),
                                  const SizedBox(height: 24),
                                  _buildAuthCard(
                                    context,
                                    cardSurface,
                                    cardBorder,
                                    primaryText,
                                    secondaryText,
                                    primaryColor,
                                    accentColor,
                                    elevatedSurface,
                                    isDark,
                                    false,
                                    tr,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP APP BAR
  // ==========================================
  Widget _buildTopBar(BuildContext context, Color primaryText, Color borderColor, bool isDark, String Function(String, [Map<String, String>?]) tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: borderColor.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 18, color: primaryText),
                      const SizedBox(width: 6),
                      Text(
                        tr('common.back'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LEFT: BRANDING & VISUAL STORYTELLING (DESKTOP)
  // ==========================================
  Widget _buildBrandingShowcase(
    Color primaryText,
    Color secondaryText,
    Color cardSurface,
    Color cardBorder,
    Color elevatedSurface,
    Color accentColor,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Logo Badge
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.gavel_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('common.appName'),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: primaryText,
                  ),
                ),
                Text(
                  tr('common.appSubtitle'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Headline
        Text(
          tr('auth.intelligentProtection'),
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: primaryText,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          tr('auth.loginHeroSub'),
          style: GoogleFonts.inter(
            fontSize: 15,
            color: secondaryText,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        // 3 Key Pillars
        _buildPillarRow(
          icon: Icons.shield_outlined,
          title: tr('auth.pillarRera'),
          subtitle: tr('auth.pillarReraSub'),
          primaryText: primaryText,
          secondaryText: secondaryText,
          cardBorder: cardBorder,
          accentColor: accentColor,
        ),
        const SizedBox(height: 16),
        _buildPillarRow(
          icon: Icons.analytics_outlined,
          title: tr('auth.pillarAudit'),
          subtitle: tr('auth.pillarAuditSub'),
          primaryText: primaryText,
          secondaryText: secondaryText,
          cardBorder: cardBorder,
          accentColor: accentColor,
        ),
        const SizedBox(height: 16),
        _buildPillarRow(
          icon: Icons.checklist_rounded,
          title: tr('auth.pillarDueDiligence'),
          subtitle: tr('auth.pillarDueDiligenceSub'),
          primaryText: primaryText,
          secondaryText: secondaryText,
          cardBorder: cardBorder,
          accentColor: accentColor,
        ),

        const SizedBox(height: 28),

        // Legal Trust Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, size: 15, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tr('auth.bankGradeSecurity'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillarRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color primaryText,
    required Color secondaryText,
    required Color cardBorder,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lightPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.lightPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondaryText,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MOBILE BRAND HEADER
  // ==========================================
  Widget _buildMobileBrandHeader(Color primaryText, Color secondaryText, Color accentColor, bool isDark, String Function(String, [Map<String, String>?]) tr) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.lightPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.gavel_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr('common.appName'),
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('auth.mobileSubtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // RIGHT / CARD: INTERACTIVE AUTH FORM
  // ==========================================
  Widget _buildAuthCard(
    BuildContext context,
    Color cardSurface,
    Color cardBorder,
    Color primaryText,
    Color secondaryText,
    Color primaryColor,
    Color accentColor,
    Color elevatedSurface,
    bool isDark,
    bool isDesktop,
    String Function(String, [Map<String, String>?]) tr,
  ) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header inside card
          Text(
            tr('auth.welcomeBack'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: primaryText,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('auth.loginToAccount'),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Channel Segmented Switch (Email vs Phone)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: elevatedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (!_isEmailMode) {
                        setState(() {
                          _isEmailMode = true;
                          _formKey.currentState?.reset();
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _isEmailMode ? cardSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: _isEmailMode ? Border.all(color: cardBorder) : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 16,
                            color: _isEmailMode ? primaryColor : secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('auth.email'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: _isEmailMode ? FontWeight.w700 : FontWeight.w500,
                              color: _isEmailMode ? primaryText : secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_isEmailMode) {
                        setState(() {
                          _isEmailMode = false;
                          _formKey.currentState?.reset();
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_isEmailMode ? cardSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: !_isEmailMode ? Border.all(color: cardBorder) : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_iphone_rounded,
                            size: 16,
                            color: !_isEmailMode ? primaryColor : secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr('auth.mobileNumber'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: !_isEmailMode ? FontWeight.w700 : FontWeight.w500,
                              color: !_isEmailMode ? primaryText : secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Input Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEmailMode) ...[
                  Text(
                    tr('auth.email'),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _identifierController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 19, color: secondaryText),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return tr('auth.emailRequired');
                      }
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(val.trim())) {
                        return tr('auth.enterValidEmail');
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  Text(
                    tr('auth.mobileNumber'),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _identifierController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '9876543210',
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: cardBorder),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🇮🇳 +91',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return tr('auth.mobileRequired');
                      }
                      final digits = val.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 10) {
                        return tr('auth.enterValidPhone');
                      }
                      return null;
                    },
                  ),
                ],

                // Disclaimer hint
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 13, color: secondaryText),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        tr('auth.sendVerificationCode'),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Submit Button
                MouseRegion(
                  onEnter: (_) => setState(() => _isHoveredButton = true),
                  onExit: (_) => setState(() => _isHoveredButton = false),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withValues(alpha: _isHoveredButton ? 0.92 : 1.0),
                      foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: _isHoveredButton ? 2 : 0,
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tr('auth.sendOtp'),
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          Divider(color: cardBorder, height: 1),

          const SizedBox(height: 20),

          // Register Link
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tr('auth.noAccount'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: secondaryText,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    tr('auth.signUp'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                      decoration: TextDecoration.underline,
                      decorationColor: primaryText.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
