import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Design System Colors for LawBuddy (Sophisticated Lavender + Warm Cream Palette)
class AppColors {
  // --- PRIMARY & SUPPORTING DESIGN SYSTEM TOKENS ---
  // Primary Lavender: #A39DAA (Primary buttons, active states, icons, key highlights, badges)
  static const Color lightPrimary = Color(0xFFA39DAA);
  // Soft Lavender: #D8D3DA (Borders, dividers, subtle backgrounds, inactive UI elements)
  static const Color lightAccent = Color(0xFFD8D3DA);
  // Sage Olive / Compliant: #6B8E78 (Success states, verified badges, secondary buttons)
  static const Color lightSecondary = Color(0xFF6B8E78);
  // Warm Cream: #EFE1D1 (Dominant page canvas background)
  static const Color lightBackground = Color(0xFFEFE1D1);
  // Off-white / White: #FAF8F5 (Cards, input fields, modals, elevated surfaces)
  static const Color lightSurface = Color(0xFFFAF8F5);
  static const Color lightSurfaceElevated = Color(0xFFFAF8F5);
  static const Color lightElevatedSurface = Color(0xFFFAF8F5);
  // Deep Charcoal: #29262B (Primary text and headings)
  static const Color lightTextPrimary = Color(0xFF29262B);
  // Warm Brown: #6F6258 (Secondary / muted text)
  static const Color lightTextSecondary = Color(0xFF6F6258);
  // Soft Lavender Border: #D8D3DA
  static const Color lightBorder = Color(0xFFD8D3DA);
  // Semantic Alerts (Harmonized, keeping semantic clarity)
  static const Color lightError = Color(0xFFC84B31); // Terracotta Red (Destructive / High Risk)
  static const Color lightCaution = Color(0xFFC68B59); // Warm Ochre / Amber (Caution severity)

  // --- DARK MODE PALETTE (Sophisticated Charcoal-Lavender) ---
  static const Color darkBackground = Color(0xFF1E1B20); // Deep Charcoal Canvas with subtle lavender undertone
  static const Color darkSurface = Color(0xFF29262B); // Deep Charcoal Card Surface
  static const Color darkSurfaceElevated = Color(0xFF343037); // Elevated Charcoal
  static const Color darkElevatedSurface = Color(0xFF343037); // Alias
  static const Color darkPrimary = Color(0xFFA39DAA); // Primary Lavender
  static const Color darkAccent = Color(0xFFD8D3DA); // Soft Lavender
  static const Color darkSecondary = Color(0xFF7E9F8B); // Sage Olive
  static const Color darkCaution = Color(0xFFDCA067); // Warm Ochre / Amber
  static const Color darkError = Color(0xFFE57368); // Terracotta / Coral Red
  static const Color darkErrorText = Color(0xFF29262B); // Deep Charcoal
  static const Color darkTextPrimary = Color(0xFFFAF8F5); // Off-White / Warm Cream text
  static const Color darkTextSecondary = Color(0xFFA9A2AF); // Muted Lavender-Gray text
  static const Color darkBorder = Color(0xFF433E47); // Subtle Charcoal-Lavender Border

  // --- SEMANTIC RISK COLOR HELPERS ---
  static Color highRisk(bool isDark) => isDark ? darkError : lightError;
  static Color highRiskText(bool isDark) => isDark ? darkErrorText : Colors.white;
  static Color caution(bool isDark) => isDark ? darkCaution : lightCaution;
  static Color compliant(bool isDark) => isDark ? darkSecondary : lightSecondary;
}

class AppTheme {
  // Light ColorScheme
  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightTextPrimary,
    secondary: AppColors.lightSecondary,
    onSecondary: Colors.white,
    tertiary: AppColors.lightAccent,
    onTertiary: AppColors.lightTextPrimary,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    onSurfaceVariant: AppColors.lightTextSecondary,
    outline: AppColors.lightBorder,
    error: AppColors.lightError,
    onError: Colors.white,
    surfaceContainerHighest: AppColors.lightSurfaceElevated,
  );

  // Dark ColorScheme
  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkErrorText,
    secondary: AppColors.darkSecondary,
    onSecondary: Colors.white,
    tertiary: AppColors.darkAccent,
    onTertiary: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkBorder,
    error: AppColors.darkError,
    onError: AppColors.darkErrorText,
    surfaceContainerHighest: AppColors.darkSurfaceElevated,
  );

  // Light ThemeData
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).copyWith(
      displayLarge: const TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: const TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: const TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w400),
      bodyMedium: const TextStyle(color: AppColors.lightTextSecondary, fontWeight: FontWeight.w400),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: lightColorScheme,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.lightTextSecondary),
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: AppColors.lightTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: AppColors.lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.lightBorder),
        ),
      ),
    );
  }

  // Dark ThemeData
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w400),
      bodyMedium: const TextStyle(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w400),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: darkColorScheme,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.darkTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkError, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.darkTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: AppColors.darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.darkBorder),
        ),
      ),
    );
  }
}
