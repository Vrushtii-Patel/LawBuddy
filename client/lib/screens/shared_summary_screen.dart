import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SharedSummaryScreen extends ConsumerStatefulWidget {
  final String shareToken;

  const SharedSummaryScreen({
    super.key,
    required this.shareToken,
  });

  @override
  ConsumerState<SharedSummaryScreen> createState() => _SharedSummaryScreenState();
}

class _SharedSummaryScreenState extends ConsumerState<SharedSummaryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _summaryData;
  String _selectedFilter = 'ALL'; // 'ALL', 'HIGH_RISK', 'CAUTION', 'COMPLIANT'

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getSharedSummary(widget.shareToken);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Summary not found or link has expired';
        });
      } else {
        setState(() {
          _isLoading = false;
          _summaryData = data;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load risk summary: $e';
      });
    }
  }

  Color _getRiskColor(String risk, bool isDark) {
    final lower = risk.toLowerCase();
    if (lower.contains('high') || lower.contains('red')) {
      return isDark ? AppColors.darkError : AppColors.lightError;
    }
    if (lower.contains('caution') || lower.contains('medium') || lower.contains('yellow')) {
      return isDark ? AppColors.darkCaution : AppColors.lightCaution;
    }
    return isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
  }

  Color _getRiskBackgroundColor(String risk, bool isDark) {
    return _getRiskColor(risk, isDark).withValues(alpha: isDark ? 0.15 : 0.08);
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tr = ref.read(localeProvider.notifier).translate;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.gavel_rounded,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              tr('common.appName'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Read-Only',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, isDark, tr),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, String Function(String, [Map<String, String>?]) tr) {
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
              tr('analysis.shareGenerating'),
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null || _summaryData == null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.link_off_rounded,
                  color: isDark ? AppColors.darkError : AppColors.lightError,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('analysis.sharedNotFound'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr('analysis.sharedNotFoundDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to home / root
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                icon: const Icon(Icons.home_outlined, size: 18),
                label: Text(tr('common.backToHome')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _summaryData!;
    final title = (data['title'] ?? 'Property Legal Risk Summary').toString();
    final overallRisk = (data['riskLevel'] ?? 'Low Risk').toString();
    final createdAt = data['createdAt'] as String?;
    final highCount = data['highRiskCount'] as int? ?? 0;
    final cautionCount = data['cautionCount'] as int? ?? 0;
    final compliantCount = data['compliantCount'] as int? ?? 0;
    final rawAnalysis = (data['analysis'] as List<dynamic>?) ?? [];

    // Filter clauses
    final filteredClauses = rawAnalysis.where((clause) {
      if (_selectedFilter == 'ALL') return true;
      final cRisk = (clause['riskLevel'] ?? '').toString().toUpperCase();
      final cCat = (clause['category'] ?? '').toString().toUpperCase();
      if (_selectedFilter == 'HIGH_RISK') {
        return cRisk == 'HIGH_RISK' || cCat == 'RED' || cCat == 'HIGH';
      }
      if (_selectedFilter == 'CAUTION') {
        return cRisk == 'CAUTION' || cCat == 'YELLOW' || cCat == 'CAUTION' || cCat == 'MEDIUM';
      }
      if (_selectedFilter == 'COMPLIANT') {
        return cRisk == 'COMPLIANT' || cCat == 'GREEN' || cCat == 'COMPLIANT' || cCat == 'LOW';
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Banner
              _buildHeaderCard(context, isDark, tr, title, overallRisk, createdAt, highCount, cautionCount, compliantCount, rawAnalysis.length),
              const SizedBox(height: 20),

              // Filter Tabs
              _buildFilterChips(isDark, tr, highCount, cautionCount, compliantCount, rawAnalysis.length),
              const SizedBox(height: 16),

              // Clause Analysis List
              if (filteredClauses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Center(
                    child: Text(
                      'No clauses found under this filter.',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredClauses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = filteredClauses[index] as Map<String, dynamic>;
                    return _buildClauseCard(context, isDark, tr, item, index + 1);
                  },
                ),

              const SizedBox(height: 28),

              // Security & Read-Only Disclaimer Card
              _buildSecurityFooter(context, isDark, tr),

              const SizedBox(height: 24),

              // CTA to Scan Own Document
              _buildScanCtaBanner(context, isDark, tr),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
    String title,
    String overallRisk,
    String? createdAt,
    int highCount,
    int cautionCount,
    int compliantCount,
    int totalCount,
  ) {
    final riskColor = _getRiskColor(overallRisk, isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 16,
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr('analysis.sharedReadOnly'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Analyzed on ${_formatDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _getRiskBackgroundColor(overallRisk, isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: riskColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      overallRisk.toLowerCase().contains('high')
                          ? Icons.warning_amber_rounded
                          : (overallRisk.toLowerCase().contains('caution') || overallRisk.toLowerCase().contains('medium')
                              ? Icons.info_outline
                              : Icons.check_circle_outline),
                      color: riskColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      overallRisk,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Metrics Row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildStatBadge('High Risk: $highCount', highCount > 0 ? (isDark ? AppColors.darkError : AppColors.lightError) : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), isDark),
              _buildStatBadge('Caution: $cautionCount', cautionCount > 0 ? (isDark ? AppColors.darkCaution : AppColors.lightCaution) : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), isDark),
              _buildStatBadge('Compliant: $compliantCount', isDark ? AppColors.darkSecondary : AppColors.lightSecondary, isDark),
              _buildStatBadge('Total Clauses: $totalCount', isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
    int highCount,
    int cautionCount,
    int compliantCount,
    int totalCount,
  ) {
    final filters = [
      {'key': 'ALL', 'label': 'All Clauses ($totalCount)'},
      {'key': 'HIGH_RISK', 'label': 'High Risk ($highCount)'},
      {'key': 'CAUTION', 'label': 'Caution ($cautionCount)'},
      {'key': 'COMPLIANT', 'label': 'Compliant ($compliantCount)'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f['key']!);
              },
              selectedColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClauseCard(
    BuildContext context,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
    Map<String, dynamic> item,
    int index,
  ) {
    final rawRisk = (item['riskLevel'] ?? item['category'] ?? 'COMPLIANT').toString();
    final riskColor = _getRiskColor(rawRisk, isDark);
    final title = (item['title'] ?? '').toString();
    final text = (item['text'] ?? '').toString();
    final reason = (item['reason'] ?? item['legalFinding'] ?? '').toString();
    final findingCategory = (item['findingCategory'] ?? '').toString();
    final buyerImpact = (item['buyerImpact'] ?? '').toString();
    final recommendation = (item['recommendation'] ?? '').toString();
    final statutoryCitations = (item['statutoryCitations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final reraReferences = (item['reraReferences'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: riskColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Risk badge & Title header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRiskBackgroundColor(rawRisk, isDark),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  rawRisk.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ),
              if (findingCategory.isNotEmpty && findingCategory != 'No material issue identified') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      findingCategory,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],

          // Clause Text Excerpt
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkBackground : AppColors.lightBackground).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.6)),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],

          // Plain-English Legal Reason
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: riskColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Citations / RERA references
          if (statutoryCitations.isNotEmpty || reraReferences.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...statutoryCitations.map((cit) => _buildCitationChip(cit, Icons.menu_book_outlined, isDark)),
                ...reraReferences.map((ref) => _buildCitationChip(ref, Icons.balance_outlined, isDark)),
              ],
            ),
          ],

          // Buyer Impact
          if (buyerImpact.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buyer Impact: $buyerImpact',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Recommendation
          if (recommendation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 15,
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recommendation: $recommendation',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitationChip(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter(
    BuildContext context,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 20,
            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('analysis.sharedDisclaimer'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCtaBanner(
    BuildContext context,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkSurfaceElevated, AppColors.darkSurface]
              : [AppColors.lightSurfaceElevated, AppColors.lightSurface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Want to scan your own real estate agreement?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get comprehensive AI risk assessments, RERA checks, and plain-English guidance.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              tr('analysis.scanYourOwnCta'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
