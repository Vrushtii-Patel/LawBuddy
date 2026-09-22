import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_profile_button.dart';
import '../widgets/staggered_entrance.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final String originalText;
  final List<dynamic> analysis;
  final String? documentTitle;
  final String? sourceType;
  final String? fileData;
  final String? mimeType;

  const AnalysisScreen({
    super.key,
    required this.originalText,
    required this.analysis,
    this.documentTitle,
    this.sourceType,
    this.fileData,
    this.mimeType,
  });

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _isExplaining = false;
  bool _isExportingPdf = false;
  bool _isGeneratingShare = false;
  String? _cachedShareToken;

  Uint8List? _getCleanBytes(String? rawBase64) {
    if (rawBase64 == null || rawBase64.trim().isEmpty) return null;
    try {
      String clean = rawBase64.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last.trim();
      }
      clean = clean.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(clean);
    } catch (e) {
      debugPrint('Error decoding base64 data: $e');
      return null;
    }
  }

  Color _getColorForCategory(BuildContext context, String category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (category.toLowerCase().trim()) {
      case 'green':
      case 'compliant':
      case 'low':
        return (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: isDark ? 0.15 : 0.08);
      case 'yellow':
      case 'caution':
      case 'medium':
        return (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: isDark ? 0.15 : 0.08);
      case 'red':
      case 'high':
      case 'high_risk':
        return isDark ? AppColors.darkSurface : AppColors.lightError.withValues(alpha: 0.08);
      default:
        return isDark ? AppColors.darkSurface : AppColors.lightSurface;
    }
  }

  Color _getBorderColor(BuildContext context, String category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (category.toLowerCase().trim()) {
      case 'green':
      case 'compliant':
      case 'low':
        return isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      case 'yellow':
      case 'caution':
      case 'medium':
        return isDark ? AppColors.darkCaution : AppColors.lightCaution;
      case 'red':
      case 'high':
      case 'high_risk':
        return isDark ? AppColors.darkError : AppColors.lightError;
      default:
        return isDark ? AppColors.darkBorder : AppColors.lightBorder;
    }
  }

  String _getDocumentTitle() {
    final t = widget.documentTitle ??
        (widget.originalText.trim().split('\n').first.replaceAll(RegExp(r'[#*_-]'), '').trim());
    return t.isNotEmpty ? t : 'Property Legal Analysis';
  }

  String _getOverallRiskLevel() {
    int red = 0;
    int yellow = 0;
    for (var item in widget.analysis) {
      final cat = (item['riskLevel'] ?? item['category'] ?? '').toString().toLowerCase();
      if (cat.contains('red') || cat.contains('high')) {
        red++;
      } else if (cat.contains('yellow') || cat.contains('caution') || cat.contains('medium')) {
        yellow++;
      }
    }
    if (red > 0) return 'High Risk';
    if (yellow > 0) return 'Medium Risk';
    return 'Low Risk';
  }

  List<String> _extractKeyFindings() {
    final findings = <String>[];
    for (var item in widget.analysis) {
      final r = (item['reason'] ?? item['legalFinding'] ?? item['title'] ?? '').toString().trim();
      if (r.isNotEmpty && !findings.contains(r)) {
        findings.add(r);
        if (findings.length >= 3) break;
      }
    }
    if (findings.isEmpty) {
      findings.add('No material legal violations identified.');
    }
    return findings;
  }

  Future<String?> _getOrGenerateShareToken() async {
    if (_cachedShareToken != null && _cachedShareToken!.isNotEmpty) {
      return _cachedShareToken;
    }
    setState(() => _isGeneratingShare = true);
    try {
      int red = 0, yellow = 0, green = 0;
      for (var item in widget.analysis) {
        final cat = (item['riskLevel'] ?? item['category'] ?? '').toString().toLowerCase();
        if (cat.contains('red') || cat.contains('high')) {
          red++;
        } else if (cat.contains('yellow') || cat.contains('caution') || cat.contains('medium')) {
          yellow++;
        } else {
          green++;
        }
      }

      final token = await ApiService.createShareLink(
        title: _getDocumentTitle(),
        riskLevel: _getOverallRiskLevel(),
        analysis: widget.analysis,
        highRiskCount: red,
        cautionCount: yellow,
        compliantCount: green,
        totalClauseCount: widget.analysis.length,
      );

      if (token != null) {
        _cachedShareToken = token;
      }
      return token;
    } catch (e) {
      debugPrint('Error generating share token: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isGeneratingShare = false);
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final token = await _getOrGenerateShareToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('analysis.shareFailed')),
          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shareUrl = ApiService.buildShareUrl(token);
    final docTitle = _getDocumentTitle();
    final riskLevel = _getOverallRiskLevel();
    final findings = _extractKeyFindings();

    final buffer = StringBuffer();
    buffer.writeln('*LawBuddy Property Risk Summary*');
    buffer.writeln();
    buffer.writeln('Property: $docTitle');
    buffer.writeln('Overall Risk: $riskLevel');
    buffer.writeln();
    buffer.writeln('Key Findings:');
    for (final f in findings) {
      buffer.writeln('• $f');
    }
    buffer.writeln();
    buffer.writeln('View the complete risk summary:');
    buffer.writeln(shareUrl);

    final msg = buffer.toString();
    final whatsappUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');

    try {
      final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not launch WhatsApp');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to open WhatsApp directly. You can use "Copy Link" instead.'),
          backgroundColor: isDark ? AppColors.darkCaution : AppColors.lightCaution,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareViaEmail() async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final token = await _getOrGenerateShareToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('analysis.shareFailed')),
          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shareUrl = ApiService.buildShareUrl(token);
    final docTitle = _getDocumentTitle();
    final riskLevel = _getOverallRiskLevel();
    final findings = _extractKeyFindings();

    final buffer = StringBuffer();
    buffer.writeln('LawBuddy Property Risk Summary');
    buffer.writeln();
    buffer.writeln('Property: $docTitle');
    buffer.writeln('Overall Risk: $riskLevel');
    buffer.writeln();
    buffer.writeln('Key Findings:');
    for (final f in findings) {
      buffer.writeln('• $f');
    }
    buffer.writeln();
    buffer.writeln('View the complete risk summary:');
    buffer.writeln(shareUrl);

    final emailUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'LawBuddy Property Risk Summary: $docTitle',
        'body': buffer.toString(),
      },
    );

    try {
      final launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not launch email client');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to open email client. You can use "Copy Link" instead.'),
          backgroundColor: isDark ? AppColors.darkCaution : AppColors.lightCaution,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyShareLink() async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final token = await _getOrGenerateShareToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('analysis.shareFailed')),
          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shareUrl = ApiService.buildShareUrl(token);
    await Clipboard.setData(ClipboardData(text: shareUrl));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('analysis.linkCopiedSuccess'))),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showShareOptionsModal() {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.share_rounded,
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('analysis.shareModalTitle'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr('analysis.shareModalSubtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // 1. WhatsApp
                  _buildShareOptionTile(
                    context: ctx,
                    isDark: isDark,
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: const Color(0xFF25D366),
                    iconBgColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                    title: tr('analysis.shareWhatsApp'),
                    subtitle: tr('analysis.shareWhatsAppDesc'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareOnWhatsApp();
                    },
                  ),
                  const SizedBox(height: 10),

                  // 2. Email
                  _buildShareOptionTile(
                    context: ctx,
                    isDark: isDark,
                    icon: Icons.mail_outline_rounded,
                    iconColor: isDark ? AppColors.darkCaution : AppColors.lightCaution,
                    iconBgColor: (isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.12),
                    title: tr('analysis.shareEmail'),
                    subtitle: tr('analysis.shareEmailDesc'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareViaEmail();
                    },
                  ),
                  const SizedBox(height: 10),

                  // 3. Copy Link
                  _buildShareOptionTile(
                    context: ctx,
                    isDark: isDark,
                    icon: Icons.link_rounded,
                    iconColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    iconBgColor: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.15),
                    title: tr('analysis.copyShareLink'),
                    subtitle: tr('analysis.copyShareLinkDesc'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _copyShareLink();
                    },
                  ),
                  const SizedBox(height: 10),

                  // 4. Download PDF
                  _buildShareOptionTile(
                    context: ctx,
                    isDark: isDark,
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    iconBgColor: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.12),
                    title: tr('analysis.exportPdf'),
                    subtitle: tr('analysis.downloadPdfDesc'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _exportPdf();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareOptionTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    setState(() => _isExportingPdf = true);
    try {
      final docTitle = widget.documentTitle ??
          (widget.originalText.trim().split('\n').first.replaceAll(RegExp(r'[#*_-]'), '').trim());

      await PdfExportService.exportAnalysisPdf(
        documentTitle: docTitle.isNotEmpty ? docTitle : 'Property Legal Analysis',
        originalText: widget.originalText,
        analysis: widget.analysis,
        sourceType: widget.sourceType ?? 'Document Analysis',
        fileData: widget.fileData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('analysis.pdfSuccess'))),
            ],
          ),
          backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('analysis.pdfFailed', {'error': '$e'})),
          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _explainSnippet(String snippet) async {
    setState(() => _isExplaining = true);
    try {
      final explanation = await ApiService.explainSnippet(widget.originalText, snippet);
      if (!mounted) return;
      _showExplanationModal(snippet, explanation);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExplaining = false);
    }
  }

  void _showExplanationModal(String snippet, String explanation) {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome, color: isDark ? AppColors.darkAccent : AppColors.lightAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('analysis.plainEnglish'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Text(
                  '"$snippet"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                explanation,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    tr('common.gotIt'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    int redCount = 0;
    int yellowCount = 0;
    int greenCount = 0;

    for (var item in widget.analysis) {
      final risk = (item['riskLevel'] ?? '').toString().toUpperCase();
      final cat = (item['category'] ?? '').toString().toLowerCase();
      if (risk == 'HIGH_RISK' || cat.contains('red')) {
        redCount++;
      } else if (risk == 'CAUTION' || cat.contains('yellow')) {
        yellowCount++;
      } else if (risk == 'COMPLIANT' || cat.contains('green')) {
        greenCount++;
      }
    }

    final summaryColor = redCount > 0
        ? (isDark ? AppColors.darkError : AppColors.lightError)
        : (yellowCount > 0 ? (isDark ? AppColors.darkCaution : AppColors.lightCaution) : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          tr('analysis.reportTitle'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        actions: const [
          UserProfileButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Executive Summary Banner
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
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
                            Icon(
                              redCount > 0
                                  ? Icons.warning_amber_rounded
                                  : (yellowCount > 0 ? Icons.info_outline : Icons.verified_user_outlined),
                              color: summaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              redCount > 0
                                  ? tr('analysis.highRiskDetected')
                                  : (yellowCount > 0 ? tr('analysis.moderateCaution') : tr('analysis.noRiskDetected')),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: summaryColor,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isGeneratingShare ? null : _showShareOptionsModal,
                              icon: _isGeneratingShare
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.share_outlined, size: 16),
                              label: Text(tr('analysis.shareRiskSummary')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isExportingPdf ? null : _exportPdf,
                              icon: const Icon(Icons.download, size: 16),
                              label: Text(tr('analysis.exportPdf')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                                foregroundColor: isDark ? AppColors.darkErrorText : AppColors.lightTextPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Stats Pill Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatPill(
                          tr('analysis.highRiskCount', {'count': '$redCount'}),
                          isDark ? AppColors.darkError : AppColors.lightError,
                          isDark,
                        ),
                        _buildStatPill(
                          tr('analysis.cautionCount', {'count': '$yellowCount'}),
                          isDark ? AppColors.darkCaution : AppColors.lightCaution,
                          isDark,
                        ),
                        _buildStatPill(
                          tr('analysis.compliantCount', {'count': '$greenCount'}),
                          isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                          isDark,
                        ),
                        _buildStatPill(
                          tr('analysis.clausesTotal', {'count': '${widget.analysis.length}'}),
                          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Source Document & Text Card (Rendered directly on the report page)
              if (widget.originalText.trim().isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _effectiveSourceType == 'Photo Scan'
                                  ? Icons.image_rounded
                                  : (_effectiveSourceType == 'Text Description' ? Icons.notes_rounded : Icons.picture_as_pdf_rounded),
                              color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.documentTitle ?? tr('analysis.sourceDocTitle'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _effectiveSourceType,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr('analysis.originalUploaded'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showDocumentViewerModal(context),
                            icon: const Icon(Icons.open_in_full_rounded, size: 14),
                            label: Text(tr('analysis.expandWindow')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      const SizedBox(height: 14),

                      // Inline Photo Preview (if Photo Scan & fileData present)
                      if (widget.fileData != null && widget.fileData!.isNotEmpty && _effectiveSourceType == 'Photo Scan') ...[
                        Builder(builder: (context) {
                          final imgBytes = _getCleanBytes(widget.fileData);
                          if (imgBytes == null) return const SizedBox.shrink();
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 320),
                                  width: double.infinity,
                                  color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                                  child: Image.memory(
                                    imgBytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          );
                        }),
                      ],

                      // Inline PDF Document Viewer Preview (if PDF Document & fileData present)
                      if (widget.fileData != null && widget.fileData!.isNotEmpty && _effectiveSourceType == 'PDF Document') ...[
                        Builder(builder: (context) {
                          final pdfBytes = _getCleanBytes(widget.fileData);
                          if (pdfBytes == null) return const SizedBox.shrink();
                          return Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 380,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SfPdfViewer.memory(
                                    pdfBytes,
                                    canShowScrollHead: true,
                                    canShowScrollStatus: true,
                                    enableDoubleTapZooming: true,
                                    onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                                      debugPrint('PDF viewer load error: ${details.error}');
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          );
                        }),
                      ],

                      // Show text box only for pure text input scans without an uploaded file/image
                      if (widget.fileData == null || widget.fileData!.isEmpty) ...[
                        Text(
                          tr('analysis.originalContractText'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 220),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              widget.originalText,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                fontFamily: 'monospace',
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Clause Analysis Section Header
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.rule_rounded,
                      size: 18,
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('analysis.analyzedClauses'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Clauses List
              ...List.generate(widget.analysis.length, (index) {
                final item = widget.analysis[index];
                final clauseId = (item['clauseId'] ?? '').toString();
                final category = (item['category'] ?? (item['riskLevel'] == 'HIGH_RISK' ? 'Red' : (item['riskLevel'] == 'CAUTION' ? 'Yellow' : 'Green'))).toString();
                final text = (item['text'] ?? '').toString();
                final reason = (item['reason'] ?? '').toString();
                final reraRefs = (item['reraReferences'] is List) ? (item['reraReferences'] as List).join(', ') : '';
                final borderColor = _getBorderColor(context, category);

                return StaggeredEntrance(
                  index: index,
                  child: Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: borderColor, width: 1.2),
                  ),
                  color: _getColorForCategory(context, category),
                  child: InkWell(
                    onTap: () => _explainSnippet(text),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (clauseId.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        clauseId,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Builder(builder: (context) {
                                    final isHighRisk = category.toLowerCase() == 'red' || category.toLowerCase() == 'high' || category.toLowerCase() == 'high_risk';
                                    if (isDark && isHighRisk) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.darkError,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 14,
                                              color: AppColors.darkErrorText,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              category.toUpperCase() == 'RED' ? 'HIGH' : category.toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppColors.darkErrorText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: borderColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        category.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: borderColor,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.touch_app_outlined,
                                    size: 15,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr('analysis.tapToExplain'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: borderColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr('analysis.riskRationale', {'reason': reason}),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      if (reraRefs.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'RERA Citations: $reraRefs',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
              }),
            ],
          ),
          if (_isExplaining)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('analysis.simplifyingJargon'),
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, Color color, bool isDark) {
    final bool isDarkHighRisk = isDark && (color == AppColors.darkError || label.toLowerCase().contains('high'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDarkHighRisk ? AppColors.darkError : color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDarkHighRisk ? AppColors.darkError : color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDarkHighRisk ? AppColors.darkErrorText : color,
        ),
      ),
    );
  }

  String get _effectiveSourceType {
    final title = (widget.documentTitle ?? '').toLowerCase();
    final mime = (widget.mimeType ?? '').toLowerCase();
    final type = (widget.sourceType ?? '').toLowerCase();

    if (title.endsWith('.png') || title.endsWith('.jpg') || title.endsWith('.jpeg') || title.endsWith('.webp') || mime.contains('image') || type.contains('photo') || type.contains('image')) {
      return 'Photo Scan';
    }
    if (title.endsWith('.pdf') || mime.contains('pdf') || type.contains('pdf')) {
      return 'PDF Document';
    }
    return widget.sourceType ?? 'Text Description';
  }

  void _showDocumentViewerModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.documentTitle ?? 'Property Legal Document';
    final sourceType = _effectiveSourceType;

    Uint8List? rawBytes = _getCleanBytes(widget.fileData);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 920,
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.0,
              ),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // --- Modal Header Bar ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            sourceType == 'Photo Scan'
                                ? Icons.image_rounded
                                : (sourceType == 'Text Description' ? Icons.description_rounded : Icons.picture_as_pdf_rounded),
                            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      sourceType,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'In-App Document Viewer',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          tooltip: 'Close Modal',
                        ),
                      ],
                    ),
                  ),

                  // --- In-Modal Tab Bar ---
                  Container(
                    color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                    child: TabBar(
                      labelColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      indicatorColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      indicatorWeight: 2,
                      tabs: [
                        Tab(
                          icon: Icon(
                            sourceType == 'Photo Scan' ? Icons.photo_library_outlined : Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          text: sourceType == 'Photo Scan'
                              ? 'Uploaded Photo View'
                              : (sourceType == 'PDF Document' ? 'Uploaded PDF Document' : 'Document Layout'),
                        ),
                        const Tab(
                          icon: Icon(Icons.text_snippet_outlined, size: 18),
                          text: 'Extracted Original Text',
                        ),
                      ],
                    ),
                  ),

                  // --- Tab View Contents ---
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Uploaded File / PDF / Image Viewer
                        _buildFileViewerTab(context, isDark, sourceType, rawBytes),

                        // Tab 2: Extracted Original Text
                        _buildExtractedTextTab(context, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileViewerTab(BuildContext context, bool isDark, String sourceType, Uint8List? rawBytes) {
    if (rawBytes != null && rawBytes.isNotEmpty) {
      if (sourceType == 'PDF Document') {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SfPdfViewer.memory(
                rawBytes,
                pageLayoutMode: PdfPageLayoutMode.continuous,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                onDocumentLoadFailed: (details) {
                  debugPrint('PDF viewer load error: ${details.error}');
                },
              ),
            ),
          ),
        );
      } else if (sourceType == 'Photo Scan') {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              width: double.infinity,
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              child: Image.memory(
                rawBytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
      }
    }

    final bool isPdf = sourceType == 'PDF Document';
    final bool isPhoto = sourceType == 'Photo Scan';

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : (isPhoto ? Icons.camera_alt_rounded : Icons.description_rounded),
                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPdf ? 'OFFICIAL PDF DOCUMENT RECORD' : (isPhoto ? 'SCANNED PHOTO DOCUMENT RECORD' : 'LEGAL TEXT DOCUMENT RECORD'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                              ),
                            ),
                            Text(
                              widget.documentTitle ?? 'Property Sale Deed Contract',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_outlined, size: 12, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
                          const SizedBox(width: 4),
                          Text(
                            ref.read(localeProvider.notifier).translate('analysis.pageOneOfOne'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                const SizedBox(height: 14),

                // Formatted Page Body Text
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.originalText,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.65,
                          fontFamily: 'serif',
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedTextTab(BuildContext context, bool isDark) {
    final tr = ref.read(localeProvider.notifier).translate;
    final wordCount = widget.originalText.trim().isEmpty ? 0 : widget.originalText.trim().split(RegExp(r'\s+')).length;

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Column(
        children: [
          // Sub-header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('analysis.extractedWords', {'count': '$wordCount'}),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.originalText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('analysis.copySuccess')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(tr('analysis.copyText')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.originalText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      fontFamily: 'monospace',
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}