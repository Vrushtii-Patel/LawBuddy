import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_profile_button.dart';
import '../admin_analytics_screen.dart';
import '../chat_screen.dart';
import '../checklists_list_screen.dart';
import '../document_comparison_screen.dart';
import '../recent_documents_screen.dart';
import '../bin_screen.dart';
import '../scan_screen.dart';
import '../stamp_duty_calculator_screen.dart';
import 'home_widgets.dart';

// ==========================================
// HOME SCREEN — SIDEBAR NAVIGATION
// Extracted from home_screen.dart. Both DesktopSidebar and SidebarDrawer
// render the same navigation content, wrapped differently (a plain bordered
// panel vs. a Material Drawer). Navigation itself and the "loading/refresh
// on return" behavior stay owned by HomeScreen and are passed in as the
// onNavigate callback, so this file has no dependency on HomeScreen's state
// beyond what's explicitly passed to it.
// ==========================================

class DesktopSidebar extends ConsumerWidget {
  final bool isDark;
  final dynamic user;
  final List<dynamic> legalNews;
  final void Function(Widget screen) onNavigate;

  const DesktopSidebar({
    super.key,
    required this.isDark,
    required this.user,
    required this.legalNews,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: _buildSidebarContent(
          context,
          ref,
          isDark,
          user,
          legalNews,
          onNavigate,
          isDrawer: false,
        ),
      ),
    );
  }
}

// ==========================================
// MOBILE SIDEBAR DRAWER
// ==========================================
class SidebarDrawer extends ConsumerWidget {
  final bool isDark;
  final dynamic user;
  final List<dynamic> legalNews;
  final void Function(Widget screen) onNavigate;

  const SidebarDrawer({
    super.key,
    required this.isDark,
    required this.user,
    required this.legalNews,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: SafeArea(
        child: _buildSidebarContent(
          context,
          ref,
          isDark,
          user,
          legalNews,
          onNavigate,
          isDrawer: true,
        ),
      ),
    );
  }
}

// ==========================================
// SHARED SIDEBAR CONTENT (PRIMARY NAVIGATION)
// Private to this file, shared by both DesktopSidebar and SidebarDrawer above.
// ==========================================
Widget _buildSidebarContent(
  BuildContext context,
  WidgetRef ref,
  bool isDark,
  dynamic user,
  List<dynamic> legalNews,
  void Function(Widget screen) onNavigate, {
  required bool isDrawer,
}) {
  ref.watch(localeProvider);
  final loc = ref.read(localeProvider.notifier);

  final String userName = (user?.fullName != null && user!.fullName.trim().isNotEmpty)
      ? user.fullName.trim()
      : 'User';
  final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Top Brand Header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.gavel_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LawBuddy',
                    style: GoogleFonts.inter(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'REAL ESTATE AI TECH',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      Divider(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        height: 1,
      ),

      // Navigation Menu List
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          children: [
            // SECTION: OVERVIEW
            _buildSidebarSectionLabel(loc.translate('sidebar.overview'), isDark),
            SidebarNavItem(
              icon: Icons.dashboard_rounded,
              label: loc.translate('sidebar.dashboard'),
              isActive: true,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 14),

            // SECTION: WORKSPACE
            _buildSidebarSectionLabel(loc.translate('sidebar.workspace'), isDark),
            SidebarNavItem(
              icon: Icons.folder_open_rounded,
              label: loc.translate('sidebar.documents'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                onNavigate(const RecentDocumentsScreen());
              },
            ),
            SidebarNavItem(
              icon: Icons.document_scanner_rounded,
              label: loc.translate('sidebar.riskAnalysis'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                onNavigate(const ScanScreen());
              },
            ),
            SidebarNavItem(
              icon: Icons.checklist_rounded,
              label: loc.translate('sidebar.checklists'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                onNavigate(const ChecklistsListScreen());
              },
            ),
            const SizedBox(height: 14),

            // SECTION: LEGAL TOOLS
            _buildSidebarSectionLabel(loc.translate('sidebar.legalTools'), isDark),
            SidebarNavItem(
              icon: Icons.compare_arrows_rounded,
              label: 'Document Comparison',
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                onNavigate(const DocumentComparisonScreen());
              },
            ),
            SidebarNavItem(
              icon: Icons.auto_awesome_rounded,
              label: loc.translate('sidebar.legalAi'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                onNavigate(const ChatScreen());
              },
            ),
            SidebarNavItem(
              icon: Icons.calculate_rounded,
              label: loc.translate('sidebar.stampDuty'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                onNavigate(const StampDutyCalculatorScreen());
              },
            ),
            const SizedBox(height: 14),

            // SECTION: LEGAL INFORMATION
            _buildSidebarSectionLabel(loc.translate('sidebar.legalInfo'), isDark),
            SidebarNavItem(
              icon: Icons.shield_outlined,
              label: loc.translate('sidebar.reraCompliance'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                _openReraDetailsModal(context, ref, legalNews);
              },
            ),

            // SECTION: ADMINISTRATION (Visible to admin users)
            if (user?.isAdmin == true || user?.role == 'admin') ...[
              const SizedBox(height: 14),
              _buildSidebarSectionLabel('ADMINISTRATION', isDark),
              SidebarNavItem(
                icon: Icons.admin_panel_settings_rounded,
                label: 'Admin Analytics',
                isActive: false,
                isDark: isDark,
                onTap: () {
                  if (isDrawer) Navigator.pop(context);
                  onNavigate(const AdminAnalyticsScreen());
                },
              ),
            ],
          ],
        ),
      ),

      Divider(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        height: 1,
      ),

      // Bottom Settings & Profile Area
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            SidebarNavItem(
              icon: Icons.delete_outline_rounded,
              label: loc.translate('sidebar.bin'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                onNavigate(const BinScreen());
              },
            ),
            const SizedBox(height: 2),
            SidebarNavItem(
              icon: Icons.settings_outlined,
              label: loc.translate('sidebar.settings'),
              isActive: false,
              isDark: isDark,
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                showSettingsDialog(context, ref);
              },
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                if (isDrawer) Navigator.pop(context);
                showProfileDialog(context, ref);
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: (isDark ? AppColors.darkAccent : AppColors.lightPrimary).withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            loc.translate('sidebar.profile'),
                            style: GoogleFonts.inter(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildSidebarSectionLabel(String text, bool isDark) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
        letterSpacing: 1.1,
      ),
    ),
  );
}

void _openReraDetailsModal(BuildContext context, WidgetRef ref, List<dynamic> legalNews) {
  final reraAlert = legalNews.firstWhere(
    (n) => (n['isWarning'] == true || (n['title'] ?? '').toString().toLowerCase().contains('rera')),
    orElse: () => null,
  );

  final String alertTitle = reraAlert != null
      ? (reraAlert['title'] ?? 'RERA: The regulator that was supposed to protect homebuyers — but has it become part of the problem?')
      : 'RERA: The regulator that was supposed to protect homebuyers — but has it become part of the problem?';

  final String alertDesc = reraAlert != null
      ? 'Regulatory update. Mandatory adherence required for real estate transactions, promoter disclosures, and escrow accounting.'
      : 'Regulatory update. Mandatory adherence required for real estate transactions, promoter disclosures, and escrow accounting.';

  final String alertLink = reraAlert != null ? (reraAlert['link'] ?? '') : '';

  handleReraDetails(context, ref, alertLink, alertTitle, alertDesc);
}
