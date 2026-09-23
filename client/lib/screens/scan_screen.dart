import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/api_service.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import '../widgets/user_profile_button.dart';
import '../widgets/form_consent_widget.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  
  bool _isProcessing = false;
  String _statusMessage = '';
  Map<String, dynamic>? _activeScanJob;
  Map<String, dynamic>? _currentJob;

  // Animations
  AnimationController? _radarController;
  AnimationController? _entryController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  void _initControllers() {
    if (_entryController == null) {
      _entryController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryController!, curve: Curves.easeOutCubic),
      );
      _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
        CurvedAnimation(parent: _entryController!, curve: Curves.easeOutCubic),
      );
      _entryController!.forward();
    }

    _radarController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
    _checkActiveScanJob();
  }

  @override
  void dispose() {
    _radarController?.dispose();
    _entryController?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkActiveScanJob() async {
    try {
      final active = await ApiService.getActiveScanJob();
      if (mounted && active != null) {
        setState(() {
          _activeScanJob = active;
        });
      }
    } catch (_) {}
  }

  Future<void> _resumeOrRetryActiveJob(String jobId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    setState(() {
      _isProcessing = true;
      _currentJob = null;
      _statusMessage = 'Resuming scan...';
    });

    try {
      final retryRes = await ApiService.retryScanJob(jobId);
      await _pollJobUntilComplete(jobId, retryRes);
    } catch (e) {
      debugPrint('Error resuming scan: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      final errorMsg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Unable to resume scan. Please try scanning the document again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMsg.isNotEmpty ? errorMsg : 'Unable to resume scan. Please try scanning the document again.'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pollJobUntilComplete(
    String jobId, 
    Map<String, dynamic> initialStatus, {
    String? originalInputText,
    String? fileData,
    String? mimeType,
    String? customTitle,
    String? sourceType,
    Uint8List? initialFileBytes,
  }) async {
    Map<String, dynamic> job = initialStatus;
    if (mounted) {
      setState(() {
        _currentJob = job;
        _statusMessage = _formatStepMessage(job['status'], job['currentStep']);
      });
    }

    // Immediate cache-hit completion without polling
    if (job['status'] == 'COMPLETED') {
      final doc = job['document'] ?? {};
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisScreen(
              originalText: job['extractedText'] ?? doc['originalText'] ?? originalInputText ?? 'Property Agreement',
              analysis: job['analysis'] ?? doc['analysis'] ?? [],
              documentTitle: job['title'] ?? doc['title'] ?? customTitle ?? 'Scanned Property Agreement',
              sourceType: job['sourceType'] ?? doc['sourceType'] ?? sourceType ?? 'PDF Document',
              fileData: fileData ?? job['fileData'] ?? doc['fileData'],
              mimeType: job['mimeType'] ?? doc['mimeType'] ?? mimeType ?? 'application/pdf',
              documentId: (job['documentId'] ?? doc['_id'] ?? doc['id'])?.toString(),
              initialFileBytes: initialFileBytes,
            ),
          ),
        );
      }
      return;
    }

    int polls = 0;
    const maxPolls = 120; // 3 minutes max

    while (mounted && job['status'] != 'COMPLETED' && job['status'] != 'FAILED' && polls < maxPolls) {
      polls++;
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      try {
        job = await ApiService.getScanJob(jobId);
        if (mounted) {
          setState(() {
            _currentJob = job;
            _statusMessage = _formatStepMessage(job['status'], job['currentStep']);
          });
        }
      } catch (pollErr) {
        debugPrint('Polling transient error: $pollErr');
      }
    }

    if (!mounted) return;

    if (job['status'] == 'COMPLETED') {
      final doc = job['document'] ?? {};
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            originalText: job['extractedText'] ?? doc['originalText'] ?? originalInputText ?? 'Property Agreement',
            analysis: job['analysis'] ?? doc['analysis'] ?? [],
            documentTitle: job['title'] ?? doc['title'] ?? customTitle ?? 'Scanned Property Agreement',
            sourceType: job['sourceType'] ?? doc['sourceType'] ?? sourceType ?? 'PDF Document',
            fileData: fileData ?? job['fileData'] ?? doc['fileData'],
            mimeType: job['mimeType'] ?? doc['mimeType'] ?? mimeType ?? 'application/pdf',
            documentId: (job['documentId'] ?? doc['_id'] ?? doc['id'])?.toString(),
            initialFileBytes: initialFileBytes,
          ),
        ),
      );
    } else if (job['status'] == 'FAILED') {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      setState(() {
        _isProcessing = false;
        _activeScanJob = job;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Scan paused: ${job['errorInfo']?['message'] ?? 'Please retry.'}'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _resumeOrRetryActiveJob(jobId),
        ),
      ));
    } else {
      setState(() {
        _isProcessing = false;
        _activeScanJob = job;
      });
    }
  }

  String _formatStepMessage(String? status, String? currentStep) {
    switch (status) {
      case 'QUEUED':
        return 'Scan queued...';
      case 'UPLOADING':
        return 'Uploading document...';
      case 'OCR_PROCESSING':
        return 'Extracting document...';
      case 'TEXT_EXTRACTED':
        return 'Document text extracted';
      case 'AI_ANALYSIS':
        return 'Analyzing legal clauses...';
      case 'REPORT_GENERATION':
        return 'Generating report...';
      case 'RETRYING':
        return 'Temporarily unavailable — retrying automatically...';
      case 'COMPLETED':
        return 'Analysis completed';
      case 'FAILED':
        return 'Scan paused';
      default:
        return currentStep ?? 'Processing document...';
    }
  }

  Future<void> _scanImage(ImageSource source) async {
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _currentJob = null;
        _statusMessage = loc.translate('scan.processingPhoto');
      });

      String extractedText = '';

      if (_isMobile) {
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        try {
          final inputImage = InputImage.fromFilePath(image.path);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          extractedText = recognizedText.text;
        } catch (mlKitErr) {
          debugPrint('MLKit local OCR error, falling back to server vision: $mlKitErr');
        } finally {
          textRecognizer.close();
        }
      }

      final Uint8List bytes = await image.readAsBytes();
      final String mimeType = image.mimeType ?? (image.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');

      if (extractedText.trim().length > 10) {
        await _analyzeText(
          extractedText, 
          title: image.name.isNotEmpty ? image.name : 'Photo Scan Document', 
          sourceType: 'Photo Scan', 
          fileBytes: bytes,
          fileName: image.name.isNotEmpty ? image.name : 'photo_scan.jpg',
          mimeType: mimeType
        );
        return;
      }

      // Multimodal AI Vision Fallback (Web, Desktop, or scanned images)
      final startRes = await ApiService.startScanJob(
        fileBytes: bytes,
        fileName: image.name.isNotEmpty ? image.name : 'photo_scan.jpg',
        mimeType: mimeType,
        title: image.name.isNotEmpty ? image.name : 'Photo Scan Document',
        sourceType: 'Photo Scan',
      );

      final String jobId = startRes['jobId'] ?? '';
      if (jobId.isNotEmpty) {
        await _pollJobUntilComplete(
          jobId,
          startRes,
          mimeType: mimeType,
          customTitle: image.name.isNotEmpty ? image.name : 'Scanned Property Agreement',
          sourceType: 'Photo Scan',
          initialFileBytes: bytes,
        );
      } else {
        throw Exception('Failed to initialize scan job.');
      }    } catch (e) {
      debugPrint('Error processing photo scan: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Unable to process the photo scan. Please ensure the image is clear and try again.'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted && _currentJob?['status'] != 'COMPLETED') {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _scanPdf() async {
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _isProcessing = true;
          _currentJob = null;
          _statusMessage = loc.translate('scan.processingPdf');
        });

        final PlatformFile file = result.files.single;
        List<int>? bytes = file.bytes?.toList();
        if (bytes == null && file.path != null) {
          final ioFile = File(file.path!);
          bytes = await ioFile.readAsBytes();
        }

        if (bytes == null || bytes.isEmpty) {
          throw Exception('Could not read selected document file.');
        }

        final Uint8List uint8bytes = Uint8List.fromList(bytes);
        final String fileName = file.name;
        final String ext = fileName.split('.').last.toLowerCase();

        if (ext == 'pdf') {
          String extractedText = '';
          try {
            final PdfDocument document = PdfDocument(inputBytes: uint8bytes);
            extractedText = PdfTextExtractor(document).extractText();
            document.dispose();
          } catch (pdfErr) {
            debugPrint('Syncfusion PDF extraction error, falling back to server: $pdfErr');
          }

          if (extractedText.trim().length > 10) {
            await _analyzeText(
              extractedText, 
              title: fileName, 
              sourceType: 'PDF Document', 
              fileBytes: uint8bytes,
              fileName: fileName,
              mimeType: 'application/pdf'
            );
            return;
          }

          // Multimodal fallback for PDF
          final startRes = await ApiService.startScanJob(
            fileBytes: uint8bytes,
            fileName: fileName,
            mimeType: 'application/pdf',
            title: fileName,
            sourceType: 'PDF Document',
          );

          final String jobId = startRes['jobId'] ?? '';
          if (jobId.isNotEmpty) {
            await _pollJobUntilComplete(
              jobId,
              startRes,
              mimeType: 'application/pdf',
              customTitle: fileName,
              sourceType: 'PDF Document',
              initialFileBytes: uint8bytes,
            );
          } else {
            throw Exception('Failed to initialize scan job.');
          }
        } else {
          // It's an image picked through document picker
          final String mimeType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
          final startRes = await ApiService.startScanJob(
            fileBytes: uint8bytes,
            fileName: fileName,
            mimeType: mimeType,
            title: fileName,
            sourceType: 'Scanned Image',
          );

          final String jobId = startRes['jobId'] ?? '';
          if (jobId.isNotEmpty) {
            await _pollJobUntilComplete(
              jobId,
              startRes,
              mimeType: mimeType,
              customTitle: fileName,
              sourceType: 'Scanned Image',
              initialFileBytes: uint8bytes,
            );
          } else {
            throw Exception('Failed to initialize scan job.');
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading document file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Unable to read the selected file.'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted && _currentJob?['status'] != 'COMPLETED') {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _analyzeText(
    String text, {
    String? title, 
    String? sourceType,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
    String? base64Data,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    setState(() {
      _isProcessing = true;
      _currentJob = null;
      _statusMessage = 'Analyzing legal provisions...';
    });

    try {
      final startRes = await ApiService.startScanJob(
        text: text,
        title: title,
        sourceType: sourceType ?? 'Text Description',
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: mimeType,
        base64Data: base64Data,
      );

      final String jobId = startRes['jobId'] ?? '';
      if (jobId.isNotEmpty) {
        await _pollJobUntilComplete(
          jobId,
          startRes,
          originalInputText: text,
          mimeType: mimeType,
          customTitle: title,
          sourceType: sourceType ?? 'Text Description',
          initialFileBytes: fileBytes,
        );
      } else {
        throw Exception('Failed to initialize scan job.');
      }
    } catch (e) {
      debugPrint('Error analyzing document text: $e');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Unable to complete document analysis. Please check your connection and try again.'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted && _currentJob?['status'] != 'COMPLETED') {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _loadSampleAgreement() {
    _textController.text = '''BUILDER-BUYER AGREEMENT CLAUSES (EXCERPT)

1. HANDOVER TIMELINE & DELAY PENALTY:
The Developer agrees to offer possession of the Apartment within 36 months from the date of sanction of building plans. If the Developer fails to deliver possession within the stipulated time, the Developer shall pay compensation to the Allottee calculated at ₹5 per sq. ft. of super built-up area per month for the period of delay.

2. ALLOTTEE DEFAULT & CANCELLATION:
If the Allottee fails to pay any installment on the due date, interest at the rate of 18% per annum compounded monthly shall be payable by the Allottee on the delayed amount. If default persists beyond 30 days, the Developer reserves the right to cancel the allotment and forfeit 20% of the total consideration.

3. ESCROW ACCOUNT & PAYMENT MILESTONES:
All amounts paid by the Allottee shall be deposited into the general operating account of the Developer. The Developer reserves the right to alter construction milestones and demand progress payments accordingly.

4. SUPER AREA VS CARPET AREA VARIATION:
The final sale consideration is subject to variation based on architectural revisions. Any increase in the super built-up area up to 10% shall be billed additionally to the Allottee at prevailing market rates.

5. INDEMNITY & STATUTORY CLEARANCES:
The Developer represents that necessary zoning approvals are under application with local municipal bodies and environmental clearance will be obtained prior to occupancy certificate issuance.''';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _initControllers();
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              // TOP BAR
              _buildTopBar(context, isDark, loc),
              const SizedBox(height: 4),

              // BODY CONTENT
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isProcessing
                      ? _buildProcessingState(isDark, loc)
                      : FadeTransition(
                          opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                          child: SlideTransition(
                            position: _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 48.0 : 20.0,
                                vertical: 16.0,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1040),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // HERO HEADER
                                      _buildHeroHeader(isDark, loc, isDesktop),
                                      const SizedBox(height: 20),

                                      // RESUMABLE SCAN JOB BANNER (IF ACTIVE/INCOMPLETE SCAN EXISTS)
                                      if (_activeScanJob != null) ...[
                                        _buildActiveJobBanner(isDark, loc),
                                        const SizedBox(height: 24),
                                      ],

                                      // 3 ACTION CARDS (CAMERA, GALLERY, PDF)
                                      _buildUploadOptionsGrid(isDark, loc, isDesktop),
                                      const SizedBox(height: 36),

                                      // STYLISH DIVIDER
                                      _buildSectionDivider(isDark, loc),
                                      const SizedBox(height: 32),

                                      // DIRECT TEXT INPUT STUDIO
                                      _buildDirectTextInputCard(isDark, loc, isDesktop),
                                      const SizedBox(height: 48),

                                      // SECURITY & PRIVACY FOOTER
                                      _buildSecurityBadge(isDark),
                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RESUMABLE SCAN JOB BANNER
  // ==========================================
  Widget _buildActiveJobBanner(bool isDark, LocaleNotifier loc) {
    final job = _activeScanJob!;
    final jobId = job['jobId'] ?? '';
    final title = job['title'] ?? 'Unfinished Document Scan';
    final status = job['status'] ?? 'QUEUED';
    final currentStep = _formatStepMessage(status, job['currentStep']);
    final isFailed = status == 'FAILED';

    final Color cardBorderColor = isFailed
        ? (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.4)
        : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.4);

    final Color cardBgColor = isFailed
        ? (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.08)
        : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isFailed ? Colors.orange : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)).withValues(alpha: 0.15),
            ),
            child: Icon(
              isFailed ? Icons.warning_amber_rounded : Icons.sync_rounded,
              color: isFailed ? Colors.orange : (isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Unfinished Scan in Progress',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isFailed ? Colors.orange : Colors.blue).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isFailed ? Colors.orange : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$title • $currentStep',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _resumeOrRetryActiveJob(jobId),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isFailed ? Icons.refresh_rounded : Icons.play_arrow_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  isFailed ? 'Retry' : 'Resume',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            tooltip: 'Dismiss',
            onPressed: () {
              setState(() {
                _activeScanJob = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOP BAR
  // ==========================================
  Widget _buildTopBar(BuildContext context, bool isDark, LocaleNotifier loc) {
    final isDesktopOrTablet = MediaQuery.of(context).size.width >= 700;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Back button
          Align(
            alignment: Alignment.centerLeft,
            child: _HoverGlassButton(
              onTap: () => Navigator.of(context).pop(),
              isDark: isDark,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.translate('common.back'),
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center: True exact center alignment (desktop/tablet only to avoid mobile overlap)
          if (isDesktopOrTablet)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI CONTRACT VERIFICATION STUDIO',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right: Profile Button
          const Align(
            alignment: Alignment.centerRight,
            child: UserProfileButton(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HERO HEADER
  // ==========================================
  Widget _buildHeroHeader(bool isDark, LocaleNotifier loc, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Eyebrow Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'RERA COMPLIANCE • LEGAL OCR • RISK DETECTION',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Main Title
        Text(
          loc.translate('scan.title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: isDesktop ? 30 : 22,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            loc.translate('scan.subtitle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isDesktop ? 14.5 : 13.5,
              height: 1.45,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Supported Formats Pills
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFormatPill('Physical Deed Photos', Icons.camera_alt_outlined, isDark ? AppColors.darkAccent : AppColors.lightPrimary, isDark),
            _buildFormatPill('Gallery Scans & PNGs', Icons.image_outlined, isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, isDark),
            _buildFormatPill('PDF Agreements', Icons.picture_as_pdf_outlined, isDark ? AppColors.darkAccent : AppColors.lightPrimary, isDark),
            _buildFormatPill('Direct Clause Paste', Icons.notes_outlined, isDark ? AppColors.darkSecondary : AppColors.lightSecondary, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatPill(String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UPLOAD OPTIONS GRID (CAMERA, GALLERY, PDF)
  // ==========================================
  Widget _buildUploadOptionsGrid(bool isDark, LocaleNotifier loc, bool isDesktop) {
    final uploadCards = [
      _UploadActionCardData(
        title: loc.translate('scan.takePhoto'),
        description: 'Instant OCR scanning of physical deed pages via camera.',
        icon: Icons.camera_enhance_rounded,
        accentColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        badgeText: 'CAMERA SCAN',
        onTap: () => _scanImage(ImageSource.camera),
      ),
      _UploadActionCardData(
        title: loc.translate('scan.uploadFromGallery'),
        description: 'Upload high-resolution document photos or screenshots.',
        icon: Icons.photo_library_outlined,
        accentColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        badgeText: 'PHOTO GALLERY',
        onTap: () => _scanImage(ImageSource.gallery),
      ),
      _UploadActionCardData(
        title: loc.translate('scan.uploadPdf'),
        description: 'Upload multi-page PDF agreements & registry documents.',
        icon: Icons.picture_as_pdf_outlined,
        accentColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        badgeText: 'PDF DOCUMENT',
        onTap: _scanPdf,
      ),
    ];

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: uploadCards.map((card) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _UploadActionCard(
                data: card,
                isDark: isDark,
              ),
            ),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: uploadCards.map((card) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: _UploadActionCard(
              data: card,
              isDark: isDark,
            ),
          );
        }).toList(),
      );
    }
  }

  // ==========================================
  // SECTION DIVIDER
  // ==========================================
  Widget _buildSectionDivider(bool isDark, LocaleNotifier loc) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Text(
              '${loc.translate('common.or')} PASTE DOCUMENT CLAUSES',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // DIRECT TEXT INPUT STUDIO
  // ==========================================
  Widget _buildDirectTextInputCard(bool isDark, LocaleNotifier loc, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      padding: EdgeInsets.all(isDesktop ? 24.0 : 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Action Helpers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('scan.documentContent'),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            loc.translate('scan.pastePrompt'),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sample Agreement Quick-Load Helper
              TextButton.icon(
                onPressed: _loadSampleAgreement,
                icon: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                ),
                label: Text(
                  'Load Sample Agreement',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Styled TextField Studio
          _StudioTextField(
            controller: _textController,
            hintText: loc.translate('scan.pasteHint'),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // Document Processing Consent Acknowledgement
          const FormConsentAcknowledgement(
            type: FormConsentType.documentUpload,
            showTerms: false,
            showPrivacy: true,
          ),
          const SizedBox(height: 14),

          // Bottom CTA Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Clear button
              if (_textController.text.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => _textController.clear()),
                  icon: Icon(Icons.clear_rounded, size: 14, color: isDark ? AppColors.darkError : AppColors.lightError),
                  label: Text(
                    'Clear',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkError : AppColors.lightError,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              // Primary Analyze CTA Button
              _AnalyzeSubmitButton(
                label: loc.translate('scan.analyzeBtn'),
                isDark: isDark,
                onPressed: () {
                  final text = _textController.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.translate('scan.emptyError'),
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                    return;
                  }
                  _analyzeText(text);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECURITY & PRIVACY FOOTER
  // ==========================================
  Widget _buildSecurityBadge(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'End-to-End Encrypted • Legal Documents Are Processed Confidentially Under Indian Privacy Norms',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PROCESSING / ANALYZING STATE
  // ==========================================
  Widget _buildProcessingState(bool isDark, LocaleNotifier loc) {
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;
    final cautionColor = isDark ? AppColors.darkCaution : AppColors.lightCaution;

    final String status = (_currentJob?['status'] as String?) ?? 'OCR_PROCESSING';
    final bool isRetrying = status == 'RETRYING';

    if (_radarController != null && !_radarController!.isAnimating) {
      _radarController!.repeat();
    }

    return Center(
      key: const ValueKey('processing_state'),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Holographic Scanning Radar Orb with Animated Scan Line
            AnimatedBuilder(
              animation: _radarController!,
              builder: (context, child) {
                final radarVal = _radarController!.value;
                final pulse = (math.sin(radarVal * 2 * math.pi) + 1) / 2;
                final scanY = -18.0 + (36.0 * radarVal);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer subtle boundary ring
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.12 + (0.08 * pulse)),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Inner circle container with scanning laser effect
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: isDark ? 0.06 : 0.08),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35 + (0.15 * pulse)),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Document Icon in center with subtle pulsing glow
                            Icon(
                              Icons.document_scanner_rounded,
                              size: 34,
                              color: accentColor.withValues(alpha: 0.85 + (0.15 * pulse)),
                              shadows: [
                                Shadow(
                                  color: accentColor.withValues(alpha: 0.25 + (0.25 * pulse)),
                                  blurRadius: 6 + (4 * pulse),
                                ),
                              ],
                            ),

                            // Subtle Scan Beam Trail (Soft gradient above the scan line)
                            Transform.translate(
                              offset: Offset(0, scanY - 6),
                              child: Container(
                                width: 38,
                                height: 12,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      accentColor.withValues(alpha: 0.0),
                                      accentColor.withValues(alpha: 0.12),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Horizontal Scanning Line
                            Transform.translate(
                              offset: Offset(0, scanY),
                              child: Container(
                                width: 38,
                                height: 1.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      accentColor.withValues(alpha: 0.0),
                                      accentColor.withValues(alpha: 0.85),
                                      accentColor.withValues(alpha: 0.0),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.45),
                                      blurRadius: 3,
                                      spreadRadius: 0.5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Main Title
            Text(
              loc.translate('scan.analyzingTitle'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle — animates between pipeline stages (e.g. "Reading
            // pages..." -> "Classifying clauses...") instead of snapping,
            // so the progression through the pipeline feels continuous.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) {
                final slideIn = Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slideIn, child: child),
                );
              },
              child: Text(
                _statusMessage.isNotEmpty ? _statusMessage : loc.translate('scan.pleaseWait'),
                key: ValueKey<String>(_statusMessage.isNotEmpty ? _statusMessage : loc.translate('scan.pleaseWait')),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),

            // Automatic Retry Alert Banner (if transient AI rate limit encountered)
            if (isRetrying) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cautionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cautionColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync_problem_rounded, size: 18, color: cautionColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentJob?['currentStep'] ?? loc.translate('scan.retryingStatus'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cautionColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// UPLOAD ACTION CARD MODEL & WIDGET
// ==========================================
class _UploadActionCardData {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String badgeText;
  final VoidCallback onTap;

  _UploadActionCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.onTap,
  });
}

class _UploadActionCard extends StatefulWidget {
  final _UploadActionCardData data;
  final bool isDark;

  const _UploadActionCard({
    required this.data,
    required this.isDark,
  });

  @override
  State<_UploadActionCard> createState() => _UploadActionCardState();
}

class _UploadActionCardState extends State<_UploadActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.data;
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? item.accentColor.withValues(alpha: 0.8)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Icon Container + Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: item.accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(item.icon, color: item.accentColor, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          item.badgeText,
                          style: GoogleFonts.inter(
                            color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    item.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bottom Action Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select & Upload',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// STUDIO TEXTFIELD
// ==========================================
class _StudioTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool isDark;

  const _StudioTextField({
    required this.controller,
    this.hintText,
    required this.isDark,
  });

  @override
  State<_StudioTextField> createState() => _StudioTextFieldState();
}

class _StudioTextFieldState extends State<_StudioTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused
              ? (isDark ? AppColors.darkAccent : AppColors.lightPrimary)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: _isFocused ? 1.5 : 1.0,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        minLines: 8,
        maxLines: 16,
        style: GoogleFonts.inter(
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontSize: 14,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Paste agreement text here...',
          hintStyle: GoogleFonts.inter(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontSize: 13.5,
          ),
          filled: false,
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ==========================================
// ANALYZE SUBMIT BUTTON
// ==========================================
class _AnalyzeSubmitButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isDark;

  const _AnalyzeSubmitButton({
    required this.label,
    required this.onPressed,
    required this.isDark,
  });

  @override
  State<_AnalyzeSubmitButton> createState() => _AnalyzeSubmitButtonState();
}

class _AnalyzeSubmitButtonState extends State<_AnalyzeSubmitButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                .withValues(alpha: _isHovered ? 0.9 : 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                color: widget.isDark ? AppColors.darkBackground : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: widget.isDark ? AppColors.darkBackground : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: widget.isDark ? AppColors.darkBackground : Colors.white,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HOVER GLASS BUTTON HELPER
// ==========================================
class _HoverGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const _HoverGlassButton({
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_HoverGlassButton> createState() => _HoverGlassButtonState();
}

class _HoverGlassButtonState extends State<_HoverGlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface)
                : (widget.isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}