// lib/core/theme/app_theme.dart
//
// Status Go design system — tokens + ThemeData (light & dark).
// Warm-friendly edition: saffron/cream palette + Nunito font for 35+ users.
//
// This is the ONLY file that may contain raw colour literals. Everything else
// must reference AppColors / AppPalette / Theme.of(context).
//
// See mobile/docs/DESIGN_SYSTEM.md for the full catalogue.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOURS
// ─────────────────────────────────────────────────────────────────────────────

/// Static colour tokens. Values here are the LIGHT-mode / brand values and are
/// `const`, so they can be used anywhere. For colours that must adapt to dark
/// mode use [AppPalette] via `context.palette`.
class AppColors {
  AppColors._();

  // ── Brand: warm saffron / marigold ─────────────────────────────────────────
  static const Color primary = Color(0xFFF97316);     // saffron orange — 4.5:1 on white
  static const Color primaryLight = Color(0xFFFFAA5C); // on-dark primary
  static const Color primaryDark = Color(0xFFEA580C);  // deep saffron
  static const Color primarySurface = Color(0xFFFFF1E3); // tinted bg
  static const Color primarySurfaceStrong = Color(0xFFFFDCB8);

  // ── Secondary: turmeric / warm gold ────────────────────────────────────────
  static const Color secondary = Color(0xFFF59E0B);   // turmeric amber
  static const Color secondaryDark = Color(0xFFB45309);
  static const Color secondarySurface = Color(0xFFFFF6DC);

  // ── Accent: deep marigold ──────────────────────────────────────────────────
  static const Color accent = Color(0xFFEA580C);
  static const Color accentDark = Color(0xFFC2410C);
  static const Color saffron = Color(0xFFFF8A00);
  static const Color accentSurface = Color(0xFFFEE9D4);
  static const Color rose = Color(0xFFDB2777);
  static const Color magenta = Color(0xFFDB2777);
  static const Color violet = Color(0xFF7C3AED);

