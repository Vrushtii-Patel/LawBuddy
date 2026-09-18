import 'dart:convert';
import 'dart:io';
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
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
    _entryController?.dispose();
    _radarController?.dispose();
    _textController.dispose();
    super.dispose();
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
      final String base64Str = base64Encode(bytes);

      if (extractedText.trim().length > 10) {
        await _analyzeText(
          extractedText, 
          title: image.name.isNotEmpty ? image.name : 'Photo Scan Document', 
          sourceType: 'Photo Scan', 
          base64Data: base64Str, 
          mimeType: mimeType
        );
        return;
      }

      // Multimodal AI Vision Fallback (Web, Desktop, or scanned images)
      final analysisResult = await ApiService.scanDocumentFile(bytes, mimeType, title: image.name, sourceType: 'Photo Scan');
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            originalText: analysisResult['extractedText'] ?? 'Scanned Property Image',
            analysis: analysisResult['analysis'] ?? [],
            documentTitle: image.name.isNotEmpty ? image.name : 'Scanned Property Agreement',
            sourceType: 'Photo Scan',
            fileData: base64Str,
            mimeType: mimeType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
      ));
    } finally {
      if (mounted) {
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
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null) {
        setState(() {
          _isProcessing = true;
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
        final String base64Str = base64Encode(uint8bytes);

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
              base64Data: base64Str, 
              mimeType: 'application/pdf'
            );
            return;
          }

          // Multimodal fallback for PDF
          final analysisResult = await ApiService.scanDocumentFile(uint8bytes, 'application/pdf', title: fileName, sourceType: 'PDF Document');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisScreen(
                originalText: analysisResult['extractedText'] ?? 'Scanned PDF Document',
                analysis: analysisResult['analysis'] ?? [],
                documentTitle: fileName,
                sourceType: 'PDF Document',
                fileData: base64Str,
                mimeType: 'application/pdf',
              ),
            ),
          );
        } else {
          // It's an image picked through document picker
          final String mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
          final analysisResult = await ApiService.scanDocumentFile(uint8bytes, mimeType, title: fileName, sourceType: 'Scanned Image');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AnalysisScreen(
                originalText: analysisResult['extractedText'] ?? 'Scanned Document Image',
                analysis: analysisResult['analysis'] ?? [],
                documentTitle: fileName,
                sourceType: 'Scanned Image',
                fileData: base64Str,
                mimeType: mimeType,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error reading document: ${e.toString()}'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _analyzeText(String text, {String? title, String? sourceType, String? base64Data, String? mimeType}) async {
    final loc = ref.read(localeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    setState(() {
      _isProcessing = true;
      _statusMessage = loc.translate('scan.processingRisk');
    });

    try {
      final analysisResult = await ApiService.scanDocument(
        text, 
        title: title, 
        sourceType: sourceType ?? 'Text Description',
        base64Data: base64Data,
        mimeType: mimeType,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            originalText: text,
            analysis: analysisResult['analysis'] ?? [],
            documentTitle: title ?? 'Scanned Property Agreement',
            sourceType: sourceType ?? 'Text Description',
            fileData: base64Data ?? analysisResult['fileData'],
            mimeType: mimeType ?? analysisResult['mimeType'],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
      ));
    } finally {
      if (mounted) {
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
              // TOP BAR
              _buildTopBar(context, isDark, loc),

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
                                      const SizedBox(height: 28),

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
  // TOP BAR
  // ==========================================
  Widget _buildTopBar(BuildContext context, bool isDark, LocaleNotifier loc) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
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

          // Center: True exact center alignment
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
          const SizedBox(height: 18),

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
        Text(
          'End-to-End Encrypted • Legal Documents Are Processed Confidentially Under Indian Privacy Norms',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PROCESSING / ANALYZING STATE (AI RADAR)
  // ==========================================
  Widget _buildProcessingState(bool isDark, LocaleNotifier loc) {
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    return Center(
      key: const ValueKey('processing_state'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Holographic Scanning Radar Orb
            AnimatedBuilder(
              animation: _radarController!,
              builder: (context, child) {
                final radarVal = _radarController!.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer expanding ripple
                    Container(
                      width: 130 + (25 * radarVal),
                      height: 130 + (25 * radarVal),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: (1.0 - radarVal) * 0.35),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Middle pulse ring
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Central Icon
                    Icon(
                      Icons.document_scanner_rounded,
                      size: 42,
                      color: accentColor,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Status message
            Text(
              _statusMessage.isNotEmpty ? _statusMessage : loc.translate('scan.processingRisk'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              loc.translate('scan.pleaseWait'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // AI Progress Indeterminate Bar
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  minHeight: 4,
                ),
              ),
            ),
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
