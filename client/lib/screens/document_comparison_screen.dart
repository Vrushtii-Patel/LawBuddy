import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';
import 'comparison_result_screen.dart';

class DocumentComparisonScreen extends ConsumerStatefulWidget {
  const DocumentComparisonScreen({super.key});

  @override
  ConsumerState<DocumentComparisonScreen> createState() => _DocumentComparisonScreenState();
}

class _DocumentComparisonScreenState extends ConsumerState<DocumentComparisonScreen> {
  List<dynamic> _recentDocs = [];
  bool _isLoadingDocs = true;
  String? _selectedDocAId;
  String? _selectedDocBId;
  String? _selectedTitleA;
  String? _selectedTitleB;

  bool _isComparing = false;
  String _comparisonStep = 'Initializing...';
  String? _errorMessage;

  Map<String, dynamic>? _activeComp;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
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
          if (_activeComp != null && _activeComp!['status'] != 'COMPLETED' && _activeComp!['status'] != 'FAILED') {
            _isComparing = true;
            _comparisonStep = _activeComp!['currentStep'] ?? 'Processing...';
            _startPolling(_activeComp!['comparisonId']);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDocs = false;
        });
      }
    }
  }

  void _startPolling(String comparisonId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final comp = await ApiService.getComparison(comparisonId);
        if (!mounted) return;
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
            _errorMessage = comp['errorInfo']?['message'] ?? 'Comparison failed.';
          });
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  Future<void> _handleStartComparison() async {
    if (_selectedDocAId == null || _selectedDocBId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both Version A and Version B documents.')),
      );
      return;
    }
    if (_selectedDocAId == _selectedDocBId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select two distinct versions to compare.')),
      );
      return;
    }

    setState(() {
      _isComparing = true;
      _comparisonStep = 'Starting comparison...';
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
      if (mounted) {
        setState(() {
          _isComparing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Compare Agreements', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: const [
          UserProfileButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),
              if (_errorMessage != null) _buildErrorBanner(),
              if (_isComparing) _buildProcessingCard(isDark),
              if (!_isComparing) ...[
                _buildVersionSelectorCard(
                  isDark: isDark,
                  versionLabel: 'Version A (Baseline / Before Negotiation)',
                  icon: Icons.history_edu,
                  color: Colors.blueAccent,
                  selectedDocId: _selectedDocAId,
                  selectedTitle: _selectedTitleA,
                  onSelect: (id, title) {
                    setState(() {
                      _selectedDocAId = id;
                      _selectedTitleA = title;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Icon(
                      Icons.swap_vert,
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildVersionSelectorCard(
                  isDark: isDark,
                  versionLabel: 'Version B (Revised / After Negotiation)',
                  icon: Icons.edit_document,
                  color: Colors.tealAccent,
                  selectedDocId: _selectedDocBId,
                  selectedTitle: _selectedTitleB,
                  onSelect: (id, title) {
                    setState(() {
                      _selectedDocBId = id;
                      _selectedTitleB = title;
                    });
                  },
                ),
                const SizedBox(height: 32),
                _buildCompareActionButton(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contract Differential Analysis',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select two agreement drafts to identify modified clauses, added obligations, deleted buyer protections, and risk escalations.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
          const SizedBox(height: 20),
          Text(
            _comparisonStep,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing clause alignments, numbers, dates, and legal statutory impact...',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSelectorCard({
    required bool isDark,
    required String versionLabel,
    required IconData icon,
    required Color color,
    required String? selectedDocId,
    required String? selectedTitle,
    required Function(String id, String title) onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedDocId != null
              ? color.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: selectedDocId != null ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  versionLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingDocs)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          else if (_recentDocs.isEmpty)
            Text(
              'No scanned documents found. Scan agreements first.',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontSize: 13,
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: selectedDocId,
              isExpanded: true,
              hint: Text(
                'Choose document version',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 14,
                ),
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              items: _recentDocs.map<DropdownMenuItem<String>>((doc) {
                final id = (doc['_id'] ?? doc['id']).toString();
                final title = (doc['title'] ?? 'Untitled Agreement').toString();
                final risk = (doc['riskLevel'] ?? '').toString();
                return DropdownMenuItem<String>(
                  value: id,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                      ),
                      if (risk.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: risk.toLowerCase().contains('high')
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            risk,
                            style: TextStyle(
                              fontSize: 11,
                              color: risk.toLowerCase().contains('high') ? Colors.redAccent : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final found = _recentDocs.firstWhere((d) => (d['_id'] ?? d['id']).toString() == val);
                  onSelect(val, (found['title'] ?? 'Untitled Agreement').toString());
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompareActionButton(bool isDark) {
    final bool canCompare = _selectedDocAId != null && _selectedDocBId != null && _selectedDocAId != _selectedDocBId;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: canCompare ? _handleStartComparison : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          disabledBackgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: const Text(
          'Run Differential Analysis',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
