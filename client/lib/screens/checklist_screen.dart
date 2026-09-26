import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../widgets/user_profile_button.dart';
import '../theme/app_theme.dart';
import 'bin_screen.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  final String type;
  final String? initialTitle;

  const ChecklistScreen({
    super.key,
    required this.type,
    this.initialTitle,
  });

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  Map<String, dynamic>? _checklistData;
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'All'; // All, Pending, Flagged, Completed

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    try {
      final data = await ApiService.fetchChecklist(widget.type);
      if (mounted) {
        setState(() {
          _checklistData = data;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching checklist details: $e');
      if (mounted) {
        setState(() {
          _error = 'Unable to load checklist details. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleItem(int index, bool? value) async {
    final bool isCompleted = value ?? false;
    final items = _checklistData?['items'] as List<dynamic>? ?? [];
    if (index < 0 || index >= items.length) return;

    final item = items[index];
    final String itemId = (item['id'] ?? item['_id'] ?? '').toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Optimistic UI update
    setState(() {
      item['isCompleted'] = isCompleted;
      if (isCompleted) {
        item['status'] = 'VERIFIED';
      } else {
        final linked = item['linkedIssues'] as List<dynamic>? ?? [];
        item['status'] = linked.isNotEmpty ? 'FLAGGED' : 'NOT_STARTED';
      }
    });

    try {
      await ApiService.updateChecklistItem(widget.type, itemId, isCompleted);
    } catch (e) {
      debugPrint('Error updating checklist item: $e');
      // Revert on failure
      if (mounted) {
        setState(() {
          item['isCompleted'] = !isCompleted;
          if (!isCompleted) {
            item['status'] = 'VERIFIED';
          } else {
            final linked = item['linkedIssues'] as List<dynamic>? ?? [];
            item['status'] = linked.isNotEmpty ? 'FLAGGED' : 'NOT_STARTED';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to update task. Please try again.'),
            backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(int index) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final items = _checklistData?['items'] as List<dynamic>? ?? [];
    if (index < 0 || index >= items.length) return;

    final item = items[index];
    final String itemId = (item['id'] ?? item['_id'] ?? '').toString();
    final itemTitle = (item['title'] ?? 'Task').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('checklists.deleteTaskTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Text(tr('checklists.deleteTaskConfirm', {'task': itemTitle})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('checklists.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('checklists.delete')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      try {
        await ApiService.deleteChecklistItem(widget.type, itemId);
        if (!mounted) return;
        setState(() {
          items.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('checklists.taskDeletedSuccess')),
            backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        debugPrint('Error deleting checklist item: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to delete task. Please try again.'),
              backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showAddItemDialog() {
    final titleController = TextEditingController();
    final tr = ref.read(localeProvider.notifier).translate;
    final messenger = ScaffoldMessenger.of(context);
    final isDarkOuter = Theme.of(context).brightness == Brightness.dark;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setDialogState) {
            final isDark = Theme.of(builderCtx).brightness == Brightness.dark;
            final colorScheme = Theme.of(builderCtx).colorScheme;

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_task_rounded, color: AppColors.lightPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('checklists.addNewTask'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('checklists.taskDescription'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    maxLines: 2,
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: tr('checklists.taskHint'),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.lightPrimary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    tr('checklists.cancel'),
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightPrimary,
                    foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = titleController.text.trim();
                          if (text.isEmpty) return;

                          setDialogState(() => isSubmitting = true);

                          try {
                            final newItem = await ApiService.addChecklistItem(widget.type, text);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (mounted) {
                              setState(() {
                                final items = _checklistData?['items'] as List<dynamic>? ?? [];
                                items.add(newItem);
                              });
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(tr('checklists.taskAddedSuccess')),
                                  backgroundColor: isDarkOuter ? AppColors.darkSecondary : AppColors.lightSecondary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error adding checklist item: $e');
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text('Unable to add task. Please try again.'),
                                  backgroundColor: isDarkOuter ? AppColors.darkError : AppColors.lightError,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(tr('checklists.addTaskAction')),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => titleController.dispose());
  }

  void _showRenameDialog() {
    final tr = ref.read(localeProvider.notifier).translate;
    final currentTitle = _checklistData?['title'] ?? widget.initialTitle ?? '';
    final controller = TextEditingController(text: currentTitle);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('checklists.renameChecklistTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: tr('checklists.newTitleHint'),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('checklists.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightPrimary,
                foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
              ),
              onPressed: () async {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty && newTitle != currentTitle) {
                  try {
                    await ApiService.renameChecklist(widget.type, newTitle);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (mounted) {
                      setState(() {
                        if (_checklistData != null) {
                          _checklistData!['title'] = newTitle;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('checklists.renameSuccess')),
                          backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error renaming checklist: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Unable to rename checklist. Please try again.'),
                          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: Text(tr('checklists.saveAction')),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
  }

  void _confirmDeleteChecklist() async {
    final tr = ref.read(localeProvider.notifier).translate;
    final currentTitle = _checklistData?['title'] ?? widget.initialTitle ?? tr('checklists.untitledChecklist');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('checklists.deleteChecklistTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Text(tr('checklists.deleteChecklistConfirm', {'title': currentTitle})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('checklists.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('checklists.deleteAction')),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await ApiService.deleteChecklist(widget.type);
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          final controller = messenger.showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              showCloseIcon: true,
              closeIconColor: Colors.white,
              content: Text(tr('checklists.checklistDeletedSuccess')),
              backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View Bin',
                textColor: Colors.white,
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BinScreen()),
                  );
                },
              ),
            ),
          );

          Future.delayed(const Duration(seconds: 5), () {
            try {
              controller.close();
            } catch (_) {}
          });

          Navigator.pop(context, true); // Pop back to list screen
        }
      } catch (e) {
        debugPrint('Error deleting checklist: $e');
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          final controller = messenger.showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              showCloseIcon: true,
              closeIconColor: Colors.white,
              content: const Text('Unable to delete checklist. Please try again.'),
              backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Future.delayed(const Duration(seconds: 5), () {
            try {
              controller.close();
            } catch (_) {}
          });
        }
      }
    }
  }

  // ==========================================
  // CROSS-REFERENCED ISSUE DETAILS BOTTOM SHEET
  // ==========================================
  void _showRelatedIssuesSheet(BuildContext context, Map<String, dynamic> item, int origIndex) {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkedIssues = item['linkedIssues'] as List<dynamic>? ?? [];
    final itemTitle = (item['title'] ?? 'Due Diligence Task').toString();
    final isComp = item['isCompleted'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('checklists.relatedIssueModalTitle'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            itemTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 0.8,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),

              // Issues List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: linkedIssues.length,
                  itemBuilder: (ctx, idx) {
                    final issue = linkedIssues[idx] as Map<String, dynamic>;
                    final docTitle = (issue['documentTitle'] ?? 'Uploaded Agreement').toString();
                    final clauseTitle = (issue['clauseTitle'] ?? issue['clauseId'] ?? 'Detected Clause').toString();
                    final riskLevel = (issue['riskLevel'] ?? 'HIGH_RISK').toString();
                    final isHighRisk = riskLevel == 'HIGH_RISK';
                    final findingCategory = (issue['findingCategory'] ?? '').toString();
                    final reason = (issue['reason'] ?? '').toString();
                    final buyerImpact = (issue['buyerImpact'] ?? '').toString();
                    final recommendation = (issue['recommendation'] ?? '').toString();
                    final citations = (issue['statutoryCitations'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
                    final reraRefs = (issue['reraReferences'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

                    final riskColor = isHighRisk
                        ? (isDark ? AppColors.darkError : AppColors.lightError)
                        : (isDark ? AppColors.darkCaution : AppColors.lightCaution);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: riskColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Document & Risk Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: riskColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isHighRisk ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                                      size: 13,
                                      color: riskColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isHighRisk ? 'HIGH RISK' : 'CAUTION',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: riskColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  docTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Why Flagged Section
                          Text(
                            tr('checklists.whyFlaggedTitle'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('checklists.whyFlaggedDesc', {'doc': docTitle}),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Clause Finding
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.darkBackground : AppColors.lightBackground),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.article_outlined,
                                      size: 15,
                                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        clauseTitle,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (findingCategory.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    findingCategory,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                                    ),
                                  ),
                                ],
                                if (reason.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    reason,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      height: 1.45,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Statutory Citations & RERA References
                          if (citations.isNotEmpty || reraRefs.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              tr('checklists.statutoryCitationsTitle'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...citations.map((cit) => _buildCitationChip(cit, Icons.gavel_rounded, isDark)),
                                ...reraRefs.map((ref) => _buildCitationChip(ref, Icons.verified_user_rounded, isDark)),
                              ],
                            ),
                          ],

                          // Buyer Impact
                          if (buyerImpact.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              tr('checklists.buyerImpactTitle'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkError : AppColors.lightError,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              buyerImpact,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],

                          // Recommendation
                          if (recommendation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 16,
                                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tr('checklists.recommendationTitle'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          recommendation,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Action Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isComp
                          ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                          : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
                      foregroundColor: isComp
                          ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                          : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: Icon(
                      isComp ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isComp ? tr('checklists.markAsPending') : tr('checklists.markAsVerified'),
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _toggleItem(origIndex, !isComp);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCitationChip(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final rawTitle = _checklistData?['title'] ?? widget.initialTitle;
    final title = (rawTitle != null && rawTitle.toString().startsWith('checklists.'))
        ? tr(rawTitle.toString())
        : (rawTitle ?? tr('checklists.defaultTitle'));

    final items = _checklistData?['items'] as List<dynamic>? ?? [];

    // Filter items
    final filteredItems = items.asMap().entries.where((entry) {
      final item = entry.value;
      final isComp = item['isCompleted'] == true;
      final linked = item['linkedIssues'] as List<dynamic>? ?? [];
      final isFlagged = !isComp && (item['status'] == 'FLAGGED' || linked.isNotEmpty);

      if (_selectedFilter == 'Pending') return !isComp;
      if (_selectedFilter == 'Flagged') return isFlagged;
      if (_selectedFilter == 'Completed') return isComp;
      return true;
    }).map((entry) {
      final item = Map<String, dynamic>.from(entry.value);
      item['_originalIndex'] = entry.key;
      return item;
    }).toList();

    final totalCount = items.length;
    final completedCount = items.where((i) => i['isCompleted'] == true).length;
    final pendingCount = totalCount - completedCount;
    final flaggedCount = items.where((i) => i['isCompleted'] != true && (i['status'] == 'FLAGGED' || ((i['linkedIssues'] as List<dynamic>?)?.isNotEmpty == true))).length;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'rename') _showRenameDialog();
              if (val == 'delete') _confirmDeleteChecklist();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 18, color: AppColors.lightPrimary),
                    const SizedBox(width: 8),
                    Text(tr('checklists.renameChecklist'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: isDark ? AppColors.darkError : AppColors.lightError),
                    const SizedBox(width: 8),
                    Text(tr('checklists.deleteChecklist'), style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkError : AppColors.lightError)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const UserProfileButton(),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : AppColors.lightTextPrimary,
        tooltip: tr('checklists.addNewTask'),
        elevation: 2,
        child: const Icon(Icons.add_rounded, size: 24),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lightPrimary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: isDark ? AppColors.darkError : AppColors.lightError),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: isDark ? AppColors.darkError : AppColors.lightError)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChecklist,
                        child: Text(tr('checklists.retryAction')),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Progress Card
                        _buildProgressCard(tr, isDark, colorScheme, completedCount, totalCount, progressRatio, flaggedCount),
                        const SizedBox(height: 20),

                        // Filters row
                        _buildFilterRow(tr, isDark, totalCount, pendingCount, flaggedCount, completedCount),
                        const SizedBox(height: 16),

                        // Tasks list
                        if (filteredItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedFilter == 'Completed'
                                      ? Icons.check_circle_outline_rounded
                                      : (_selectedFilter == 'Flagged' ? Icons.verified_rounded : Icons.task_alt_rounded),
                                  size: 40,
                                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFilter == 'Completed'
                                      ? 'No completed tasks yet.'
                                      : (_selectedFilter == 'Flagged'
                                          ? 'No flagged document issues in this checklist.'
                                          : (_selectedFilter == 'Pending'
                                              ? tr('checklists.allDone')
                                              : 'No tasks found in this checklist.')),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...filteredItems.map((item) {
                            final origIndex = item['_originalIndex'] as int;
                            final isComp = item['isCompleted'] == true;
                            final itemTitle = (item['title'] ?? '').toString();
                            final linkedIssues = item['linkedIssues'] as List<dynamic>? ?? [];
                            final isFlagged = !isComp && (item['status'] == 'FLAGGED' || linkedIssues.isNotEmpty);

                            // Document names for attribution
                            final docNames = linkedIssues
                                .map((li) => (li['documentTitle'] ?? 'Document').toString())
                                .toSet()
                                .toList();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isFlagged
                                    ? (isDark ? AppColors.darkCaution.withValues(alpha: 0.07) : AppColors.lightCaution.withValues(alpha: 0.05))
                                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isComp
                                      ? (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: isDark ? 0.4 : 0.3)
                                      : (isFlagged
                                          ? (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.5)
                                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                                  width: isFlagged ? 1.2 : 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                clipBehavior: Clip.antiAlias,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Task Row: Checkbox, Title, Delete Action
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: isComp,
                                            activeColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            onChanged: (val) => _toggleItem(origIndex, val),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 10),
                                              child: Text(
                                                itemTitle,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isComp ? FontWeight.w500 : FontWeight.w600,
                                                  decoration: isComp ? TextDecoration.lineThrough : null,
                                                  color: isComp
                                                      ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                                                      : colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                            hoverColor: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.1),
                                            tooltip: tr('checklists.deleteItem'),
                                            onPressed: () => _deleteItem(origIndex),
                                          ),
                                        ],
                                      ),

                                      // Flagged Issue Attribution & View Related Issue Action
                                      if (linkedIssues.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          margin: const EdgeInsets.only(left: 44, right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.warning_amber_rounded,
                                                    size: 14,
                                                    color: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    tr('checklists.flaggedBadge'),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.5,
                                                      color: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                docNames.length == 1
                                                    ? tr('checklists.triggeredBy', {'doc': docNames.first})
                                                    : tr('checklists.triggeredByMulti', {'count': docNames.length.toString()}),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              InkWell(
                                                onTap: () => _showRelatedIssuesSheet(context, item, origIndex),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        linkedIssues.length == 1
                                                            ? '${tr('checklists.viewRelatedIssue')} →'
                                                            : '${tr('checklists.viewRelatedIssues', {'count': linkedIssues.length.toString()})} →',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProgressCard(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
    ColorScheme colorScheme,
    int completed,
    int total,
    double ratio,
    int flaggedCount,
  ) {
    final percent = (ratio * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.task_alt_rounded, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tr('checklists.progress'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (flaggedCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 12, color: isDark ? AppColors.darkCaution : AppColors.lightCaution),
                          const SizedBox(width: 4),
                          Text(
                            tr('checklists.flaggedCountBadge', {'count': flaggedCount.toString()}),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (percent == 100
                              ? (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
                              : AppColors.lightPrimary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: percent == 100
                            ? (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 100
                    ? (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
                    : AppColors.lightPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr('checklists.completedRatio', {'completed': completed.toString(), 'total': total.toString()}),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
    int total,
    int pending,
    int flagged,
    int completed,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('All', '${tr('checklists.filterAll')} ($total)', isDark),
          const SizedBox(width: 8),
          _buildChip('Pending', '${tr('checklists.filterPending')} ($pending)', isDark, color: isDark ? AppColors.darkCaution : AppColors.lightCaution),
          if (flagged > 0) ...[
            const SizedBox(width: 8),
            _buildChip('Flagged', '${tr('checklists.filterFlagged')} ($flagged)', isDark, color: isDark ? AppColors.darkError : AppColors.lightError),
          ],
          const SizedBox(width: 8),
          _buildChip('Completed', '${tr('checklists.filterCompleted')} ($completed)', isDark, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
        ],
      ),
    );
  }

  Widget _buildChip(String key, String label, bool isDark, {Color? color}) {
    final isSelected = _selectedFilter == key;
    final effectiveColor = color ?? AppColors.lightPrimary;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? effectiveColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? effectiveColor : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}