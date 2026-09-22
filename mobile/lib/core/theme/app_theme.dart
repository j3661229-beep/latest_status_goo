// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Status Go — Clean White & Royal Blue palette (40+ user design)
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1A56DB);       // Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);  // Medium blue
  static const Color secondary = Color(0xFF3B82F6);
  static const Color primarySurface = Color(0xFFEBF5FF); // Light blue bg
  static const Color accent = Color(0xFFF97316);         // Warm orange (festivals/CTAs)
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> cardShadowFor(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // Background & Surface
  static const Color bg = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceBorder = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF374151);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Shimmer
  static const Color shimmer = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF9FAFB);

  // Category gradients (solid fallbacks)
  static const Color devotional = Color(0xFFD97706);
  static const Color motivational = Color(0xFF1A56DB);
  static const Color festival = Color(0xFFF97316);
  static const Color morning = Color(0xFF059669);

  // Simple card shadow
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color(0x14000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        const BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

  /// Parse gradient JSON string → list of Colors
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
          secondary: AppColors.accent,
          surface: AppColors.surface,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        // Hind — excellent Devanagari (Hindi) rendering
        textTheme: GoogleFonts.hindTextTheme().copyWith(
          displayLarge: GoogleFonts.hind(
              fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          displayMedium: GoogleFonts.hind(
              fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          titleLarge: GoogleFonts.hind(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          titleMedium: GoogleFonts.hind(
              fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          titleSmall: GoogleFonts.hind(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          bodyLarge: GoogleFonts.hind(
              fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
          bodyMedium: GoogleFonts.hind(
              fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
          bodySmall: GoogleFonts.hind(
              fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMuted),
          labelLarge: GoogleFonts.hind(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 2,
          shadowColor: const Color(0x33000000),
          titleTextStyle: GoogleFonts.hind(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white, size: 26),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primarySurface,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 28);
            }
            return const IconThemeData(color: AppColors.textMuted, size: 26);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.hind(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary);
            }
            return GoogleFonts.hind(
                fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textMuted);
          }),
          elevation: 8,
          shadowColor: const Color(0x29000000),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          hintStyle: GoogleFonts.hind(
              fontSize: 16, color: AppColors.textHint, fontWeight: FontWeight.w400),
          labelStyle: GoogleFonts.hind(
              fontSize: 16, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 17),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 17),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primarySurface,
          labelStyle: GoogleFonts.hind(fontSize: 15, fontWeight: FontWeight.w500),
          side: const BorderSide(color: AppColors.surfaceBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: ListTileThemeData(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          titleTextStyle: GoogleFonts.hind(
              fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          subtitleTextStyle: GoogleFonts.hind(
              fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMuted),
          iconColor: AppColors.textMuted,
          minLeadingWidth: 24,
        ),
      );
}
