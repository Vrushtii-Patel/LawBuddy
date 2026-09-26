import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_model.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  AdminAnalyticsData? _data;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isForbidden = false;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isForbidden = false;
    });

    try {
      final data = await ApiService.fetchAdminAnalytics();
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin analytics: $e');
      if (mounted) {
        final errStr = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isLoading = false;
          _errorMessage = errStr;
          _isForbidden = errStr.toLowerCase().contains('access denied') ||
              errStr.toLowerCase().contains('403') ||
              errStr.toLowerCase().contains('admin privileges required');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkPrimary.withValues(alpha: 0.25)
                        : AppColors.lightPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    loc.translate('adminAnalytics.badge'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  loc.translate('adminAnalytics.title'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            Text(
              loc.translate('adminAnalytics.subtitle'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: loc.translate('adminAnalytics.refreshTooltip'),
            onPressed: _isLoading ? null : _loadAnalytics,
          ),
          const SizedBox(width: 4),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: UserProfileButton(),
          ),
        ],
      ),
      body: _buildBody(isDark, loc),
    );
  }

  Widget _buildBody(bool isDark, LocaleNotifier loc) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              loc.translate('adminAnalytics.loading'),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_isForbidden) {
      return _buildUnauthorizedState(isDark, loc);
    }

    if (_errorMessage != null) {
      return _buildErrorState(isDark, loc);
    }

    if (_data == null) {
      return _buildEmptyState(isDark, loc);
    }

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiGrid(isDark, _data!.overview, loc),
                const SizedBox(height: 24),
                _buildRiskSection(isDark, _data!.riskDistribution, loc),
                const SizedBox(height: 24),
                _buildFindingCategoriesSection(isDark, _data!.findingCategories, loc),
                const SizedBox(height: 24),
                _buildPipelineInsightsSection(
                  isDark,
                  _data!.sourceDistribution,
                  _data!.extractionMethods,
                  loc,
                ),
                const SizedBox(height: 24),
                _buildRecentScansSection(isDark, _data!.recentScans, loc),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SECTION 1: KPI CARDS ---
  Widget _buildKpiGrid(bool isDark, OverviewKpi kpi, LocaleNotifier loc) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildKpiCard(
                    isDark: isDark,
                    title: loc.translate('adminAnalytics.kpiTotalUsers'),
                    value: kpi.totalUsers.toString(),
                    icon: Icons.people_alt_rounded,
                    accentColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    subtitle: loc.translate('adminAnalytics.kpiTotalUsersSub'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildKpiCard(
                    isDark: isDark,
                    title: loc.translate('adminAnalytics.kpiDocsAnalyzed'),
                    value: kpi.totalDocumentsAnalyzed.toString(),
                    icon: Icons.description_rounded,
                    accentColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    subtitle: loc.translate('adminAnalytics.kpiDocsAnalyzedSub'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildKpiCard(
                    isDark: isDark,
                    title: loc.translate('adminAnalytics.kpiClausesEvaluated'),
                    value: kpi.totalClausesEvaluated.toString(),
                    icon: Icons.gavel_rounded,
                    accentColor: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                    subtitle: loc.translate('adminAnalytics.kpiClausesEvaluatedSub'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildKpiCard(
                    isDark: isDark,
                    title: loc.translate('adminAnalytics.kpiAvgPages'),
                    value: kpi.averagePagesPerDoc.toStringAsFixed(1),
                    icon: Icons.auto_stories_rounded,
                    accentColor: const Color(0xFF6A8EAE),
                    subtitle: loc.translate('adminAnalytics.kpiAvgPagesSub'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Secondary system activity strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.translate('adminAnalytics.supportingActivity'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildMiniBadge(
                    isDark: isDark,
                    label: loc.translate('adminAnalytics.badgeChatSessions'),
                    count: kpi.totalChatSessions,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniBadge(
                    isDark: isDark,
                    label: loc.translate('adminAnalytics.badgeDiligenceChecklists'),
                    count: kpi.totalChecklists,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.8) : AppColors.lightTextSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge({required bool isDark, required String label, required int count}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  // --- SECTION 2: RISK SECTION (DOCUMENT VS CLAUSE LEVEL) ---
  Widget _buildRiskSection(bool isDark, RiskDistribution risk, LocaleNotifier loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isDark: isDark,
          title: loc.translate('adminAnalytics.riskSectionTitle'),
          subtitle: loc.translate('adminAnalytics.riskSectionSubtitle'),
          icon: Icons.shield_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDocumentRiskCard(isDark, risk.documentLevel, loc),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildClauseRiskCard(isDark, risk.clauseLevel, loc),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildDocumentRiskCard(isDark, risk.documentLevel, loc),
                  const SizedBox(height: 16),
                  _buildClauseRiskCard(isDark, risk.clauseLevel, loc),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildDocumentRiskCard(bool isDark, DocumentRiskDistribution docRisk, LocaleNotifier loc) {
    final total = docRisk.total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_shared_outlined, size: 18, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              const SizedBox(width: 8),
              Text(
                loc.translate('adminAnalytics.docRiskTitle'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                loc.translate('adminAnalytics.docRiskTotal', {'count': total.toString()}),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMultiProgressBar(
            isDark: isDark,
            high: docRisk.highRisk,
            medium: docRisk.mediumRisk,
            low: docRisk.lowRisk,
            total: total,
          ),
          const SizedBox(height: 16),
          _buildRiskStatRow(
            isDark: isDark,
            label: loc.translate('adminAnalytics.docRiskHigh'),
            count: docRisk.highRisk,
            total: total,
            color: AppColors.highRisk(isDark),
          ),
          const SizedBox(height: 8),
          _buildRiskStatRow(
            isDark: isDark,
            label: loc.translate('adminAnalytics.docRiskMed'),
            count: docRisk.mediumRisk,
            total: total,
            color: AppColors.caution(isDark),
          ),
          const SizedBox(height: 8),
          _buildRiskStatRow(
            isDark: isDark,
            label: loc.translate('adminAnalytics.docRiskLow'),
            count: docRisk.lowRisk,
            total: total,
            color: AppColors.compliant(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildClauseRiskCard(bool isDark, ClauseRiskDistribution clauseRisk, LocaleNotifier loc) {
    final total = clauseRisk.total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule_rounded, size: 18, color: isDark ? AppColors.darkCaution : AppColors.lightCaution),
              const SizedBox(width: 8),
              Text(
                loc.translate('adminAnalytics.clauseRiskTitle'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                loc.translate('adminAnalytics.clauseRiskTotal', {'count': total.toString()}),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMultiProgressBar(
            isDark: isDark,
            high: clauseRisk.highRisk,
            medium: clauseRisk.caution,
            low: clauseRisk.compliant,
            total: total,
          ),
          const SizedBox(height: 16),
          _buildRiskStatRow(
            isDark: isDark,
            label: loc.translate('adminAnalytics.clauseRiskHigh'),
            count: clauseRisk.highRisk,
            total: total,
            color: AppColors.highRisk(isDark),
          ),
          const SizedBox(height: 8),
          _buildRiskStatRow(
            isDark: isDark,
            label: loc.translate('adminAnalytics.clauseRiskCaution'),
            count: clauseRisk.caution,
            total: total,
            color: AppColors.caution(isDark),
          ),
          const SizedBox(height: 8),
          _buildRiskStatRow(
            isDark: isDark,
            label: loc.translate('adminAnalytics.clauseRiskCompliant'),
            count: clauseRisk.compliant,
            total: total,
            color: AppColors.compliant(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiProgressBar({
    required bool isDark,
    required int high,
    required int medium,
    required int low,
    required int total,
  }) {
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final double highFlex = high.toDouble();
    final double medFlex = medium.toDouble();
    final double lowFlex = low.toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (high > 0)
              Expanded(
                flex: (highFlex * 100).toInt(),
                child: Container(color: AppColors.highRisk(isDark)),
              ),
            if (medium > 0)
              Expanded(
                flex: (medFlex * 100).toInt(),
                child: Container(color: AppColors.caution(isDark)),
              ),
            if (low > 0)
              Expanded(
                flex: (lowFlex * 100).toInt(),
                child: Container(color: AppColors.compliant(isDark)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskStatRow({
    required bool isDark,
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final double percentage = total > 0 ? (count / total) * 100 : 0.0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          child: Text(
            '(${percentage.toStringAsFixed(0)}%)',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // --- SECTION 3: CLAUSE FINDING CATEGORIES ---
  Widget _buildFindingCategoriesSection(bool isDark, List<FindingCategoryStat> categories, LocaleNotifier loc) {
    final total = categories.fold<int>(0, (sum, item) => sum + item.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isDark: isDark,
          title: loc.translate('adminAnalytics.issueCategoriesTitle'),
          subtitle: loc.translate('adminAnalytics.issueCategoriesSubtitle'),
          icon: Icons.category_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: categories.isEmpty
              ? _buildEmptyCategoryNotice(isDark, loc)
              : Column(
                  children: categories.map((cat) {
                    final double ratio = total > 0 ? (cat.count / total) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  cat.category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                loc.translate('adminAnalytics.issueCategoryCount', {
                                  'count': cat.count.toString(),
                                  'percent': (ratio * 100).toStringAsFixed(1),
                                }),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getCategoryColor(cat.category, isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category, bool isDark) {
    final lower = category.toLowerCase();
    if (lower.contains('statutory') || lower.contains('violation')) {
      return AppColors.highRisk(isDark);
    } else if (lower.contains('contractual') || lower.contains('title') || lower.contains('concern')) {
      return AppColors.caution(isDark);
    } else if (lower.contains('no material') || lower.contains('compliant')) {
      return AppColors.compliant(isDark);
    }
    return isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
  }

  Widget _buildEmptyCategoryNotice(bool isDark, LocaleNotifier loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          loc.translate('adminAnalytics.noCategories'),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  // --- SECTION 4: PIPELINE INSIGHTS (SOURCES & EXTRACTION) ---
  Widget _buildPipelineInsightsSection(
    bool isDark,
    List<SourceTypeStat> sources,
    List<ExtractionMethodStat> methods,
    LocaleNotifier loc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isDark: isDark,
          title: loc.translate('adminAnalytics.pipelineTitle'),
          subtitle: loc.translate('adminAnalytics.pipelineSubtitle'),
          icon: Icons.memory_rounded,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSourceTypesCard(isDark, sources, loc),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildExtractionMethodsCard(isDark, methods, loc),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildSourceTypesCard(isDark, sources, loc),
                  const SizedBox(height: 16),
                  _buildExtractionMethodsCard(isDark, methods, loc),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSourceTypesCard(bool isDark, List<SourceTypeStat> sources, LocaleNotifier loc) {
    final total = sources.fold<int>(0, (sum, item) => sum + item.count);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.file_present_rounded, size: 18, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              const SizedBox(width: 8),
              Text(
                loc.translate('adminAnalytics.sourceTypesTitle'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (sources.isEmpty)
            _buildEmptyCategoryNotice(isDark, loc)
          else
            ...sources.map((s) {
              final double ratio = total > 0 ? (s.count / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      _getSourceIcon(s.sourceType),
                      size: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.sourceType,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${s.count}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '(${(ratio * 100).toStringAsFixed(0)}%)',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _getSourceIcon(String sourceType) {
    final lower = sourceType.toLowerCase();
    if (lower.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.contains('photo') || lower.contains('scan') || lower.contains('image')) {
      return Icons.camera_alt_rounded;
    }
    return Icons.text_snippet_rounded;
  }

  Widget _buildExtractionMethodsCard(bool isDark, List<ExtractionMethodStat> methods, LocaleNotifier loc) {
    final total = methods.fold<int>(0, (sum, item) => sum + item.count);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, size: 18, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
              const SizedBox(width: 8),
              Text(
                loc.translate('adminAnalytics.extractionMethodsTitle'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (methods.isEmpty)
            _buildEmptyCategoryNotice(isDark, loc)
          else
            ...methods.map((m) {
              final double ratio = total > 0 ? (m.count / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_suggest_rounded,
                      size: 16,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.displayLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${m.count}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '(${(ratio * 100).toStringAsFixed(0)}%)',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- SECTION 5: RECENT ANALYSIS ACTIVITY ---
  Widget _buildRecentScansSection(bool isDark, List<RecentScanSummary> recentScans, LocaleNotifier loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isDark: isDark,
          title: loc.translate('adminAnalytics.recentActivityTitle'),
          subtitle: loc.translate('adminAnalytics.recentActivitySubtitle'),
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: recentScans.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      loc.translate('adminAnalytics.noRecentActivity'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentScans.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder.withValues(alpha: 0.6) : AppColors.lightBorder.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final scan = recentScans[index];
                    return _buildRecentScanTile(isDark, scan, loc);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecentScanTile(bool isDark, RecentScanSummary scan, LocaleNotifier loc) {
    final riskColor = _getDocRiskColor(scan.riskLevel, isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.article_outlined,
              size: 20,
              color: riskColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildTagChip(
                      isDark: isDark,
                      label: '${scan.totalPages} ${loc.translate(scan.totalPages == 1 ? 'docView.page' : 'docView.pages')}',
                      icon: Icons.auto_stories_outlined,
                    ),
                    _buildTagChip(
                      isDark: isDark,
                      label: scan.sourceType,
                      icon: Icons.cloud_upload_outlined,
                    ),
                    _buildTagChip(
                      isDark: isDark,
                      label: scan.extractionMethodLabel,
                      icon: Icons.memory_outlined,
                    ),
                    _buildTagChip(
                      isDark: isDark,
                      label: _formatDate(scan.createdAt, loc),
                      icon: Icons.access_time_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: riskColor.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  scan.riskLevel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${scan.highRiskCount}H • ${scan.cautionCount}C • ${scan.compliantCount}OK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip({
    required bool isDark,
    required String label,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Color _getDocRiskColor(String riskLevel, bool isDark) {
    final lower = riskLevel.toLowerCase();
    if (lower.contains('high')) return AppColors.highRisk(isDark);
    if (lower.contains('medium') || lower.contains('caution')) return AppColors.caution(isDark);
    return AppColors.compliant(isDark);
  }

  String _formatDate(DateTime dt, LocaleNotifier loc) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return loc.translate('time.justNow');
    if (diff.inMinutes < 60) return loc.translate('time.minutesAgo', {'count': diff.inMinutes.toString()});
    if (diff.inHours < 24) return loc.translate('time.hoursAgo', {'count': diff.inHours.toString()});
    if (diff.inDays < 7) return loc.translate('time.daysAgo', {'count': diff.inDays.toString()});
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // --- SECTION HEADERS ---
  Widget _buildSectionHeader({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- EMPTY, ERROR, AND UNAUTHORIZED STATES ---
  Widget _buildUnauthorizedState(bool isDark, LocaleNotifier loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.highRisk(isDark).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_rounded,
                size: 48,
                color: AppColors.highRisk(isDark),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              loc.translate('adminAnalytics.unauthorizedTitle'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                loc.translate('adminAnalytics.unauthorizedDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(loc.translate('adminAnalytics.returnToWorkspace')),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor: isDark ? AppColors.darkErrorText : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark, LocaleNotifier loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.highRisk(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              loc.translate('adminAnalytics.errorTitle'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? loc.translate('adminAnalytics.defaultError'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(loc.translate('adminAnalytics.retryConnection')),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor: isDark ? AppColors.darkErrorText : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, LocaleNotifier loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_rounded,
              size: 48,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              loc.translate('adminAnalytics.emptyTitle'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.translate('adminAnalytics.emptyDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(loc.translate('adminAnalytics.refresh')),
            ),
          ],
        ),
      ),
    );
  }
}
