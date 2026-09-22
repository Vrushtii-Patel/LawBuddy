import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import 'home_widgets.dart';

class HomeMetricsRow extends ConsumerWidget {
  final List<RecentDocItem> recentDocs;
  final List<dynamic> checklists;
  final bool isDark;
  final bool isDesktop;

  const HomeMetricsRow({
    super.key,
    required this.recentDocs,
    required this.checklists,
    required this.isDark,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final int analyzedDocsCount = recentDocs
        .where((d) => d.analysisStatus == 'completed' || d.analysis.isNotEmpty)
        .length;

    int highRiskFlags = 0;
    for (final doc in recentDocs) {
      if (doc.analysis.isNotEmpty) {
        for (final item in doc.analysis) {
          if (item is Map) {
            final rLevel = (item['riskLevel'] ?? item['category'] ?? '').toString().toLowerCase();
            if (rLevel.contains('high') || rLevel.contains('red')) {
              highRiskFlags++;
            }
          }
        }
      } else if (doc.riskLabel.toLowerCase().contains('high')) {
        highRiskFlags++;
      }
    }

    final int checklistCount = checklists.length;

    int totalTasks = 0;
    int completedTasks = 0;
    for (final cl in checklists) {
      final items = (cl['items'] as List<dynamic>?) ?? [];
      totalTasks += items.length;
      completedTasks += items.where((it) => it['isCompleted'] == true).length;
    }
    final double checklistProgress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    final cards = [
      WorkspaceMetricData(
        icon: Icons.description_outlined,
        title: loc.translate('home.totalScannedDocs'),
        value: analyzedDocsCount.toString(),
        subtitle: loc.translate('home.totalScannedDocsSub'),
        accentColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      ),
      WorkspaceMetricData(
        icon: highRiskFlags > 0 ? Icons.warning_amber_rounded : Icons.shield_outlined,
        title: loc.translate('home.highRiskCount'),
        value: highRiskFlags.toString(),
        subtitle: highRiskFlags > 0
            ? '$highRiskFlags ${loc.translate('home.highRiskCountSub')}'
            : loc.translate('home.noHighRisks'),
        accentColor: highRiskFlags > 0
            ? (isDark ? AppColors.darkError : AppColors.lightError)
            : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
      ),
      WorkspaceMetricData(
        icon: Icons.checklist_rounded,
        title: loc.translate('home.dueDiligenceProgress'),
        value: '${(checklistProgress * 100).toInt()}%',
        subtitle: totalTasks > 0 ? '$completedTasks of $totalTasks tasks done' : loc.translate('home.checklistZeroTasks'),
        accentColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
      ),
      WorkspaceMetricData(
        icon: Icons.assignment_outlined,
        title: loc.translate('home.activeChecklists'),
        value: checklistCount.toString(),
        subtitle: checklistCount == 0
            ? loc.translate('home.activeChecklistsZero')
            : loc.translate('home.activeChecklistsBadge', {
                'count': checklistCount.toString(),
                'unit': loc.translate(checklistCount == 1 ? 'home.checklistUnitSingular' : 'home.checklistUnitPlural'),
              }),
        accentColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: WorkspaceMetricCard(data: cards[i], isDark: isDark)),
              ],
            ],
          );
        } else if (constraints.maxWidth >= 520) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: WorkspaceMetricCard(data: cards[0], isDark: isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: WorkspaceMetricCard(data: cards[1], isDark: isDark)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: WorkspaceMetricCard(data: cards[2], isDark: isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: WorkspaceMetricCard(data: cards[3], isDark: isDark)),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WorkspaceMetricCard(data: c, isDark: isDark),
                    ))
                .toList(),
          );
        }
      },
    );
  }
}
