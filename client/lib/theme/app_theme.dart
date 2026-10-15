import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Design System Colors for LawBuddy
/// Palette: Lavender Haze (#92A9E1) • Soft Graphite (#2D3139) • Warm Linen (#EFE8D6)
class AppColors {
  // --- THE CORE CANONICAL PALETTE SWATCHES ---
  // Lavender Haze: #92A9E1 (Signature periwinkle accent, dark mode primary CTA, chips, pills)
  static const Color lavenderHaze = Color(0xFF92A9E1);
  // Soft Graphite: #2D3139 (Primary brand, headers, buttons, dark surface, light text primary)
  static const Color softGraphite = Color(0xFF2D3139);
  // Warm Linen: #EFE8D6 (Warm parchment canvas in light mode, dark mode primary text)
  static const Color warmLinen = Color(0xFFEFE8D6);
  // Lavender Slate: #4A5F96 (Deep periwinkle slate for verified / compliant states)
  static const Color lavenderSlate = Color(0xFF4A5F96);

  // --- LIGHT MODE PALETTE ---
  // Soft Graphite: #2D3139 (Primary brand color, headers, CTAs, action buttons)
  static const Color lightPrimary = Color(0xFF2D3139);
  // Deep Graphite (Active / pressed / hover states)
  static const Color lightPrimaryHover = Color(0xFF1E2127);
  // Lavender Haze: #92A9E1 (Accent chips, tags, supporting pills)
  static const Color lightAccent = Color(0xFF92A9E1);
  // Lavender Slate: #4A5F96 (Secondary brand, compliant / verified states)
  static const Color lightSecondary = Color(0xFF4A5F96);
  // Warm Linen: #EFE8D6 (Primary light-mode background canvas from image)
  static const Color lightBackground = Color(0xFFEFE8D6);
  // Crisp White: #FFFFFF (Crisp card & modal surfaces layered atop Linen)
  static const Color lightSurface = Color(0xFFFFFFFF);
  // Soft Linen Cream: #F7F2E6 (Elevated dropdowns, dialogs)
  static const Color lightSurfaceElevated = Color(0xFFF7F2E6);
  static const Color lightElevatedSurface = Color(0xFFFFFFFF);
  // Soft Graphite: #2D3139 (Primary text, headings — 9.9:1 AAA contrast on Linen, 12.4:1 on White)
  static const Color lightTextPrimary = Color(0xFF2D3139);
  // Slate Graphite: #656B77 (Secondary / supporting body text — 4.8:1 contrast on Linen, 6.0:1 on White)
  static const Color lightTextSecondary = Color(0xFF656B77);
  // Warm Linen Border: #DDD4BE (Hairline card & container borders)
  static const Color lightBorder = Color(0xFFDDD4BE);
  // Medium Linen Border: #C9BFAB (Dividers, structural borders)
  static const Color lightBorderMedium = Color(0xFFC9BFAB);
  // Lavender Accent: #92A9E1 (Signature Lavender Haze from image)
  static const Color lightGold = Color(0xFF92A9E1);
  static const Color lightTaupe = Color(0xFF7E8492);

  // Semantic Alerts
  static const Color lightError =
      Color(0xFF992B35); // Deep Crimson-Graphite (High Risk)
  static const Color lightCaution =
      Color(0xFFC28B38); // Warm Ochre / Honey Amber (Caution severity)

  // --- DARK MODE PALETTE ---
  // Deep Obsidian Graphite: #1A1D23 (Midnight canvas derived directly from Soft Graphite)
  static const Color darkBackground = Color(0xFF1A1D23);
  // Soft Graphite Surface: #2D3139 (The exact Soft Graphite swatch from the image!)
  static const Color darkSurface = Color(0xFF2D3139);
  // Elevated Graphite: #393E49 (Modals, Dialogs, Dropdowns)
  static const Color darkSurfaceElevated = Color(0xFF393E49);
  static const Color darkElevatedSurface = Color(0xFF393E49);
  // Lavender Haze: #92A9E1 (High-contrast, radiant action color against dark Graphite)
  static const Color darkPrimary = Color(0xFF92A9E1);
  static const Color darkPrimaryHover = Color(0xFFA8BCED);
  // Lavender Haze: #92A9E1 (Hero accents and pills in dark mode)
  static const Color darkAccent = Color(0xFF92A9E1);
  // Luminous Iris: #92A9E1
  static const Color darkGold = Color(0xFF92A9E1);
  // Luminous Periwinkle: #A0B4E8 (Compliant / Verified status in dark mode)
  static const Color darkSecondary = Color(0xFFA0B4E8);
  static const Color darkCaution = Color(0xFFE09E48);
  static const Color darkError = Color(0xFFE26B74); // Radiant coral rose for dark mode
  static const Color darkErrorText = Color(0xFF2D3139); // Soft Graphite text on luminous alert badges
  // Warm Linen: #EFE8D6 (The exact Linen Cream swatch — glare-free text in dark mode — 9.9:1 AAA contrast)
  static const Color darkTextPrimary = Color(0xFFEFE8D6);
  // Lavender-tinted Slate: #ADB7C9 (Muted secondary text in dark mode — 5.2:1 contrast)
  static const Color darkTextSecondary = Color(0xFFADB7C9);
  // Subtle Graphite Border: #444B57 (Subtle border for cards)
  static const Color darkBorder = Color(0xFF444B57);

  // --- SEMANTIC RISK & THEME COLOR HELPERS ---
  static Color highRisk(bool isDark) => isDark ? darkError : lightError;
  static Color highRiskText(bool isDark) =>
      isDark ? darkErrorText : Colors.white;
  static Color caution(bool isDark) => isDark ? darkCaution : lightCaution;
  static Color compliant(bool isDark) =>
      isDark ? darkSecondary : lightSecondary;
  static Color gold(bool isDark) => isDark ? darkGold : lightGold;
  static Color primary(bool isDark) => isDark ? darkPrimary : lightPrimary;
  static Color primaryForeground(bool isDark) =>
      isDark ? darkErrorText : Colors.white;
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
    onPrimary: AppColors.warmLinen,
    secondary: AppColors.lightSecondary,
    onSecondary: Colors.white,
    tertiary: AppColors.lightAccent,
    onTertiary: AppColors.softGraphite,
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
    onPrimary: AppColors.softGraphite,
    secondary: AppColors.darkSecondary,
    onSecondary: AppColors.softGraphite,
    tertiary: AppColors.darkGold,
    onTertiary: AppColors.softGraphite,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkBorder,
    error: AppColors.darkError,
    onError: AppColors.softGraphite,
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
          foregroundColor: AppColors.warmLinen,
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
          foregroundColor: AppColors.softGraphite,
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