  /// Brand gradient: saffron → deep orange → turmeric.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF97316), Color(0xFFEA580C)],
    stops: [0.0, 0.50, 1.0],
  );

  /// Soft warm tint gradient for hero backgrounds / tinted surfaces.
  static const LinearGradient brandSoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF7ED), Color(0xFFFFF1E3)],
  );

  /// Festival / trending gradient (saffron → rose).
  static const LinearGradient festivalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFDB2777)],
  );

  // ── Premium gold ──────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFF5B301);
  static const Color goldDark = Color(0xFFB45309);
  static const Color goldSurface = Color(0xFFFFF6DB);

  /// Gold gradient — put DARK ink text/icons on it ([ink]).
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD60A), Color(0xFFF5B301), Color(0xFFF59E0B)],
  );

  // ── WhatsApp (reserved for the SHARE CTA only) ─────────────────────────────
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);
  static const Color whatsappSurface = Color(0xFFE6F9EE);
  static const LinearGradient whatsappGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1FB855), Color(0xFF128C7E)],
  );

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF15803D);
  static const Color successSurface = Color(0xFFE7F7EC);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFFF4DC);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFDECEC);
  static const Color info = Color(0xFF0369A1);
  static const Color infoSurface = Color(0xFFE5F3FB);

  // ── Neutrals (light) — clean crisp white & modern slate ───────────────────
  static const Color bg = Color(0xFFF8FAFC);          // clean soft white (Slate 50)
  static const Color surface = Color(0xFFFFFFFF);     // pure white
  static const Color surfaceMuted = Color(0xFFF1F5F9); // slate 100
  static const Color surfaceBorder = Color(0xFFE2E8F0); // clean slate 200 border
  static const Color borderSubtle = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFE2E8F0);

  static const Color ink = Color(0xFF0F172A);          // deep slate 900 (16:1 contrast for 35+ users)
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155); // slate 700 (8.5:1 high-readability body)
  static const Color textMuted = Color(0xFF64748B);    // slate 500 captions (4.5:1 WCAG AA)
  static const Color textHint = Color(0xFF94A3B8);     // placeholders only
  static const Color textInverse = Color(0xFFFFFFFF);

  // ── Dark mode surfaces — sleek modern midnight slate ──────────────────────
  static const Color inkSurface = Color(0xFF0B0F19);   // deep midnight slate (no muddy brown)
  static const Color inkSurface2 = Color(0xFF1E293B);  // elevated slate 800 card
  static const Color inkSurface3 = Color(0xFF151E2E);  // slate 850
  static const Color inkBorder = Color(0xFF334155);    // slate 700 subtle border
  static const Color onDark = Color(0xFFF8FAFC);       // pure crisp white text (16:1 on dark)
  static const Color onDarkMuted = Color(0xFFCBD5E1);  // slate 300 body text
  static const Color onDarkHint = Color(0xFF94A3B8);   // slate 400

  /// Immersive page background (feed / preview).
  static const LinearGradient inkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B0F19), Color(0xFF1E293B)],
  );

  /// Scrim for text over full-bleed imagery.
  static const LinearGradient scrimBottom = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xCC0B0F19), Color(0x000B0F19)],
  );
  static const LinearGradient scrimTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x800B0F19), Color(0x000B0F19)],
  );

  // ── Glass overlays ────────────────────────────────────────────────────────
  static const Color glass = Color(0x1FFFFFFF);
  static const Color glassStrong = Color(0x29FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassLight = Color(0xCCFFFFFF);
  static const Color scrim = Color(0x731A0A00);        // warm modal barrier

  // ── Shimmer ───────────────────────────────────────────────────────────────
  static const Color shimmer = Color(0xFFECE5DB);
  static const Color shimmerHighlight = Color(0xFFF8F3EC);
  static const Color shimmerDark = Color(0xFF5A3D28);
  static const Color shimmerHighlightDark = Color(0xFF6B4A35);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  /// Parse a comma separated hex list ("#FF0000,#00FF00") into colours.
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

/// Theme-adaptive colours. Read with `context.palette`.
@immutable
class AppPalette {
  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textHint;
  final Color primary; // brand colour tuned for the surface
  final Color primarySurface;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textHint,
    required this.primary,
    required this.primarySurface,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  bool get isDark => brightness == Brightness.dark;

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    bg: AppColors.bg,
    surface: AppColors.surface,
    surfaceMuted: AppColors.surfaceMuted,
    surfaceElevated: AppColors.surface,
    border: AppColors.surfaceBorder,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    textHint: AppColors.textHint,
    primary: AppColors.primary,
    primarySurface: AppColors.primarySurface,
    shimmerBase: AppColors.shimmer,
    shimmerHighlight: AppColors.shimmerHighlight,
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    bg: AppColors.inkSurface,
    surface: AppColors.inkSurface2,
    surfaceMuted: AppColors.inkSurface3,
    surfaceElevated: AppColors.inkSurface3,
    border: AppColors.inkBorder,
    divider: AppColors.inkBorder,
    textPrimary: AppColors.onDark,
    textSecondary: AppColors.onDarkMuted,
    textMuted: AppColors.onDarkHint,
    textHint: AppColors.onDarkHint,
    primary: AppColors.primaryLight,
    primarySurface: Color(0x28FB923C),
    shimmerBase: Color(0xFF1E293B),
    shimmerHighlight: Color(0xFF334155),
  );
}

extension AppThemeContext on BuildContext {
  /// Brightness-aware colours.
  AppPalette get palette =>
      Theme.of(this).brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  TextTheme get text => Theme.of(this).textTheme;
}

// ─────────────────────────────────────────────────────────────────────────────
// SPACING / RADIUS / SHADOWS / MOTION
// ─────────────────────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  /// Default horizontal page gutter.
  static const double page = 20.0;

  /// Minimum touch target (dp) — 35+ friendly, slightly larger.
  static const double minTouch = 52.0;
}

