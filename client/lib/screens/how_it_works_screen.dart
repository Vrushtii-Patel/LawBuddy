import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'scan_screen.dart';
import 'home_screen.dart';
import 'stamp_duty_calculator_screen.dart';
import 'chat_screen.dart';
import 'checklists_list_screen.dart';

class HowItWorksScreen extends ConsumerStatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  ConsumerState<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends ConsumerState<HowItWorksScreen> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _scannerKey = GlobalKey();
  final GlobalKey _checklistsKey = GlobalKey();
  final GlobalKey _calculatorKey = GlobalKey();
  final GlobalKey _legalAiKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onScanCta() {
    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ScanScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _navigateTo(Widget targetScreen) {
    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => targetScreen),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 700 && size.width < 1024;
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    // Feature 1: Document Scanner & Risk Detection
    final scannerSteps = [
      const _StepInfo(
        number: '01',
        title: 'Upload Agreement',
        description: 'Upload your property agreement, sale deed, or rental contract as a PDF, photo, or pasted text.',
      ),
      const _StepInfo(
        number: '02',
        title: 'AI Contract Scan',
        description: 'Our AI reads each clause and cross-references statutory RERA rules to detect risks.',
      ),
      const _StepInfo(
        number: '03',
        title: 'Plain-English Insights',
        description: 'See clear color-coded flags (Safe, Caution, High Risk) with simple clause explanations.',
      ),
      const _StepInfo(
        number: '04',
        title: 'Legal Audit Report',
        description: 'Download a structured summary report to negotiate with confidence before signing.',
      ),
    ];

    // Feature 2: Property Due Diligence Checklists
    final checklistSteps = [
      const _StepInfo(
        number: '01',
        title: 'Select Property Type',
        description: 'Choose a dedicated legal verification checklist for resale flats, builder floors, or land plots.',
      ),
      const _StepInfo(
        number: '02',
        title: '30-Year EC & Title',
        description: 'Verify 30-year Encumbrance Certificates to confirm continuous clear ownership and no active bank liens.',
      ),
      const _StepInfo(
        number: '03',
        title: 'Municipal Approvals',
        description: 'Track Occupancy Certificates (OC), Commencement (CC), sanctioned layout plans, and builder NOCs.',
      ),
      const _StepInfo(
        number: '04',
        title: 'Custom AI Checklist',
        description: 'Generate a customized city-specific verification list tailored to your exact property transaction.',
      ),
    ];

    // Feature 3: Stamp Duty & Registration Calculator
    final calculatorSteps = [
      const _StepInfo(
        number: '01',
        title: 'Choose State & City',
        description: 'Select your state (Maharashtra, Karnataka, Delhi, UP, etc.) and specific urban or rural locality.',
      ),
      const _StepInfo(
        number: '02',
        title: 'Enter Property Value',
        description: 'Input agreed purchase price and local Ready Reckoner (circle rate) to establish the statutory taxable base.',
      ),
      const _StepInfo(
        number: '03',
        title: 'Apply Concessions',
        description: 'Automatically factor in state government concessions for female buyers, first-time owners, and metro cess.',
      ),
      const _StepInfo(
        number: '04',
        title: 'Instant Fee Summary',
        description: 'Receive an itemized breakdown of stamp duty, statutory surcharge, and registration fees payable.',
      ),
    ];

    // Feature 4: Legal AI Assistant & Agreement Comparison
    final legalAiSteps = [
      const _StepInfo(
        number: '01',
        title: 'Ask Legal AI',
        description: 'Ask real estate questions anytime to clarify complex indemnity clauses, maintenance rules, or RERA rights.',
      ),
      const _StepInfo(
        number: '02',
        title: 'Compare 2 Drafts',
        description: 'Upload an original contract draft and builder revised version to compare both texts line by line.',
      ),
      const _StepInfo(
        number: '03',
        title: 'Spot Hidden Changes',
        description: 'Instantly view highlighted deletions, altered liability clauses, and stealthy extra fees between versions.',
      ),
      const _StepInfo(
        number: '04',
        title: 'Secure Cloud Archive',
        description: 'Keep all audited contracts safely stored in your private workspace with a dedicated recycle bin for recovery.',
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Bar
            _buildTopNavBar(
              context,
              isDark: isDark,
              isDesktop: isDesktop,
              isAuthenticated: isAuthenticated,
              textPrimary: textPrimary,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                        vertical: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. HERO HEADER
                          _buildHeroHeader(
                            isDark: isDark,
                            isDesktop: isDesktop,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            primaryColor: primaryColor,
                            accentColor: accentColor,
                          ),

                          const SizedBox(height: 32),

                          // Quick jump filter bar
                          _buildQuickJumpBar(
                            isDark: isDark,
                            borderColor: borderColor,
                            surfaceColor: surfaceColor,
                            textPrimary: textPrimary,
                            accentColor: accentColor,
                          ),

                          const SizedBox(height: 48),

                          // 2. FEATURE 1: DOCUMENT SCANNER & AI RISK DETECTION
                          _buildFeatureWorkflowSection(
                            key: _scannerKey,
                            badgeNumber: 'FEATURE 1',
                            eyebrow: 'DOCUMENT SCANNER',
                            title: 'How Document Analysis Works',
                            subtitle: 'Four clear steps to review and verify any real estate contract with complete confidence.',
                            steps: scannerSteps,
                            actionLabel: 'Start Document Scan',
                            actionIcon: Icons.document_scanner_rounded,
                            onAction: _onScanCta,
                            isDark: isDark,
                            isDesktop: isDesktop,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                            accentColor: accentColor,
                            borderColor: borderColor,
                          ),

                          _buildSectionDivider(borderColor),

                          // 3. FEATURE 2: PROPERTY DUE DILIGENCE CHECKLISTS
                          _buildFeatureWorkflowSection(
                            key: _checklistsKey,
                            badgeNumber: 'FEATURE 2',
                            eyebrow: 'BUYER PROTECTION',
                            title: 'How Due Diligence Checklists Work',
                            subtitle: 'Four clear steps to verify encumbrance, clearances, and mandatory government approvals.',
                            steps: checklistSteps,
                            actionLabel: 'Open Checklists',
                            actionIcon: Icons.checklist_rounded,
                            onAction: () => _navigateTo(const ChecklistsListScreen()),
                            isDark: isDark,
                            isDesktop: isDesktop,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                            accentColor: accentColor,
                            borderColor: borderColor,
                          ),

                          _buildSectionDivider(borderColor),

                          // 4. FEATURE 3: STAMP DUTY & REGISTRATION CALCULATOR
                          _buildFeatureWorkflowSection(
                            key: _calculatorKey,
                            badgeNumber: 'FEATURE 3',
                            eyebrow: 'CLOSING COSTS',
                            title: 'How Stamp Duty Calculation Works',
                            subtitle: 'Four clear steps to estimate exact government stamp duty and statutory registration fees.',
                            steps: calculatorSteps,
                            actionLabel: 'Calculate Stamp Duty',
                            actionIcon: Icons.calculate_rounded,
                            onAction: () => _navigateTo(const StampDutyCalculatorScreen()),
                            isDark: isDark,
                            isDesktop: isDesktop,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                            accentColor: accentColor,
                            borderColor: borderColor,
                          ),

                          _buildSectionDivider(borderColor),

                          // 5. FEATURE 4: LEGAL AI ASSISTANT & CONTRACT COMPARISON
                          _buildFeatureWorkflowSection(
                            key: _legalAiKey,
                            badgeNumber: 'FEATURE 4',
                            eyebrow: 'LEGAL ASSISTANT & COMPARISON',
                            title: 'How Legal AI & Comparison Works',
                            subtitle: 'Four clear steps to clarify confusing clauses and catch sneaky changes between agreement drafts.',
                            steps: legalAiSteps,
                            actionLabel: 'Ask Legal AI',
                            actionIcon: Icons.auto_awesome_rounded,
                            onAction: () => _navigateTo(const ChatScreen()),
                            isDark: isDark,
                            isDesktop: isDesktop,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                            accentColor: accentColor,
                            borderColor: borderColor,
                          ),

                          const SizedBox(height: 52),

                          // 6. COMMON QUESTIONS (FAQ)
                          _buildFaqSection(
                            key: _faqKey,
                            isDark: isDark,
                            isDesktop: isDesktop,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                            accentColor: accentColor,
                          ),

                          const SizedBox(height: 48),

                          // 7. BOTTOM CTA CARD
                          _buildBottomCtaCard(
                            isDark: isDark,
                            isDesktop: isDesktop,
                            isAuthenticated: isAuthenticated,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                          ),

                          const SizedBox(height: 28),

                          // 8. BRIEF DISCLAIMER
                          Text(
                            'Educational Notice: LawBuddy provides preliminary document transparency and statutory RERA awareness. It does not provide formal legal representation. Always consult a licensed property advocate for high-value transactions.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: textSecondary.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TOP NAVBAR
  // =========================================================================
  Widget _buildTopNavBar(
    BuildContext context, {
    required bool isDark,
    required bool isDesktop,
    required bool isAuthenticated,
    required Color textPrimary,
    required Color surfaceColor,
    required Color borderColor,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: borderColor.withValues(alpha: isDark ? 0.45 : 0.8),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 20),
                tooltip: 'Back',
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/welcome');
                  }
                },
              ),
              const SizedBox(width: 4),

              InkWell(
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.gavel_rounded, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LawBuddy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'HOW IT WORKS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              if (isDesktop) ...[
                if (isAuthenticated)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    icon: const Icon(Icons.dashboard_rounded, size: 14),
                    label: const Text('Dashboard'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightSurfaceElevated,
                      foregroundColor: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorderMedium,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.lightSurfaceElevated,
                      foregroundColor: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorderMedium,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Sign In'),
                  ),
                const SizedBox(width: 8),
              ],

              ElevatedButton.icon(
                onPressed: _onScanCta,
                icon: const Icon(Icons.document_scanner_rounded, size: 14),
                label: Text(isDesktop ? 'Start Scanning' : 'Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.softGraphite : AppColors.warmLinen,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 14 : 10,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. HERO HEADER
  // =========================================================================
  Widget _buildHeroHeader({
    required bool isDark,
    required bool isDesktop,
    required Color textPrimary,
    required Color textSecondary,
    required Color surfaceColor,
    required Color borderColor,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 18,
        vertical: isDesktop ? 36 : 24,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: accentColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'STEP-BY-STEP GUIDES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'How LawBuddy Works',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Explore simple, structured walkthroughs for every tool on LawBuddy. Understand your contract, verify property titles, and calculate closing fees with ease.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isDesktop ? 14.5 : 13.5,
                height: 1.5,
                color: textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 22),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _onScanCta,
                icon: const Icon(Icons.document_scanner_rounded, size: 16),
                label: const Text('Start Scanning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.softGraphite : AppColors.warmLinen,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _scrollTo(_faqKey),
                icon: const Icon(Icons.help_outline_rounded, size: 16),
                label: const Text('Common Questions'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.lightSurfaceElevated,
                  foregroundColor: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorderMedium,
                    width: 1.2,
                  ),
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // QUICK JUMP FILTER BAR (OVERVIEW & ANCHOR)
  // =========================================================================
  Widget _buildQuickJumpBar({
    required bool isDark,
    required Color borderColor,
    required Color surfaceColor,
    required Color textPrimary,
    required Color accentColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2)),
          ),
          child: Text(
            'Explore LawBuddy Tools',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildJumpChip('📄 Document Scanner', () => _scrollTo(_scannerKey), isDark, surfaceColor, borderColor, textPrimary),
            _buildJumpChip('📋 Due Diligence Checklists', () => _scrollTo(_checklistsKey), isDark, surfaceColor, borderColor, textPrimary),
            _buildJumpChip('🧮 Stamp Duty Calculator', () => _scrollTo(_calculatorKey), isDark, surfaceColor, borderColor, textPrimary),
            _buildJumpChip('💬 Legal AI & Comparison', () => _scrollTo(_legalAiKey), isDark, surfaceColor, borderColor, textPrimary),
            _buildJumpChip('❓ FAQ', () => _scrollTo(_faqKey), isDark, surfaceColor, borderColor, textPrimary),
          ],
        ),
      ],
    );
  }

  Widget _buildJumpChip(
    String label,
    VoidCallback onTap,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color textPrimary,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // REUSABLE 4-STEP WORKFLOW SECTION (PERFECTLY ALIGNED PLAYCARDS)
  // =========================================================================
  Widget _buildFeatureWorkflowSection({
    Key? key,
    required String badgeNumber,
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<_StepInfo> steps,
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback onAction,
    required bool isDark,
    required bool isDesktop,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color accentColor,
    required Color borderColor,
  }) {
    return Container(
      key: key,
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeNumber,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isDesktop ? 26 : 21,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 26),

          // INTRINSIC HEIGHT ENSURES EVERY PLAYCARD HAS THE EXACT SAME HEIGHT
          isDesktop
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _SimpleStepCard(
                          number: steps[0].number,
                          title: steps[0].title,
                          description: steps[0].description,
                          isDark: isDark,
                        ),
                      ),
                      _buildStepArrow(isDark),
                      Expanded(
                        child: _SimpleStepCard(
                          number: steps[1].number,
                          title: steps[1].title,
                          description: steps[1].description,
                          isDark: isDark,
                        ),
                      ),
                      _buildStepArrow(isDark),
                      Expanded(
                        child: _SimpleStepCard(
                          number: steps[2].number,
                          title: steps[2].title,
                          description: steps[2].description,
                          isDark: isDark,
                        ),
                      ),
                      _buildStepArrow(isDark),
                      Expanded(
                        child: _SimpleStepCard(
                          number: steps[3].number,
                          title: steps[3].title,
                          description: steps[3].description,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: steps.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _SimpleStepCard(
                        number: s.number,
                        title: s.title,
                        description: s.description,
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 15),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              foregroundColor: isDark ? AppColors.softGraphite : AppColors.warmLinen,
              elevation: 0,
              shadowColor: Colors.transparent,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepArrow(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          Icons.chevron_right_rounded,
          size: 22,
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
    );
  }

  Widget _buildSectionDivider(Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Divider(
        color: borderColor.withValues(alpha: 0.5),
        height: 1,
      ),
    );
  }

  // =========================================================================
  // 6. COMMON QUESTIONS (FAQ)
  // =========================================================================
  Widget _buildFaqSection({
    required Key key,
    required bool isDark,
    required bool isDesktop,
    required Color textPrimary,
    required Color textSecondary,
    required Color surfaceColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    final faqs = [
      const _FaqItem(
        question: 'What types of property documents can I upload?',
        answer: 'You can upload Sale Deeds, Agreements for Sale, Builder-Buyer Agreements, Lease/Rental Agreements, and Allotment Letters as PDFs, camera photos, image scans, or pasted text.',
      ),
      const _FaqItem(
        question: 'What do the risk colors mean in Document Analysis?',
        answer: '🟢 Green indicates safe, standard clauses. 🟡 Yellow warns of missing terms or vague charges. 🔴 Red flags dangerous liabilities, unfair forfeiture terms, or statutory RERA violations.',
      ),
      const _FaqItem(
        question: 'How accurate is the Stamp Duty Calculator?',
        answer: 'It calculates statutory stamp duty, registration charges, and municipal cess based on active state revenue rates and gender/first-time buyer concessions.',
      ),
      const _FaqItem(
        question: 'Does LawBuddy replace a real estate lawyer?',
        answer: 'No. LawBuddy provides preliminary document transparency and educational AI analysis. For high-value purchases, always consult a licensed property advocate for formal title clearance.',
      ),
    ];

    return Container(
      key: key,
      child: Column(
        children: [
          Text(
            'COMMON QUESTIONS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Frequently Asked Questions',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isDesktop ? 26 : 21,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 20),

          Column(
            children: faqs.map((f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: surfaceColor,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: accentColor,
                      collapsedIconColor: textSecondary,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                      title: Text(
                        f.question,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              f.answer,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                height: 1.5,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. BOTTOM CTA CARD
  // =========================================================================
  Widget _buildBottomCtaCard({
    required bool isDark,
    required bool isDesktop,
    required bool isAuthenticated,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 18,
        vertical: isDesktop ? 30 : 22,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Ready to Check Your Agreement?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isDesktop ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Upload your document now to detect unfair clauses and get plain-English guidance in seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.45,
                color: textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _onScanCta,
                icon: const Icon(Icons.document_scanner_rounded, size: 16),
                label: const Text('Start Document Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  foregroundColor: isDark ? AppColors.softGraphite : AppColors.warmLinen,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
              if (!isAuthenticated)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Create Free Account'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.lightSurfaceElevated,
                    foregroundColor: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorderMedium,
                      width: 1.2,
                    ),
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// REUSABLE STEP CARD (PERFECTLY UNIFORM & STRETCHED)
// =========================================================================
class _SimpleStepCard extends StatefulWidget {
  final String number;
  final String title;
  final String description;
  final bool isDark;

  const _SimpleStepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.isDark,
  });

  @override
  State<_SimpleStepCard> createState() => _SimpleStepCardState();
}

class _SimpleStepCardState extends State<_SimpleStepCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.lightPrimary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        constraints: const BoxConstraints(minHeight: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? accentColor : borderColor,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.number,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                widget.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.4,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// DATA MODELS
// =========================================================================
class _StepInfo {
  final String number;
  final String title;
  final String description;

  const _StepInfo({
    required this.number,
    required this.title,
    required this.description,
  });
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });
}
