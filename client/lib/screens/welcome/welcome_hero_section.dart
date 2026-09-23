import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'welcome_hero_visual.dart';

class WelcomeHeroSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        final scrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
        final clampedScroll = scrollOffset.clamp(0.0, 450.0);
        final scrollProgress = clampedScroll / 450.0;

        // Dynamic scroll parallax offsets
        final titleShiftBack = scrollProgress * 14.0;
        final titleShiftMid = scrollProgress * 8.0;
        final titleShiftThird = scrollProgress * 4.0;
        final docShift = scrollProgress * -14.0;
        final sideWordInward = (1.0 - scrollProgress) * (isDesktop ? 30.0 : 14.0);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32.0 : (isTablet ? 20.0 : 16.0),
            vertical: isDesktop ? 32.0 : 20.0,
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
                      // Eyebrow Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: isDark ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: isDark ? 0.35 : 0.20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isDesktop
                                    ? 'AI-POWERED LEGALTECH FOR INDIAN REAL ESTATE'
                                    : 'AI-POWERED REAL ESTATE LEGALTECH',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Giant Dimensional 4-Layered Headline (All 3 lines 100% visible & readable)
                      _buildLayeredHeadline(
                        titleShiftBack,
                        titleShiftMid,
                        titleShiftThird,
                      ),

                      const SizedBox(height: 24),

                      // 3D Document Visual with Live Scanning Animation
                      Transform.translate(
                        offset: Offset(0, docShift),
                        child: HeroDocumentScanVisual(
                          isDark: isDark,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Supporting Narrative
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Text(
                          'Analyze real-estate contracts, detect potential legal risks under RERA, and understand complex clauses in plain English — powered by AI built for Indian property law.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: isDesktop ? 15.0 : 13.5,
                            height: 1.6,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

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
                              backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                              foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Get Started',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: onSignIn,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                children: [
                                  const TextSpan(text: 'Already have an account? '),
                                  TextSpan(
                                    text: 'Sign in',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
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
                              offset: Offset(-sideWordInward + (1.0 - sideWordsAnim.value) * -20.0, 0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildSideWordColumn(
                          ['SCAN', 'ANALYZE', 'PROTECT', 'UNDERSTAND'],
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
                              offset: Offset(sideWordInward + (1.0 - sideWordsAnim.value) * 20.0, 0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildSideWordColumn(
                          ['PROPERTY', 'RERA', 'CLAUSES', 'SECURE'],
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

  Widget _buildLayeredHeadline(
    double shiftBack,
    double shiftMid,
    double shiftThird,
  ) {
    final fontSize = isDesktop ? 68.0 : (isTablet ? 46.0 : 30.0);

    final backOffsetY = (isDesktop ? 18.0 : (isTablet ? 12.0 : 9.0)) + shiftBack;
    final secOffsetY = (isDesktop ? 12.0 : (isTablet ? 8.0 : 6.0)) + shiftMid;
    final thirdOffsetY = (isDesktop ? 6.0 : (isTablet ? 4.0 : 3.0)) + shiftThird;

    final baseStyle = GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.05,
      letterSpacing: -1.5,
    );

    Widget buildHeadlineLine(String lineText, Animation<double> anim, {String? prefix, String? accentWord, String? suffix}) {
      return ClipRect(
        child: AnimatedBuilder(
          animation: anim,
          builder: (context, child) {
            final progress = anim.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, (1.0 - progress) * 35.0),
                child: child,
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Layer 1: Back Deep Slate Tone
              Transform.translate(
                offset: Offset(0, backOffsetY),
                child: Text(
                  lineText,
                  textAlign: TextAlign.center,
                  style: baseStyle.copyWith(
                    color: (isDark ? AppColors.darkSurface : AppColors.lightBorder).withValues(alpha: 0.5),
                  ),
                ),
              ),

              // Layer 2: Mid Lavender Shadow
              Transform.translate(
                offset: Offset(0, secOffsetY),
                child: Text(
                  lineText,
                  textAlign: TextAlign.center,
                  style: baseStyle.copyWith(
                    color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.4),
                  ),
                ),
              ),

              // Layer 3: Third Brand Warm Tone
              Transform.translate(
                offset: Offset(0, thirdOffsetY),
                child: Text(
                  lineText,
                  textAlign: TextAlign.center,
                  style: baseStyle.copyWith(
                    color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                  ),
                ),
              ),

              // Layer 4: Front Crisp Dominant Layer
              if (accentWord != null)
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: baseStyle.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    children: [
                      if (prefix != null) TextSpan(text: prefix),
                      TextSpan(
                        text: accentWord,
                        style: TextStyle(
                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        ),
                      ),
                      if (suffix != null) TextSpan(text: suffix),
                    ],
                  ),
                )
              else
                Text(
                  lineText,
                  textAlign: TextAlign.center,
                  style: baseStyle.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildHeadlineLine('UNDERSTAND', headlineLine1),
        buildHeadlineLine('YOUR PROPERTY', headlineLine2, prefix: 'YOUR ', accentWord: 'PROPERTY'),
        buildHeadlineLine('BEFORE YOU SIGN.', headlineLine3),
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
            style: GoogleFonts.inter(
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
