import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'login_screen.dart';
import '../widgets/app_toast.dart';
import '../widgets/password_checklist_widget.dart';
import '../utils/password_validator.dart';
import '../theme/app_theme.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _codeFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  int _currentStep = 1; // 1: Enter OTP, 2: New Password
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isHoveredButton = false;
  bool _hasInteractedWithPassword = false;

  Timer? _cooldownTimer;
  int _resendCooldown = 30;
  bool _canResend = false;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _startCooldown();

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

  void _startCooldown() {
    setState(() {
      _resendCooldown = 30;
      _canResend = false;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendCooldown = 0;
            _canResend = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _codeFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  PasswordValidationResult get _passwordValidation =>
      PasswordValidator.validate(_newPasswordController.text);

  bool get _isCodeValid => _codeController.text.trim().length == 6;

  bool get _isPasswordFormValid {
    final passwordValid = _passwordValidation.isValid;
    final confirmValid = _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _newPasswordController.text;
    return passwordValid && confirmValid;
  }

  void _goToPasswordStep() {
    if (_isCodeValid) {
      setState(() {
        _currentStep = 2;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _newPasswordFocusNode.requestFocus();
        }
      });
    }
  }

  void _backToCodeStep() {
    setState(() {
      _currentStep = 1;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _codeFocusNode.requestFocus();
      }
    });
  }

  void _resendCode() async {
    if (!_canResend) return;
    final tr = ref.read(localeProvider.notifier).translate;

    final success = await ref.read(authProvider.notifier).resendOtp(
      email: widget.email,
      purpose: 'reset',
    );

    if (success && mounted) {
      AppToast.showSuccess(context, tr('auth.otpResentSuccess'));
      _startCooldown();
    } else if (mounted) {
      final error = ref.read(authProvider).errorMessage;
      AppToast.showError(context, error ?? tr('auth.resendFailed'));
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final tr = ref.read(localeProvider.notifier).translate;
      final code = _codeController.text.trim();
      final newPassword = _newPasswordController.text;

      final success = await ref.read(authProvider.notifier).resetPassword(
        email: widget.email,
        otp: code,
        newPassword: newPassword,
      );

      if (success && mounted) {
        AppToast.showSuccess(context, tr('auth.passwordResetSuccess'));
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                LoginScreen(prefilledEmail: widget.email),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
          (route) => false,
        );
      } else if (mounted) {
        final error = ref.read(authProvider).errorMessage;
        AppToast.showError(context, error ?? 'Failed to reset password. Please check your code.');
        _backToCodeStep();
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

    // Pin theme for 6-digit code
    final defaultPinTheme = PinTheme(
      width: 44,
      height: 48,
      textStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      decoration: BoxDecoration(
        color: elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: primaryColor, width: 1.5),
      ),
    );

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
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.03),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _currentStep == 1
                                      ? _buildStep1Otp(
                                          primaryText: primaryText,
                                          secondaryText: secondaryText,
                                          primaryColor: primaryColor,
                                          cardBorder: cardBorder,
                                          elevatedSurface: elevatedSurface,
                                          defaultPinTheme: defaultPinTheme,
                                          focusedPinTheme: focusedPinTheme,
                                          isLoading: isLoading,
                                          tr: tr,
                                        )
                                      : _buildStep2Password(
                                          primaryText: primaryText,
                                          secondaryText: secondaryText,
                                          primaryColor: primaryColor,
                                          cardBorder: cardBorder,
                                          elevatedSurface: elevatedSurface,
                                          isDark: isDark,
                                          isLoading: isLoading,
                                          tr: tr,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Otp({
    required Color primaryText,
    required Color secondaryText,
    required Color primaryColor,
    required Color cardBorder,
    required Color elevatedSurface,
    required PinTheme defaultPinTheme,
    required PinTheme focusedPinTheme,
    required bool isLoading,
    required String Function(String, [Map<String, String>?]) tr,
  }) {
    return Column(
      key: const ValueKey('step_1_otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Icon
        Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Header
        Text(
          tr('auth.verifyResetCodeTitle'),
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('auth.enterCodeSentTo', {'email': widget.email}),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // 6-digit Code field
        Text(
          '6-Digit Code',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Pinput(
            length: 6,
            controller: _codeController,
            focusNode: _codeFocusNode,
            autofocus: true,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            onChanged: (val) {
              setState(() {});
              if (val.trim().length == 6) {
                _goToPasswordStep();
              }
            },
            onCompleted: (pin) => _goToPasswordStep(),
          ),
        ),
        const SizedBox(height: 14),

        // Resend OTP row with 30s countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!_canResend) ...[
              Text(
                tr('auth.waitCooldown', {
                  'seconds': _resendCooldown.toString(),
                }),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              InkWell(
                onTap: _resendCode,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    tr('auth.resend'),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // Continue Button
        ElevatedButton(
          onPressed: _isCodeValid ? _goToPasswordStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            disabledBackgroundColor: elevatedSurface,
            disabledForegroundColor: secondaryText.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tr('auth.continueToPassword'),
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
        const SizedBox(height: 18),

        // Notice that this also works for legacy accounts
        Center(
          child: Text(
            tr('auth.legacyAccountNotice'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: secondaryText.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Password({
    required Color primaryText,
    required Color secondaryText,
    required Color primaryColor,
    required Color cardBorder,
    required Color elevatedSurface,
    required bool isDark,
    required bool isLoading,
    required String Function(String, [Map<String, String>?]) tr,
  }) {
    return Column(
      key: const ValueKey('step_2_password'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Icon
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
        const SizedBox(height: 18),

        // Header
        Text(
          tr('auth.resetPasswordTitle'),
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('auth.resetPasswordSub'),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Verified Code Badge with change button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: elevatedSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('auth.codeVerifiedBadge', {'code': _codeController.text.trim()}),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _backToCodeStep,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    tr('auth.changeCode'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // New Password
        Text(
          tr('auth.newPassword'),
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _newPasswordController,
          focusNode: _newPasswordFocusNode,
          autofillHints: const [AutofillHints.newPassword],
          obscureText: _obscureNewPassword,
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
            hintText: tr('auth.newPasswordHint'),
            hintStyle: GoogleFonts.inter(
              fontSize: 13.5,
              color: secondaryText.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: secondaryText,
              size: 18,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: secondaryText,
                size: 18,
              ),
              tooltip: _obscureNewPassword
                  ? tr('auth.showPassword')
                  : tr('auth.hidePassword'),
              onPressed: () => setState(
                () => _obscureNewPassword = !_obscureNewPassword,
              ),
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
              borderSide: BorderSide(
                color: primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkError : AppColors.lightError,
              ),
            ),
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

        // Password Checklist
        PasswordChecklistWidget(
          validation: _passwordValidation,
          isVisible: _hasInteractedWithPassword ||
              _newPasswordController.text.isNotEmpty,
        ),
        const SizedBox(height: 16),

        // Confirm New Password
        Text(
          tr('auth.confirmNewPassword'),
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
            if (_isPasswordFormValid && !isLoading) _submit();
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
            prefixIcon: Icon(
              Icons.lock_reset_rounded,
              color: secondaryText,
              size: 18,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: secondaryText,
                size: 18,
              ),
              tooltip: _obscureConfirmPassword
                  ? tr('auth.showPassword')
                  : tr('auth.hidePassword'),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
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
              borderSide: BorderSide(
                color: primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkError : AppColors.lightError,
              ),
            ),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return tr('auth.confirmPasswordRequired');
            }
            if (val != _newPasswordController.text) {
              return tr('auth.passwordsDoNotMatch');
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Submit Button
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveredButton = true),
          onExit: (_) => setState(() => _isHoveredButton = false),
          child: ElevatedButton(
            onPressed: (isLoading || !_isPasswordFormValid) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor
                  .withValues(alpha: _isHoveredButton ? 0.92 : 1.0),
              foregroundColor: isDark
                  ? AppColors.darkErrorText
                  : AppColors.lightTextPrimary,
              minimumSize: const Size(double.infinity, 48),
              disabledBackgroundColor: elevatedSurface,
              disabledForegroundColor:
                  secondaryText.withValues(alpha: 0.5),
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
                        tr('auth.resetPasswordButton'),
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
                  if (_currentStep == 2) {
                    _backToCodeStep();
                  } else if (Navigator.canPop(context)) {
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
