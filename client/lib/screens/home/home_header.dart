import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_profile_button.dart';
import 'home_widgets.dart';

// ==========================================
// HOME SCREEN — TOP NAV BAR & HEADER GREETING
// Extracted from home_screen.dart. Both are ConsumerWidgets since they need
// Riverpod's `ref` (auth state, locale) that used to come implicitly from
// _HomeScreenState.
// ==========================================

String _getGreeting(WidgetRef ref) {
  final hour = DateTime.now().hour;
  final loc = ref.read(localeProvider.notifier);
  if (hour < 12) {
    return loc.translate('home.goodMorning');
  } else if (hour < 17) {
    return loc.translate('home.goodAfternoon');
  } else {
    return loc.translate('home.goodEvening');
  }
}

// ==========================================
// TOP NAVIGATION BAR (Mobile / Drawer only)
// ==========================================
class TopNavBar extends ConsumerWidget {
  final bool isDark;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const TopNavBar({
    super.key,
    required this.isDark,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final String userName = (user?.fullName != null && user!.fullName.trim().isNotEmpty)
        ? user.fullName.trim()
        : 'User';
    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Menu',
              ),
              const SizedBox(width: 6),
              Text(
                'LawBuddy',
                style: GoogleFonts.inter(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => showProfileDialog(context, ref),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
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
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// A. WORKSPACE GREETING & HERO
// ==========================================
class HeaderGreeting extends ConsumerWidget {
  final bool isDark;
  final bool isDesktop;
  final String userName;

  const HeaderGreeting({
    super.key,
    required this.isDark,
    required this.isDesktop,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final loc = ref.read(localeProvider.notifier);

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
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28.0 : 18.0,
        vertical: isDesktop ? 22.0 : 18.0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showIllustration = constraints.maxWidth >= 720;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Eyebrow Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: isDark ? 0.2 : 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: isDark ? 0.35 : 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? AppColors.darkAccent : AppColors.lightPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              loc.translate('home.heroTag'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightPrimary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Greeting Headline
                    Text(
                      loc.translate('home.greeting', {'greeting': _getGreeting(ref), 'name': userName}),
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 24 : 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Workspace Subtitle
                    Text(
                      loc.translate('home.heroSub'),
                      style: GoogleFonts.inter(
                        fontSize: isDesktop ? 13 : 12,
                        height: 1.4,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (showIllustration) ...[
                const SizedBox(width: 24),
                SizedBox(
                  width: 190,
                  height: 80,
                  child: CustomPaint(
                    painter: LegalPropertyIllustrationPainter(
                      accentBlue: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      accentGold: isDark ? AppColors.darkAccent : AppColors.lightAccent,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
