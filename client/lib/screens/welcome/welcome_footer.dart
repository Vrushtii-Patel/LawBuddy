import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cookie_consent_banner.dart';
import '../privacy_policy_screen.dart';
import '../terms_of_use_screen.dart';
import 'welcome_header.dart';

class WelcomeFooter extends ConsumerWidget {
  final bool isDark;
  final bool isDesktop;
  final VoidCallback onFeaturesTap;
  final VoidCallback? onDownloadTap;
  final VoidCallback onHowItWorksTap;
  final VoidCallback onRiskSystemTap;
  final VoidCallback? onFaqTap;

  const WelcomeFooter({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.onFeaturesTap,
    this.onDownloadTap,
    required this.onHowItWorksTap,
    required this.onRiskSystemTap,
    this.onFaqTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.5)
        : AppColors.lightBorder;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 20,
        vertical: 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Grid: Brand Column + Navigation + Legal
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Info
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkPrimary
                                      : AppColors.lightPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.gavel_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LawBuddy',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    loc.translate('welcome.headerTagline'),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkAccent
                                          : AppColors.lightPrimary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loc.translate('welcome.footerDescription'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.5,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkBackground.withValues(alpha: 0.6)
                                  : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: borderColor,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Not an advocate under Advocates Act, 1961.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),

                    // Quick Navigation Links
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFooterLink(
                              loc.translate('welcome.navFeatures'), onFeaturesTap, textSecondary),
                          if (kIsWeb && onDownloadTap != null)
                            _buildFooterLink('Android APK', onDownloadTap!, textSecondary),
                          _buildFooterLink(
                              loc.translate('welcome.navHowItWorks'), onHowItWorksTap, textSecondary),
                          _buildFooterLink(
                              loc.translate('welcome.navRiskSystem'), onRiskSystemTap, textSecondary),
                          if (onFaqTap != null)
                            _buildFooterLink(
                                loc.translate('welcome.navFaq'), onFaqTap!, textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),

                    // Legal & Policies
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Legal & Policies',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFooterLink(
                            loc.translate('welcome.privacyPolicy'),
                            () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                            ),
                            textSecondary,
                          ),
                          _buildFooterLink(
                            loc.translate('welcome.termsOfUse'),
                            () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                            ),
                            textSecondary,
                          ),
                          _buildFooterLink(
                            loc.translate('welcome.disclaimerTitle'),
                            () => showLegalDisclaimerDialog(context, isDark, ref),
                            textSecondary,
                          ),
                          _buildFooterLink(
                            loc.translate('welcome.storagePreferences'),
                            () => showPrivacyPreferencesDialog(context),
                            textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),

                    // Support & Contact
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('welcome.footerSupportTitle'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFooterLink(
                            loc.translate('welcome.footerContactSupport'),
                            () => _handleContactTap(context, isDark),
                            textSecondary,
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _handleContactTap(context, isDark),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.mail_outline_rounded,
                                    size: 14,
                                    color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'finalyearproject2513@gmail.com',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // Mobile layout
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'LawBuddy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI legal assistant for Indian real estate documents. Not formal legal counsel.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        height: 1.45,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      children: [
                        _buildFooterLink(
                            loc.translate('welcome.navFeatures'), onFeaturesTap, textSecondary),
                        if (kIsWeb && onDownloadTap != null)
                          _buildFooterLink('APK Download', onDownloadTap!, textSecondary),
                        _buildFooterLink(
                            loc.translate('welcome.navHowItWorks'), onHowItWorksTap, textSecondary),
                        _buildFooterLink(
                            loc.translate('welcome.navRiskSystem'), onRiskSystemTap, textSecondary),
                        if (onFaqTap != null)
                          _buildFooterLink(
                              loc.translate('welcome.navFaq'), onFaqTap!, textSecondary),
                        _buildFooterLink(
                          loc.translate('welcome.privacyPolicy'),
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                          ),
                          textSecondary,
                        ),
                        _buildFooterLink(
                          loc.translate('welcome.termsOfUse'),
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                          ),
                          textSecondary,
                        ),
                        _buildFooterLink(
                          loc.translate('welcome.disclaimerTitle'),
                          () => showLegalDisclaimerDialog(context, isDark, ref),
                          textSecondary,
                        ),
                        _buildFooterLink(
                          loc.translate('welcome.footerContactSupport'),
                          () => _handleContactTap(context, isDark),
                          textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _handleContactTap(context, isDark),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBackground.withValues(alpha: 0.6)
                              : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 14,
                              color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'finalyearproject2513@gmail.com',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 36),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 20),

              // Bottom Bar
              Text(
                '© 2026 LawBuddy. Built with precision for Indian Real Estate.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String label, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleContactTap(BuildContext context, bool isDark) async {
    const email = 'finalyearproject2513@gmail.com';
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'LawBuddy Support & Legal Tech Inquiry',
      },
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showContactInfoDialog(context, isDark, email);
      }
    } catch (_) {
      if (context.mounted) {
        _showContactInfoDialog(context, isDark, email);
      }
    }
  }

  void _showContactInfoDialog(
    BuildContext context,
    bool isDark,
    String email,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.support_agent_rounded,
                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'LawBuddy Support',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Need assistance with document scanning, legal clause queries, or account support? Reach out directly:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        email,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
