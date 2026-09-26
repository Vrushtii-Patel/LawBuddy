import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Centralized Floating Toast Card Utility for LawBuddy
class AppToast {
  static void show(
    BuildContext context, {
    required Widget content,
    Duration duration = const Duration(seconds: 4),
    Widget? action,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    messenger.clearSnackBars();

    final screenWidth = MediaQuery.of(context).size.width;
    final toastWidth = screenWidth > 540 ? 460.0 : (screenWidth - 32.0).clamp(280.0, 540.0);

    final effectiveBg = backgroundColor ?? (isDark ? AppColors.darkElevatedSurface : AppColors.lightSurface);
    final effectiveBorder = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    messenger.showSnackBar(
      SnackBar(
        width: toastWidth,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        backgroundColor: effectiveBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: effectiveBorder,
            width: 1.2,
          ),
        ),
        duration: duration,
        content: Row(
          children: [
            Expanded(child: content),
            if (action != null) ...[
              const SizedBox(width: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    Widget? action,
    IconData icon = Icons.check_rounded,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;

    show(
      context,
      duration: duration,
      action: action,
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    Widget? action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errColor = isDark ? AppColors.darkError : AppColors.lightError;

    show(
      context,
      duration: duration,
      action: action,
      backgroundColor: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),
      borderColor: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
      content: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: errColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFFEE2E2) : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    Widget? action,
    IconData icon = Icons.info_outline_rounded,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    show(
      context,
      duration: duration,
      action: action,
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
