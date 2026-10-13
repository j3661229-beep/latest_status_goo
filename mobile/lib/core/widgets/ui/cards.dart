// lib/core/widgets/ui/cards.dart
//
// Badges, template card and masonry-style template grid.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/templates/domain/models/template_model.dart';
import '../../theme/app_theme.dart';
import 'feedback.dart';
import 'motion.dart';

/// Small rounded label badge (gradient or flat).
///
/// ```dart
/// AppBadge(label: 'नया', icon: Icons.bolt_rounded, gradient: AppColors.festivalGradient)
/// ```
class AppBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Gradient? gradient;
  final Color? color;
  final Color foreground;
  final bool compact;

  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.gradient,
    this.color,
    this.foreground = AppColors.white,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (color ?? AppColors.ink.withValues(alpha: 0.7)) : null,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: compact ? 12 : 14, color: foreground), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: compact ? 10.5 : 12.5, weight: FontWeight.w800, color: foreground, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold crown badge for premium content.
///
/// ```dart
/// const PremiumBadge()            // "प्रीमियम"
/// const PremiumBadge(compact: true)
/// ```
class PremiumBadge extends StatelessWidget {
  final String label;
  final bool compact;
  const PremiumBadge({super.key, this.label = 'प्रीमियम', this.compact = false});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: label,
      icon: Icons.workspace_premium_rounded,
      gradient: AppColors.premiumGradient,
      foreground: AppColors.ink,
      compact: compact,
    );
  }
}

/// Lock overlay for premium templates the user cannot use yet.
class TemplateLock extends StatelessWidget {
  final bool compact;
  const TemplateLock({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'प्रीमियम स्टेटस — अनलॉक करने के लिए प्रीमियम लें',
      child: Container(
        color: AppColors.scrim,
        alignment: Alignment.center,
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 16),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.premiumGradient,
            boxShadow: AppShadows.premiumGlow,
          ),
          child: Icon(Icons.lock_rounded, color: AppColors.ink, size: compact ? 20 : 30),
        ),
      ),
    );
  }
}

String formatCount(int n) {
  if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Full-bleed rounded template tile: image with shimmer placeholder, scrim,
/// premium/trending/new badges, lock overlay and use-count.
///
/// Default tap: locked → `/premium`, otherwise `/template/:id`.
///
/// ```dart
/// TemplateCard(template: t, aspectRatio: 0.72)
/// TemplateCard(template: t, onTap: () => ..., showTitle: false, actionOverlay: removeBtn)
/// ```
class TemplateCard extends StatelessWidget {
  final TemplateModel template;
  final double aspectRatio; // width / height of the artwork
  final VoidCallback? onTap;
  final bool showTitle;
  final bool showStats;
  final Widget? actionOverlay; // top-right slot
  final double radius;

  const TemplateCard({
    super.key,
    required this.template,
    this.aspectRatio = 0.75,
    this.onTap,
    this.showTitle = true,
    this.showStats = true,
    this.actionOverlay,
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final imgUrl = template.imageThumbUrl ?? template.imageUrl ?? template.videoThumbUrl;
    final name = template.nameHi ?? template.nameEn ?? '';
    final isPremium = template.isPremium == true;
    final isLocked = template.isLocked;
    final uses = template.useCount ?? 0;

    return PressableScale(
      semanticLabel: name.isEmpty ? 'स्टेटस टेम्पलेट' : name,
      onTap: onTap ?? () => context.push(isLocked ? '/premium' : '/template/${template.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: AppShadows.card,
                color: p.surfaceMuted,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: AppMotion.normal,
                      placeholder: (_, __) => const ShimmerBox(radius: 0),
                      errorWidget: (_, __, ___) => _FallbackArt(template),
                    )
                  else
                    _FallbackArt(template),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 72,
                    child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.scrimBottom)),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (isPremium) const PremiumBadge(compact: true),
                              if (template.isTrending == true)
                                const AppBadge(
                                  label: 'ट्रेंडिंग',
                                  icon: Icons.local_fire_department_rounded,
                                  gradient: AppColors.festivalGradient,
                                  compact: true,
                                )
                              else if (template.isNew == true)
                                const AppBadge(
                                  label: 'नया',
                                  icon: Icons.bolt_rounded,
                                  gradient: AppColors.brandGradient,
                                  compact: true,
                                ),
                            ],
                          ),
                        ),
                        if (actionOverlay != null) actionOverlay!,
                      ],
                    ),
                  ),
                  if (isLocked) const TemplateLock(),
                  if (showStats && uses > 0)
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_done_rounded, size: 14, color: AppColors.white),
                          const SizedBox(width: 4),
                          Text(
                            formatCount(uses),
                            style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.white, height: 1),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showTitle && name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 14.5, weight: FontWeight.w700, color: p.textPrimary, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _FallbackArt extends StatelessWidget {
  final TemplateModel template;
  const _FallbackArt(this.template);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.parseGradient(template.gradient);
    final trimmed = template.nameHi?.trim();
    final label = (trimmed != null && trimmed.isNotEmpty) ? trimmed.characters.first : '🙏';
    return Container(
      decoration: BoxDecoration(
        gradient: colors != null
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)
            : AppColors.brandGradient,
      ),
      alignment: Alignment.center,
      child: Text(label, style: AppText.heading(size: 40, color: AppColors.white)),
    );
  }
}

