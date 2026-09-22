import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_widgets.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class HomeRiskBreakdownCard extends ConsumerWidget {
  final List<RecentDocItem> recentDocs;
  final bool isDark;

  const HomeRiskBreakdownCard({
    super.key,
    required this.recentDocs,
    required this.isDark,
  });

  Widget _buildRiskLegendItem({
    required Color color,
    required String label,
    required int count,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final int total = recentDocs.length;
    final int highRisk = recentDocs.where((d) => (d.riskLabel).toLowerCase().contains('high')).length;
    final int mediumRisk = recentDocs.where((d) => (d.riskLabel).toLowerCase().contains('medium') || (d.riskLabel).toLowerCase().contains('caution')).length;
    final int lowRisk = total - highRisk - mediumRisk > 0 ? (total - highRisk - mediumRisk) : 0;

    final double highPct = total > 0 ? (highRisk / total) : 0.0;
    final double medPct = total > 0 ? (mediumRisk / total) : 0.0;
    final double lowPct = total > 0 ? (lowRisk / total) : (total == 0 ? 1.0 : 0.0);

    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;
    final cautionColor = isDark ? AppColors.darkCaution : AppColors.lightCaution;
    final successColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pie_chart_outline_rounded, color: errorColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('home.riskDistribution'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      loc.translate('home.riskDistributionSub'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Multi-Segment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              width: double.infinity,
              child: Row(
                children: [
                  if (highPct > 0)
                    Flexible(
                      flex: (highPct * 100).toInt(),
                      child: Container(color: errorColor),
                    ),
                  if (medPct > 0)
                    Flexible(
                      flex: (medPct * 100).toInt(),
                      child: Container(color: cautionColor),
                    ),
                  if (lowPct > 0)
                    Flexible(
                      flex: (lowPct * 100).toInt(),
                      child: Container(color: successColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _buildRiskLegendItem(
                color: errorColor,
                label: loc.translate('home.highRiskLabel'),
                count: highRisk,
                isDark: isDark,
              ),
              _buildRiskLegendItem(
                color: cautionColor,
                label: loc.translate('home.mediumRiskLabel'),
                count: mediumRisk,
                isDark: isDark,
              ),
              _buildRiskLegendItem(
                color: successColor,
                label: loc.translate('home.lowRiskLabel'),
                count: total > 0 ? lowRisk : 0,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Analysis Summary Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: highRisk > 0
                  ? errorColor.withValues(alpha: isDark ? 0.12 : 0.08)
                  : successColor.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highRisk > 0
                    ? errorColor.withValues(alpha: 0.25)
                    : successColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  highRisk > 0 ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                  size: 15,
                  color: highRisk > 0 ? errorColor : successColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highRisk > 0
                        ? '$highRisk high-risk clauses flagged across analyzed documents'
                        : 'All analyzed documents within normal legal risk parameters',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
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
}
