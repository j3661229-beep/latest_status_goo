// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Status Go — Design Tokens & Core System
class AppColors {
  AppColors._();

  // ── Brand Colors ────────────────────────────────────────────────────────────
  // Royal Indigo — trustworthy, mature, vibrant
  static const Color primary = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primarySurface = Color(0xFFEFF6FF); // Ultra-light blue tint
  static const Color primaryDark = Color(0xFF1E40AF);
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
  );

  // WhatsApp Green — reserved exclusively for primary sharing action
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF1EBE5D);
  static const Color whatsappSurface = Color(0xFFE8F8EE);

  // Warm Accent — for festivals, trending alerts
  static const Color accent = Color(0xFFEA580C);
  static const Color accentSurface = Color(0xFFFFF7ED);

  // Semantic Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);

  // ── Surface & Background ──────────────────────────────────────────────────
  static const Color bg = Color(0xFFF8FAFC);         // Clean off-white canvas
  static const Color surface = Color(0xFFFFFFFF);    // Pure white cards & sheets
  static const Color surfaceMuted = Color(0xFFF1F5F9);// Subtle fills, chips, search
  static const Color surfaceBorder = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFEEF2F6);
  static const Color divider = Color(0xFFF1F5F9);

  // ── Typography Colors ─────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);   // High contrast slate
  static const Color textSecondary = Color(0xFF334155); // Body text
  static const Color textMuted = Color(0xFF64748B);     // Captions & timestamps
  static const Color textHint = Color(0xFF94A3B8);      // Form placeholders
  static const Color textInverse = Color(0xFFFFFFFF);   // On dark / brand buttons

  // ── Media & Shimmer ───────────────────────────────────────────────────────
  static const Color shimmer = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);

  // Parse gradient JSON string if template has color stops
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

/// Restrained spacing scale
class AppSpacing {
  AppSpacing._();
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Restrained radius scale
class AppRadius {
  AppRadius._();
  static const double sm = 8.0;   // Tags, chips, indicators
  static const double md = 12.0;  // Inputs, buttons
  static const double lg = 14.0;  // Media thumbnails & cards
  static const double xl = 20.0;  // Bottom sheets
  static const double pill = 999.0;
}

/// Restrained, natural shadows
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> bottomDock = [
    BoxShadow(
      color: Color(0x120F172A),
      blurRadius: 16,
      offset: Offset(0, -4),
    ),
  ];
}

/// Refined ThemeData
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.danger,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: GoogleFonts.hindTextTheme().copyWith(
          displayLarge: GoogleFonts.hind(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: GoogleFonts.hind(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
          titleLarge: GoogleFonts.hind(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          titleMedium: GoogleFonts.hind(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleSmall: GoogleFonts.hind(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          bodyLarge: GoogleFonts.hind(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
          bodyMedium: GoogleFonts.hind(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          bodySmall: GoogleFonts.hind(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
          labelLarge: GoogleFonts.hind(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: const Color(0x1A000000),
          centerTitle: false,
          titleTextStyle: GoogleFonts.hind(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.surfaceBorder, width: 0.8),
          ),
          margin: EdgeInsets.zero,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primarySurface,
          height: 64,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 24);
            }
            return const IconThemeData(color: AppColors.textMuted, size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.hind(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              );
            }
            return GoogleFonts.hind(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            );
          }),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceMuted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          hintStyle: GoogleFonts.hind(
            fontSize: 15,
            color: AppColors.textHint,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: GoogleFonts.hind(
            fontSize: 15,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            textStyle: GoogleFonts.hind(fontWeight: FontWeight.w700, fontSize: 16),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.surfaceBorder, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            textStyle: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: GoogleFonts.hind(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
      );
}