/// Two-column masonry grid (plain widgets; items flow into the shorter column).
/// Non-scrolling — place inside a scroll view (or use [SliverTemplateGrid]).
///
/// ```dart
/// TemplateGrid(templates: list, onTapTemplate: (t) => ...)
/// ```
class TemplateGrid extends StatelessWidget {
  final List<TemplateModel> templates;
  final void Function(TemplateModel)? onTapTemplate;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final bool showTitle;
  final Widget Function(TemplateModel)? actionBuilder;

  /// Width/height ratios cycled through to create the masonry rhythm.
  static const List<double> ratios = [0.72, 0.86, 0.78, 0.66, 0.9, 0.74];

  const TemplateGrid({
    super.key,
    required this.templates,
    this.onTapTemplate,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
    this.spacing = AppSpacing.sm,
    this.showTitle = true,
    this.actionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    var leftH = 0.0;
    var rightH = 0.0;
    for (var i = 0; i < templates.length; i++) {
      final t = templates[i];
      final ratio = ratios[i % ratios.length];
      final est = 1 / ratio + (showTitle ? 0.2 : 0);
      final item = Padding(
        key: ValueKey(t.id),
        padding: EdgeInsets.only(bottom: spacing + 4),
        child: FadeSlideIn(
          key: ValueKey('fade-${t.id}'),
          index: i % 6,
          child: TemplateCard(
            template: t,
            aspectRatio: ratio,
            showTitle: showTitle,
            actionOverlay: actionBuilder?.call(t),
            onTap: onTapTemplate == null ? null : () => onTapTemplate!(t),
          ),
        ),
      );
      if (leftH <= rightH) {
        left.add(item);
        leftH += est;
      } else {
        right.add(item);
        rightH += est;
      }
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left)),
          SizedBox(width: spacing),
          Expanded(child: Column(children: right)),
        ],
      ),
    );
  }
}

/// Sliver wrapper around [TemplateGrid] for CustomScrollView screens.
class SliverTemplateGrid extends StatelessWidget {
  final List<TemplateModel> templates;
  final void Function(TemplateModel)? onTapTemplate;
  final EdgeInsetsGeometry padding;
  final bool showTitle;
  final Widget Function(TemplateModel)? actionBuilder;

  const SliverTemplateGrid({
    super.key,
    required this.templates,
    this.onTapTemplate,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
    this.showTitle = true,
    this.actionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: TemplateGrid(
        templates: templates,
        onTapTemplate: onTapTemplate,
        padding: padding,
        showTitle: showTitle,
        actionBuilder: actionBuilder,
      ),
    );
  }
}
