import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/terms_of_use_screen.dart';
import '../screens/privacy_policy_screen.dart';

enum FormConsentType {
  legalQuestion,
  documentUpload,
  custom,
}

/// A reusable interactive checkbox for mandatory terms and privacy consent during registration.
class FormConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool hasError;
  final String? errorMessage;
  final String? customText;

  const FormConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.hasError = false,
    this.errorMessage,
    this.customText,
  });

  void _openTerms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
    );
  }

  void _openPrivacy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = AppColors.lightPrimary;
    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: value,
                    onChanged: onChanged,
                    activeColor: primaryColor,
                    checkColor: isDark ? AppColors.darkBackground : Colors.white,
                    side: BorderSide(
                      color: hasError ? errorColor : cardBorder,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          height: 1.45,
                          color: hasError ? errorColor : secondaryText,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms of Use',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                              decoration: TextDecoration.underline,
                              decorationColor: primaryText.withValues(alpha: 0.5),
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _openTerms(context),
                          ),
                          const TextSpan(text: ' and acknowledge the '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                              decoration: TextDecoration.underline,
                              decorationColor: primaryText.withValues(alpha: 0.5),
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _openPrivacy(context),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34.0),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 12, color: errorColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorMessage ?? 'Please agree to the Terms of Use and Privacy Policy.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A reusable contextual acknowledgement notice for legal query submissions and document uploads.
class FormConsentAcknowledgement extends StatelessWidget {
  final FormConsentType type;
  final String? customText;
  final bool showTerms;
  final bool showPrivacy;
  final EdgeInsetsGeometry? margin;

  const FormConsentAcknowledgement({
    super.key,
    this.type = FormConsentType.legalQuestion,
    this.customText,
    this.showTerms = true,
    this.showPrivacy = true,
    this.margin,
  });

  void _openTerms(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
    );
  }

  void _openPrivacy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bgCol = (isDark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.6);

    String mainText = '';
    switch (type) {
      case FormConsentType.legalQuestion:
        mainText =
            'I understand that the information I provide may be processed by LawBuddy to provide the requested legal assistance. Please do not submit information you do not wish to share.';
        break;
      case FormConsentType.documentUpload:
        mainText =
            'I understand that the document I submit will be processed by LawBuddy for the purpose described above.';
        break;
      case FormConsentType.custom:
        mainText = customText ?? '';
        break;
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(
              type == FormConsentType.documentUpload
                  ? Icons.shield_outlined
                  : Icons.info_outline_rounded,
              size: 14,
              color: secondaryText,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.4,
                  color: secondaryText,
                ),
                children: [
                  TextSpan(text: '$mainText '),
                  if (showPrivacy) ...[
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                        decoration: TextDecoration.underline,
                        decorationColor: primaryText.withValues(alpha: 0.4),
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openPrivacy(context),
                    ),
                  ],
                  if (showTerms && showPrivacy) const TextSpan(text: ' • '),
                  if (showTerms) ...[
                    TextSpan(
                      text: 'Terms of Use',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: primaryText,
                        decoration: TextDecoration.underline,
                        decorationColor: primaryText.withValues(alpha: 0.4),
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openTerms(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
