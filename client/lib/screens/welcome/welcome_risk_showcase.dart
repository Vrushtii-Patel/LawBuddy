import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class RiskSystemShowcase extends StatefulWidget {
  final bool isDark;
  final bool isDesktop;

  const RiskSystemShowcase({
    super.key,
    required this.isDark,
    required this.isDesktop,
  });

  @override
  State<RiskSystemShowcase> createState() => _RiskSystemShowcaseState();
}

class _RiskSystemShowcaseState extends State<RiskSystemShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _scoreAnim = Tween<double>(begin: 0.0, end: 72.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isDesktop = widget.isDesktop;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: _buildMockDocumentPanel(isDark)),
                const SizedBox(width: 24),
                Expanded(flex: 9, child: _buildRiskScorePanel(isDark)),
              ],
            )
          : Column(
              children: [
                _buildMockDocumentPanel(isDark),
                const SizedBox(height: 20),
                _buildRiskScorePanel(isDark),
              ],
            ),
    );
  }

  Widget _buildMockDocumentPanel(bool isDark) {
    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined, size: 16, color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'AGREEMENT FOR SALE (EXTRACT)',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: errorColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'POTENTIAL RISK DETECTED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: errorColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Clause 7.2 — Default & Forfeiture of Earnest Deposit',
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: errorColor.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: errorColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Text(
              '"In the event of any delay in milestone payment exceeding 15 days, the Promoter shall have the unilateral right to cancel the allotment and forfeit 100% of the Earnest Money Deposit and accrued interest without further notice."',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.5,
                color: errorColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: errorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Excessive forfeiture clause exceeds statutory 10% ceiling prescribed under Section 13(1) of RERA Model Rules.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskScorePanel(bool isDark) {
    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;
    final cautionColor = isDark ? AppColors.darkCaution : AppColors.lightCaution;
    final successColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'AI Legal Risk Assessment',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, _) {
                  final score = _scoreAnim.value.round();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: errorColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$score / 100 • Elevated',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: errorColor,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _scoreAnim,
            builder: (context, _) {
              final progress = (_scoreAnim.value / 100.0).clamp(0.0, 1.0);
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: errorColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(errorColor),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildRiskItemRow('🔴 High Risk', 'Clause 7.2: Unilateral earnest forfeiture (100%)', errorColor, isDark),
          const SizedBox(height: 8),
          _buildRiskItemRow('🟡 Caution', 'Clause 14.1: Asymmetric delay penalty compensation', cautionColor, isDark),
          const SizedBox(height: 8),
          _buildRiskItemRow('🟢 Standard', 'Clause 3.1: Carpet area specification & RERA warranty', successColor, isDark),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: isDark ? 0.3 : 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 16, color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recommendation: Demand amendment to restrict forfeiture to max 10% of total consideration as per standard MahaRERA guidelines.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskItemRow(String tag, String text, Color color, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            tag,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.35,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class WelcomeRiskSystemSection extends StatelessWidget {
  final bool isDark;
  final bool isDesktop;
  final bool isTablet;

  const WelcomeRiskSystemSection({
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
                'AI-POWERED AUDIT PREVIEW',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'See What LawBuddy Finds',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: isDesktop ? 30 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Our RERA-trained engine inspects agreement clauses line-by-line to flag unfair conditions, non-compliant timelines, and asymmetric liabilities.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 36),

              // Interactive Live Simulation Showcase
              RiskSystemShowcase(isDark: isDark, isDesktop: isDesktop),
            ],
          ),
        ),
      ),
    );
  }
}
