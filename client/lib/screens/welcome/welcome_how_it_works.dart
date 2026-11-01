import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class StepCard extends StatefulWidget {
  final String number;
  final String title;
  final String description;
  final String? tag;
  final IconData? icon;
  final List<String>? bulletPoints;
  final double? minHeight;
  final bool isDark;

  const StepCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    this.tag,
    this.icon,
    this.bulletPoints,
    this.minHeight,
    required this.isDark,
  });

  @override
  State<StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<StepCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        width: double.infinity,
        constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered
                ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                      .withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: _isHovered ? 18 : 10,
              offset: Offset(0, _isHovered ? 6 : 3),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Number badge + Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.number,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightPrimary,
                      ),
                    ),
                  ),
                  if (widget.icon != null)
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkBackground
                                : AppColors.lightBackground)
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 16,
                        color: isDark
                            ? AppColors.darkAccent
                            : AppColors.lightPrimary,
                      ),
                    ),
                ],
              ),

              if (widget.tag != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground)
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder)
                          .withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    widget.tag!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 9),
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  height: 1.42,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),

              if (widget.bulletPoints != null &&
                  widget.bulletPoints!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...widget.bulletPoints!.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(top: 3.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: isDark
                                ? AppColors.darkAccent
                                : AppColors.lightPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            point,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeHowItWorksSection extends ConsumerWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;

  const WelcomeHowItWorksSection({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final step1Title = loc.translate('welcome.step1Title');
    final step1Desc = loc.translate('welcome.step1Desc');
    final step2Title = loc.translate('welcome.step2Title');
    final step2Desc = loc.translate('welcome.step2Desc');
    final step3Title = loc.translate('welcome.step3Title');
    final step3Desc = loc.translate('welcome.step3Desc');
    final step4Title = loc.translate('welcome.step4Title');
    final step4Desc = loc.translate('welcome.step4Desc');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                loc.translate('welcome.howEyebrow'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.translate('welcome.howTitle'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isDesktop ? 30 : 22,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 36),
              isDesktop
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: StepCard(
                              number: '01',
                              title: step1Title,
                              description: step1Desc,
                              tag: 'INGESTION & OCR',
                              icon: Icons.document_scanner_rounded,
                              bulletPoints: const [
                                'Digital PDF & deed upload',
                                'English & Devanagari OCR',
                              ],
                              isDark: isDark,
                            ),
                          ),
                          _buildStepArrow(isDark),
                          Expanded(
                            child: StepCard(
                              number: '02',
                              title: step2Title,
                              description: step2Desc,
                              tag: 'STATUTORY AUDIT',
                              icon: Icons.rule_folder_rounded,
                              bulletPoints: const [
                                'RERA Section 13 benchmark check',
                                'Forfeiture & milestone scrutiny',
                              ],
                              isDark: isDark,
                            ),
                          ),
                          _buildStepArrow(isDark),
                          Expanded(
                            child: StepCard(
                              number: '03',
                              title: step3Title,
                              description: step3Desc,
                              tag: 'RISK SCORING',
                              icon: Icons.gavel_rounded,
                              bulletPoints: const [
                                '3-tier color risk ratings',
                                'Plain-English clause breakdown',
                              ],
                              isDark: isDark,
                            ),
                          ),
                          _buildStepArrow(isDark),
                          Expanded(
                            child: StepCard(
                              number: '04',
                              title: step4Title,
                              description: step4Desc,
                              tag: 'AUDIT & ACTION',
                              icon: Icons.picture_as_pdf_rounded,
                              bulletPoints: const [
                                'Exportable legal PDF audit report',
                                'Actionable renegotiation points',
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
                          title: step1Title,
                          description: step1Desc,
                          tag: 'INGESTION & OCR',
                          icon: Icons.document_scanner_rounded,
                          bulletPoints: const [
                            'Digital PDF & deed upload',
                            'English & Devanagari OCR',
                          ],
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        StepCard(
                          number: '02',
                          title: step2Title,
                          description: step2Desc,
                          tag: 'STATUTORY AUDIT',
                          icon: Icons.rule_folder_rounded,
                          bulletPoints: const [
                            'RERA Section 13 benchmark check',
                            'Forfeiture & milestone scrutiny',
                          ],
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        StepCard(
                          number: '03',
                          title: step3Title,
                          description: step3Desc,
                          tag: 'RISK SCORING',
                          icon: Icons.gavel_rounded,
                          bulletPoints: const [
                            '3-tier color risk ratings',
                            'Plain-English clause breakdown',
                          ],
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        StepCard(
                          number: '04',
                          title: step4Title,
                          description: step4Desc,
                          tag: 'AUDIT & ACTION',
                          icon: Icons.picture_as_pdf_rounded,
                          bulletPoints: const [
                            'Exportable legal PDF audit report',
                            'Actionable renegotiation points',
                          ],
                          isDark: isDark,
                        ),
                      ],
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
}
