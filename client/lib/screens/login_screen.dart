import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import '../widgets/app_toast.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? prefilledEmail;

  const LoginScreen({super.key, this.prefilledEmail});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isHoveredButton = false;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefilledEmail ?? '');

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
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      final success = await ref.read(authProvider.notifier).login(
        email: email,
        password: password,
      );

      if (success && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
      } else if (mounted) {
        final authState = ref.read(authProvider);
        if (authState.errorCode == 'EMAIL_NOT_VERIFIED') {
          AppToast.showInfo(context, authState.errorMessage ?? 'Please verify your email address to continue.');
          await ref.read(authProvider.notifier).resendOtp(
            email: email,
            purpose: 'signup',
          );
          if (mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    OtpScreen(email: email, type: 'signup'),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        } else if (authState.errorCode == 'PASSWORD_NOT_SET') {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ForgotPasswordScreen(prefilledEmail: email, showLegacyBanner: true),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        } else {
          AppToast.showError(
            context,
            authState.errorMessage ?? 'Invalid email or password',
          );
        }
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      child: Scaffold(
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
                            maxWidth: isDesktop ? 1040 : 480,
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

                                    // Right: Refined Sign In Card
                                    Expanded(
                                      flex: 10,
                                      child: _buildLoginCard(
                                        context,
                                        primaryText,
                                        secondaryText,
                                        cardSurface,
                                        cardBorder,
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
                                    _buildLoginCard(
                                      context,
                                      primaryText,
                                      secondaryText,
                                      cardSurface,
                                      cardBorder,
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
      ),
    );
  }

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
        _buildPillarRow(
          icon: Icons.verified_outlined,
          title: tr('auth.pillarRera'),
          subtitle: tr('auth.pillarReraSub'),
          primaryText: primaryText,
          secondaryText: secondaryText,
          cardBorder: cardBorder,
          accentColor: accentColor,
        ),
        const SizedBox(height: 16),
        _buildPillarRow(
          icon: Icons.shield_outlined,
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
              Icon(Icons.lock_outline_rounded, size: 15, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
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

  Widget _buildMobileBrandHeader(
    Color primaryText,
    Color secondaryText,
    Color accentColor,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
  ) {
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

  Widget _buildLoginCard(
    BuildContext context,
    Color primaryText,
    Color secondaryText,
    Color cardSurface,
    Color cardBorder,
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
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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

              // Email Field
              Text(
                tr('auth.emailAddress'),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: elevatedSurface,
                  hintText: tr('auth.emailHint'),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: secondaryText.withValues(alpha: 0.7),
                  ),
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    color: secondaryText,
                    size: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkError : AppColors.lightError)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return tr('auth.emailRequired');
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!emailRegex.hasMatch(val.trim())) {
                    return tr('auth.enterValidEmail');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('auth.password'),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              ForgotPasswordScreen(
                            prefilledEmail: _emailController.text.trim(),
                          ),
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
                        tr('auth.forgotPassword'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                autofillHints: const [AutofillHints.password],
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!isLoading) _submit();
                },
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: elevatedSurface,
                  hintText: tr('auth.passwordHint'),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: secondaryText.withValues(alpha: 0.7),
                  ),
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: secondaryText, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: secondaryText,
                      size: 18,
                    ),
                    tooltip: _obscurePassword ? tr('auth.showPassword') : tr('auth.hidePassword'),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkError : AppColors.lightError)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return tr('auth.passwordRequired');
                  }
                  return null;
                },
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr('auth.logIn'),
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

              const SizedBox(height: 24),
              Divider(color: cardBorder, height: 1),
              const SizedBox(height: 20),

              // Sign Up Link
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
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const SignupScreen(),
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
        ),
      ),
    );
  }
}
