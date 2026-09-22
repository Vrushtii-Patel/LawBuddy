import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'home/home_widgets.dart';
import 'home/home_sidebar.dart';
import 'home/home_header.dart';
import 'home/home_metrics_row.dart';
import 'home/home_latest_doc_card.dart';
import 'home/home_risk_breakdown.dart';
import 'home/home_checklist_card.dart';
import 'home/home_recent_activity.dart';
import 'home/home_legal_updates.dart';
import 'home/home_rera_card.dart';

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
                                    HomeMetricsRow(
                                      recentDocs: _recentDocs,
                                      checklists: _checklists,
                                      isDark: isDark,
                                      isDesktop: isDesktop,
                                    ),
                                    const SizedBox(height: 28),

                                    // C. Main Workspace Feature: Latest Document Analysis Review
                                    HomeLatestDocCard(
                                      recentDocs: _recentDocs,
                                      isLoadingDocs: _isLoadingDocs,
                                      isDark: isDark,
                                      isDesktop: isDesktop,
                                      onNavigate: _navigateTo,
                                    ),
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
                                                    HomeRiskBreakdownCard(recentDocs: _recentDocs, isDark: isDark),
                                                    const SizedBox(height: 24),
                                                    HomeChecklistCard(checklists: _checklists, isDark: isDark, onNavigate: _navigateTo),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                flex: 5,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    HomeRecentActivityCard(recentDocs: _recentDocs, isDark: isDark),
                                                    const SizedBox(height: 24),
                                                    HomeLegalUpdatesCard(legalNews: _legalNews, isLoadingNews: _isLoadingNews, isDark: isDark),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          return Column(
                                            children: [
                                              HomeRiskBreakdownCard(recentDocs: _recentDocs, isDark: isDark),
                                              const SizedBox(height: 24),
                                              HomeChecklistCard(checklists: _checklists, isDark: isDark, onNavigate: _navigateTo),
                                              const SizedBox(height: 24),
                                              HomeRecentActivityCard(recentDocs: _recentDocs, isDark: isDark),
                                              const SizedBox(height: 24),
                                              HomeLegalUpdatesCard(legalNews: _legalNews, isLoadingNews: _isLoadingNews, isDark: isDark),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 28),

                                    // G. RERA Statutory Advisory Notice
                                    HomeReraAwarenessCard(legalNews: _legalNews, isDark: isDark, isDesktop: isDesktop),
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
}