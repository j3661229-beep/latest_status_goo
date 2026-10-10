// lib/core/widgets/ui/layout.dart
//
// Scaffolds, backgrounds, headers, sheets, grouped settings lists, info cards,
// avatar and brand logo.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../profile_photo.dart';
import 'motion.dart';

// ── Theme override / backgrounds ──────────────────────────────────────────────

/// Forces the dark "immersive" theme for a subtree (feed / preview screens),
/// independent of the user's ThemeMode. Also sets light status-bar icons.
///
/// ```dart
/// ImmersiveTheme(child: Scaffold(...))
/// ```
class ImmersiveTheme extends StatelessWidget {
  final Widget child;
  const ImmersiveTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: AppColors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: child,
      ),
    );
  }
}

/// Scaffold with a full-bleed gradient background. Default is the dark ink
/// gradient (wrapped in [ImmersiveTheme]); pass any [gradient] to override.
///
/// ```dart
/// GradientScaffold(
///   body: SafeArea(child: ...),
///   gradient: AppColors.brandGradient, // optional
/// )
/// ```
class GradientScaffold extends StatelessWidget {
  final Widget body;
  final Gradient gradient;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;
  final bool dark;

  const GradientScaffold({
    super.key,
    required this.body,
    this.gradient = AppColors.inkGradient,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
    this.resizeToAvoidBottomInset = true,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: body,
    );
    final content = DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: scaffold,
    );
    return dark ? ImmersiveTheme(child: content) : content;
  }
}

/// Standard themed page: title bar + body. Use for every secondary page.
///
/// ```dart
/// AppScaffold(title: 'सेटिंग्स', body: ListView(...))
/// ```
class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final Widget? leading;
  final bool showBack;
  final PreferredSizeWidget? bottom;

  const AppScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.bottomBar,
    this.floatingActionButton,
    this.leading,
    this.showBack = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: leading ??
            (showBack && canPop
                ? IconButton(
                    tooltip: 'वापस जाएं',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null),
        title: title == null ? null : Text(title!),
        actions: actions,
        bottom: bottom,
      ),
      body: body,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

// ── Glass ─────────────────────────────────────────────────────────────────────

/// Frosted-glass container (blur + translucent fill + hairline border).
///
/// ```dart
/// GlassContainer(padding: EdgeInsets.all(12), child: Text('...'))
/// GlassContainer.light(child: ...) // for light pages
/// ```
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = AppRadius.lg,
    this.blur = 18,
    this.color,
    this.borderColor,
    this.shadows,
  });

  /// Glass tuned for light backgrounds.
  const GlassContainer.light({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = AppRadius.lg,
    this.blur = 18,
    this.shadows = AppShadows.floating,
  })  : color = AppColors.glassLight,
        borderColor = AppColors.white;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppColors.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? AppColors.glassBorder),
            boxShadow: shadows,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Headers ───────────────────────────────────────────────────────────────────

/// Section title with optional "सभी देखें" action.
///
/// ```dart
/// SectionHeader(title: 'आज के त्योहार', subtitle: 'Festivals', onAction: () => context.go('/discover'))
/// ```
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final bool onDark;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel = 'सभी देखें',
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm),
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final titleColor = onDark ? AppColors.onDark : p.textPrimary;
    final subColor = onDark ? AppColors.onDarkMuted : p.textMuted;
    final actionColor = onDark ? AppColors.primaryLight : p.primary;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.heading(size: 19, color: titleColor)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.body(size: 13.5, color: subColor, height: 1.3)),
                ],
              ],
            ),
          ),
          if (onAction != null)
            Semantics(
              button: true,
              label: '$actionLabel: $title',
              excludeSemantics: true,
              child: InkWell(
                onTap: onAction,
                borderRadius: AppRadius.pillAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel,
                          style: AppText.body(size: 14.5, weight: FontWeight.w700, color: actionColor, height: 1.2),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 20, color: actionColor),
                      ],
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

// ── Bottom sheets ─────────────────────────────────────────────────────────────

/// Small drag handle for sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(color: context.palette.border, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}

