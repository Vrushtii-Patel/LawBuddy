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
  static const Color lightError =
      Color(0xFFC84B31); // Terracotta Red (Destructive / High Risk)
  static const Color lightCaution =
      Color(0xFFC68B59); // Warm Ochre / Amber (Caution severity)

  // --- DARK MODE PALETTE (Sophisticated Charcoal-Lavender) ---
  static const Color darkBackground =
      Color(0xFF1E1B20); // Deep Charcoal Canvas with subtle lavender undertone
  static const Color darkSurface =
      Color(0xFF29262B); // Deep Charcoal Card Surface
  static const Color darkSurfaceElevated =
      Color(0xFF343037); // Elevated Charcoal
  static const Color darkElevatedSurface = Color(0xFF343037); // Alias
  static const Color darkPrimary = Color(0xFFA39DAA); // Primary Lavender
  static const Color darkAccent = Color(0xFFD8D3DA); // Soft Lavender
  static const Color darkSecondary = Color(0xFF7E9F8B); // Sage Olive
  static const Color darkCaution = Color(0xFFDCA067); // Warm Ochre / Amber
  static const Color darkError = Color(0xFFE57368); // Terracotta / Coral Red
  static const Color darkErrorText = Color(0xFF29262B); // Deep Charcoal
  static const Color darkTextPrimary =
      Color(0xFFFAF8F5); // Off-White / Warm Cream text
  static const Color darkTextSecondary =
      Color(0xFFA9A2AF); // Muted Lavender-Gray text
  static const Color darkBorder =
      Color(0xFF433E47); // Subtle Charcoal-Lavender Border

  // --- SEMANTIC RISK COLOR HELPERS ---
  static Color highRisk(bool isDark) => isDark ? darkError : lightError;
  static Color highRiskText(bool isDark) =>
      isDark ? darkErrorText : Colors.white;
  static Color caution(bool isDark) => isDark ? darkCaution : lightCaution;
  static Color compliant(bool isDark) =>
      isDark ? darkSecondary : lightSecondary;
}

/// Centralized spacing scale (logical pixels) for consistent padding, margins, and gaps
class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;

  // Semantic layout insets
  static const EdgeInsets pageDesktop =
      EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0);
  static const EdgeInsets pageMobile =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0);
  static const EdgeInsets card = EdgeInsets.all(16.0);
  static const EdgeInsets cardCompact = EdgeInsets.all(12.0);
  static const EdgeInsets cardLarge = EdgeInsets.all(20.0);
  static const EdgeInsets dialog = EdgeInsets.all(24.0);
  static const EdgeInsets modalHeader =
      EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 12.0);
}

/// Standardized corner radii and borders across components
class AppRadii {
  static const double r4 = 4.0;
  static const double r6 = 6.0;
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;

  static const BorderRadius rounded4 = BorderRadius.all(Radius.circular(r4));
  static const BorderRadius rounded6 = BorderRadius.all(Radius.circular(r6));
  static const BorderRadius rounded8 = BorderRadius.all(Radius.circular(r8));
  static const BorderRadius rounded12 = BorderRadius.all(Radius.circular(r12));
  static const BorderRadius rounded16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius rounded20 = BorderRadius.all(Radius.circular(r20));
  static const BorderRadius rounded24 = BorderRadius.all(Radius.circular(r24));
}

/// Centralized Typography System using Plus Jakarta Sans
class AppTypography {
  // Page / Major Headings (~28-32 px, weight 700, line-height 1.25)
  static TextStyle pageTitle(bool isDark) => GoogleFonts.plusJakartaSans(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.5,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  // Section Headings (~20-22 px, weight 700, line-height 1.3)
  static TextStyle sectionTitle(bool isDark) => GoogleFonts.plusJakartaSans(
        fontSize: 20.0,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  // Card Titles (~16-18 px, weight 600, line-height 1.35)
  static TextStyle cardTitle(bool isDark) => GoogleFonts.plusJakartaSans(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  // Body Primary / Legal Explanation (~14-15 px, weight 400-500, line-height 1.5)
  static TextStyle body(bool isDark) => GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  // Body Secondary / Descriptions (~13-14 px, weight 400, line-height 1.45)
  static TextStyle bodySecondary(bool isDark) => GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      );

  // Metadata / Captions / Timestamps (~12-13 px, weight 500, line-height 1.35)
  static TextStyle caption(bool isDark) => GoogleFonts.plusJakartaSans(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color:
            isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      );

  // Button Labels / Actions (~14-15 px, weight 600)
  static TextStyle button(bool isDark) => GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      );

  // Chips & Badges (~12-13 px, weight 600)
  static TextStyle badge(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );
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
    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme)
            .copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.6),
      headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          height: 1.28,
          letterSpacing: -0.4),
      titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: -0.3),
      titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
          height: 1.35),
      titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
          height: 1.4),
      bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w400,
          height: 1.5),
      bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.lightTextSecondary,
          fontWeight: FontWeight.w400,
          height: 1.45),
      bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.lightTextSecondary,
          fontWeight: FontWeight.w400,
          height: 1.4),
      labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
      labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
      labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.2),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide:
              const BorderSide(color: AppColors.lightPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightError, width: 1.5),
        ),
        labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lightTextSecondary),
        hintStyle:
            const TextStyle(fontSize: 14, color: AppColors.lightTextSecondary),
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
          textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w700),
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
          textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w600),
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
    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
            .copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.6),
      headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          height: 1.28,
          letterSpacing: -0.4),
      titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: -0.3),
      titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
          height: 1.35),
      titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
          height: 1.4),
      bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w400,
          height: 1.5),
      bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
          fontWeight: FontWeight.w400,
          height: 1.45),
      bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.darkTextSecondary,
          fontWeight: FontWeight.w400,
          height: 1.4),
      labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
      labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
      labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.2),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary),
        hintStyle:
            const TextStyle(fontSize: 14, color: AppColors.darkTextSecondary),
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
          textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w600),
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
          textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w600),
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
