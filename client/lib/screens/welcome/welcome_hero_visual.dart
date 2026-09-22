import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class HeroDocumentScanVisual extends StatefulWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;

  const HeroDocumentScanVisual({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  State<HeroDocumentScanVisual> createState() => _HeroDocumentScanVisualState();
}

class _HeroDocumentScanVisualState extends State<HeroDocumentScanVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isDesktop = widget.isDesktop;
    final isTablet = widget.isTablet;

    return Center(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          constraints: BoxConstraints(maxWidth: isDesktop ? 540 : (isTablet ? 460 : 360)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.06),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 22 : 18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkElevatedSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : AppColors.lightBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Header with pulsating AI Scan Active indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: isDark ? 0.15 : 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.description_outlined,
                                      size: 16,
                                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'PROPERTY SALE AGREEMENT',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // AI Scan Active Badge with subtle pulsing light
                            AnimatedBuilder(
                              animation: _scanController,
                              builder: (context, child) {
                                final pulse = 0.6 + 0.4 * _scanController.value;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: (isDark ? 0.35 : 0.25) * pulse),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'AI Scan Active',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: isDark ? AppColors.darkBorder.withValues(alpha: 0.4) : AppColors.lightBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Clause 7.2 Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Clause 7.2 — Forfeiture',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: isDark ? 0.14 : 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: isDark ? 0.35 : 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Relevant Property Law',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Clause Body with subtle border
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightError.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.darkError : AppColors.lightError.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            '"In case of delay beyond 30 days, 100% of earnest deposit shall be forfeited without notice."',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.45,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightError,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // AI Assessment Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightElevatedSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder.withValues(alpha: 0.45) : AppColors.lightBorder,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (isDark)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.darkError,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.darkErrorText),
                                          const SizedBox(width: 4),
                                          Text(
                                            'High Legal Risk Detected',
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.darkErrorText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined, size: 14, color: AppColors.lightError),
                                        const SizedBox(width: 6),
                                        Text(
                                          'High Legal Risk Detected',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.lightError,
                                          ),
                                        ),
                                      ],
                                    ),
                                  Text(
                                    'Score: 84/100',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightError,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 0.68,
                                  minHeight: 6,
                                  backgroundColor: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: isDark ? 0.2 : 0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkError : AppColors.lightError),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Plain English: The builder can confiscate all your advance money even for minor payment delays.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