/// Title row for sheets (title, optional subtitle, close button).
class SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  const SheetHeader({super.key, required this.title, this.subtitle, this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.heading(size: 19, color: p.textPrimary)),
                if (subtitle != null)
                  Text(subtitle!, style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'बंद करें',
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Opens a themed modal bottom sheet with handle + header.
///
/// ```dart
/// final lang = await AppBottomSheet.show<String>(
///   context,
///   title: 'भाषा चुनें',
///   builder: (ctx) => Column(children: [...]),
/// );
/// ```
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? subtitle,
    required WidgetBuilder builder,
    bool scrollable = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        final body = builder(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              if (title != null) SheetHeader(title: title, subtitle: subtitle),
              if (scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
                    child: body,
                  ),
                )
              else
                Flexible(child: body),
            ],
          ),
        );
      },
    );
  }
}

// ── Grouped settings list ─────────────────────────────────────────────────────

/// Rounded group of rows with an optional caption title.
///
/// ```dart
/// SettingsSection(title: 'खाता', children: [
///   SettingsTile(icon: Icons.person_outline, title: 'प्रोफ़ाइल', onTap: ...),
///   SettingsTile(icon: Icons.language, title: 'भाषा', value: 'हिंदी', onTap: ...),
/// ])
/// ```
class SettingsSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsSection({
    super.key,
    this.title,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Divider(height: 1, indent: 72, endIndent: 16, color: p.divider));
      }
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Text(
                title!,
                style: AppText.body(size: 13.5, weight: FontWeight.w700, color: p.textMuted, letterSpacing: 0.4),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: p.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

/// One row inside a [SettingsSection].
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool destructive;
  final bool showChevron;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.destructive = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = destructive ? AppColors.danger : (iconColor ?? p.primary);
    final titleColor = destructive ? AppColors.danger : p.textPrimary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: destructive ? AppColors.dangerSurface : tone.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, size: 22, color: tone),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(size: 16, weight: FontWeight.w600, color: titleColor, height: 1.25)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3)),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 14.5, weight: FontWeight.w600, color: p.textMuted),
                    ),
                  ),
                ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (trailing == null && showChevron && onTap != null)
                Icon(Icons.chevron_right_rounded, color: p.textHint, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch row for a [SettingsSection] (or standalone).
///
/// ```dart
/// LabeledSwitchTile(icon: Icons.notifications_outlined, title: 'पुश सूचनाएं',
///     value: _on, onChanged: (v) => setState(() => _on = v))
/// ```
class LabeledSwitchTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const LabeledSwitchTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: p.primarySurface, borderRadius: AppRadius.smAll),
                  child: Icon(icon, size: 22, color: p.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(size: 16, weight: FontWeight.w600, color: p.textPrimary, height: 1.25)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: AppText.body(size: 13.5, color: p.textMuted, height: 1.3)),
                      ),
                  ],
                ),
              ),
              Semantics(
                label: title,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info / stats ──────────────────────────────────────────────────────────────

enum InfoTone { brand, info, success, warning, danger }

/// Tinted callout card.
///
/// ```dart
/// InfoCard(tone: InfoTone.warning, title: 'ध्यान दें', message: 'यह क्रिया वापस नहीं होगी।')
/// ```
class InfoCard extends StatelessWidget {
  final String? title;
  final String message;
  final InfoTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const InfoCard({
    super.key,
    this.title,
    required this.message,
    this.tone = InfoTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  (Color, Color, IconData) _spec(AppPalette p) {
    switch (tone) {
      case InfoTone.brand:
        return (p.primarySurface, p.primary, Icons.auto_awesome_rounded);
      case InfoTone.info:
        return (AppColors.infoSurface, AppColors.info, Icons.info_rounded);
      case InfoTone.success:
        return (AppColors.successSurface, AppColors.success, Icons.check_circle_rounded);
      case InfoTone.warning:
        return (AppColors.warningSurface, AppColors.warning, Icons.warning_amber_rounded);
      case InfoTone.danger:
        return (AppColors.dangerSurface, AppColors.danger, Icons.error_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg, defaultIcon) = _spec(p);
    // Tinted surfaces are light in both themes; text on them uses ink.
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: fg, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: AppText.body(size: 15.5, weight: FontWeight.w700, color: AppColors.ink, height: 1.3)),
                Text(message, style: AppText.body(size: 14.5, color: AppColors.textSecondary, height: 1.45)),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      onTap: onAction,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1,
                          child: Text(actionLabel!, style: AppText.body(size: 14.5, weight: FontWeight.w800, color: fg)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact value pill, e.g. streak / shares / saves.
///
/// ```dart
/// StatPill(icon: Icons.local_fire_department_rounded, value: '7', label: 'दिन स्ट्रीक', color: AppColors.accent)
/// ```
class StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final Color? color;

  const StatPill({super.key, required this.icon, required this.value, this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = color ?? p.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 6),
          Text(value, style: AppText.heading(size: 15, color: p.textPrimary, height: 1.1)),
          if (label != null) ...[
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 13, weight: FontWeight.w600, color: p.textMuted, height: 1.1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Avatar / logo ─────────────────────────────────────────────────────────────

/// Circular avatar with gradient ring (optional) and initial fallback.
/// Uses the profile_photo helpers, so URLs and local files both work.
///
/// ```dart
/// AppAvatar(image: currentUserPhotoProvider(serverPhoto: user?.profilePhoto), name: user?.name, radius: 36, ring: true)
/// ```
class AppAvatar extends StatelessWidget {
  final ImageProvider? image;
  final String? name;
  final double radius;
  final bool ring;
  final Gradient? ringGradient;

  const AppAvatar({
    super.key,
    this.image,
    this.name,
    this.radius = 28,
    this.ring = false,
    this.ringGradient,
  });

  /// Convenience: build from a URL / path string.
  AppAvatar.fromSource({
    super.key,
    String? source,
    this.name,
    this.radius = 28,
    this.ring = false,
    this.ringGradient,
  }) : image = photoImageProvider(source);

  @override
  Widget build(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    final initial = trimmed.isEmpty ? null : trimmed.characters.first.toUpperCase();
    final avatar = ProfilePhotoAvatar(
      image: image,
      radius: radius,
      backgroundColor: context.palette.primarySurface,
      fallback: initial == null
          ? Icon(Icons.person_rounded, size: radius, color: context.palette.primary)
          : Text(
              initial,
              style: AppText.heading(size: radius * 0.9, color: context.palette.primary, height: 1),
            ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: ringGradient ?? AppColors.festivalGradient),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, color: context.palette.bg),
        child: avatar,
      ),
    );
  }
}

/// Brand logo built from widgets: gradient rounded-square with "स्टे" + spark,
/// optionally with the "Status Go" wordmark.
///
/// ```dart
/// AppLogo(size: 88)                       // mark only
/// AppLogo(size: 72, showWordmark: true)   // mark + wordmark below
/// ```
class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final Color? wordmarkColor;
  final bool horizontal;

  const AppLogo({
    super.key,
    this.size = 72,
    this.showWordmark = false,
    this.wordmarkColor,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: AppShadows.primaryGlow,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'स्टे',
            style: AppText.heading(size: size * 0.4, weight: FontWeight.w800, color: AppColors.white, height: 1),
          ),
          Positioned(
            top: size * 0.14,
            right: size * 0.16,
            child: Icon(Icons.auto_awesome_rounded, size: size * 0.2, color: AppColors.gold),
          ),
          Positioned(
            bottom: size * 0.13,
            child: Container(
              width: size * 0.34,
              height: size * 0.05,
              decoration: BoxDecoration(
                gradient: AppColors.premiumGradient,
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
        ],
      ),
    );
    if (!showWordmark) {
      return Semantics(label: 'Status Go', image: true, child: mark);
    }
    final color = wordmarkColor ?? context.palette.textPrimary;
    final word = Column(
      crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Status Go', style: AppText.heading(size: size * 0.34, weight: FontWeight.w800, color: color, height: 1.1)),
        Text('स्टेटस गो',
            style: AppText.body(size: size * 0.2, weight: FontWeight.w600, color: color.withValues(alpha: 0.75), height: 1.2)),
      ],
    );
    return Semantics(
      label: 'Status Go',
      child: horizontal
          ? Row(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(width: size * 0.25), word])
          : Column(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(height: size * 0.2), word]),
    );
  }
}

/// Wraps a list child in a staggered entrance + press feedback in one go.
/// Handy for menu rows: `AnimatedListItem(index: i, child: ...)`.
class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  const AnimatedListItem({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) => FadeSlideIn(index: index, child: child);
}
