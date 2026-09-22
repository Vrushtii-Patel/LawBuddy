import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/consent_provider.dart';
import '../theme/app_theme.dart';
import '../screens/privacy_policy_screen.dart';

/// Floating or bottom-docked privacy & storage consent banner.
class CookieConsentBanner extends ConsumerStatefulWidget {
  const CookieConsentBanner({super.key});

  @override
  ConsumerState<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends ConsumerState<CookieConsentBanner> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox.shrink();
    }
    final consentState = ref.watch(consentProvider);
    if (consentState.hasDecided) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 768;

    final bgColor = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primaryBtnColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: isDesktop ? 20 : 0,
          left: isDesktop ? 24 : 0,
          right: isDesktop ? 24 : 0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 1080 : double.infinity,
            ),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 0),
            color: bgColor,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 18,
                vertical: isDesktop ? 18 : 16,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 0),
                border: Border.all(
                  color: borderColor,
                  width: 1,
                ),
              ),
              child: isDesktop
                  ? _buildDesktopLayout(
                      context,
                      ref,
                      isDark,
                      primaryTextColor,
                      secondaryTextColor,
                      borderColor,
                      primaryBtnColor,
                    )
                  : _buildMobileLayout(
                      context,
                      ref,
                      isDark,
                      primaryTextColor,
                      secondaryTextColor,
                      borderColor,
                      primaryBtnColor,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
    Color primaryBtnColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryBtnColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.shield_outlined, color: primaryBtnColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Privacy Matters',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'LawBuddy uses browser storage to keep you signed in and remember preferences such as your theme and language. We don\'t currently use advertising or analytics cookies.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.45,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => showPrivacyPreferencesDialog(context),
              style: TextButton.styleFrom(
                foregroundColor: secondaryTextColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              child: Text(
                'Customize',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => ref.read(consentProvider.notifier).necessaryOnly(),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryTextColor,
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(
                'Necessary Only',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => ref.read(consentProvider.notifier).acceptAll(),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBtnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(
                'Accept Preferences',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
    Color primaryBtnColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: primaryBtnColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.shield_outlined, color: primaryBtnColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Your Privacy Matters',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'LawBuddy uses browser storage to keep you signed in and remember preferences such as your theme and language. We don\'t currently use advertising or analytics cookies.',
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.45,
            color: secondaryTextColor,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref.read(consentProvider.notifier).necessaryOnly(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryTextColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Necessary Only',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => ref.read(consentProvider.notifier).acceptAll(),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryBtnColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Accept Preferences',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () => showPrivacyPreferencesDialog(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              foregroundColor: secondaryTextColor,
            ),
            child: Text(
              'Customize Preferences',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Global navigator key for dialogs triggered from top-level overlays
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Modal dialog for managing granular Privacy & Storage Preferences.
void showPrivacyPreferencesDialog([BuildContext? context]) {
  final targetContext = (context != null && Navigator.maybeOf(context) != null)
      ? context
      : (rootNavigatorKey.currentContext ?? context);

  if (targetContext != null) {
    showDialog(
      context: targetContext,
      builder: (ctx) => const _PrivacyPreferencesDialog(),
    );
  }
}

class _PrivacyPreferencesDialog extends ConsumerStatefulWidget {
  const _PrivacyPreferencesDialog();

  @override
  ConsumerState<_PrivacyPreferencesDialog> createState() => _PrivacyPreferencesDialogState();
}

class _PrivacyPreferencesDialogState extends ConsumerState<_PrivacyPreferencesDialog> {
  late bool _functionalEnabled;

  @override
  void initState() {
    super.initState();
    final consent = ref.read(consentProvider);
    _functionalEnabled = consent.functionalEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accentColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.tune_rounded, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Privacy & Storage Preferences',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure how LawBuddy uses local storage to store data on your device. Strictly necessary tokens cannot be disabled as they are required for account security.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.5,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 16),

              // 1. Strictly Necessary
              _buildCategoryCard(
                title: 'STRICTLY NECESSARY',
                statusBadge: 'Always On',
                isStatusActive: true,
                description: 'Required for authentication and core LawBuddy functionality.',
                isDark: isDark,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                accentColor: accentColor,
              ),
              const SizedBox(height: 12),

              // 2. Functional / Preferences
              _buildToggleCategoryCard(
                title: 'FUNCTIONAL / PREFERENCES',
                description: 'Remember theme and language preferences across sessions.',
                value: _functionalEnabled,
                onChanged: (val) => setState(() => _functionalEnabled = val),
                isDark: isDark,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                accentColor: accentColor,
              ),
              const SizedBox(height: 12),

              // 3. Analytics
              _buildCategoryCard(
                title: 'ANALYTICS',
                statusBadge: 'Not currently used',
                isStatusActive: false,
                description: 'We do not collect usage telemetry or run analytics trackers.',
                isDark: isDark,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                accentColor: accentColor,
              ),
              const SizedBox(height: 12),

              // 4. Marketing
              _buildCategoryCard(
                title: 'MARKETING',
                statusBadge: 'Not currently used',
                isStatusActive: false,
                description: 'We do not display third-party advertisements or tracking pixels.',
                isDark: isDark,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                accentColor: accentColor,
              ),
              const SizedBox(height: 16),

              // Policy link
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                  icon: Icon(Icons.arrow_outward_rounded, size: 14, color: accentColor),
                  label: Text(
                    'Read our full Privacy Policy',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () {
            ref.read(consentProvider.notifier).acceptAll();
            Navigator.of(context).pop();
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderColor),
            foregroundColor: primaryTextColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'Accept All',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ),
        FilledButton(
          onPressed: () {
            ref.read(consentProvider.notifier).saveCustom(functional: _functionalEnabled);
            Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'Save Preferences',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String statusBadge,
    required bool isStatusActive,
    required String description,
    required bool isDark,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: primaryTextColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isStatusActive
                      ? accentColor.withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusBadge,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isStatusActive ? accentColor : secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCategoryCard({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: primaryTextColor,
                ),
              ),
              Switch.adaptive(
                value: value,
                activeThumbColor: accentColor,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
