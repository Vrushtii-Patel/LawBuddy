import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String type; // 'signup' or 'login'
  final String? fullName;

  const OtpScreen({
    super.key,
    required this.email,
    required this.type,
    this.fullName,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _timer;
  int _start = 300; // 5 minutes
  bool _canResend = false;
  int _resendCooldown = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  void _startTimer() {
    _start = 300; // 5 minutes overall expiry
    _resendCooldown = 30;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
          if (_resendCooldown > 0) _resendCooldown--;
          if (_resendCooldown == 0) _canResend = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    int minutes = _start ~/ 60;
    int seconds = _start % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _resendOtp() async {
    if (!_canResend) return;
    final tr = ref.read(localeProvider.notifier).translate;
    
    final success = await ref.read(authProvider.notifier).resendOtp(widget.email);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('auth.otpResentSuccess')),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondary : AppColors.lightSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startTimer();
    } else if (mounted) {
      final error = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? tr('auth.resendFailed')),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _verifyOtp() async {
    final otp = _pinController.text.trim();
    final tr = ref.read(localeProvider.notifier).translate;
    
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('auth.enterComplete6Digit')),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).verifyOtp(
      email: widget.email,
      otp: otp,
      type: widget.type,
      fullName: widget.fullName,
    );
    
    if (success && mounted) {
      // Show success briefly
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('auth.verificationSuccess')),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondary : AppColors.lightSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Navigate to dashboard
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
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
        }
      });
    } else if (mounted) {
      final error = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? tr('auth.invalidOtp')),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _pinController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authProvider);

    final defaultPinTheme = PinTheme(
      width: 54,
      height: 60,
      textStyle: TextStyle(fontSize: 22, color: colorScheme.onSurface, fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: colorScheme.primary, width: 1.5),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        border: Border.all(color: colorScheme.outline),
      ),
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.mark_email_read_outlined,
                              size: 32,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          tr('auth.verifyYourEmail'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('auth.enter6Digit', {'email': widget.email}),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        Center(
                          child: Pinput(
                            length: 6,
                            controller: _pinController,
                            focusNode: _focusNode,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: focusedPinTheme,
                            submittedPinTheme: submittedPinTheme,
                            pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                            showCursor: true,
                            onCompleted: (pin) => _verifyOtp(),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          _start > 0 ? tr('auth.codeExpiresIn', {'time': _formattedTime}) : tr('auth.codeExpired'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _start > 0 ? colorScheme.onSurfaceVariant : colorScheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        ElevatedButton(
                          onPressed: authState.status == AuthStatus.loading || _start == 0 ? null : _verifyOtp,
                          child: authState.status == AuthStatus.loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                                  ),
                                )
                              : Text(
                                  tr('auth.verify'),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),

                        const SizedBox(height: 24),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr('auth.didntReceiveCode'),
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _canResend ? _resendOtp : null,
                              child: Text(
                                _canResend ? tr('auth.resend') : tr('auth.waitCooldown', {'seconds': '$_resendCooldown'}),
                                style: TextStyle(
                                  color: _canResend ? (isDark ? AppColors.darkAccent : AppColors.lightAccent) : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
