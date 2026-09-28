import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'reset_password_screen.dart';
import '../widgets/app_toast.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? prefilledEmail;
  final bool showLegacyBanner;

  const ForgotPasswordScreen({
    super.key,
    this.prefilledEmail,
    this.showLegacyBanner = false,
  });

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _emailFocusNode = FocusNode();

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
    _emailFocusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim().toLowerCase();
      final tr = ref.read(localeProvider.notifier).translate;

      await ref.read(authProvider.notifier).forgotPassword(email: email);

      if (mounted) {
        AppToast.showInfo(
          context,
          tr('auth.sendVerificationCode'),
        );

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ResetPasswordScreen(email: email),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
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
    final Color elevatedSurface = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;

    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

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
              // Top Bar
              _buildTopBar(context, primaryText, cardBorder, tr),
              const SizedBox(height: 4),

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
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Container(
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
                                    // Brand Logo Badge
                                    Center(
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.lock_reset_rounded,
                                          size: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Header
                                    Text(
                                      tr('auth.forgotPasswordTitle'),
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: primaryText,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tr('auth.forgotPasswordSub'),
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        color: secondaryText,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Legacy Notice Banner if applicable
                                    if (widget.showLegacyBanner) ...[
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.info_outline_rounded,
                                              size: 18,
                                              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                tr('auth.passwordNotSetBanner'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],

                                    // Email Address Field
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
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: cardBorder),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: cardBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: primaryColor, width: 1.5),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: isDark ? AppColors.darkError : AppColors.lightError,
                                          ),
                                        ),
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
                                    const SizedBox(height: 24),

                                    // Submit Button
                                    MouseRegion(
                                      onEnter: (_) => setState(() => _isHoveredButton = true),
                                      onExit: (_) => setState(() => _isHoveredButton = false),
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor
                                              .withValues(alpha: _isHoveredButton ? 0.92 : 1.0),
                                          foregroundColor: isDark
                                              ? AppColors.darkErrorText
                                              : AppColors.lightTextPrimary,
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
                                                    isDark
                                                        ? AppColors.darkErrorText
                                                        : AppColors.lightTextPrimary,
                                                  ),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    tr('auth.sendResetCode'),
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
                                    const SizedBox(height: 18),

                                    // Return to login
                                    Center(
                                      child: InkWell(
                                        onTap: () => Navigator.pop(context),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.arrow_back_rounded,
                                                size: 15,
                                                color: secondaryText,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                tr('auth.goToLogin'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: secondaryText,
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
                            ),
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
}
