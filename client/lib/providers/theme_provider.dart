import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _themePrefKey = 'theme_preference';

  ThemeNotifier() : super(ThemeMode.system) {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final functionalAllowed = prefs.getBool('storage_consent_functional');
    if (functionalAllowed == true) {
      final isDark = prefs.getBool(_themePrefKey);
      if (isDark != null) {
        state = isDark ? ThemeMode.dark : ThemeMode.light;
      }
    }
  }

  void toggleTheme() async {
    final isDark = state == ThemeMode.dark || (state == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    final newTheme = isDark ? ThemeMode.light : ThemeMode.dark;
    
    state = newTheme;
    
    final prefs = await SharedPreferences.getInstance();
    final functionalAllowed = prefs.getBool('storage_consent_functional');
    if (functionalAllowed == true) {
      await prefs.setBool(_themePrefKey, newTheme == ThemeMode.dark);
    }
  }

  void setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_themePrefKey);
    } else {
      final functionalAllowed = prefs.getBool('storage_consent_functional');
      if (functionalAllowed == true) {
        await prefs.setBool(_themePrefKey, mode == ThemeMode.dark);
      }
    }
  }
}
