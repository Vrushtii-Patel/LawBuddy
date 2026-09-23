import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'scan_screen.dart';
import 'document_comparison_screen.dart';
import '../widgets/user_profile_button.dart';

class RecentDocumentsScreen extends ConsumerStatefulWidget {
  final List<dynamic>? initialDocs;

  const RecentDocumentsScreen({super.key, this.initialDocs});

  @override
  ConsumerState<RecentDocumentsScreen> createState() => _RecentDocumentsScreenState();
}

class _RecentDocumentsScreenState extends ConsumerState<RecentDocumentsScreen> {
  List<dynamic> _allDocs = [];
  bool _isLoading = true;
  String? _docsError;
  String _searchQuery = '';
  String _selectedCategory = 'All'; // All, High Risk, Caution, Compliant
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialDocs != null && widget.initialDocs!.isNotEmpty) {
      _allDocs = List.from(widget.initialDocs!);
      _isLoading = false;
    }
    _fetchDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchDocuments() async {
    try {
      if (_allDocs.isEmpty) {
        setState(() => _isLoading = true);
      }
      final docs = await ApiService.fetchRecentDocuments();
      if (mounted) {
        setState(() {
          _allDocs = docs;
          _isLoading = false;
          _docsError = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching recent documents: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Only surface an error state when we have nothing cached to show;
          // if we already have docs on screen, a background refresh failure
          // shouldn't replace them with an error card.
          if (_allDocs.isEmpty) {
            _docsError = 'Unable to load recent documents. Please check your connection and try again.';
          }
        });
      }
    }
  }

  List<dynamic> get _filteredDocs {
    return _allDocs.where((doc) {
      final title = (doc['title'] ?? '').toString().toLowerCase();
      final riskLevel = (doc['riskLevel'] ?? '').toString().toLowerCase();
      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch = query.isEmpty ||
          title.contains(query) ||
          riskLevel.contains(query);

      if (!matchesSearch) return false;

      if (_selectedCategory == 'High Risk') {
        return riskLevel.contains('high') || riskLevel.contains('red');
      } else if (_selectedCategory == 'Caution') {
        return riskLevel.contains('medium') || riskLevel.contains('yellow') || riskLevel.contains('caution');
      } else if (_selectedCategory == 'Compliant') {
        return riskLevel.contains('low') || riskLevel.contains('green') || riskLevel.contains('compliant');
      }

      return true;
    }).toList();
  }

  int get _redCount => _allDocs.where((d) {
        final r = (d['riskLevel'] ?? '').toString().toLowerCase();
        return r.contains('high') || r.contains('red');
      }).length;

  int get _yellowCount => _allDocs.where((d) {
        final r = (d['riskLevel'] ?? '').toString().toLowerCase();
        return r.contains('medium') || r.contains('yellow') || r.contains('caution');
      }).length;

  int get _greenCount => _allDocs.where((d) {
        final r = (d['riskLevel'] ?? '').toString().toLowerCase();
        return r.contains('low') || r.contains('green') || r.contains('compliant');
      }).length;

  String _formatRelativeTime(dynamic dateVal) {
    final tr = ref.read(localeProvider.notifier).translate;
    if (dateVal == null) return tr('recentDocs.recently');
    try {
      final date = DateTime.parse(dateVal.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return tr('recentDocs.justNow');
      if (diff.inMinutes < 60) return tr('recentDocs.mAgo', {'count': '${diff.inMinutes}'});
      if (diff.inHours < 24) return tr('recentDocs.hAgo', {'count': '${diff.inHours}'});
      if (diff.inDays < 7) return tr('recentDocs.dAgo', {'count': '${diff.inDays}'});
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return tr('recentDocs.recently');
    }
  }

  // --- ACTION 1 & 2: VIEW DOCUMENT & VIEW ANALYSIS ---
  void _openAnalysis(Map<String, dynamic> doc) {
    final title = (doc['title'] ?? 'Scanned Agreement').toString();
    final originalText = (doc['originalText'] ?? '').toString();
    final analysis = (doc['analysis'] as List<dynamic>?) ?? [];
    final sourceType = (doc['sourceType'] as String?) ?? 'PDF Document';
    final fileData = doc['fileData'] as String?;
    final mimeType = doc['mimeType'] as String?;
    final docId = doc['_id'] ?? doc['id'];

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AnalysisScreen(
          documentTitle: title,
          originalText: originalText,
          analysis: analysis,
          sourceType: sourceType,
          fileData: fileData,
          mimeType: mimeType,
          documentId: docId?.toString(),
          heroTag: docId != null ? 'doc-icon-$docId' : null,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // --- ACTION 3: DOWNLOAD RISK REPORT PDF ---
  Future<void> _downloadRiskReport(Map<String, dynamic> doc) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = (doc['title'] ?? 'Scanned Agreement').toString();
    final originalText = (doc['originalText'] ?? '').toString();
    final analysis = (doc['analysis'] as List<dynamic>?) ?? [];
    final sourceType = (doc['sourceType'] as String?) ?? 'PDF Document';
    final fileData = doc['fileData'] as String?;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('recentDocs.downloadingReport'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await PdfExportService.exportAnalysisPdf(
        documentTitle: title,
        originalText: originalText,
        analysis: analysis,
        sourceType: sourceType,
        fileData: fileData,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('recentDocs.reportDownloaded'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading risk report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to download PDF report. Please try again.'),
            backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- ACTION 4: RENAME DOCUMENT ---
  void _showRenameDialog(Map<String, dynamic> doc) {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTitle = (doc['title'] ?? '').toString();
    final controller = TextEditingController(text: currentTitle);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('recentDocs.renameTitle'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: tr('recentDocs.renameHint'),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (val) async {
                      if (val.trim().isNotEmpty && !isSaving) {
                        setDialogState(() => isSaving = true);
                        final docId = (doc['_id'] ?? doc['id']).toString();
                        final success = await ApiService.renameDocument(docId, val.trim());
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (mounted && success) {
                          setState(() {
                            doc['title'] = val.trim();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('recentDocs.renamedSuccess')),
                              backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    tr('recentDocs.cancel'),
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newTitle = controller.text.trim();
                          if (newTitle.isEmpty) return;
                          setDialogState(() => isSaving = true);
                          final docId = (doc['_id'] ?? doc['id']).toString();
                          final success = await ApiService.renameDocument(docId, newTitle);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted && success) {
                            setState(() {
                              doc['title'] = newTitle;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr('recentDocs.renamedSuccess')),
                                backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr('recentDocs.save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- ACTION 5: RE-ANALYZE DOCUMENT WITH AI ---
  Future<void> _reanalyzeDocument(Map<String, dynamic> doc) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = (doc['title'] ?? 'Scanned Agreement').toString();
    final originalText = (doc['originalText'] ?? '').toString();
    final sourceType = (doc['sourceType'] as String?) ?? 'PDF Document';
    final fileData = doc['fileData'] as String?;
    final mimeType = doc['mimeType'] as String?;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('recentDocs.reanalyzing'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final result = await ApiService.scanDocument(
        originalText,
        title: title,
        sourceType: sourceType,
        base64Data: fileData,
        mimeType: mimeType,
      );

      if (mounted && result.isNotEmpty) {
        setState(() {
          if (result['analysis'] != null) {
            doc['analysis'] = result['analysis'];
          }
          if (result['riskLevel'] != null) {
            doc['riskLevel'] = result['riskLevel'];
          }
          if (result['canonicalClauses'] != null) {
            doc['canonicalClauses'] = result['canonicalClauses'];
          }
          if (result['highRiskCount'] != null) {
            doc['highRiskCount'] = result['highRiskCount'];
          }
          if (result['cautionCount'] != null) {
            doc['cautionCount'] = result['cautionCount'];
          }
          if (result['compliantCount'] != null) {
            doc['compliantCount'] = result['compliantCount'];
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('recentDocs.reanalyzeSuccess'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error re-analyzing document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('recentDocs.reanalyzeFailed')}. Please try again.'),
            backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- ACTION 6: DELETE DOCUMENT ---
  void _confirmDelete(Map<String, dynamic> doc) {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = (doc['title'] ?? 'Document').toString();
    final docId = (doc['_id'] ?? doc['id']).toString();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_outline_rounded, color: isDark ? AppColors.darkError : AppColors.lightError, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                tr('recentDocs.delete'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            '${tr('recentDocs.deleteConfirm')}\n\n"$title"',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                tr('recentDocs.cancel'),
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final success = await ApiService.deleteDocument(docId);
                if (mounted && success) {
                  setState(() {
                    _allDocs.removeWhere((d) => (d['_id'] ?? d['id']).toString() == docId);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('recentDocs.deletedSuccess')),
                      backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(tr('recentDocs.delete')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayDocs = _filteredDocs;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          tr('recentDocs.title'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.compare_arrows_rounded,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            tooltip: 'Compare Agreements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DocumentComparisonScreen()),
              );
            },
          ),
          const UserProfileButton(),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const ScanScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
        icon: const Icon(Icons.document_scanner_rounded, size: 20),
        label: Text(
          tr('recentDocs.scanNew'),
          style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
        backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : AppColors.lightTextPrimary,
        elevation: 2,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: [
                // 1. EDITORIAL LEGAL REPOSITORY COMMAND VAULT
                _buildRepositorySummaryCard(tr, isDark),
                const SizedBox(height: 18),

                // 2. SEARCH BAR WITH KEYBOARD SHORTCUT HINT
                _buildSearchBar(tr, isDark),
                const SizedBox(height: 14),

                // 3. REFINED SEGMENTED FILTER BAR
                _buildFilterSegment(tr, isDark),
                const SizedBox(height: 18),

                // 4. DOCUMENT CARDS LIST & EMPTY STATES
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else if (displayDocs.isEmpty)
                  _buildEmptyState(tr, isDark)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayDocs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = displayDocs[index] as Map<String, dynamic>;
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 220 + (index * 40).clamp(0, 300)),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - val)),
                              child: child,
                            ),
                          );
                        },
                        child: _DocumentCardItem(
                          key: ValueKey(doc['_id'] ?? doc['id'] ?? index),
                          doc: doc,
                          isDark: isDark,
                          formattedDate: _formatRelativeTime(doc['createdAt']),
                          onOpenAnalysis: () => _openAnalysis(doc),
                          onViewDocument: () => _openAnalysis(doc),
                          onDownloadReport: () => _downloadRiskReport(doc),
                          onRename: () => _showRenameDialog(doc),
                          onReanalyze: () => _reanalyzeDocument(doc),
                          onDelete: () => _confirmDelete(doc),
                          tr: tr,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- EDITORIAL REPOSITORY SUMMARY COMMAND CARD ---
  Widget _buildRepositorySummaryCard(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
  ) {
    final stats = [
      _StatItemData(
        label: tr('recentDocs.total').toUpperCase(),
        subLabel: tr('recentDocs.documents'),
        count: '${_allDocs.length}',
        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        category: 'All',
      ),
      _StatItemData(
        label: tr('recentDocs.highRisk').toUpperCase(),
        subLabel: 'CRITICAL',
        count: _redCount < 10 ? '0$_redCount' : '$_redCount',
        color: isDark ? AppColors.darkError : AppColors.lightError,
        category: 'High Risk',
      ),
      _StatItemData(
        label: tr('recentDocs.caution').toUpperCase(),
        subLabel: 'ATTENTION',
        count: _yellowCount < 10 ? '0$_yellowCount' : '$_yellowCount',
        color: isDark ? AppColors.darkCaution : AppColors.lightCaution,
        category: 'Caution',
      ),
      _StatItemData(
        label: tr('recentDocs.compliant').toUpperCase(),
        subLabel: 'VERIFIED',
        count: _greenCount < 10 ? '0$_greenCount' : '$_greenCount',
        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        category: 'Compliant',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Editorial Header Area
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stacked Vault Shield Emblem
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.folder_special_rounded,
                      color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            tr('recentDocs.repository'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              tr('recentDocs.secureVault'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('recentDocs.vaultSubtitle'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Legal Status Indicators Command Strip
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 520;
                  if (isWide) {
                    return Row(
                      children: [
                        for (int i = 0; i < stats.length; i++) ...[
                          Expanded(
                            child: _buildCommandStatCell(stats[i], isDark),
                          ),
                          if (i < stats.length - 1)
                            Container(
                              width: 1,
                              height: 38,
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                        ],
                      ],
                    );
                  } else {
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: stats.map((item) => _buildCommandStatCell(item, isDark)).toList(),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandStatCell(_StatItemData item, bool isDark) {
    final isSelected = _selectedCategory == item.category;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = item.category;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? item.color.withValues(alpha: isDark ? 0.16 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? item.color.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isSelected ? item.color : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    item.count,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: item.color,
                    ),
                  ),
                  if (item.category == 'All') ...[
                    const SizedBox(width: 4),
                    Text(
                      item.subLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SEARCH BAR WITH DESKTOP KEYBOARD SHORTCUT BADGE ---
  Widget _buildSearchBar(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: tr('recentDocs.searchHint'),
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // --- REFINED SEGMENTED FILTER TABS ---
  Widget _buildFilterSegment(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterChip('All', tr('recentDocs.all'), _allDocs.length, isDark, activeColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
          const SizedBox(width: 8),
          _buildFilterChip('High Risk', tr('recentDocs.highRisk'), _redCount, isDark, activeColor: isDark ? AppColors.darkError : AppColors.lightError),
          const SizedBox(width: 8),
          _buildFilterChip('Caution', tr('recentDocs.caution'), _yellowCount, isDark, activeColor: isDark ? AppColors.darkCaution : AppColors.lightCaution),
          const SizedBox(width: 8),
          _buildFilterChip('Compliant', tr('recentDocs.compliant'), _greenCount, isDark, activeColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String categoryId,
    String label,
    int count,
    bool isDark, {
    required Color activeColor,
  }) {
    final isSelected = _selectedCategory == categoryId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategory = categoryId);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.6)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (categoryId != 'All') ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppColors.darkTextPrimary : activeColor)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.25)
                      : (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (isDark ? AppColors.darkTextPrimary : activeColor)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MINIMALIST LEGAL VAULT EMPTY STATE ---
  Widget _buildEmptyState(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
  ) {
    final isSearching = _searchQuery.trim().isNotEmpty;
    final isCategoryFiltered = _selectedCategory != 'All';
    final hasError = _docsError != null;

    String title = tr('recentDocs.emptyPrompt');
    String subtitle = tr('recentDocs.emptyDesc');
    IconData icon = Icons.folder_open_rounded;

    if (hasError) {
      title = 'Couldn\'t load your documents';
      subtitle = 'Check your connection and try again.';
      icon = Icons.wifi_off_rounded;
    } else if (isSearching) {
      title = tr('recentDocs.noDocsMatching', {'query': _searchQuery});
      subtitle = 'Try checking for spelling or searching with a different term.';
      icon = Icons.search_off_rounded;
    } else if (isCategoryFiltered) {
      title = tr('recentDocs.noDocsCategory');
      subtitle = 'There are currently no agreements analyzed under the $_selectedCategory category.';
      icon = Icons.filter_alt_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      margin: const EdgeInsets.symmetric(vertical: 12),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              icon,
              size: 36,
              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _fetchDocuments,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                side: BorderSide(color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else if (isSearching || isCategoryFiltered) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(tr('recentDocs.resetFilters')),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                side: BorderSide(color: isDark ? AppColors.darkAccent : AppColors.lightPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const ScanScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              icon: const Icon(Icons.document_scanner_rounded, size: 18),
              label: Text(tr('recentDocs.scanNew')),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Data holder for repository statistics
class _StatItemData {
  final String label;
  final String subLabel;
  final String count;
  final Color color;
  final String category;

  _StatItemData({
    required this.label,
    required this.subLabel,
    required this.count,
    required this.color,
    required this.category,
  });
}

// ==========================================
// 5. INDIVIDUAL TACTILE LEGAL DOSSIER CARD
// ==========================================
class _DocumentCardItem extends StatefulWidget {
  final Map<String, dynamic> doc;
  final bool isDark;
  final String formattedDate;
  final VoidCallback onOpenAnalysis;
  final VoidCallback onViewDocument;
  final VoidCallback onDownloadReport;
  final VoidCallback onRename;
  final VoidCallback onReanalyze;
  final VoidCallback onDelete;
  final String Function(String, [Map<String, String>?]) tr;

  const _DocumentCardItem({
    super.key,
    required this.doc,
    required this.isDark,
    required this.formattedDate,
    required this.onOpenAnalysis,
    required this.onViewDocument,
    required this.onDownloadReport,
    required this.onRename,
    required this.onReanalyze,
    required this.onDelete,
    required this.tr,
  });

  @override
  State<_DocumentCardItem> createState() => _DocumentCardItemState();
}

class _DocumentCardItemState extends State<_DocumentCardItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.doc['title'] ?? 'Scanned Agreement').toString().trim();
    String rawRisk = (widget.doc['riskLevel'] ?? '').toString().trim();
    if (rawRisk.isEmpty) {
      final highCount = widget.doc['highRiskCount'] as int? ?? 0;
      final cautionCount = widget.doc['cautionCount'] as int? ?? 0;
      if (highCount > 0) {
        rawRisk = 'High Risk';
      } else if (cautionCount > 0) {
        rawRisk = 'Caution';
      } else {
        rawRisk = 'Compliant';
      }
    }
    final riskLevel = rawRisk;
    final docSize = (widget.doc['docSize'] ?? '1.2 MB').toString();
    final dateText = widget.tr('recentDocs.scanned', {'time': widget.formattedDate});
    final sourceType = (widget.doc['sourceType'] as String?) ??
        (title.toLowerCase().endsWith('.pdf') ? 'PDF Document' : 'Document');

    // Risk badge configuration
    Color badgeColor = widget.isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
    IconData badgeIcon = Icons.check_circle_rounded;
    final rLower = riskLevel.toLowerCase();

    if (rLower.contains('high') || rLower.contains('red')) {
      badgeColor = widget.isDark ? AppColors.darkError : AppColors.lightError;
      badgeIcon = Icons.error_outline_rounded;
    } else if (rLower.contains('medium') || rLower.contains('yellow') || rLower.contains('caution')) {
      badgeColor = widget.isDark ? AppColors.darkCaution : AppColors.lightCaution;
      badgeIcon = Icons.warning_amber_rounded;
    }

    // Format badge configuration
    IconData formatIcon = Icons.picture_as_pdf_rounded;
    Color formatColor = widget.isDark ? AppColors.darkError : AppColors.lightError;

    final sLower = sourceType.toLowerCase();
    if (sLower.contains('photo') || sLower.contains('image')) {
      formatIcon = Icons.image_rounded;
      formatColor = widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    } else if (sLower.contains('text')) {
      formatIcon = Icons.notes_rounded;
      formatColor = widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onOpenAnalysis,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.6)
                  : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. TACTILE STACKED DOCUMENT SHEET BADGE
              Hero(
                tag: 'doc-icon-${widget.doc['_id'] ?? widget.doc['id']}',
                child: _buildTactilePaperBadge(formatIcon, formatColor, widget.isDark),
              ),
              const SizedBox(width: 16),

              // 2. DOCUMENT TITLE & METADATA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Format pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: formatColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            sourceType,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: formatColor,
                            ),
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        // Scanned time
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        // Doc Size
                        Text(
                          docSize,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 3. RISK STATUS BADGE WITH PULSE DOT
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: widget.isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      riskLevel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // 4. THREE-DOT MENU
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  size: 20,
                ),
                tooltip: widget.tr('recentDocs.actions'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                color: widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                elevation: 4,
                onSelected: (value) {
                  switch (value) {
                    case 'view_document':
                      widget.onViewDocument();
                      break;
                    case 'view_analysis':
                      widget.onOpenAnalysis();
                      break;
                    case 'download_report':
                      widget.onDownloadReport();
                      break;
                    case 'rename':
                      widget.onRename();
                      break;
                    case 'reanalyze':
                      widget.onReanalyze();
                      break;
                    case 'delete':
                      widget.onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view_document',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.tr('recentDocs.viewDocument'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'view_analysis',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 18,
                          color: widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.tr('recentDocs.viewAnalysis'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'download_report',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.tr('recentDocs.downloadReport'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.tr('recentDocs.rename'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reanalyze',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.tr('recentDocs.reanalyze'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: widget.isDark ? AppColors.darkError : AppColors.lightError,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.tr('recentDocs.delete'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? AppColors.darkError : AppColors.lightError,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tactile stacked paper sheet badge
  Widget _buildTactilePaperBadge(IconData formatIcon, Color formatColor, bool isDark) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: formatColor.withValues(alpha: isDark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: formatColor.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Icon(
              formatIcon,
              color: formatColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}