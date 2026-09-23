import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';

class ComparisonResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> comparisonData;

  const ComparisonResultScreen({super.key, required this.comparisonData});

  @override
  ConsumerState<ComparisonResultScreen> createState() => _ComparisonResultScreenState();
}

class _ComparisonResultScreenState extends ConsumerState<ComparisonResultScreen> {
  String _selectedFilter = 'All'; // All, Modified, Added, Removed, Escalated, Unchanged

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comp = widget.comparisonData;
    final titleA = comp['titleA'] ?? 'Version A';
    final titleB = comp['titleB'] ?? 'Version B';
    final List<dynamic> allPairs = (comp['clauseComparisons'] as List<dynamic>?) ?? [];

    final filteredPairs = allPairs.where((pair) {
      final status = (pair['changeStatus'] ?? '').toString().toUpperCase();
      final migration = (pair['riskMigration'] ?? '').toString().toUpperCase();
      if (_selectedFilter == 'Modified') return status == 'MODIFIED' || status == 'SPLIT' || status == 'MERGED';
      if (_selectedFilter == 'Added') return status == 'ADDED';
      if (_selectedFilter == 'Removed') return status == 'REMOVED';
      if (_selectedFilter == 'Unchanged') return status == 'UNCHANGED';
      if (_selectedFilter == 'Escalated') return migration == 'ESCALATED_RISK' || migration == 'NEW_RISK_ADDED';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Comparison Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: const [
          UserProfileButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(titleA, titleB, comp, isDark),
              const SizedBox(height: 16),
              _buildSummaryMetrics(comp, isDark),
              const SizedBox(height: 20),
              _buildFilterChips(isDark),
              const SizedBox(height: 16),
              if (filteredPairs.isEmpty)
                _buildEmptyFilteredState(isDark)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredPairs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 14),
                  itemBuilder: (ctx, i) => _buildClausePairCard(filteredPairs[i], isDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String titleA, String titleB, Map<String, dynamic> comp, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Agreement Version Differential',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('VERSION A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const SizedBox(height: 4),
                      Text(titleA, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VERSION B',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(titleB, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if ((comp['overallSummary'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comp['overallSummary'],
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics(Map<String, dynamic> comp, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMetricBadge('Modified', comp['modifiedCount'] ?? 0, AppColors.caution(isDark)),
          const SizedBox(width: 8),
          _buildMetricBadge('Added', comp['addedCount'] ?? 0, AppColors.compliant(isDark)),
          const SizedBox(width: 8),
          _buildMetricBadge('Removed', comp['removedCount'] ?? 0, AppColors.highRisk(isDark)),
          const SizedBox(width: 8),
          _buildMetricBadge('Unchanged', comp['unchangedCount'] ?? 0, isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          const SizedBox(width: 8),
          _buildMetricBadge('Risk Escalations', comp['escalatedRiskCount'] ?? 0, AppColors.highRisk(isDark)),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, dynamic count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          Text('$count', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ['All', 'Modified', 'Added', 'Removed', 'Escalated', 'Unchanged'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              selectedColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedFilter = f);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClausePairCard(dynamic pair, bool isDark) {
    final status = (pair['changeStatus'] ?? '').toString();
    final confidence = (pair['matchConfidence'] ?? '').toString();
    final migration = (pair['riskMigration'] ?? '').toString();
    final titleA = pair['titleA'] ?? '';
    final titleB = pair['titleB'] ?? '';
    final textA = (pair['textA'] ?? '').toString();
    final textB = (pair['textB'] ?? '').toString();
    final diffs = (pair['materialChangesDetected'] as List<dynamic>?) ?? [];
    final impact = (pair['buyerImpact'] ?? '').toString();
    final considerations = (pair['buyerConsiderations'] ?? '').toString();
    final citations = (pair['statutoryCitations'] as List<dynamic>?) ?? [];

    Color statusColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    if (status == 'MODIFIED') {
      statusColor = AppColors.caution(isDark);
    } else if (status == 'ADDED') {
      statusColor = AppColors.compliant(isDark);
    } else if (status == 'REMOVED') {
      statusColor = AppColors.highRisk(isDark);
    } else if (status == 'UNCHANGED') {
      statusColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: migration == 'ESCALATED_RISK' || migration == 'NEW_RISK_ADDED'
              ? AppColors.highRisk(isDark).withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: migration == 'ESCALATED_RISK' || migration == 'NEW_RISK_ADDED' ? 1.5 : 1.0,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: status == 'MODIFIED' || status == 'ADDED' || status == 'REMOVED',
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildTag(status, statusColor),
                if (confidence.isNotEmpty && confidence != 'EXACT' && confidence != 'NONE')
                  _buildTag('Match: $confidence', Colors.blueGrey),
                if (migration.isNotEmpty && migration != 'UNCHANGED_RISK')
                  _buildTag(migration.replaceAll('_', ' '), Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titleB.isNotEmpty ? titleB : (titleA.isNotEmpty ? titleA : 'Clause Modification'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                // Material Changes / Diffs
                if (diffs.isNotEmpty) ...[
                  Text(
                    'Detected Material Differences:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...diffs.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '• [${d['category']}]: ${d['changeDescription']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  )),
                  const SizedBox(height: 10),
                ],

                // Side-by-side or stacked text comparison
                if (textA.isNotEmpty && textB.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextSnippet(isDark, 'Version A', textA, Colors.blueAccent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextSnippet(isDark, 'Version B', textB, Colors.tealAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else if (textA.isNotEmpty) ...[
                  _buildTextSnippet(isDark, 'Removed Clause (From Version A)', textA, Colors.redAccent),
                  const SizedBox(height: 12),
                ] else if (textB.isNotEmpty) ...[
                  _buildTextSnippet(isDark, 'Added Clause (In Version B)', textB, Colors.greenAccent),
                  const SizedBox(height: 12),
                ],

                // Buyer Impact
                if (impact.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'Buyer Impact',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          impact,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            height: 1.35,
                          ),
                        ),
                        if (considerations.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Consideration: $considerations',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Grounded Citations
                if (citations.isNotEmpty) ...[
                  Text(
                    'Authoritative Statutory Citations:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...citations.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.gavel, size: 14, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${c['actName']} — ${c['sectionOrRule']} (${c['provisionTitle'] ?? ''})',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSnippet(bool isDark, String label, String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildEmptyFilteredState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: Colors.greenAccent),
            const SizedBox(height: 12),
            Text(
              'No clauses matching "$_selectedFilter"',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
