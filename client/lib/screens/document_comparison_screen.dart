import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';
import '../widgets/app_toast.dart';
import 'comparison_result_screen.dart';
import 'scan_screen.dart';

class DocumentComparisonScreen extends ConsumerStatefulWidget {
  final List<dynamic>? initialDocs;
  const DocumentComparisonScreen({super.key, this.initialDocs});

  @override
  ConsumerState<DocumentComparisonScreen> createState() =>
      _DocumentComparisonScreenState();
}

class _DocumentComparisonScreenState
    extends ConsumerState<DocumentComparisonScreen> {
  List<dynamic> _recentDocs = [];
  bool _isLoadingDocs = true;
  bool _docsLoadFailed = false;
  String? _selectedDocAId;
  String? _selectedDocBId;
  String? _selectedTitleA;
  String? _selectedTitleB;

  bool _isComparing = false;
  String _comparisonStep = 'Initializing...';
  String? _errorMessage;

  Map<String, dynamic>? _activeComp;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 60; // 60 x 2s = 2 minutes cap
  static const int _maxConsecutivePollErrors = 5;
  int _consecutivePollErrors = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocs != null) {
      _recentDocs = List<dynamic>.from(widget.initialDocs!);
      _isLoadingDocs = false;
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_recentDocs.isEmpty) {
      setState(() {
        _isLoadingDocs = true;
        _docsLoadFailed = false;
      });
    }
    try {
      final results = await Future.wait([
        ApiService.fetchRecentDocuments(),
        ApiService.getActiveComparison(),
      ]);
      if (mounted) {
        setState(() {
          _recentDocs = results[0] as List<dynamic>;
          _isLoadingDocs = false;
          _activeComp = results[1] as Map<String, dynamic>?;
          if (_activeComp != null &&
              _activeComp!['status'] != 'COMPLETED' &&
              _activeComp!['status'] != 'FAILED') {
            _isComparing = true;
            _comparisonStep = _activeComp!['currentStep'] ?? 'Processing...';
            _startPolling(_activeComp!['comparisonId']);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load documents/active comparison: $e');
      if (mounted) {
        setState(() {
          _isLoadingDocs = false;
          if (_recentDocs.isEmpty) {
            _docsLoadFailed = true;
          }
        });
      }
    }
  }

  void _startPolling(String comparisonId) {
    _pollTimer?.cancel();
    _pollAttempts = 0;
    _consecutivePollErrors = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _pollAttempts++;
      if (_pollAttempts > _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          final loc = ref.read(localeProvider.notifier);
          setState(() {
            _isComparing = false;
            _errorMessage = loc.translate('docComparison.timeoutError');
          });
        }
        return;
      }

      try {
        final comp = await ApiService.getComparison(comparisonId);
        if (!mounted) return;
        _consecutivePollErrors = 0;
        final status = comp['status'];
        final step = comp['currentStep'] ?? 'Processing...';
        setState(() {
          _comparisonStep = step;
        });

        if (status == 'COMPLETED') {
          timer.cancel();
          setState(() {
            _isComparing = false;
            _activeComp = null;
          });
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (ctx) => ComparisonResultScreen(comparisonData: comp),
            ),
          );
        } else if (status == 'FAILED') {
          timer.cancel();
          setState(() {
            _isComparing = false;
            _errorMessage =
                comp['errorInfo']?['message'] ?? 'Comparison failed.';
          });
        }
      } catch (e) {
        debugPrint('Polling error: $e');
        _consecutivePollErrors++;
        if (_consecutivePollErrors >= _maxConsecutivePollErrors && mounted) {
          timer.cancel();
          final loc = ref.read(localeProvider.notifier);
          setState(() {
            _isComparing = false;
            _errorMessage = loc.translate('docComparison.connectionLost');
          });
        }
      }
    });
  }

  Future<void> _handleStartComparison() async {
    final loc = ref.read(localeProvider.notifier);
    if (_selectedDocAId == null || _selectedDocBId == null) {
      AppToast.showError(
          context, loc.translate('docComparison.selectBothPrompt'));
      return;
    }
    if (_selectedDocAId == _selectedDocBId) {
      AppToast.showError(
          context, loc.translate('docComparison.selectDistinctPrompt'));
      return;
    }

    setState(() {
      _isComparing = true;
      _comparisonStep = loc.translate('docComparison.startingComparison');
      _errorMessage = null;
    });

    try {
      final res = await ApiService.startComparison(
        docAId: _selectedDocAId,
        docBId: _selectedDocBId,
        titleA: _selectedTitleA,
        titleB: _selectedTitleB,
      );

      final comparisonId = res['comparisonId'] ?? res['_id'];
      if (res['status'] == 'COMPLETED') {
        final fullComp = await ApiService.getComparison(comparisonId);
        if (!mounted) return;
        setState(() => _isComparing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (ctx) => ComparisonResultScreen(comparisonData: fullComp),
          ),
        );
      } else {
        _startPolling(comparisonId);
      }
    } catch (e) {
      debugPrint('Error starting document comparison: $e');
      if (mounted) {
        setState(() {
          _isComparing = false;
          _errorMessage = loc.translate('docComparison.startError');
        });
      }
    }
  }

  void _swapSelections() {
    if (_selectedDocAId == null && _selectedDocBId == null) return;
    setState(() {
      final tempId = _selectedDocAId;
      final tempTitle = _selectedTitleA;
      _selectedDocAId = _selectedDocBId;
      _selectedTitleA = _selectedTitleB;
      _selectedDocBId = tempId;
      _selectedTitleB = tempTitle;
    });
  }

  Map<String, dynamic>? _getDocById(String? id) {
    if (id == null) return null;
    try {
      final found = _recentDocs.firstWhere(
        (d) => (d['_id'] ?? d['id']).toString() == id,
      );
      if (found is Map<String, dynamic>) return found;
      return Map<String, dynamic>.from(found as Map);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktopOrTablet = size.width >= 820;
    final isCompact = size.width < 500;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          loc.translate('docComparison.appBarTitle'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: const [
          UserProfileButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktopOrTablet ? 32 : 16,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Compact Page Introduction
                  _buildIntroduction(isDark, loc),
                  const SizedBox(height: 16),

                  // 2. Step Flow Indicator (Original -> Revised -> Compare)
                  if (!isCompact) ...[
                    _buildStepFlow(isDark),
                    const SizedBox(height: 18),
                  ],

                  // 3. Error Banner (if any)
                  if (_errorMessage != null) _buildErrorBanner(),

                  // 4. Processing State OR Selection Cards
                  if (_isComparing)
                    _buildProcessingCard(isDark, loc)
                  else ...[
                    // Selection Cards (Side-by-Side on desktop/tablet, stacked on mobile)
                    if (isDesktopOrTablet)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildVersionCard(
                              isDark: isDark,
                              isVersionA: true,
                              selectedDocId: _selectedDocAId,
                              selectedTitle: _selectedTitleA,
                              onSelect: (id, title) {
                                setState(() {
                                  _selectedDocAId = id;
                                  _selectedTitleA = title;
                                });
                              },
                              onClear: () {
                                setState(() {
                                  _selectedDocAId = null;
                                  _selectedTitleA = null;
                                });
                              },
                              loc: loc,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _buildComparisonIndicator(
                              isDark: isDark,
                              isHorizontal: true,
                            ),
                          ),
                          Expanded(
                            child: _buildVersionCard(
                              isDark: isDark,
                              isVersionA: false,
                              selectedDocId: _selectedDocBId,
                              selectedTitle: _selectedTitleB,
                              onSelect: (id, title) {
                                setState(() {
                                  _selectedDocBId = id;
                                  _selectedTitleB = title;
                                });
                              },
                              onClear: () {
                                setState(() {
                                  _selectedDocBId = null;
                                  _selectedTitleB = null;
                                });
                              },
                              loc: loc,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildVersionCard(
                        isDark: isDark,
                        isVersionA: true,
                        selectedDocId: _selectedDocAId,
                        selectedTitle: _selectedTitleA,
                        onSelect: (id, title) {
                          setState(() {
                            _selectedDocAId = id;
                            _selectedTitleA = title;
                          });
                        },
                        onClear: () {
                          setState(() {
                            _selectedDocAId = null;
                            _selectedTitleA = null;
                          });
                        },
                        loc: loc,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: _buildComparisonIndicator(
                          isDark: isDark,
                          isHorizontal: false,
                        ),
                      ),
                      _buildVersionCard(
                        isDark: isDark,
                        isVersionA: false,
                        selectedDocId: _selectedDocBId,
                        selectedTitle: _selectedTitleB,
                        onSelect: (id, title) {
                          setState(() {
                            _selectedDocBId = id;
                            _selectedTitleB = title;
                          });
                        },
                        onClear: () {
                          setState(() {
                            _selectedDocBId = null;
                            _selectedTitleB = null;
                          });
                        },
                        loc: loc,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 5. Primary Action & Functional Status
                    _buildPrimaryActionSection(isDark, loc),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. PAGE INTRODUCTION
  // ==========================================
  Widget _buildIntroduction(bool isDark, LocaleNotifier loc) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
                    .withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.compare_arrows_rounded,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contract Differential Analysis',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Compare agreement versions to identify changes, missing protections, and potential risks.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. STEP FLOW INDICATOR
  // ==========================================
  Widget _buildStepFlow(bool isDark) {
    final hasA = _selectedDocAId != null;
    final hasB = _selectedDocBId != null;
    final canCompare = hasA && hasB && _selectedDocAId != _selectedDocBId;

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                .withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepItem(
                stepNumber: '1',
                label: 'Original Agreement',
                isComplete: hasA,
                isDark: isDark,
              ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          _buildStepItem(
            stepNumber: '2',
            label: 'Revised Agreement',
            isComplete: hasB,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          _buildStepItem(
            stepNumber: '3',
            label: 'Compare Changes',
            isComplete: canCompare,
            isDark: isDark,
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildStepItem({
    required String stepNumber,
    required String label,
    required bool isComplete,
    required bool isDark,
  }) {
    final activeColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete
                ? activeColor
                : inactiveColor.withValues(alpha: 0.18),
          ),
          child: Center(
            child: isComplete
                ? Icon(
                    Icons.check_rounded,
                    size: 11,
                    color: isDark ? AppColors.softGraphite : Colors.white,
                  )
                : Text(
                    stepNumber,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: inactiveColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isComplete ? FontWeight.w700 : FontWeight.w500,
            color: isComplete
                ? (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary)
                : inactiveColor,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. VERSION CARD (A OR B)
  // ==========================================
  Widget _buildVersionCard({
    required bool isDark,
    required bool isVersionA,
    required String? selectedDocId,
    required String? selectedTitle,
    required Function(String id, String title) onSelect,
    required VoidCallback onClear,
    required LocaleNotifier loc,
  }) {
    // Subtle accent for Version B (lavender haze / periwinkle) vs Version A (graphite / neutral)
    final accentColor = isVersionA
        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightPrimary)
        : (isDark ? AppColors.darkPrimary : AppColors.lightSecondary);

    final eyebrowLabel = isVersionA ? 'VERSION A' : 'VERSION B';
    final cardTitle =
        isVersionA ? 'Original Agreement' : 'Revised Agreement';
    final supportingLabel =
        isVersionA ? 'Before negotiation' : 'After negotiation';
    final icon = isVersionA
        ? Icons.history_edu_outlined
        : Icons.edit_document;

    final selectedDoc = _getDocById(selectedDocId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selectedDocId != null
              ? accentColor.withValues(alpha: isDark ? 0.6 : 0.45)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: selectedDocId != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            eyebrowLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            supportingLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cardTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content States
          if (_isLoadingDocs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: isDark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,
                  ),
                ),
              ),
            )
          else if (_docsLoadFailed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.translate('docComparison.loadFailed'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadInitialData,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                    child: Text(loc.translate('common.retry')),
                  ),
                ],
              ),
            )
          else if (_recentDocs.isEmpty)
            _buildEmptyDocsState(isDark, loc)
          else ...[
            // Document Selector Dropdown
            _buildDropdownSelector(
              isDark: isDark,
              selectedDocId: selectedDocId,
              onSelect: onSelect,
              loc: loc,
            ),
            // Selected Agreement Metadata Preview
            if (selectedDoc != null)
              _buildSelectedDocPreview(
                doc: selectedDoc,
                isDark: isDark,
                accentColor: accentColor,
                onClear: onClear,
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 4. DROPDOWN SELECTOR
  // ==========================================
  Widget _buildDropdownSelector({
    required bool isDark,
    required String? selectedDocId,
    required Function(String id, String title) onSelect,
    required LocaleNotifier loc,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedDocId,
      isExpanded: true,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
      dropdownColor:
          isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(12),
      hint: Text(
        loc.translate('docComparison.chooseVersion'),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor:
            isDark ? AppColors.darkBackground : AppColors.lightSurfaceElevated,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            width: 1.2,
          ),
        ),
      ),
      items: _recentDocs.map<DropdownMenuItem<String>>((doc) {
        final id = (doc['_id'] ?? doc['id']).toString();
        final title = (doc['title'] ??
                loc.translate('docComparison.untitledAgreement'))
            .toString();
        final risk = (doc['riskLevel'] ?? '').toString();
        final isHigh = risk.toLowerCase().contains('high') ||
            risk.toLowerCase().contains('red');
        final isCaution = risk.toLowerCase().contains('caution') ||
            risk.toLowerCase().contains('yellow');
        final badgeColor = isHigh
            ? AppColors.highRisk(isDark)
            : (isCaution
                ? AppColors.caution(isDark)
                : AppColors.compliant(isDark));
        return DropdownMenuItem<String>(
          value: id,
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              if (risk.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    risk,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          final found = _recentDocs
              .firstWhere((d) => (d['_id'] ?? d['id']).toString() == val);
          onSelect(val,
              (found['title'] ?? loc.translate('docComparison.untitledAgreement'))
                  .toString());
        }
      },
    );
  }

  // ==========================================
  // 5. SELECTED DOCUMENT PREVIEW TILE
  // ==========================================
  Widget _buildSelectedDocPreview({
    required Map<String, dynamic> doc,
    required bool isDark,
    required Color accentColor,
    required VoidCallback onClear,
  }) {
    final title = (doc['title'] ?? 'Untitled Agreement').toString();
    final fileName = (doc['fileName'] ?? '').toString();
    final risk = (doc['riskLevel'] ?? '').toString();
    final docSize = (doc['docSize'] ?? '').toString();

    final isHigh = risk.toLowerCase().contains('high') ||
        risk.toLowerCase().contains('red');
    final isCaution = risk.toLowerCase().contains('caution') ||
        risk.toLowerCase().contains('yellow');
    final badgeColor = isHigh
        ? AppColors.highRisk(isDark)
        : (isCaution
            ? AppColors.caution(isDark)
            : AppColors.compliant(isDark));

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkBackground : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.article_outlined,
                size: 18,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                if (fileName.isNotEmpty && fileName != title) ...[
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (risk.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          risk.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    if (docSize.isNotEmpty)
                      Text(
                        docSize,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            onPressed: onClear,
            tooltip: 'Remove',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. COMPACT EMPTY STATE (WHEN NO DOCS)
  // ==========================================
  Widget _buildEmptyDocsState(bool isDark, LocaleNotifier loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground.withValues(alpha: 0.5)
            : AppColors.lightBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.6)
              : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 26,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            loc.translate('docComparison.noScannedDocs'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            loc.translate('docComparison.scanPrompt'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                ).then((_) => _loadInitialData());
              },
              icon: const Icon(Icons.document_scanner_rounded, size: 14),
              label: Text(
                loc.translate('docComparison.scanNewAgreement'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                foregroundColor:
                    isDark ? AppColors.softGraphite : AppColors.warmLinen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. COMPARISON INDICATOR WITH SWAP
  // ==========================================
  Widget _buildComparisonIndicator({
    required bool isDark,
    required bool isHorizontal,
  }) {
    final hasAnySelection =
        _selectedDocAId != null || _selectedDocBId != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isHorizontal) const SizedBox(height: 52),
        Tooltip(
          message: 'Swap Original & Revised Agreements',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasAnySelection ? _swapSelections : null,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorderMedium,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isHorizontal
                        ? Icons.swap_horiz_rounded
                        : Icons.swap_vert_rounded,
                    size: 20,
                    color: hasAnySelection
                        ? (isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary)
                        : (isDark
                            ? AppColors.darkTextSecondary
                                .withValues(alpha: 0.5)
                            : AppColors.lightTextSecondary
                                .withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 8. PRIMARY ACTION SECTION
  // ==========================================
  Widget _buildPrimaryActionSection(bool isDark, LocaleNotifier loc) {
    final bool hasA = _selectedDocAId != null;
    final bool hasB = _selectedDocBId != null;
    final bool isSame = hasA && hasB && _selectedDocAId == _selectedDocBId;
    final bool canCompare = hasA && hasB && !isSame && !_isComparing;

    String helperMessage;
    IconData helperIcon;
    Color helperColor;

    if (!hasA && !hasB) {
      helperMessage =
          'Select two agreement drafts above to enable differential analysis.';
      helperIcon = Icons.info_outline_rounded;
      helperColor = isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;
    } else if (!hasA || !hasB) {
      helperMessage = 'Select a second agreement version to proceed.';
      helperIcon = Icons.arrow_upward_rounded;
      helperColor = isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;
    } else if (isSame) {
      helperMessage =
          'Please select two distinct agreement drafts to compare.';
      helperIcon = Icons.warning_amber_rounded;
      helperColor = isDark ? AppColors.darkCaution : AppColors.lightCaution;
    } else {
      helperMessage =
          'Ready to analyze clause modifications and risk escalations.';
      helperIcon = Icons.check_circle_outline_rounded;
      helperColor =
          isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
    }

    return Column(
      children: [
        // Helper Explanation
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(helperIcon, size: 14, color: helperColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                helperMessage,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: helperColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Primary Button (compact width, centered on desktop)
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: canCompare ? _handleStartComparison : null,
                icon: _isComparing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark
                              ? AppColors.softGraphite
                              : Colors.white,
                        ),
                      )
                    : const Icon(Icons.compare_arrows_rounded, size: 20),
                label: Text(
                  _isComparing
                      ? 'Analyzing Agreements...'
                      : loc.translate('docComparison.runAnalysis'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  foregroundColor:
                      isDark ? AppColors.softGraphite : Colors.white,
                  disabledBackgroundColor: (isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder)
                      .withValues(alpha: 0.6),
                  disabledForegroundColor: (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary)
                      .withValues(alpha: 0.7),
                  elevation: canCompare ? 1 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 9. PROCESSING / PROGRESS STATE
  // ==========================================
  Widget _buildProcessingCard(bool isDark, LocaleNotifier loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
              .withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color:
                  isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _comparisonStep,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            loc.translate('docComparison.processingSubtitle'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 10. ERROR BANNER
  // ==========================================
  Widget _buildErrorBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkError : AppColors.lightError)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isDark ? AppColors.darkError : AppColors.lightError)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: isDark ? AppColors.darkError : AppColors.lightError,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? AppColors.darkError : AppColors.lightError,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: isDark ? AppColors.darkError : AppColors.lightError,
            ),
            onPressed: () => setState(() => _errorMessage = null),
            tooltip: 'Dismiss',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}