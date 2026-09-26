import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';

class BinScreen extends ConsumerStatefulWidget {
  const BinScreen({super.key});

  @override
  ConsumerState<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends ConsumerState<BinScreen> {
  List<dynamic> _binnedDocs = [];
  List<dynamic> _binnedChecklists = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTabIndex = 0; // 0: Documents, 1: Checklists

  @override
  void initState() {
    super.initState();
    _fetchBinData();
  }

  Future<void> _fetchBinData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.fetchBinDocuments(),
        ApiService.fetchBinChecklists(),
      ]);

      if (mounted) {
        setState(() {
          _binnedDocs = results[0];
          _binnedChecklists = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Recycle Bin data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load Recycle Bin. Please check your connection.';
        });
      }
    }
  }

  void _showToast({
    required Widget content,
    Duration duration = const Duration(seconds: 4),
    Widget? action,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final screenWidth = MediaQuery.of(context).size.width;
    final toastWidth = screenWidth > 540 ? 460.0 : (screenWidth - 32.0).clamp(280.0, 540.0);

    final effectiveBg = backgroundColor ?? (isDark ? AppColors.darkElevatedSurface : AppColors.lightSurface);
    final effectiveBorder = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    messenger.showSnackBar(
      SnackBar(
        width: toastWidth,
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        backgroundColor: effectiveBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: effectiveBorder,
            width: 1.2,
          ),
        ),
        duration: duration,
        content: Row(
          children: [
            Expanded(child: content),
            if (action != null) ...[
              const SizedBox(width: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _restoreDocument(String docId, String title) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final success = await ApiService.restoreDocument(docId);
    if (mounted) {
      if (success) {
        setState(() {
          _binnedDocs.removeWhere((d) => (d['_id'] ?? d['id']).toString() == docId);
        });

        _showToast(
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.restore_page_rounded,
                  color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"$title" ${tr('bin.restoredSuccess').toLowerCase()}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        _showToast(
          backgroundColor: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),
          borderColor: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: isDark ? AppColors.darkError : AppColors.lightError,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to restore document. Please try again.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFFEE2E2) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteDocument(String docId, String title) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await _showPermanentDeleteConfirmationDialog(title: title, isChecklist: false);
    if (confirmed != true) return;

    final success = await ApiService.permanentlyDeleteDocument(docId);
    if (mounted) {
      if (success) {
        setState(() {
          _binnedDocs.removeWhere((d) => (d['_id'] ?? d['id']).toString() == docId);
        });

        final toastBg = isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2);
        final toastBorder = isDark ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFFFCA5A5);
        final toastAccent = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

        _showToast(
          duration: const Duration(seconds: 4),
          backgroundColor: toastBg,
          borderColor: toastBorder,
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: toastAccent.withValues(alpha: isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: toastAccent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: toastAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"$title" ${tr('bin.permanentlyDeletedSuccess').toLowerCase()}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFEE2E2) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        _showToast(
          backgroundColor: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),
          borderColor: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: isDark ? AppColors.darkError : AppColors.lightError,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to permanently delete document.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFFEE2E2) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _restoreChecklist(String idOrType, String title) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final success = await ApiService.restoreChecklist(idOrType);
    if (mounted) {
      if (success) {
        setState(() {
          _binnedChecklists.removeWhere((c) => 
            (c['_id'] ?? c['id']).toString() == idOrType || (c['type'] ?? '').toString() == idOrType
          );
        });

        final toastBg = isDark ? const Color(0xFF13271F) : const Color(0xFFECFDF5);
        final toastBorder = isDark ? const Color(0xFF10B981).withValues(alpha: 0.6) : const Color(0xFF6EE7B7);
        final toastAccent = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);

        _showToast(
          duration: const Duration(seconds: 4),
          backgroundColor: toastBg,
          borderColor: toastBorder,
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: toastAccent.withValues(alpha: isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: toastAccent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.restore_page_rounded,
                  color: toastAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"$title" ${tr('bin.checklistRestoredSuccess').toLowerCase()}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF0FDF4) : const Color(0xFF064E3B),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        _showToast(
          backgroundColor: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),
          borderColor: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: isDark ? AppColors.darkError : AppColors.lightError,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to restore checklist. Please try again.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFFEE2E2) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteChecklist(String idOrType, String title) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await _showPermanentDeleteConfirmationDialog(title: title, isChecklist: true);
    if (confirmed != true) return;

    final success = await ApiService.permanentlyDeleteChecklist(idOrType);
    if (mounted) {
      if (success) {
        setState(() {
          _binnedChecklists.removeWhere((c) => 
            (c['_id'] ?? c['id']).toString() == idOrType || (c['type'] ?? '').toString() == idOrType
          );
        });
        _showToast(
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: isDark ? AppColors.darkError : AppColors.lightError,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"$title" ${tr('bin.checklistPermanentlyDeletedSuccess').toLowerCase()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        _showToast(
          content: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: isDark ? AppColors.darkError : AppColors.lightError,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Failed to permanently delete checklist.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<bool?> _showPermanentDeleteConfirmationDialog({
    required String title,
    required bool isChecklist,
  }) {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: isDark ? AppColors.darkError : AppColors.lightError,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isChecklist
                      ? tr('bin.permanentConfirmChecklistTitle')
                      : tr('bin.permanentConfirmTitle'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete "$title"?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isChecklist
                    ? tr('bin.permanentConfirmChecklistMessage')
                    : tr('bin.permanentConfirmMessage'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                tr('recentDocs.cancel'),
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                tr('bin.deletePermanently'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDeletedRelativeTime(dynamic deletedAtVal) {
    if (deletedAtVal == null) return 'Deleted recently';
    try {
      final date = DateTime.parse(deletedAtVal.toString());
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Deleted just now';
      if (diff.inMinutes < 60) return 'Deleted ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Deleted ${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Deleted yesterday';
      if (diff.inDays < 30) return 'Deleted ${diff.inDays} days ago';
      return 'Deleted on ${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Deleted recently';
    }
  }

  int _calculateDaysRemaining(dynamic deletedAtVal) {
    if (deletedAtVal == null) return 30;
    try {
      final date = DateTime.parse(deletedAtVal.toString());
      final diff = DateTime.now().difference(date);
      final remaining = 30 - diff.inDays;
      return remaining > 0 ? remaining : 0;
    } catch (_) {
      return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 960;

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
          tr('bin.title'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: const [
          UserProfileButton(),
          SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchBinData,
          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
          child: _buildBody(context, isDark, tr, isDesktop),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, String Function(String, [Map<String, String>?]) tr, bool isDesktop) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: isDark ? AppColors.darkError : AppColors.lightError),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchBinData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentItems = _selectedTabIndex == 0 ? _binnedDocs : _binnedChecklists;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 700),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24.0 : 16.0,
            vertical: 20.0,
          ),
          children: [
            // Segmented Tab Switcher (Documents | Checklists)
            _buildSegmentedTabControl(isDark, tr),
            const SizedBox(height: 16),

            // Auto-purge advisory notice banner
            _buildAutoPurgeNoticeBanner(isDark, tr),
            const SizedBox(height: 18),

            // Tab Content
            if (currentItems.isEmpty)
              _buildEmptyTabState(isDark, tr)
            else if (_selectedTabIndex == 0)
              ..._binnedDocs.map((doc) => _buildBinnedDocCard(context, doc as Map<String, dynamic>, isDark, tr))
            else
              ..._binnedChecklists.map((chk) => _buildBinnedChecklistCard(context, chk as Map<String, dynamic>, isDark, tr)),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabControl(bool isDark, String Function(String, [Map<String, String>?]) tr) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              index: 0,
              icon: Icons.description_outlined,
              label: tr('bin.documentsTab'),
              count: _binnedDocs.length,
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _buildTabItem(
              index: 1,
              icon: Icons.checklist_rtl_rounded,
              label: tr('bin.checklistsTab'),
              count: _binnedChecklists.length,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkSurfaceElevated : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoPurgeNoticeBanner(bool isDark, String Function(String, [Map<String, String>?]) tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E2638) : const Color(0xFFEBF3FF)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '30-Day Auto-Purge Policy',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('bin.autoPurgeNote'),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState(bool isDark, String Function(String, [Map<String, String>?]) tr) {
    final isDocs = _selectedTabIndex == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Icon(
              isDocs ? Icons.delete_outline_rounded : Icons.checklist_rtl_rounded,
              size: 36,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isDocs ? tr('bin.emptyTitle') : tr('bin.emptyChecklistsTitle'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              isDocs ? tr('bin.emptySubtitle') : tr('bin.emptyChecklistsSubtitle'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinnedDocCard(
    BuildContext context,
    Map<String, dynamic> doc,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
  ) {
    final docId = (doc['_id'] ?? doc['id']).toString();
    final title = (doc['title'] ?? 'Untitled Document').toString();
    final sourceType = (doc['sourceType'] ?? 'PDF Document').toString();
    final deletedAt = doc['deletedAt'];
    final daysRemaining = _calculateDaysRemaining(deletedAt);
    final riskLevel = (doc['riskLevel'] ?? 'Low Risk').toString();

    Color riskColor;
    if (riskLevel.toLowerCase().contains('high') || riskLevel.toLowerCase().contains('red')) {
      riskColor = AppColors.highRisk(isDark);
    } else if (riskLevel.toLowerCase().contains('medium') || riskLevel.toLowerCase().contains('caution') || riskLevel.toLowerCase().contains('yellow')) {
      riskColor = AppColors.caution(isDark);
    } else {
      riskColor = AppColors.compliant(isDark);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Document Icon, Title, and Auto-Purge Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Icon(
                  sourceType.contains('Photo') ? Icons.image_rounded : Icons.description_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatDeletedRelativeTime(deletedAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            riskLevel,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: riskColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Retention Countdown Pill
              _buildRetentionPill(daysRemaining, isDark),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          const SizedBox(height: 12),

          // Action Buttons: Restore & Delete Permanently
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                  side: BorderSide(
                    color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => _permanentlyDeleteDocument(docId, title),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: Text(
                  tr('bin.deletePermanently'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () => _restoreDocument(docId, title),
                icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                label: Text(
                  tr('bin.restore'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBinnedChecklistCard(
    BuildContext context,
    Map<String, dynamic> chk,
    bool isDark,
    String Function(String, [Map<String, String>?]) tr,
  ) {
    final chkId = (chk['_id'] ?? chk['id'] ?? chk['type']).toString();
    final type = (chk['type'] ?? chkId).toString();
    final title = (chk['title'] ?? 'Untitled Checklist').toString();
    final items = (chk['items'] as List<dynamic>?) ?? [];
    final deletedAt = chk['deletedAt'];
    final daysRemaining = _calculateDaysRemaining(deletedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Checklist Icon, Title, and Auto-Purge Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Icon(
                  Icons.checklist_rounded,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatDeletedRelativeTime(deletedAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${items.length} tasks',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Retention Countdown Pill
              _buildRetentionPill(daysRemaining, isDark),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          const SizedBox(height: 12),

          // Action Buttons: Restore & Delete Permanently
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                  side: BorderSide(
                    color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () => _permanentlyDeleteChecklist(type.isNotEmpty ? type : chkId, title),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: Text(
                  tr('bin.deletePermanently'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () => _restoreChecklist(type.isNotEmpty ? type : chkId, title),
                icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                label: Text(
                  tr('bin.restore'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetentionPill(int daysRemaining, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: daysRemaining <= 3
            ? (isDark ? AppColors.darkError.withValues(alpha: 0.15) : AppColors.lightError.withValues(alpha: 0.1))
            : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: daysRemaining <= 3
              ? (isDark ? AppColors.darkError.withValues(alpha: 0.4) : AppColors.lightError.withValues(alpha: 0.4))
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 13,
            color: daysRemaining <= 3
                ? (isDark ? AppColors.darkError : AppColors.lightError)
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            '$daysRemaining d left',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: daysRemaining <= 3
                  ? (isDark ? AppColors.darkError : AppColors.lightError)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
