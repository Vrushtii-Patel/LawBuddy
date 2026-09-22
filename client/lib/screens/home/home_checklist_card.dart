import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../checklists_list_screen.dart';

class HomeChecklistCard extends ConsumerWidget {
  final List<dynamic> checklists;
  final bool isDark;
  final Function(Widget) onNavigate;

  const HomeChecklistCard({
    super.key,
    required this.checklists,
    required this.isDark,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    int totalTasks = 0;
    int completedTasks = 0;
    String activeTitle = loc.translate('home.defaultChecklistTitle');
    List<dynamic> pendingItems = [];

    for (final cl in checklists) {
      if (cl['title'] != null && cl['title'].toString().isNotEmpty) {
        activeTitle = cl['title'].toString();
      }
      final items = (cl['items'] as List<dynamic>?) ?? [];
      totalTasks += items.length;
      for (final it in items) {
        if (it['isCompleted'] == true) {
          completedTasks++;
        } else if (pendingItems.length < 3) {
          pendingItems.add(it);
        }
      }
    }
    final double checklistProgress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.checklist_rounded, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('home.dueDiligenceSection'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            activeTitle,
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
              ),
              const SizedBox(width: 8),
              Text(
                '${(checklistProgress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              width: double.infinity,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: checklistProgress > 0 ? checklistProgress : 0.0,
                child: Container(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Sample Upcoming Tasks
          if (pendingItems.isNotEmpty) ...[
            for (final it in pendingItems)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked_rounded,
                      size: 15,
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (it['task'] ?? it['title'] ?? loc.translate('home.defaultTaskTitle')).toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Text(
              totalTasks > 0 ? loc.translate('home.allTasksDone') : loc.translate('home.noActiveChecklists'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Action Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onNavigate(const ChecklistsListScreen()),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: Text(
                loc.translate('home.openChecklist'),
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
