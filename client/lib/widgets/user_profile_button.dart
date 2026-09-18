import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/welcome_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/terms_of_use_screen.dart';
import 'cookie_consent_banner.dart';
import '../theme/app_theme.dart';

class UserProfileButton extends ConsumerStatefulWidget {
  const UserProfileButton({super.key});

  @override
  ConsumerState<UserProfileButton> createState() => _UserProfileButtonState();
}

class _UserProfileButtonState extends ConsumerState<UserProfileButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final colorScheme = Theme.of(context).colorScheme;

    final String userName = (user?.fullName.isNotEmpty == true)
        ? user!.fullName
        : 'User';
    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => showSettingsDialog(context, ref),
        child: Tooltip(
          message: '$userName (Settings)',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isHovered ? colorScheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                initial,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showSettingsDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (dialogContext, ref, _) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          final currentLanguage = ref.watch(localeProvider);
          final currentThemeMode = ref.watch(themeProvider);

          return AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outline),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings_outlined, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  currentLanguage == AppLanguage.hindi ? 'सेटिंग्स' : 'Settings',
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme / Appearance Control
                    Text(
                      currentLanguage == AppLanguage.hindi ? 'थीम' : 'Theme',
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentLanguage == AppLanguage.hindi ? 'चुनें कि LawBuddy कैसा दिखे' : 'Choose how LawBuddy looks',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          // Light
                          Expanded(
                            child: InkWell(
                              onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.light),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: currentThemeMode == ThemeMode.light ? colorScheme.primary : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.light_mode_rounded,
                                      size: 15,
                                      color: currentThemeMode == ThemeMode.light ? Colors.white : colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      currentLanguage == AppLanguage.hindi ? 'लाइट' : 'Light',
                                      style: TextStyle(
                                        color: currentThemeMode == ThemeMode.light ? Colors.white : colorScheme.onSurface,
                                        fontWeight: currentThemeMode == ThemeMode.light ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Dark
                          Expanded(
                            child: InkWell(
                              onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.dark),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: currentThemeMode == ThemeMode.dark ? colorScheme.primary : Colors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.dark_mode_rounded,
                                      size: 15,
                                      color: currentThemeMode == ThemeMode.dark ? Colors.white : colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      currentLanguage == AppLanguage.hindi ? 'डार्क' : 'Dark',
                                      style: TextStyle(
                                        color: currentThemeMode == ThemeMode.dark ? Colors.white : colorScheme.onSurface,
                                        fontWeight: currentThemeMode == ThemeMode.dark ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // System
                          Expanded(
                            child: InkWell(
                              onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.system),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: currentThemeMode == ThemeMode.system ? colorScheme.primary : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.brightness_auto_rounded,
                                      size: 15,
                                      color: currentThemeMode == ThemeMode.system ? Colors.white : colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      currentLanguage == AppLanguage.hindi ? 'सिस्टम' : 'System',
                                      style: TextStyle(
                                        color: currentThemeMode == ThemeMode.system ? Colors.white : colorScheme.onSurface,
                                        fontWeight: currentThemeMode == ThemeMode.system ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Language Option inside Settings
                    Text(
                      currentLanguage == AppLanguage.hindi ? 'भाषा' : 'Language',
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentLanguage == AppLanguage.hindi ? 'एप्लिकेशन इंटरफ़ेस भाषा' : 'Application interface language',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => ref.read(localeProvider.notifier).setLanguage(AppLanguage.english),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: currentLanguage == AppLanguage.english ? colorScheme.primary : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'English',
                                  style: TextStyle(
                                    color: currentLanguage == AppLanguage.english ? Colors.white : colorScheme.onSurface,
                                    fontWeight: currentLanguage == AppLanguage.english ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => ref.read(localeProvider.notifier).setLanguage(AppLanguage.hindi),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: currentLanguage == AppLanguage.hindi ? colorScheme.primary : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'हिंदी',
                                  style: TextStyle(
                                    color: currentLanguage == AppLanguage.hindi ? Colors.white : colorScheme.onSurface,
                                    fontWeight: currentLanguage == AppLanguage.hindi ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Legal & Privacy Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currentLanguage == AppLanguage.hindi ? 'कानूनी और गोपनीयता' : 'Legal & Privacy',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              leading: Icon(Icons.shield_outlined, size: 19, color: colorScheme.primary),
                              title: Text(
                                currentLanguage == AppLanguage.hindi ? 'गोपनीयता नीति' : 'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colorScheme.onSurfaceVariant),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                                );
                              },
                            ),
                            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              leading: Icon(Icons.tune_rounded, size: 19, color: colorScheme.primary),
                              title: Text(
                                currentLanguage == AppLanguage.hindi ? 'गोपनीयता और संग्रहण प्राथमिकताएं' : 'Privacy & Storage Preferences',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colorScheme.onSurfaceVariant),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                showPrivacyPreferencesDialog(context);
                              },
                            ),
                            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              leading: Icon(Icons.description_outlined, size: 19, color: colorScheme.primary),
                              title: Text(
                                currentLanguage == AppLanguage.hindi ? 'उपयोग की शर्तें' : 'Terms of Use',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colorScheme.onSurfaceVariant),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // App Engine Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LawBuddy Core Engine v1.0',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'RERA Real Estate Analysis Module',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  currentLanguage == AppLanguage.hindi ? 'बंद करें' : 'Close',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void showProfileDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return _ProfileDialogContent(parentContext: context);
    },
  );
}

class _ProfileDialogContent extends ConsumerStatefulWidget {
  final BuildContext parentContext;
  const _ProfileDialogContent({required this.parentContext});

  @override
  ConsumerState<_ProfileDialogContent> createState() => _ProfileDialogContentState();
}

class _ProfileDialogContentState extends ConsumerState<_ProfileDialogContent> {
  bool _isEditing = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _nameController = TextEditingController(text: authState.user?.fullName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final currentLanguage = ref.watch(localeProvider);

    final String userName = (user?.fullName.isNotEmpty == true) ? user!.fullName : 'LawBuddy User';
    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outline),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_outline_rounded, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            currentLanguage == AppLanguage.hindi ? 'उपयोगकर्ता प्रोफ़ाइल' : 'User Profile',
            style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Account summary
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 13, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Active Account',
                            style: TextStyle(
                              color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Full Name section (with inline edit)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentLanguage == AppLanguage.hindi ? 'पूरा नाम' : 'Full Name',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (!_isEditing)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _nameController.text = user?.fullName ?? '';
                          _isEditing = true;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 13, color: colorScheme.primary),
                          const SizedBox(width: 3),
                          Text(
                            currentLanguage == AppLanguage.hindi ? 'संपादित करें' : 'Edit',
                            style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              if (_isEditing) ...[
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: currentLanguage == AppLanguage.hindi ? 'पूरा नाम' : 'Full name',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: Text(
                        currentLanguage == AppLanguage.hindi ? 'रद्द करें' : 'Cancel',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final newName = _nameController.text.trim();
                        if (newName.isNotEmpty) {
                           ref.read(authProvider.notifier).updateUserName(newName);
                        }
                        setState(() => _isEditing = false);
                      },
                      child: Text(
                        currentLanguage == AppLanguage.hindi ? 'सहेजें' : 'Save',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Text(
                    userName,
                    style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Email Address
              Text(
                currentLanguage == AppLanguage.hindi ? 'ईमेल पता' : 'Email Address',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Text(
                  (user?.email != null && user!.email!.isNotEmpty) ? user.email! : 'user@lawbuddy.in',
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            currentLanguage == AppLanguage.hindi ? 'बंद करें' : 'Close',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        if (authState.user != null || authState.status == AuthStatus.authenticated)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              Navigator.pushAndRemoveUntil(
                widget.parentContext,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: Text(currentLanguage == AppLanguage.hindi ? 'साइन आउट' : 'Sign Out'),
          ),
      ],
    );
  }
}
