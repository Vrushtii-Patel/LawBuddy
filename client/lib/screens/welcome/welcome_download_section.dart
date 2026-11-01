import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../services/apk_download/apk_downloader.dart';
import '../../theme/app_theme.dart';
import 'welcome_how_it_works.dart';

class WelcomeDownloadSection extends ConsumerStatefulWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;

  const WelcomeDownloadSection({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  ConsumerState<WelcomeDownloadSection> createState() =>
      _WelcomeDownloadSectionState();
}

class _WelcomeDownloadSectionState extends ConsumerState<WelcomeDownloadSection> {
  final GlobalKey _guideAnchorKey = GlobalKey();

  Future<void> _handleDownloadApk(BuildContext context) async {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.downloading_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Starting LawBuddy APK download...'),
            ],
          ),
          backgroundColor: AppColors.softGraphite,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    try {
      await downloadLawBuddyApk();
    } catch (e) {
      debugPrint('Error launching APK download: $e');
    }
  }

  void _scrollToGuide() {
    final ctx = _guideAnchorKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showInstallGuideModal(BuildContext context) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final isDark = widget.isDark;

    final surfaceColor =
        isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.install_mobile_rounded,
                  size: 22, color: primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.translate('welcome.installTitle'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Step-by-step Android installation instructions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                StepCard(
                  number: '01',
                  title: loc.translate('welcome.installStep1Title'),
                  description: loc.translate('welcome.installStep1Desc'),
                  tag: 'DIRECT HTTPS • ~40 MB',
                  icon: Icons.download_for_offline_rounded,
                  bulletPoints: const [
                    'Saves directly to your Downloads folder',
                    'Zero store accounts or sign-ins needed',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                StepCard(
                  number: '02',
                  title: loc.translate('welcome.installStep2Title'),
                  description: loc.translate('welcome.installStep2Desc'),
                  tag: 'SECURITY PROMPT',
                  icon: Icons.security_rounded,
                  bulletPoints: const [
                    'Tap "Download anyway" on browser alert',
                    'Standard Android notice for third-party APKs',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                StepCard(
                  number: '03',
                  title: loc.translate('welcome.installStep3Title'),
                  description: loc.translate('welcome.installStep3Desc'),
                  tag: 'ONE-TIME PERMISSION',
                  icon: Icons.settings_suggest_rounded,
                  bulletPoints: const [
                    'Settings → Allow from this source',
                    'One-time setup on Android 8+',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                StepCard(
                  number: '04',
                  title: loc.translate('welcome.installStep4Title'),
                  description: loc.translate('welcome.installStep4Desc'),
                  tag: 'ON-SITE READY',
                  icon: Icons.camera_enhance_rounded,
                  bulletPoints: const [
                    'Tap "Install" → "Open"',
                    'Camera deed scanning ready',
                  ],
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleDownloadApk(context);
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download APK Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              foregroundColor:
                  isDark ? AppColors.softGraphite : AppColors.warmLinen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final isDark = widget.isDark;
    final isDesktop = widget.isDesktop;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Download Banner Card
              Container(
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
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                          Expanded(
                            flex: 4,
                            child: _buildAppPreviewCard(
                              accentColor: accentColor,
                              surfaceColor: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated,
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
                            surfaceColor: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.lightSurfaceElevated,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 48),

              // 2. Step-by-Step Android Installation Guide (Matching How It Works Format)
              Container(
                key: _guideAnchorKey,
                child: Column(
                  children: [
                    Text(
                      loc.translate('welcome.installEyebrow'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.translate('welcome.installTitle'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isDesktop ? 28 : 22,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        loc.translate('welcome.installSubtitle'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          height: 1.45,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 4 StepCards in exact same format as How It Works
                    isDesktop
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: StepCard(
                                    number: '01',
                                    title: loc
                                        .translate('welcome.installStep1Title'),
                                    description: loc
                                        .translate('welcome.installStep1Desc'),
                                    tag: 'DIRECT HTTPS • ~40 MB',
                                    icon: Icons.download_for_offline_rounded,
                                    bulletPoints: const [
                                      'Direct cryptographic download',
                                      'No Google Play account needed',
                                    ],
                                    isDark: isDark,
                                  ),
                                ),
                                _buildStepArrow(isDark),
                                Expanded(
                                  child: StepCard(
                                    number: '02',
                                    title: loc
                                        .translate('welcome.installStep2Title'),
                                    description: loc
                                        .translate('welcome.installStep2Desc'),
                                    tag: 'SECURITY PROMPT',
                                    icon: Icons.security_rounded,
                                    bulletPoints: const [
                                      'Select "Download anyway"',
                                      'Standard Android outside-store notice',
                                    ],
                                    isDark: isDark,
                                  ),
                                ),
                                _buildStepArrow(isDark),
                                Expanded(
                                  child: StepCard(
                                    number: '03',
                                    title: loc
                                        .translate('welcome.installStep3Title'),
                                    description: loc
                                        .translate('welcome.installStep3Desc'),
                                    tag: 'ONE-TIME PERMISSION',
                                    icon: Icons.settings_suggest_rounded,
                                    bulletPoints: const [
                                      'Settings → Allow from this source',
                                      'One-time setup on Android 8+',
                                    ],
                                    isDark: isDark,
                                  ),
                                ),
                                _buildStepArrow(isDark),
                                Expanded(
                                  child: StepCard(
                                    number: '04',
                                    title: loc
                                        .translate('welcome.installStep4Title'),
                                    description: loc
                                        .translate('welcome.installStep4Desc'),
                                    tag: 'ON-SITE READY',
                                    icon: Icons.camera_enhance_rounded,
                                    bulletPoints: const [
                                      'Tap "Install" → "Open"',
                                      'Camera deed scanning ready',
                                    ],
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              StepCard(
                                number: '01',
                                title:
                                    loc.translate('welcome.installStep1Title'),
                                description:
                                    loc.translate('welcome.installStep1Desc'),
                                tag: 'DIRECT HTTPS • ~40 MB',
                                icon: Icons.download_for_offline_rounded,
                                bulletPoints: const [
                                  'Direct cryptographic download',
                                  'No Google Play account needed',
                                ],
                                isDark: isDark,
                              ),
                              const SizedBox(height: 14),
                              StepCard(
                                number: '02',
                                title:
                                    loc.translate('welcome.installStep2Title'),
                                description:
                                    loc.translate('welcome.installStep2Desc'),
                                tag: 'SECURITY PROMPT',
                                icon: Icons.security_rounded,
                                bulletPoints: const [
                                  'Select "Download anyway"',
                                  'Standard Android outside-store notice',
                                ],
                                isDark: isDark,
                              ),
                              const SizedBox(height: 14),
                              StepCard(
                                number: '03',
                                title:
                                    loc.translate('welcome.installStep3Title'),
                                description:
                                    loc.translate('welcome.installStep3Desc'),
                                tag: 'ONE-TIME PERMISSION',
                                icon: Icons.settings_suggest_rounded,
                                bulletPoints: const [
                                  'Settings → Allow from this source',
                                  'One-time setup on Android 8+',
                                ],
                                isDark: isDark,
                              ),
                              const SizedBox(height: 14),
                              StepCard(
                                number: '04',
                                title:
                                    loc.translate('welcome.installStep4Title'),
                                description:
                                    loc.translate('welcome.installStep4Desc'),
                                tag: 'ON-SITE READY',
                                icon: Icons.camera_enhance_rounded,
                                bulletPoints: const [
                                  'Tap "Install" → "Open"',
                                  'Camera deed scanning ready',
                                ],
                                isDark: isDark,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepArrow(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          Icons.chevron_right_rounded,
          size: 22,
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
    final isDark = widget.isDark;
    final isDesktop = widget.isDesktop;

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
                backgroundColor:
                    isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor:
                    isDark ? AppColors.softGraphite : AppColors.warmLinen,
                elevation: 0,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _scrollToGuide();
              },
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('View Install Guide'),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.lightSurfaceElevated,
                foregroundColor: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorderMedium,
                  width: 1.2,
                ),
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () => _showInstallGuideModal(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              tooltip: 'Open in Pop-up Modal',
              style: IconButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Specs note
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded,
                size: 13, color: AppColors.compliant(isDark)),
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
    final isDark = widget.isDark;
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
                child: Icon(Icons.phone_android_rounded,
                    size: 20, color: accentColor),
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
