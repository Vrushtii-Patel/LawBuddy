import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import 'checklist_screen.dart';
import '../widgets/user_profile_button.dart';

class ChecklistsListScreen extends ConsumerStatefulWidget {
  const ChecklistsListScreen({super.key});

  @override
  ConsumerState<ChecklistsListScreen> createState() => _ChecklistsListScreenState();
}

class _ChecklistsListScreenState extends ConsumerState<ChecklistsListScreen> with TickerProviderStateMixin {
  List<dynamic> _checklists = [];
  bool _isLoading = true;
  String? _error;

  // Animation Controllers
  AnimationController? _entryController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

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
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadChecklists();
  }

  @override
  void dispose() {
    _entryController?.dispose();
    super.dispose();
  }

  Future<void> _loadChecklists() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
      final checklists = await ApiService.fetchAllChecklists();
      if (mounted) {
        setState(() {
          _checklists = checklists;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching checklists: $e');
      if (mounted) {
        setState(() {
          _error = 'Unable to load checklists. Please check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) => _loadChecklists());
  }

  Future<void> _deleteChecklist(String type, String title) async {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.3),
            ),
          ),
          title: Text(
            tr('checklists.deleteChecklist'),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          content: Text(
            '${tr('checklists.deleteConfirm')}\n\n"$title"',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                tr('common.cancel'),
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
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                tr('common.delete'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final success = await ApiService.deleteChecklist(type);
      if (success && mounted) {
        setState(() {
          _checklists.removeWhere((c) => c['type'] == type);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('checklists.deletedSuccess')),
            backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting checklist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to delete checklist. Please try again.'),
            backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRenameDialog(String type, String currentTitle) {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentTitle);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              title: Text(
                tr('checklists.renameChecklist'),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  labelText: tr('checklists.titleLabel'),
                  labelStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    tr('common.cancel'),
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newTitle = controller.text.trim();
                          if (newTitle.isEmpty || newTitle == currentTitle) {
                            Navigator.pop(dialogCtx);
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final success = await ApiService.renameChecklist(type, newTitle);
                            if (success.isNotEmpty && mounted) {
                              setState(() {
                                final idx = _checklists.indexWhere((c) => c['type'] == type);
                                if (idx != -1) {
                                  _checklists[idx]['title'] = newTitle;
                                }
                              });
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('checklists.renamedSuccess')),
                                  backgroundColor: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error renaming checklist: $e');
                            setDialogState(() => isSaving = false);
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(
                                  content: const Text('Unable to rename checklist. Please try again.'),
                                  backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          tr('common.save'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateChecklistDialog(BuildContext context, [String? initialPrompt]) {
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: initialPrompt ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
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
                      color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('checklists.createTitle'),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('checklists.createPromptDesc'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: 3,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: tr('checklists.createHint'),
                        hintStyle: TextStyle(
                          color: (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary).withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('checklists.quickPresets'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildPresetChip('Resale Apartment', controller, isDark),
                        _buildPresetChip('RERA Builder Flat', controller, isDark),
                        _buildPresetChip('Commercial Lease', controller, isDark),
                        _buildPresetChip('Open Plot Purchase', controller, isDark),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    tr('common.cancel'),
                    style: GoogleFonts.inter(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final prompt = controller.text.trim();
                          if (prompt.isEmpty) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            final res = await ApiService.generateChecklist(prompt);
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (mounted) {
                              _loadChecklists();
                              _navigateTo(ChecklistScreen(
                                type: (res['type'] ?? prompt).toString(),
                                initialTitle: (res['title'] ?? prompt).toString(),
                              ));
                            }
                          } catch (e) {
                            debugPrint('Error generating checklist: $e');
                            setDialogState(() => isSubmitting = false);
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(
                                  content: const Text('Unable to generate checklist. Please try again.'),
                                  backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          tr('checklists.generateBtn'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String text, TextEditingController controller, bool isDark) {
    return InkWell(
      onTap: () => controller.text = text,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initControllers();
    ref.watch(localeProvider);
    final tr = ref.read(localeProvider.notifier).translate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateChecklistDialog(context),
        backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        foregroundColor: isDark ? AppColors.darkBackground : AppColors.lightTextPrimary,
        elevation: 2,
        hoverElevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          tr('checklists.newBtn'),
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      body: Container(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              // TOP BAR
              _buildTopBar(context, isDark, tr),
              const SizedBox(height: 4),

              // BODY CONTENT
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
                  child: SlideTransition(
                    position: _slideAnimation ?? const AlwaysStoppedAnimation(Offset.zero),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: _isLoading
                            ? _buildLoadingSkeleton(isDark)
                            : _error != null
                                ? _buildErrorState(tr, isDark)
                                : _checklists.isEmpty
                                    ? _buildEmptyState(tr, isDark, isDesktop)
                                    : _buildChecklistCollection(tr, isDark, isDesktop),
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
  Widget _buildTopBar(BuildContext context, bool isDark, String Function(String, [Map<String, String>?]) tr) {
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
                    tr('common.back'),
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

          // Center: Exact dead-center badge (shown only on wider screens to prevent overlap on mobile)
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
                      'PROPERTY DUE DILIGENCE ENGINE',
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
  // HERO INTRO BANNER
  // ==========================================
  Widget _buildHeroIntro(String Function(String, [Map<String, String>?]) tr, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tr('checklists.heroTitle'),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr('checklists.heroHeadline'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr('checklists.heroSub'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
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

  // ==========================================
  // CHECKLIST COLLECTION
  // ==========================================
  Widget _buildChecklistCollection(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
    bool isDesktop,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32.0 : 16.0,
        vertical: 16.0,
      ),
      children: [
        _buildHeroIntro(tr, isDark),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  tr('checklists.casesHeading'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    '${_checklists.length}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._checklists.map((checklist) {
          return _DueDiligenceCaseCard(
            checklist: checklist,
            isDark: isDark,
            tr: tr,
            onTap: () => _navigateTo(ChecklistScreen(
              type: (checklist['type'] ?? '').toString(),
              initialTitle: (checklist['title'] ?? '').toString(),
            )),
            onRename: () => _showRenameDialog(
              (checklist['type'] ?? '').toString(),
              (checklist['title'] ?? tr('checklists.untitled')).toString(),
            ),
            onDelete: () => _deleteChecklist(
              (checklist['type'] ?? '').toString(),
              (checklist['title'] ?? tr('checklists.untitled')).toString(),
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  // ==========================================
  // ONBOARDING EMPTY STATE
  // ==========================================
  Widget _buildEmptyState(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32.0 : 16.0,
        vertical: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildHeroIntro(tr, isDark),
          const SizedBox(height: 12),

          // Layered Document Motif
          _buildLayeredDocumentMotif(isDark),
          const SizedBox(height: 22),

          Text(
            tr('checklists.emptyTitle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              tr('checklists.emptySub'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Primary Create CTA
          ElevatedButton.icon(
            onPressed: () => _showCreateChecklistDialog(context),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              tr('checklists.newChecklist'),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
              foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 40),

          // Quick Start Section
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('checklists.starterTitle'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr('checklists.quickStartSub'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _buildStarterCard(
            title: tr('checklists.template1'),
            subtitle: 'Title deed chain, society NOC, Khata extract & encumbrance check',
            icon: Icons.apartment_rounded,
            isDark: isDark,
            onTap: () => _showCreateChecklistDialog(context, 'Buying a resale apartment in a co-operative housing society'),
          ),
          const SizedBox(height: 10),
          _buildStarterCard(
            title: tr('checklists.template2'),
            subtitle: 'RERA registration, builder-buyer agreement, milestone approvals & CC',
            icon: Icons.domain_rounded,
            isDark: isDark,
            onTap: () => _showCreateChecklistDialog(context, 'Buying an under-construction flat from a RERA registered builder'),
          ),
          const SizedBox(height: 10),
          _buildStarterCard(
            title: tr('checklists.template3'),
            subtitle: 'Lock-in period, security deposit, stamp duty, sub-letting & usage clauses',
            icon: Icons.store_mall_directory_rounded,
            isDark: isDark,
            onTap: () => _showCreateChecklistDialog(context, 'Commercial property lease due diligence and agreement clauses'),
          ),
          const SizedBox(height: 10),
          _buildStarterCard(
            title: tr('checklists.template4'),
            subtitle: 'Title clearance, 7/12 extract, zoning & mutation entries',
            icon: Icons.landscape_rounded,
            isDark: isDark,
            onTap: () => _showCreateChecklistDialog(context, 'Agricultural or open plot land purchase due diligence and title verification'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLayeredDocumentMotif(bool isDark) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.1,
              child: Container(
                width: 34,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
            ),
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.checklist_rounded,
                  size: 24,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarterCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return _HoverStarterCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      isDark: isDark,
      onTap: onTap,
    );
  }

  // ==========================================
  // LOADING SKELETON
  // ==========================================
  Widget _buildLoadingSkeleton(bool isDark) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < 3; i++) ...[
          Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // ERROR RECOVERY STATE
  // ==========================================
  Widget _buildErrorState(
    String Function(String, [Map<String, String>?]) tr,
    bool isDark,
  ) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkError : AppColors.lightError).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, size: 36, color: isDark ? AppColors.darkError : AppColors.lightError),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Checklists',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadChecklists,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(tr('common.retry'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// LEGAL CASE FILE CARD WIDGET
// ==========================================
class _DueDiligenceCaseCard extends StatefulWidget {
  final Map<String, dynamic> checklist;
  final bool isDark;
  final String Function(String, [Map<String, String>?]) tr;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _DueDiligenceCaseCard({
    required this.checklist,
    required this.isDark,
    required this.tr,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_DueDiligenceCaseCard> createState() => _DueDiligenceCaseCardState();
}

class _DueDiligenceCaseCardState extends State<_DueDiligenceCaseCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final title = (widget.checklist['title'] ?? widget.tr('checklists.untitled')).toString();
    final items = widget.checklist['items'] as List<dynamic>? ?? [];
    final totalCount = items.length;
    final completedCount = items.where((i) => i['isCompleted'] == true).length;
    final ratio = totalCount > 0 ? (completedCount / totalCount) : 0.0;
    final percent = (ratio * 100).toInt();
    final isAllDone = totalCount > 0 && completedCount == totalCount;

    final accentColor = isAllDone
        ? (widget.isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
        : (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary);

    final flaggedCount = items.where((i) => i['isCompleted'] != true && (i['status'] == 'FLAGGED' || ((i['linkedIssues'] as List<dynamic>?)?.isNotEmpty == true))).length;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 14),
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? accentColor.withValues(alpha: 0.8)
                  : (isAllDone
                      ? (widget.isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.5)
                      : (flaggedCount > 0
                          ? (widget.isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.4)
                          : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder))),
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Legal dossier icon, Case type & Title, Actions Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isAllDone ? Icons.verified_user_rounded : Icons.folder_shared_rounded,
                        color: accentColor,
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
                                widget.tr('checklists.verificationBadge'),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: accentColor,
                                ),
                              ),
                              if (flaggedCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (widget.isDark ? AppColors.darkCaution : AppColors.lightCaution).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 11,
                                        color: widget.isDark ? AppColors.darkCaution : AppColors.lightCaution,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.tr('checklists.flaggedCountBadge', {'count': flaggedCount.toString()}),
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: widget.isDark ? AppColors.darkCaution : AppColors.lightCaution,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      color: widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      onSelected: (val) {
                        if (val == 'rename') {
                          widget.onRename();
                        } else if (val == 'delete') {
                          widget.onDelete();
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 17,
                                color: widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.tr('checklists.renameChecklist'),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 17,
                                color: widget.isDark ? AppColors.darkError : AppColors.lightError,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.tr('checklists.deleteChecklist'),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: widget.isDark ? AppColors.darkError : AppColors.lightError,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fine Divider
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                const SizedBox(height: 12),

                // Progress Info Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.tr('checklists.dueDiligenceProgress'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Smooth Linear Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: widget.isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Row: Completion Count & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completedCount of $totalCount completed',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: widget.isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAllDone ? Icons.check_circle_rounded : Icons.pending_outlined,
                            size: 12,
                            color: accentColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isAllDone
                                ? widget.tr('checklists.completed')
                                : widget.tr('checklists.inProgress'),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
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
      ),
    );
  }
}

// ==========================================
// STARTER TEMPLATE CARD
// ==========================================
class _HoverStarterCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _HoverStarterCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HoverStarterCard> createState() => _HoverStarterCardState();
}

class _HoverStarterCardState extends State<_HoverStarterCard> {
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
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                  : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: _isHovered
                    ? (widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary)
                    : (widget.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HOVER GLASS BUTTON
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
