import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../utils/password_validator.dart';

class PasswordChecklistWidget extends ConsumerWidget {
  final PasswordValidationResult validation;
  final bool isVisible;

  const PasswordChecklistWidget({
    super.key,
    required this.validation,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible) return const SizedBox.shrink();

    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final validColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final elevatedSurface = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: elevatedSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRuleItem(
            context,
            isValid: validation.hasMinLength,
            label: tr('auth.passwordRuleMinLength'),
            validColor: validColor,
            secondaryText: secondaryText,
            primaryText: primaryText,
          ),
          const SizedBox(height: 6),
          _buildRuleItem(
            context,
            isValid: validation.hasLetter,
            label: tr('auth.passwordRuleLetter'),
            validColor: validColor,
            secondaryText: secondaryText,
            primaryText: primaryText,
          ),
          const SizedBox(height: 6),
          _buildRuleItem(
            context,
            isValid: validation.hasNumber,
            label: tr('auth.passwordRuleNumber'),
            validColor: validColor,
            secondaryText: secondaryText,
            primaryText: primaryText,
          ),
          const SizedBox(height: 6),
          _buildRuleItem(
            context,
            isValid: validation.isNotTooLong,
            label: tr('auth.passwordRuleMaxLength'),
            validColor: validColor,
            secondaryText: secondaryText,
            primaryText: primaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(
    BuildContext context, {
    required bool isValid,
    required String label,
    required Color validColor,
    required Color secondaryText,
    required Color primaryText,
  }) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isValid ? validColor : Colors.transparent,
            border: Border.all(
              color: isValid ? validColor : secondaryText.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: isValid
              ? const Icon(
                  Icons.check,
                  size: 11,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isValid ? FontWeight.w600 : FontWeight.w400,
              color: isValid ? primaryText : secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}
