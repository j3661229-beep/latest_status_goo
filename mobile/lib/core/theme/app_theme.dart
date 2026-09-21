// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Status Go brand palette
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF7C5CFC);
  static const Color primaryLight = Color(0xFF9B82FF);
  static const Color primaryDark = Color(0xFF6344E8);
  static const Color secondary = Color(0xFFFF6B9D);
  static const Color accent = Color(0xFF2DD4BF);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFFD60A);
  static const Color danger = Color(0xFFEF4444);

  // Background
  static const Color bg = Color(0xFFF8F7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceBorder = Color(0xFFEDECF8);
  static const Color shimmer = Color(0xFFEEECFF);

  // Text
  static const Color textPrimary = Color(0xFF1E1B4B);
  static const Color textSecondary = Color(0xFF6366F1);
  static const Color textMuted = Color(0xFF9A96B8);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primary],
  );

  static const LinearGradient devotionalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
  );

  static const LinearGradient morningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), primary],
  );

  // Shared card shadow
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // Glam template card shadow
  static List<BoxShadow> cardShadowFor(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: color.withOpacity(0.10),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  // Coordinator / Festival special colors
  static const Color coordinatorGold = Color(0xFFFFD700);
  static const Color festivalOrange = Color(0xFFFF6B35);

  /// Parse a gradient JSON string like "#FF7C5CFC,#FFFF6B9D" into a list of Colors.
  /// Returns null if the string is null or cannot be parsed.
  static List<Color>? parseGradient(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.split(',');
      if (parts.length < 2) return null;
      return parts.map((hex) {
        final h = hex.trim().replaceAll('#', '');
        final val = int.parse(h.padLeft(8, 'F'), radix: 16);
        return Color(val);
      }).toList();
    } catch (_) {
      return null;
    }
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.nunitoTextTheme().copyWith(
      displayLarge: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
      displayMedium: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      titleLarge: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      bodyLarge: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyMedium: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      bodySmall: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15),
        elevation: 0,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bg,
      selectedColor: AppColors.primary.withOpacity(0.1),
      labelStyle: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
      side: const BorderSide(color: AppColors.surfaceBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
