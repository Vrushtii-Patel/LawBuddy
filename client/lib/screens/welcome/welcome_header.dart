import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../privacy_policy_screen.dart';
import '../terms_of_use_screen.dart';
import '../../widgets/cookie_consent_banner.dart';

void showLegalDisclaimerDialog(BuildContext context, bool isDark) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.gavel_rounded,
              size: 20,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Legal Disclaimer',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This application provides AI-generated information for preliminary document review and educational purposes only. It does not constitute legal advice or create an advocate-client relationship. For important property transactions, consult a qualified legal professional.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                  icon: const Icon(Icons.shield_outlined, size: 14),
                  label: const Text('Privacy Policy'),
                  style: OutlinedButton.styleFrom(
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                    );
                  },
                  icon: const Icon(Icons.description_outlined, size: 14),
                  label: const Text('Terms of Use'),
                  style: OutlinedButton.styleFrom(
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    showPrivacyPreferencesDialog(context);
                  },
                  icon: const Icon(Icons.tune_rounded, size: 14),
                  label: const Text('Storage Preferences'),
                  style: OutlinedButton.styleFrom(
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Understood', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class WelcomeHeader extends StatelessWidget {
  final bool isDark;
  final bool isDesktop;
  final VoidCallback onLogoTap;
  final VoidCallback onFeaturesTap;
  final VoidCallback onHowItWorksTap;
  final VoidCallback onRiskSystemTap;
  final VoidCallback onLoginTap;

  const WelcomeHeader({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.onLogoTap,
    required this.onFeaturesTap,
    required this.onHowItWorksTap,
    required this.onRiskSystemTap,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder.withValues(alpha: 0.40) : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand Logo + Title
              Expanded(
                child: InkWell(
                  onTap: onLogoTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.gavel_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LawBuddy',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.inter(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 20,
                              height: 1.5,
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'REAL ESTATE AI TECH',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Desktop Navigation Links
              if (isDesktop)
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavButton('Features', onFeaturesTap, isDark),
                        _buildNavButton('How It Works', onHowItWorksTap, isDark),
                        _buildNavButton('Risk System', onRiskSystemTap, isDark),
                        _buildNavButton('Privacy Policy', () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                          );
                        }, isDark),
                        _buildNavButton('Terms of Use', () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                          );
                        }, isDark),
                        _buildNavButton('Disclaimer', () => showLegalDisclaimerDialog(context, isDark), isDark),
                      ],
                    ),
                  ),
                ),

              // Right Actions (Sign In + Mobile Menu)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onLoginTap,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!isDesktop) ...[
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.menu_rounded,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'features':
                            onFeaturesTap();
                            break;
                          case 'howItWorks':
                            onHowItWorksTap();
                            break;
                          case 'riskSystem':
                            onRiskSystemTap();
                            break;
                          case 'privacy':
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                            );
                            break;
                          case 'terms':
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                            );
                            break;
                          case 'disclaimer':
                            showLegalDisclaimerDialog(context, isDark);
                            break;
                          case 'storage':
                            showPrivacyPreferencesDialog(context);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'features', child: Text('Features')),
                        const PopupMenuItem(value: 'howItWorks', child: Text('How It Works')),
                        const PopupMenuItem(value: 'riskSystem', child: Text('Risk System')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
                        const PopupMenuItem(value: 'terms', child: Text('Terms of Use')),
                        const PopupMenuItem(value: 'disclaimer', child: Text('Legal Disclaimer')),
                        const PopupMenuItem(value: 'storage', child: Text('Storage Preferences')),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(String label, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
