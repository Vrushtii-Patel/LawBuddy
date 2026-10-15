import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class WelcomeDownloadSection extends StatelessWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;

  const WelcomeDownloadSection({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.isTablet,
  });

  Future<void> _handleDownloadApk(BuildContext context) async {
    final uri = Uri.parse('/app-release.apk');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting LawBuddy APK download...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showInstallGuide(BuildContext context) {
    final surfaceColor = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.install_mobile_rounded, size: 20, color: primaryColor),
            ),
            const SizedBox(width: 12),
            Text(
              'How to Install APK',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideStep('1', 'Tap "Download Android APK" to save the file to your device.', textPrimary, textSecondary, primaryColor),
              const SizedBox(height: 12),
              _buildGuideStep('2', 'If prompted by Chrome or your browser, select "Download anyway".', textPrimary, textSecondary, primaryColor),
              const SizedBox(height: 12),
              _buildGuideStep('3', 'Open the downloaded file and tap "Install". Enable "Allow from this source" in Android settings if requested.', textPrimary, textSecondary, primaryColor),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              foregroundColor: isDark ? AppColors.softGraphite : AppColors.warmLinen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text, Color textPrimary, Color textSecondary, Color primaryColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only display on website/web browser; do NOT display inside installed mobile application
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 22,
              vertical: isDesktop ? 38 : 26,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor.withValues(alpha: isDark ? 0.8 : 0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left Column: Details & CTAs
                      Expanded(
                        flex: 6,
                        child: _buildDetailsColumn(
                          context,
                          accentColor: accentColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          primaryColor: primaryColor,
                          borderColor: borderColor,
                        ),
                      ),
                      const SizedBox(width: 48),

                      // Right Column: Mobile App Preview Card
                      Expanded(
                        flex: 4,
                        child: _buildAppPreviewCard(
                          accentColor: accentColor,
                          surfaceColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderColor: borderColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          primaryColor: primaryColor,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDetailsColumn(
                        context,
                        accentColor: accentColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        primaryColor: primaryColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: 24),
                      _buildAppPreviewCard(
                        accentColor: accentColor,
                        surfaceColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        primaryColor: primaryColor,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(
    BuildContext context, {
    required Color accentColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.android_rounded, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                'MOBILE APPLICATION',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Title
        Text(
          'Download LawBuddy for Mobile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isDesktop ? 28 : 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),

        // Subtitle
        Text(
          'Scan physical sale deeds with your camera right at the registrar office, verify due diligence on site, and review real estate agreements on the go.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isDesktop ? 14 : 13,
            height: 1.5,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 22),

        // Action Buttons
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _handleDownloadApk(context),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download Android APK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor: isDark ? AppColors.softGraphite : AppColors.warmLinen,
                elevation: 0,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _showInstallGuide(context),
              icon: const Icon(Icons.help_outline_rounded, size: 16),
              label: const Text('Install Guide'),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.lightSurfaceElevated,
                foregroundColor: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorderMedium,
                  width: 1.2,
                ),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Specs note
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 13, color: AppColors.compliant(isDark)),
            const SizedBox(width: 5),
            Text(
              'Direct APK • Android 8.0+ • Free standalone package',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppPreviewCard({
    required Color accentColor,
    required Color surfaceColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    final features = [
      'Camera scanning for multi-page paper deeds',
      'Encumbrance & occupancy verification lists',
      'Color-coded RERA compliance warnings',
      'Works offline with encrypted local session',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.phone_android_rounded, size: 20, color: accentColor),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LawBuddy Mobile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Official Android Edition',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: features.map((f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.compliant(isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
