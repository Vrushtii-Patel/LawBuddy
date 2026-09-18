import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../widgets/user_profile_button.dart';
import '../theme/app_theme.dart';

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
  String _selectedFilter = 'All'; // All, Pending, Completed

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
      if (mounted) {
        setState(() {
          _error = e.toString();
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
    });

    try {
      await ApiService.updateChecklistItem(widget.type, itemId, isCompleted);
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          item['isCompleted'] = !isCompleted;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('checklists.failedToDelete', {'error': e.toString()})),
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
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSubmitting = false);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(tr('checklists.failedToAdd', {'error': e.toString()})),
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
    );
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr('checklists.renameFailed', {'error': e.toString()})),
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
    );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('checklists.checklistDeletedSuccess')),
              backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true); // Pop back to list screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('checklists.failedToDelete', {'error': e.toString()})),
              backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
      if (_selectedFilter == 'Pending') return !isComp;
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
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
        tooltip: tr('checklists.addNewTask'),
        elevation: 0,
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
                        _buildProgressCard(tr, isDark, colorScheme, completedCount, totalCount, progressRatio),
                        const SizedBox(height: 20),

                        // Filters row
                        _buildFilterRow(tr, isDark, totalCount, pendingCount, completedCount),
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
                                  _selectedFilter == 'Completed' ? Icons.check_circle_outline_rounded : Icons.task_alt_rounded,
                                  size: 40,
                                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFilter == 'Completed'
                                      ? 'No completed tasks yet.'
                                      : (_selectedFilter == 'Pending'
                                          ? tr('checklists.allDone')
                                          : 'No tasks found in this checklist.'),
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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isComp
                                      ? (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: isDark ? 0.4 : 0.3)
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  leading: Checkbox(
                                    value: isComp,
                                    activeColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    onChanged: (val) => _toggleItem(origIndex, val),
                                  ),
                                  title: Text(
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
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    hoverColor: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.1),
                                    tooltip: tr('checklists.deleteItem'),
                                    onPressed: () => _deleteItem(origIndex),
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
