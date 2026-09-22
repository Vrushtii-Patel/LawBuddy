import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'scan_screen.dart';
import 'checklists_list_screen.dart';
import 'analysis_screen.dart';
import 'recent_documents_screen.dart';
import 'home/home_widgets.dart';
import 'home/home_sidebar.dart';
import 'home/home_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<RecentDocItem> _recentDocs = [];
  List<dynamic> _checklists = [];
  List<dynamic> _legalNews = [];
  bool _isLoadingDocs = false;
  bool _isLoadingNews = false;

  @override
  void initState() {
    super.initState();
    // Entrance animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    _loadRecentDocuments();
    _loadChecklists();
    _loadLegalNews();
  }

  Future<void> _loadRecentDocuments() async {
    if (!mounted) return;
    setState(() => _isLoadingDocs = true);
    try {
      final rawDocs = await ApiService.fetchRecentDocuments();
      if (mounted) {
        setState(() {
          _recentDocs = rawDocs
              .map((d) => RecentDocItem.fromJson(d as Map<String, dynamic>))
              .toList();
          _isLoadingDocs = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading documents: $e');
      if (mounted) setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _loadChecklists() async {
    try {
      final cls = await ApiService.fetchAllChecklists();
      if (mounted) {
        setState(() {
          _checklists = cls;
        });
      }
    } catch (e) {
      debugPrint('Error loading checklists: $e');
    }
  }

  Future<void> _loadLegalNews() async {
    if (!mounted) return;
    setState(() => _isLoadingNews = true);
    try {
      final news = await ApiService.getLegalNews();
      if (mounted) {
        setState(() {
          _legalNews = news;
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading legal news: $e');
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    ).then((_) {
      if (mounted) _loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    final String greetingName = (user?.fullName != null && user!.fullName.trim().isNotEmpty)
        ? user.fullName.trim().split(' ').first
        : 'User';

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop ? SidebarDrawer(isDark: isDark, user: user, legalNews: _legalNews, onNavigate: _navigateTo) : null,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // 1. PRIMARY PERSISTENT SIDEBAR NAVIGATION
          // ==========================================
          if (isDesktop)
            DesktopSidebar(isDark: isDark, user: user, legalNews: _legalNews, onNavigate: _navigateTo),

          // ==========================================
          // 2. INTELLIGENT WORKSPACE / DASHBOARD
          // ==========================================
          Expanded(
            child: Container(
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              child: SafeArea(
                child: Column(
                    children: [
                          // Top Navigation Bar (Mobile / Drawer only)
                          if (!isDesktop) TopNavBar(isDark: isDark, scaffoldKey: _scaffoldKey),

                          // Scrollable Workspace Content
                          Expanded(
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 32.0 : 18.0,
                                    vertical: 24.0,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 1200),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // A. Workspace Greeting & Hero
                                          HeaderGreeting(isDark: isDark, isDesktop: isDesktop, userName: greetingName),
                                          const SizedBox(height: 24),

                                          // B. High-Level Real-Data Summary Metrics Row
                                          _buildSummaryMetricsRow(context, isDark, isDesktop),
                                          const SizedBox(height: 28),

                                          // C. Main Workspace Feature: Latest Document Analysis Review
                                          _buildLatestDocumentReview(context, isDark, isDesktop),
                                          const SizedBox(height: 28),

                                          // D & E & F. 2-Column Intelligence Grid
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              if (constraints.maxWidth >= 900) {
                                                return Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      flex: 6,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          _buildRiskBreakdownCard(context, isDark),
                                                          const SizedBox(height: 24),
                                                          _buildChecklistProgressCard(context, isDark),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 24),
                                                    Expanded(
                                                      flex: 5,
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          _buildRecentActivityCard(context, isDark),
                                                          const SizedBox(height: 24),
                                                          _buildLegalUpdatesCard(context, isDark),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              } else {
                                                return Column(
                                                  children: [
                                                    _buildRiskBreakdownCard(context, isDark),
                                                    const SizedBox(height: 24),
                                                    _buildChecklistProgressCard(context, isDark),
                                                    const SizedBox(height: 24),
                                                    _buildRecentActivityCard(context, isDark),
                                                    const SizedBox(height: 24),
                                                    _buildLegalUpdatesCard(context, isDark),
                                                  ],
                                                );
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 28),

                                          // G. RERA Statutory Advisory Notice
                                          _buildReraAwarenessCard(context, isDark, isDesktop),
                                          const SizedBox(height: 40),
                                        ],
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
                ),
              ],
            ),
          );
  }

  // ==========================================
  // B. SUMMARY METRICS ROW (REAL DATA ONLY)
  // ==========================================
  Widget _buildSummaryMetricsRow(BuildContext context, bool isDark, bool isDesktop) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final int analyzedDocsCount = _recentDocs
        .where((d) => d.analysisStatus == 'completed' || d.analysis.isNotEmpty)
        .length;

    int highRiskFlags = 0;
    for (final doc in _recentDocs) {
      if (doc.analysis.isNotEmpty) {
        for (final item in doc.analysis) {
          if (item is Map) {
            final rLevel = (item['riskLevel'] ?? item['category'] ?? '').toString().toLowerCase();
            if (rLevel.contains('high') || rLevel.contains('red')) {
              highRiskFlags++;
            }
          }
        }
      } else if (doc.riskLabel.toLowerCase().contains('high')) {
        highRiskFlags++;
      }
    }

    final int checklistCount = _checklists.length;

    int totalTasks = 0;
    int completedTasks = 0;
    for (final cl in _checklists) {
      final items = (cl['items'] as List<dynamic>?) ?? [];
      totalTasks += items.length;
      completedTasks += items.where((it) => it['isCompleted'] == true).length;
    }
    final double checklistProgress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    final cards = [
      WorkspaceMetricData(
        icon: Icons.description_outlined,
        title: loc.translate('home.totalScannedDocs'),
        value: analyzedDocsCount.toString(),
        subtitle: loc.translate('home.totalScannedDocsSub'),
        accentColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      ),
      WorkspaceMetricData(
        icon: highRiskFlags > 0 ? Icons.warning_amber_rounded : Icons.shield_outlined,
        title: loc.translate('home.highRiskCount'),
        value: highRiskFlags.toString(),
        subtitle: highRiskFlags > 0
            ? '$highRiskFlags ${loc.translate('home.highRiskCountSub')}'
            : loc.translate('home.noHighRisks'),
        accentColor: highRiskFlags > 0
            ? (isDark ? AppColors.darkError : AppColors.lightError)
            : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
      ),
      WorkspaceMetricData(
        icon: Icons.checklist_rounded,
        title: loc.translate('home.dueDiligenceProgress'),
        value: '${(checklistProgress * 100).toInt()}%',
        subtitle: totalTasks > 0 ? '$completedTasks of $totalTasks tasks done' : loc.translate('home.checklistZeroTasks'),
        accentColor: isDark ? AppColors.darkAccent : AppColors.lightAccent,
      ),
      WorkspaceMetricData(
        icon: Icons.assignment_outlined,
        title: loc.translate('home.activeChecklists'),
        value: checklistCount.toString(),
        subtitle: checklistCount == 0
            ? loc.translate('home.activeChecklistsZero')
            : loc.translate('home.activeChecklistsBadge', {
                'count': checklistCount.toString(),
                'unit': loc.translate(checklistCount == 1 ? 'home.checklistUnitSingular' : 'home.checklistUnitPlural'),
              }),
        accentColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 860) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: WorkspaceMetricCard(data: cards[i], isDark: isDark)),
              ],
            ],
          );
        } else if (constraints.maxWidth >= 520) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: WorkspaceMetricCard(data: cards[0], isDark: isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: WorkspaceMetricCard(data: cards[1], isDark: isDark)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: WorkspaceMetricCard(data: cards[2], isDark: isDark)),
                  const SizedBox(width: 14),
                  Expanded(child: WorkspaceMetricCard(data: cards[3], isDark: isDark)),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WorkspaceMetricCard(data: c, isDark: isDark),
                    ))
                .toList(),
          );
        }
      },
    );
  }

  // ==========================================
  // C. MAIN WORKSPACE: LATEST DOCUMENT REVIEW
  // ==========================================
  Widget _buildLatestDocumentReview(BuildContext context, bool isDark, bool isDesktop) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final bool hasDocs = _recentDocs.isNotEmpty;
    final RecentDocItem? latestDoc = hasDocs ? _recentDocs.first : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(Icons.analytics_outlined, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('home.latestAnalysisReview'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            loc.translate('home.latestAnalysisSub'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDocs) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _navigateTo(const RecentDocumentsScreen()),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.translate('home.viewAll', {'count': _recentDocs.length.toString()}),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // Content: Active Latest Document vs Empty State
          if (_isLoadingDocs && _recentDocs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                ),
              ),
            )
          else if (!hasDocs || latestDoc == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 26,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.translate('home.noAgreementsScanned'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.translate('home.uploadOrScanAgreement'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _navigateTo(const ScanScreen()),
                      icon: const Icon(Icons.document_scanner_outlined, size: 15),
                      label: Text(
                        loc.translate('home.scanNewDocument'),
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;

                  final docInfo = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: latestDoc.riskColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: latestDoc.riskColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(latestDoc.riskIcon, size: 12, color: latestDoc.riskColor),
                                const SizedBox(width: 4),
                                Text(
                                  latestDoc.riskLabel,
                                  style: GoogleFonts.inter(
                                    color: latestDoc.riskColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${latestDoc.sourceType} • ${latestDoc.dateText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        latestDoc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestDoc.analysis.isNotEmpty
                            ? loc.translate('home.clausesEvaluated', {'count': latestDoc.analysis.length.toString()})
                            : loc.translate('home.assessmentComplete'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  );

                  final actionButton = ElevatedButton.icon(
                    onPressed: () {
                      if (latestDoc.analysis.isNotEmpty && latestDoc.originalText.isNotEmpty) {
                        _navigateTo(
                          AnalysisScreen(
                            originalText: latestDoc.originalText,
                            analysis: latestDoc.analysis,
                            documentTitle: latestDoc.title,
                            sourceType: latestDoc.sourceType,
                            fileData: latestDoc.fileData,
                            mimeType: latestDoc.mimeType,
                            documentId: latestDoc.id,
                          ),
                        );
                      } else {
                        _navigateTo(const RecentDocumentsScreen());
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: Text(
                      loc.translate('home.viewFullAnalysis'),
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        docInfo,
                        const SizedBox(height: 14),
                        actionButton,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: docInfo),
                      const SizedBox(width: 16),
                      actionButton,
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // D. RISK BREAKDOWN CARD
  // ==========================================
  Widget _buildRiskBreakdownCard(BuildContext context, bool isDark) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final int total = _recentDocs.length;
    final int highRisk = _recentDocs.where((d) => d.riskLabel.toLowerCase().contains('high')).length;
    final int mediumRisk = _recentDocs.where((d) => d.riskLabel.toLowerCase().contains('medium') || d.riskLabel.toLowerCase().contains('caution')).length;
    final int lowRisk = total - highRisk - mediumRisk > 0 ? (total - highRisk - mediumRisk) : 0;

    final double highPct = total > 0 ? (highRisk / total) : 0.0;
    final double medPct = total > 0 ? (mediumRisk / total) : 0.0;
    final double lowPct = total > 0 ? (lowRisk / total) : (total == 0 ? 1.0 : 0.0);

    final errorColor = isDark ? AppColors.darkError : AppColors.lightError;
    final cautionColor = isDark ? AppColors.darkCaution : AppColors.lightCaution;
    final successColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pie_chart_outline_rounded, color: errorColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('home.riskDistribution'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      loc.translate('home.riskDistributionSub'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Multi-Segment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              width: double.infinity,
              child: Row(
                children: [
                  if (highPct > 0)
                    Flexible(
                      flex: (highPct * 100).toInt(),
                      child: Container(color: errorColor),
                    ),
                  if (medPct > 0)
                    Flexible(
                      flex: (medPct * 100).toInt(),
                      child: Container(color: cautionColor),
                    ),
                  if (lowPct > 0)
                    Flexible(
                      flex: (lowPct * 100).toInt(),
                      child: Container(color: successColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _buildRiskLegendItem(
                color: errorColor,
                label: loc.translate('home.highRiskLabel'),
                count: highRisk,
                isDark: isDark,
              ),
              _buildRiskLegendItem(
                color: cautionColor,
                label: loc.translate('home.mediumRiskLabel'),
                count: mediumRisk,
                isDark: isDark,
              ),
              _buildRiskLegendItem(
                color: successColor,
                label: loc.translate('home.lowRiskLabel'),
                count: total > 0 ? lowRisk : 0,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Analysis Summary Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: highRisk > 0
                  ? errorColor.withValues(alpha: isDark ? 0.12 : 0.08)
                  : successColor.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highRisk > 0
                    ? errorColor.withValues(alpha: 0.25)
                    : successColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  highRisk > 0 ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                  size: 15,
                  color: highRisk > 0 ? errorColor : successColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highRisk > 0
                        ? '$highRisk high-risk clauses flagged across analyzed documents'
                        : 'All analyzed documents within normal legal risk parameters',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLegendItem({
    required Color color,
    required String label,
    required int count,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // E. DUE DILIGENCE CHECKLIST PROGRESS CARD
  // ==========================================
  Widget _buildChecklistProgressCard(BuildContext context, bool isDark) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    int totalTasks = 0;
    int completedTasks = 0;
    String activeTitle = loc.translate('home.defaultChecklistTitle');
    List<dynamic> pendingItems = [];

    for (final cl in _checklists) {
      if (cl['title'] != null && cl['title'].toString().isNotEmpty) {
        activeTitle = cl['title'].toString();
      }
      final items = (cl['items'] as List<dynamic>?) ?? [];
      totalTasks += items.length;
      for (final it in items) {
        if (it['isCompleted'] == true) {
          completedTasks++;
        } else if (pendingItems.length < 3) {
          pendingItems.add(it);
        }
      }
    }
    final double checklistProgress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkAccent : AppColors.lightAccent).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.checklist_rounded, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('home.dueDiligenceSection'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            activeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(checklistProgress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              width: double.infinity,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: checklistProgress > 0 ? checklistProgress : 0.0,
                child: Container(color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Sample Upcoming Tasks
          if (pendingItems.isNotEmpty) ...[
            for (final it in pendingItems)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked_rounded,
                      size: 15,
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (it['task'] ?? it['title'] ?? loc.translate('home.defaultTaskTitle')).toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Text(
              totalTasks > 0 ? loc.translate('home.allTasksDone') : loc.translate('home.noActiveChecklists'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),

          // Action Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _navigateTo(const ChecklistsListScreen()),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: Text(
                loc.translate('home.openChecklist'),
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // F. RECENT ACTIVITY TIMELINE CARD
  // ==========================================
  Widget _buildRecentActivityCard(BuildContext context, bool isDark) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final activities = <Map<String, dynamic>>[];

    for (final d in _recentDocs.take(3)) {
      activities.add({
        'title': 'Document scanned: ${d.title}',
        'time': d.dateText.replaceAll('Scanned ', ''),
        'icon': Icons.description_outlined,
        'color': isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      });
    }

    if (activities.isEmpty) {
      activities.add({
        'title': 'Workspace initialized',
        'time': 'Recent',
        'icon': Icons.check_circle_outline_rounded,
        'color': isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.history_rounded, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('home.recentActivity'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      loc.translate('home.recentActivitySub'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          for (int i = 0; i < activities.length; i++) ...[
            Container(
              margin: EdgeInsets.only(bottom: i < activities.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (activities[i]['color'] as Color).withValues(alpha: isDark ? 0.15 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activities[i]['icon'] as IconData,
                      size: 16,
                      color: activities[i]['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activities[i]['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activities[i]['time'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
  }

  // ==========================================
  // G. LEGAL INTELLIGENCE & NEWS CARD
  // ==========================================
  Widget _buildLegalUpdatesCard(BuildContext context, bool isDark) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final news = _legalNews;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.feed_outlined, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('home.legalIntelligence'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            loc.translate('home.legalIntelligenceSub'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  loc.translate('common.live'),
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isLoadingNews && _legalNews.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                ),
              ),
            )
          else if (news.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                loc.translate('home.noLegalUpdates'),
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            for (int i = 0; i < news.take(2).length; i++) ...[
              Container(
                margin: EdgeInsets.only(bottom: i < news.take(2).length - 1 ? 8 : 0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedSurface : AppColors.lightElevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final link = (news[i]['link'] ?? '').toString();
                      if (link.isNotEmpty) {
                        final uri = Uri.parse(link);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (news[i]['title'] ?? 'Legal Notice').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${news[i]['source'] ?? 'Legal News'} • ${formatRelativeTime(news[i]['pubDate'])}',
                                  style: GoogleFonts.inter(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ==========================================
  // H. RERA STATUTORY AWARENESS CARD
  // ==========================================
  Widget _buildReraAwarenessCard(BuildContext context, bool isDark, bool isDesktop) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

    final reraAlert = _legalNews.firstWhere(
      (n) => (n['isWarning'] == true || (n['title'] ?? '').toString().toLowerCase().contains('rera')),
      orElse: () => null,
    );

    final String alertTitle = reraAlert != null
        ? (reraAlert['title'] ?? 'RERA: Promoter Escrow & Statutory Handover Compliance Under Section 18')
        : 'RERA: Promoter Escrow & Statutory Handover Compliance Under Section 18';

    final String alertDesc = reraAlert != null
        ? 'Regulatory notice via ${reraAlert['source'] ?? 'inventiva.co.in'}. Mandatory promoter disclosures and statutory interest protections apply to all registered transactions.'
        : 'Mandatory promoter disclosures and statutory interest protections apply to all registered transactions.';

    final String alertLink = reraAlert != null ? (reraAlert['link'] ?? '') : '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 22 : 16,
        vertical: isDesktop ? 18 : 16,
      ),
      child: LayoutBuilder(
        builder: (context, reraConstraints) {
          final isNarrow = reraConstraints.maxWidth < 620;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        loc.translate('home.reraAlert'),
                        style: GoogleFonts.inter(
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  alertTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alertDesc,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => handleReraDetails(context, ref, alertLink, alertTitle, alertDesc),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                      foregroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.translate('common.viewDetails'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            loc.translate('home.reraAlert'),
                            style: GoogleFonts.inter(
                              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alertTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alertDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () => handleReraDetails(context, ref, alertLink, alertTitle, alertDesc),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  foregroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.translate('common.viewDetails'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 13, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}