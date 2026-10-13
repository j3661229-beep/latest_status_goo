// lib/features/home/presentation/widgets/home_feed_widgets.dart
//
// Building blocks of the immersive Home feed: header, category pills, the
// Crafto-style action rail, the caption block, swipe hint and loading skeleton.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../templates/domain/models/template_model.dart';
import '../../../templates/presentation/widgets/template_composition.dart';

/// Heights used to reserve space under the overlay chrome.
class HomeChrome {
  HomeChrome._();
  static const double headerHeight = 60;
  static const double pillsHeight = 52;

  /// Total top inset a page must reserve (status bar + header + pills).
  static double topInset(BuildContext context) =>
      MediaQuery.of(context).padding.top + headerHeight + pillsHeight;
}

// ─── Header ───────────────────────────────────────────────────────────────────

class HomeHeader extends StatelessWidget {
  final String greeting;
  final Widget chip;
  final ImageProvider? photo;
  final String name;
  final int unread;
  final VoidCallback onAvatarTap;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  const HomeHeader({
    super.key,
    required this.greeting,
    required this.chip,
    required this.photo,
    required this.name,
    required this.unread,
    required this.onAvatarTap,
    required this.onSearch,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeChrome.headerHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xxs),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'अपनी फोटो और नाम बदलें',
              child: PressableScale(
                onTap: onAvatarTap,
                child: SizedBox(
                  width: AppSpacing.minTouch - 4,
                  height: AppSpacing.minTouch,
                  child: Center(child: AppAvatar(image: photo, name: name, radius: 20, ring: true)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.heading(size: 17, color: AppColors.onDark, height: 1.25),
                  ),
                  const SizedBox(height: 2),
                  Align(alignment: AlignmentDirectional.centerStart, child: chip),
                ],
              ),
            ),
            AppIconButton(
              icon: Icons.search_rounded,
              glass: true,
              semanticLabel: 'खोजें',
              onPressed: onSearch,
            ),
            Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              offset: const Offset(-6, 4),
              child: AppIconButton(
                icon: Icons.notifications_none_rounded,
                glass: true,
                semanticLabel: unread > 0 ? 'सूचनाएं, $unread नई' : 'सूचनाएं',
                onPressed: onNotifications,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small glass chip: "आज • 11 अक्टूबर" or a festival gradient chip.
class HomeInfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool festival;

  const HomeInfoChip({super.key, required this.label, required this.icon, this.festival = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: festival ? AppColors.festivalGradient : null,
        color: festival ? null : AppColors.glass,
        borderRadius: AppRadius.pillAll,
        border: festival ? null : Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.white, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category pills ───────────────────────────────────────────────────────────

class HomeCategory {
  final String slug;
  final String label;
  final String emoji;
  const HomeCategory(this.slug, this.label, [this.emoji = '']);
}

class HomeCategoryPills extends StatelessWidget {
  final List<HomeCategory> categories;
  final String selectedSlug;
  final ValueChanged<HomeCategory> onSelected;

  const HomeCategoryPills({
    super.key,
    required this.categories,
    required this.selectedSlug,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeChrome.pillsHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final c = categories[i];
          final selected = c.slug == selectedSlug;
          return Semantics(
            button: true,
            selected: selected,
            label: c.label,
            child: PressableScale(
              onTap: () {
                if (selected) return;
                HapticFeedback.selectionClick();
                onSelected(c);
              },
              child: Center(
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.brandGradient : null,
                    color: selected ? null : AppColors.glass,
                    borderRadius: AppRadius.pillAll,
                    border: selected ? null : Border.all(color: AppColors.glassBorder),
                    boxShadow: selected ? AppShadows.primaryGlow.map((s) => s.scale(0.5)).toList() : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.emoji.isNotEmpty) ...[
                        Text(c.emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        c.label,
                        maxLines: 1,
                        style: AppText.body(
                          size: 14.5,
                          weight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? AppColors.white : AppColors.onDark,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Action rail ──────────────────────────────────────────────────────────────

class RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final Color? iconColor;
  final double size;
  final bool busy;

  const RailButton({
    super.key,
    required this.icon,
    required this.label,
    this.count,
    this.onTap,
    this.gradient,
    this.shadows,
    this.iconColor,
    this.size = 52,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final big = size > 56;
    return Semantics(
      button: true,
      label: count == null ? label : '$label, $count',
      onTap: onTap,
      child: PressableScale(
        onTap: busy ? null : onTap,
        scale: 0.9,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                  color: gradient == null ? AppColors.ink.withValues(alpha: 0.55) : null,
                  border: gradient == null ? Border.all(color: AppColors.glassBorder) : null,
                  boxShadow: shadows,
                ),
                child: busy
                    ? Padding(
                        padding: EdgeInsets.all(size * 0.28),
                        child: const CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.white),
                      )
                    : Icon(icon, size: big ? 32 : 26, color: iconColor ?? AppColors.white),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppText.body(
                    size: big ? 14 : 12.5,
                    weight: FontWeight.w800,
                    color: AppColors.white,
                    height: 1.2,
                  ).copyWith(shadows: const [Shadow(blurRadius: 6, color: AppColors.ink)]),
                ),
              ),
              if (count != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    count!,
                    maxLines: 1,
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.onDarkMuted, height: 1.2)
                        .copyWith(shadows: const [Shadow(blurRadius: 6, color: AppColors.ink)]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Caption ──────────────────────────────────────────────────────────────────

class FeedCaption extends StatelessWidget {
  final TemplateModel template;
  const FeedCaption({super.key, required this.template});

  static String titleOf(TemplateModel t) {
    for (final s in [t.nameHi, t.nameMr, t.nameEn, t.category?.nameHi, t.category?.nameEn]) {
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    return 'स्टेटस';
  }

  bool get _isFestival {
    final slug = (template.category?.slug ?? '').toLowerCase();
    return slug.contains('festival') || template.tags.any((t) => t.toLowerCase().contains('festival'));
  }

  @override
  Widget build(BuildContext context) {
    final cat = template.category;
    final catLabel = (cat?.nameHi?.isNotEmpty == true) ? cat!.nameHi! : (cat?.nameEn ?? '');
    final uses = template.useCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (template.isPremium == true || template.isLocked) const PremiumBadge(compact: true),
            if (_isFestival)
              const AppBadge(
                label: 'त्योहार',
                icon: Icons.celebration_rounded,
                gradient: AppColors.festivalGradient,
                compact: true,
              )
            else if (template.isTrending == true)
              const AppBadge(
                label: 'ट्रेंडिंग',
                icon: Icons.local_fire_department_rounded,
                gradient: AppColors.festivalGradient,
                compact: true,
              ),
            if (catLabel.isNotEmpty)
              AppBadge(
                label: '${(cat?.emoji ?? '').trim().isEmpty ? '' : '${cat?.emoji} '}$catLabel',
                color: AppColors.glassStrong,
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          titleOf(template),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.heading(size: 19, color: AppColors.white, height: 1.3),
        ),
        if (uses > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${formatCount(uses)} लोगों ने इस्तेमाल किया',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 13, color: AppColors.onDarkMuted, height: 1.3),
            ),
          ),
      ],
    );
  }
}

/// "अनलॉक करें" pill shown on premium-locked cards.
class UnlockPill extends StatelessWidget {
  final VoidCallback onTap;
  const UnlockPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      haptic: true,
      semanticLabel: 'प्रीमियम अनलॉक करें',
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: AppColors.premiumGradient,
          borderRadius: AppRadius.pillAll,
          boxShadow: AppShadows.premiumGlow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 20, color: AppColors.ink),
            const SizedBox(width: 6),
            Text(
              'Premium लें',
              style: AppText.body(size: 15, weight: FontWeight.w800, color: AppColors.ink, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Swipe hint ───────────────────────────────────────────────────────────────

class SwipeUpHint extends StatefulWidget {
  const SwipeUpHint({super.key});

  @override
  State<SwipeUpHint> createState() => _SwipeUpHintState();
}

class _SwipeUpHintState extends State<SwipeUpHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: 'अगला स्टेटस देखने के लिए ऊपर स्वाइप करें',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -10 * Curves.easeInOut.transform(_c.value)),
                child: child,
              ),
              child: const Icon(
                Icons.keyboard_double_arrow_up_rounded,
                size: 36,
                color: AppColors.white,
                shadows: [Shadow(blurRadius: 8, color: AppColors.ink)],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.7),
                borderRadius: AppRadius.pillAll,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                'ऊपर स्वाइप करें',
                style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.white, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class HomeFeedSkeleton extends StatelessWidget {
  const HomeFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: HomeChrome.topInset(context), bottom: AppSpacing.sm),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 14, right: 4),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: kStatusAspectRatio,
                        child: ShimmerBox(radius: AppRadius.lg),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        ShimmerBox(width: 60, height: 60, radius: AppRadius.pill),
                        SizedBox(height: 16),
                        ShimmerBox(width: 48, height: 48, radius: AppRadius.pill),
                        SizedBox(height: 16),
                        ShimmerBox(width: 48, height: 48, radius: AppRadius.pill),
                        SizedBox(height: 16),
                        ShimmerBox(width: 48, height: 48, radius: AppRadius.pill),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 20, radius: AppRadius.pill),
                  SizedBox(height: 8),
                  ShimmerBox(width: 240, height: 22, radius: AppRadius.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
