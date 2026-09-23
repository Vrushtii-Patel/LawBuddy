import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class WelcomeCtaBanner extends StatelessWidget {
  final bool isDark;
  final bool isDesktop;
  final VoidCallback onExploreFeatures;
  final VoidCallback onAnalyzeDoc;

  const WelcomeCtaBanner({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.onExploreFeatures,
    required this.onAnalyzeDoc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 48 : 24,
              vertical: isDesktop ? 42 : 30,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : AppColors.lightTextPrimary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Before You Sign,\nKnow What You\'re Signing.',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Upload your property document and let LawBuddy help you understand the clauses, risks, and important legal considerations.',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                height: 1.45,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: onExploreFeatures,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                width: 1.2,
                              ),
                              foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Explore Features',
                              style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: onAnalyzeDoc,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightTextPrimary,
                              foregroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: Text(
                              'Analyze Your Document →',
                              style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Before You Sign,\nKnow What You\'re Signing.',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.2,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload your property document and let LawBuddy help you understand the clauses, risks, and important legal considerations.',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          height: 1.45,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: onAnalyzeDoc,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightTextPrimary,
                          foregroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Analyze Your Document →',
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: onExploreFeatures,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 1.2,
                          ),
                          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Explore Features',
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
