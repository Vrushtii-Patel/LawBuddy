import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class StepCard extends StatefulWidget {
  final String number;
  final String title;
  final String description;
  final bool isDark;

  const StepCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
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
        transform: Matrix4.translationValues(0, _isHovered ? -5 : 0, 0),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 165),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.number,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeHowItWorksSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'SIMPLE 4-STEP PROCESS',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How It Works',
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 30 : 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 36),

              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: StepCard(number: '01', title: 'Upload Agreement', description: 'Upload your property agreement, sale deed, or rental contract.', isDark: isDark)),
                        _buildStepArrow(isDark),
                        Expanded(child: StepCard(number: '02', title: 'AI Contract Scan', description: 'AI examines the text and evaluates statutory RERA compliance.', isDark: isDark)),
                        _buildStepArrow(isDark),
                        Expanded(child: StepCard(number: '03', title: 'Plain-English Insights', description: 'Get plain-English explanations and flagged risk highlights.', isDark: isDark)),
                        _buildStepArrow(isDark),
                        Expanded(child: StepCard(number: '04', title: 'Legal Audit Report', description: 'Generate and download a structured legal risk assessment PDF.', isDark: isDark)),
                      ],
                    )
                  : Column(
                      children: [
                        StepCard(number: '01', title: 'Upload Agreement', description: 'Upload your property agreement, sale deed, or rental contract.', isDark: isDark),
                        const SizedBox(height: 14),
                        StepCard(number: '02', title: 'AI Contract Scan', description: 'AI examines the text and evaluates statutory RERA compliance.', isDark: isDark),
                        const SizedBox(height: 14),
                        StepCard(number: '03', title: 'Plain-English Insights', description: 'Get plain-English explanations and flagged risk highlights.', isDark: isDark),
                        const SizedBox(height: 14),
                        StepCard(number: '04', title: 'Legal Audit Report', description: 'Generate and download a structured legal risk assessment PDF.', isDark: isDark),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepArrow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 56),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      ),
    );
  }
}
