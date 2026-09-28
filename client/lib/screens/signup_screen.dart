import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'login_screen.dart';
import 'otp_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/form_consent_widget.dart';
import '../widgets/app_toast.dart';
import '../widgets/password_checklist_widget.dart';
import '../utils/password_validator.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;
  bool _showConsentError = false;
  bool _isHoveredButton = false;
  bool _hasInteractedWithPassword = false;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  PasswordValidationResult get _passwordValidation =>
      PasswordValidator.validate(_passwordController.text);

  bool get _isFormValid {
    final nameValid = _nameController.text.trim().isNotEmpty;
    final emailValid = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(_emailController.text.trim());
    final passwordValid = _passwordValidation.isValid;
    final confirmValid = _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _passwordController.text;
    return nameValid && emailValid && passwordValid && confirmValid && _termsAccepted;
  }

  void _submit() async {
    final tr = ref.read(localeProvider.notifier).translate;
    if (!_termsAccepted) {
      setState(() => _showConsentError = true);
      AppToast.showError(context, tr('auth.termsMustBeAccepted'));
      return;
    }

    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      final success = await ref.read(authProvider.notifier).signup(
        fullName: name,
        email: email,
        password: password,
        acceptedTerms: _termsAccepted,
      );

      if (success && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => OtpScreen(
              email: email,
              type: 'signup',
              fullName: name,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else if (mounted) {
        final authState = ref.read(authProvider);
        if (authState.errorCode == 'ACCOUNT_EXISTS') {
          AppToast.showError(
            context,
            tr('auth.accountExistsToast'),
            action: TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        LoginScreen(prefilledEmail: email),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              child: Text(
                tr('auth.goToLogin'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        } else {
          AppToast.showError(context, authState.errorMessage ?? 'Signup failed. Please try again.');
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

                                    // Right: Refined Sign Up Card
                                    Expanded(
                                      flex: 11,
                                      child: _buildSignupCard(
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
                                    _buildSignupCard(
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

  Widget _buildTopBar(
    BuildContext context,
    Color primaryText,
    Color borderColor,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
  ) {
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
          tr('auth.signupHeroTitle'),
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
          tr('auth.signupHeroSub'),
          style: GoogleFonts.inter(
            fontSize: 15,
            color: secondaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildPillarRow(
          icon: Icons.flash_on_outlined,
          title: tr('auth.signupFeatureInstantAudit'),
          subtitle: tr('auth.signupFeatureInstantAuditSub'),
          primaryText: primaryText,
          secondaryText: secondaryText,
          cardBorder: cardBorder,
          accentColor: accentColor,
        ),
        const SizedBox(height: 16),
        _buildPillarRow(
          icon: Icons.psychology_outlined,
          title: tr('auth.signupFeatureAiExplain'),
          subtitle: tr('auth.signupFeatureAiExplainSub'),
          primaryText: primaryText,
          secondaryText: secondaryText,
          cardBorder: cardBorder,
          accentColor: accentColor,
        ),
        const SizedBox(height: 16),
        _buildPillarRow(
          icon: Icons.checklist_rtl_rounded,
          title: tr('auth.signupFeatureCustomChecklists'),
          subtitle: tr('auth.signupFeatureCustomChecklistsSub'),
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

  Widget _buildSignupCard(
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
                tr('auth.createAccount'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr('auth.createAccountSub'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // Full Name
              Text(
                tr('auth.fullName'),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                autofillHints: const [AutofillHints.name],
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: elevatedSurface,
                  hintText: tr('auth.nameHint'),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: secondaryText.withValues(alpha: 0.7),
                  ),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: secondaryText, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkError : AppColors.lightError)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('auth.enterFullName');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Address
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
                onChanged: (_) => setState(() {}),
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
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: secondaryText, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkError : AppColors.lightError)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return tr('auth.emailRequired');
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return tr('auth.enterValidEmail');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              Text(
                tr('auth.password'),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                autofillHints: const [AutofillHints.newPassword],
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                onChanged: (val) {
                  setState(() {
                    _hasInteractedWithPassword = true;
                  });
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
                  final result = PasswordValidator.validate(val);
                  if (!result.isValid) {
                    return result.errorMessage;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Live Password Checklist
              PasswordChecklistWidget(
                validation: _passwordValidation,
                isVisible: _hasInteractedWithPassword || _passwordController.text.isNotEmpty,
              ),
              const SizedBox(height: 16),

              // Confirm Password
              Text(
                tr('auth.confirmPassword'),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                autofillHints: const [AutofillHints.newPassword],
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) {
                  if (_isFormValid && !isLoading) {
                    _submit();
                  }
                },
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: elevatedSurface,
                  hintText: tr('auth.confirmPasswordHint'),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: secondaryText.withValues(alpha: 0.7),
                  ),
                  prefixIcon: Icon(Icons.lock_reset_rounded, color: secondaryText, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: secondaryText,
                      size: 18,
                    ),
                    tooltip: _obscureConfirmPassword ? tr('auth.showPassword') : tr('auth.hidePassword'),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkError : AppColors.lightError)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return tr('auth.confirmPasswordRequired');
                  }
                  if (val != _passwordController.text) {
                    return tr('auth.passwordsDoNotMatch');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Terms & Privacy Consent Checkbox
              FormConsentCheckbox(
                value: _termsAccepted,
                hasError: _showConsentError,
                errorMessage: tr('auth.termsMustBeAccepted'),
                onChanged: (val) {
                  setState(() {
                    _termsAccepted = val ?? false;
                    if (_termsAccepted) {
                      _showConsentError = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 20),

              // Submit Button
              MouseRegion(
                onEnter: (_) => setState(() => _isHoveredButton = true),
                onExit: (_) => setState(() => _isHoveredButton = false),
                child: ElevatedButton(
                  onPressed: (isLoading || !_isFormValid) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: _isHoveredButton ? 0.92 : 1.0),
                    foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
                    minimumSize: const Size(double.infinity, 48),
                    disabledBackgroundColor: elevatedSurface,
                    disabledForegroundColor: secondaryText.withValues(alpha: 0.5),
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
                              tr('auth.createAccount'),
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

              // Log In Link
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tr('auth.alreadyHaveAccount'),
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
                              LoginScreen(prefilledEmail: _emailController.text.trim()),
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
                        tr('auth.logIn'),
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
