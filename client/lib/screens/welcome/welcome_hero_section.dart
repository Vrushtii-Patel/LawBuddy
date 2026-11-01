import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import 'welcome_hero_visual.dart';

class WelcomeHeroSection extends ConsumerWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;
  final ScrollController scrollController;
  final Animation<double> headlineLine1;
  final Animation<double> headlineLine2;
  final Animation<double> headlineLine3;
  final Animation<double> sideWordsAnim;
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const WelcomeHeroSection({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.isTablet,
    required this.scrollController,
    required this.headlineLine1,
    required this.headlineLine2,
    required this.headlineLine3,
    required this.sideWordsAnim,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        final scrollOffset =
            scrollController.hasClients ? scrollController.offset : 0.0;
        final clampedScroll = scrollOffset.clamp(0.0, 450.0);
        final scrollProgress = clampedScroll / 450.0;

        // Dynamic scroll parallax offsets
        final docShift = scrollProgress * -14.0;
        final sideWordInward =
            (1.0 - scrollProgress) * (isDesktop ? 30.0 : 14.0);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32.0 : (isTablet ? 20.0 : 16.0),
            vertical: isDesktop ? 32.0 : (isTablet ? 20.0 : 12.0),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Main Content Column (Eyebrow, Layered Typography, Document, Narrative, CTAs)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Clean Eyebrow Header (No pill container, no dot)
                      Text(
                        isDesktop
                            ? loc.translate('welcome.heroEyebrowDesktop')
                            : loc.translate('welcome.heroEyebrowMobile'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isDesktop ? 12.0 : 11.0,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.lightPrimary,
                          letterSpacing: 1.4,
                        ),
                      ),

                      SizedBox(height: isDesktop ? 16.0 : (isTablet ? 12.0 : 8.0)),

                      // Clean High-Contrast Headline (Crisp, single-layer, zero shadow)
                      _buildHeadline(
                        context,
                        loc,
                      ),

                      SizedBox(height: isDesktop ? 24.0 : (isTablet ? 18.0 : 14.0)),

                      // 3D Document Visual with Live Scanning Animation
                      Transform.translate(
                        offset: Offset(0, docShift),
                        child: HeroDocumentScanVisual(
                          isDark: isDark,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                      ),

                      SizedBox(height: isDesktop ? 24.0 : (isTablet ? 18.0 : 14.0)),

                      // Supporting Narrative
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Text(
                          loc.translate('welcome.heroNarrative'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: isDesktop ? 15.0 : 13.0,
                            height: isDesktop ? 1.6 : 1.45,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),

                      SizedBox(height: isDesktop ? 24.0 : (isTablet ? 18.0 : 16.0)),

                      // CTA Buttons Row
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          ElevatedButton(
                            onPressed: onGetStarted,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                              foregroundColor: isDark
                                  ? AppColors.softGraphite
                                  : AppColors.warmLinen,
                              padding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 28.0 : 24.0,
                                  vertical: isDesktop ? 15.0 : 12.0),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  loc.translate('welcome.getStarted'),
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 16),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: onSignIn,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              foregroundColor: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                                children: [
                                  TextSpan(
                                      text: loc.translate(
                                          'welcome.alreadyHaveAccount')),
                                  TextSpan(
                                    text: loc.translate('welcome.signInAction'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkAccent
                                          : AppColors.lightPrimary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Layer 3: Left & Right Background Words with Staggered Entrance
                  if (isDesktop || isTablet) ...[
                    // Left Column Words: SCAN, ANALYZE, PROTECT, UNDERSTAND
                    Positioned(
                      left: isDesktop ? 16 : 8,
                      top: isDesktop ? 390 : 310,
                      child: AnimatedBuilder(
                        animation: sideWordsAnim,
                        builder: (context, child) {
                          return Opacity(
                            opacity: sideWordsAnim.value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(
                                  -sideWordInward +
                                      (1.0 - sideWordsAnim.value) * -20.0,
                                  0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildSideWordColumn(
                          [
                            loc.translate('welcome.sideWordScan'),
                            loc.translate('welcome.sideWordAnalyze'),
                            loc.translate('welcome.sideWordProtect'),
                            loc.translate('welcome.sideWordUnderstand'),
                          ],
                          CrossAxisAlignment.start,
                        ),
                      ),
                    ),

                    // Right Column Words: PROPERTY, RERA, CLAUSES, SECURE
                    Positioned(
                      right: isDesktop ? 16 : 8,
                      top: isDesktop ? 390 : 310,
                      child: AnimatedBuilder(
                        animation: sideWordsAnim,
                        builder: (context, child) {
                          return Opacity(
                            opacity: sideWordsAnim.value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(
                                  sideWordInward +
                                      (1.0 - sideWordsAnim.value) * 20.0,
                                  0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildSideWordColumn(
                          [
                            loc.translate('welcome.sideWordProperty'),
                            loc.translate('welcome.sideWordRera'),
                            loc.translate('welcome.sideWordClauses'),
                            loc.translate('welcome.sideWordSecure'),
                          ],
                          CrossAxisAlignment.end,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeadline(
    BuildContext context,
    LocaleNotifier loc,
  ) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rawFontSize = isDesktop ? 62.0 : (isTablet ? 42.0 : 28.0);
    final fontSize = (rawFontSize / (textScale > 1.2 ? textScale * 0.8 : 1.0)).clamp(20.0, 68.0);

    final baseStyle = GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.15,
      letterSpacing: -1.0,
    );

    Widget buildHeadlineLine(String lineText, Animation<double> anim) {
      return Padding(
        padding: EdgeInsets.only(bottom: isDesktop ? 6.0 : (isTablet ? 4.0 : 2.0)),
        child: AnimatedBuilder(
          animation: anim,
          builder: (context, child) {
            final progress = anim.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, (1.0 - progress) * 25.0),
                child: child,
              ),
            );
          },
          child: Text(
            lineText,
            textAlign: TextAlign.center,
            style: baseStyle.copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildHeadlineLine(
            loc.translate('welcome.headlineLine1'), headlineLine1),
        buildHeadlineLine(
            loc.translate('welcome.headlineLine2Full'), headlineLine2),
        buildHeadlineLine(
            loc.translate('welcome.headlineLine3'), headlineLine3),
      ],
    );
  }

  Widget _buildSideWordColumn(
    List<String> words,
    CrossAxisAlignment alignment,
  ) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: words.map((word) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 12.0 : 7.0),
          child: Text(
            word,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isDesktop ? 26.0 : (isTablet ? 18.0 : 12.0),
              fontWeight: FontWeight.w900,
              letterSpacing: isDesktop ? 5.5 : 3.5,
              color: isDark
                  ? AppColors.darkTextSecondary.withValues(alpha: 0.85)
                  : AppColors.lightTextPrimary.withValues(alpha: 0.65),
            ),
          ),
        );
      }).toList(),
    );
  }
}