class AppRadius {
  AppRadius._();
  static const double xs = 8.0;
  static const double sm = 12.0;  // tags, chips — rounder for warmth
  static const double md = 18.0;  // inputs, buttons, tiles
  static const double lg = 24.0;  // cards, template tiles
  static const double xl = 32.0;  // sheets, hero cards
  static const double pill = 999.0;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x100F172A), blurRadius: 18, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 26, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> bottomDock = [
    BoxShadow(color: Color(0x120F172A), blurRadius: 20, offset: Offset(0, -4)),
  ];

  // Coloured glows for CTAs
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(color: Color(0x66F97316), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> whatsappGlow = [
    BoxShadow(color: Color(0x6625D366), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> premiumGlow = [
    BoxShadow(color: Color(0x66F5B301), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> festivalGlow = [
    BoxShadow(color: Color(0x66EA580C), blurRadius: 22, offset: Offset(0, 8)),
  ];
}

class AppMotion {
  AppMotion._();
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 440);
  static const Duration stagger = Duration(milliseconds: 60);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve spring = Curves.easeOutBack;
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY — Nunito for 35+ friendly readability
// ─────────────────────────────────────────────────────────────────────────────

/// Headings & body: Nunito (warm, rounded). Devanagari glyphs
/// (Hindi / Marathi) fall back to Noto Sans Devanagari automatically.
class AppText {
  AppText._();

  static List<String> get _fallback => [
        GoogleFonts.notoSansDevanagari().fontFamily!,
      ];

  static TextStyle heading({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.25,
        letterSpacing: letterSpacing,
      ).copyWith(fontFamilyFallback: _fallback);

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.55,
        letterSpacing: letterSpacing,
      ).copyWith(fontFamilyFallback: _fallback);

  static TextTheme textTheme({required Color primary, required Color secondary, required Color muted}) {
    return TextTheme(
      // 35+ friendly: slightly larger sizes, generous line heights
      displayLarge: heading(size: 34, weight: FontWeight.w800, color: primary, height: 1.15, letterSpacing: -0.3),
      displayMedium: heading(size: 28, weight: FontWeight.w800, color: primary, height: 1.2, letterSpacing: -0.2),
      displaySmall: heading(size: 24, weight: FontWeight.w700, color: primary, height: 1.2),
      headlineLarge: heading(size: 26, weight: FontWeight.w700, color: primary),
      headlineMedium: heading(size: 22, weight: FontWeight.w700, color: primary),
      headlineSmall: heading(size: 20, weight: FontWeight.w700, color: primary),
      titleLarge: heading(size: 19, weight: FontWeight.w700, color: primary),
      titleMedium: heading(size: 17, weight: FontWeight.w600, color: primary),
      titleSmall: heading(size: 15, weight: FontWeight.w600, color: secondary),
      bodyLarge: body(size: 17, weight: FontWeight.w500, color: primary),
      bodyMedium: body(size: 16, weight: FontWeight.w400, color: secondary),
      bodySmall: body(size: 14, weight: FontWeight.w500, color: muted),
      labelLarge: body(size: 16, weight: FontWeight.w700, color: primary, height: 1.2),
      labelMedium: body(size: 14, weight: FontWeight.w600, color: secondary, height: 1.2),
      labelSmall: body(size: 13, weight: FontWeight.w600, color: muted, height: 1.2),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME DATA
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(AppPalette.light);
  static final ThemeData dark = _build(AppPalette.dark);

  /// Use for inherently dark screens (feed / preview) regardless of ThemeMode:
  /// `Theme(data: AppTheme.immersive, child: ...)` or `ImmersiveTheme(child: ...)`.
  static ThemeData get immersive => dark;

  static ThemeData _build(AppPalette p) {
    final isDark = p.isDark;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    final scheme = (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: p.primary,
      onPrimary: AppColors.white,
      primaryContainer: p.primarySurface,
      onPrimaryContainer: isDark ? AppColors.onDark : AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.secondarySurface,
      tertiary: AppColors.gold,
      onTertiary: AppColors.ink,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textMuted,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceMuted,
      surfaceContainerHighest: p.surfaceMuted,
      outline: p.border,
      outlineVariant: p.divider,
      error: AppColors.danger,
      onError: AppColors.white,
      errorContainer: AppColors.dangerSurface,
      shadow: AppColors.ink,
      inverseSurface: isDark ? AppColors.onDark : AppColors.ink,
      onInverseSurface: isDark ? AppColors.ink : AppColors.onDark,
    );

    final textTheme = AppText.textTheme(
      primary: p.textPrimary,
      secondary: p.textSecondary,
      muted: p.textMuted,
    );

    final shapeMd = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: p.border, width: 1.2),
    );

    return base.copyWith(
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: AppColors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.xs,
        toolbarHeight: 64,
        titleTextStyle: AppText.heading(size: 21, color: p.textPrimary, weight: FontWeight.w800),
        iconTheme: IconThemeData(color: p.textPrimary, size: 26),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: p.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: p.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: AppColors.transparent,
        modalBackgroundColor: p.surface,
        modalBarrierColor: AppColors.scrim,
        showDragHandle: false,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: AppText.heading(size: 20, color: p.textPrimary),
        contentTextStyle: AppText.body(size: 15.5, color: p.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: AppColors.transparent,
        indicatorColor: p.primarySurface,
        height: 72,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(color: sel ? p.primary : p.textMuted, size: 27);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return AppText.body(
            size: 13,
            weight: sel ? FontWeight.w800 : FontWeight.w500,
            color: sel ? p.primary : p.textMuted,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? p.surfaceMuted : p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.divider, width: 1)),
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: p.primary, width: 2.2)),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger, width: 1.4)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger, width: 2.2)),
        hintStyle: AppText.body(size: 16, color: p.textHint),
        labelStyle: AppText.body(size: 16, weight: FontWeight.w500, color: p.textMuted),
        floatingLabelStyle: AppText.body(size: 14, weight: FontWeight.w700, color: p.primary),
        helperStyle: AppText.body(size: 13.5, color: p.textMuted),
        errorStyle: AppText.body(size: 13.5, weight: FontWeight.w600, color: AppColors.danger),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: p.surfaceMuted,
          disabledForegroundColor: p.textHint,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: AppText.body(size: 17, weight: FontWeight.w800, height: 1.2),
          elevation: 0,
          shadowColor: AppColors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: AppText.body(size: 17, weight: FontWeight.w800, height: 1.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          side: BorderSide(color: p.border, width: 1.8),
          shape: const StadiumBorder(),
          textStyle: AppText.body(size: 17, weight: FontWeight.w700, height: 1.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: AppText.body(size: 16, weight: FontWeight.w700, height: 1.2),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          foregroundColor: p.textPrimary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary,
        disabledColor: p.surfaceMuted,
        side: BorderSide(color: p.border, width: 1),
        shape: const StadiumBorder(),
        labelStyle: AppText.body(size: 15, weight: FontWeight.w600, color: p.textPrimary, height: 1.2),
        secondaryLabelStyle:
            AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.white, height: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.white : (isDark ? AppColors.onDarkMuted : AppColors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : (isDark ? AppColors.inkBorder : AppColors.textHint),
        ),
        trackOutlineColor: WidgetStateProperty.all(AppColors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : AppColors.transparent,
        ),
        side: BorderSide(color: p.textMuted, width: 1.8),
      ),
      listTileTheme: ListTileThemeData(
        shape: shapeMd,
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        iconColor: p.textMuted,
        textColor: p.textPrimary,
        titleTextStyle: AppText.body(size: 17, weight: FontWeight.w600, color: p.textPrimary),
        subtitleTextStyle: AppText.body(size: 14.5, color: p.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.inkSurface3 : AppColors.ink,
        contentTextStyle: AppText.body(size: 15.5, weight: FontWeight.w600, color: AppColors.onDark),
        actionTextColor: AppColors.gold,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceMuted,
        circularTrackColor: p.surfaceMuted,
        linearMinHeight: 6,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.textMuted,
        labelStyle: AppText.body(size: 16, weight: FontWeight.w700, height: 1.2),
        unselectedLabelStyle: AppText.body(size: 16, weight: FontWeight.w500, height: 1.2),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.primary, width: 3),
          borderRadius: BorderRadius.circular(3),
        ),
        dividerColor: p.divider,
        overlayColor: WidgetStateProperty.all(p.primarySurface),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: AppColors.transparent,
        shape: shapeMd,
        textStyle: AppText.body(size: 15.5, color: p.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: AppRadius.smAll),
        textStyle: AppText.body(size: 13, color: AppColors.onDark),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
