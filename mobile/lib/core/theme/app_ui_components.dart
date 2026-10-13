// lib/core/theme/app_ui_components.dart
//
// LEGACY component names kept so existing screens compile. They now delegate to
// the new design system (lib/core/widgets/app_ui.dart). New code should use:
//   AppSectionHeader   -> SectionHeader
//   AppTemplateCard    -> TemplateCard / TemplateGrid
//   AppWhatsAppButton  -> GradientButton(variant: GradientButtonVariant.whatsapp)
//   AppSearchBarTrigger-> keep (still valid) or AppSearchField for real input
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';
import '../widgets/ui/feedback.dart';
import '../widgets/ui/layout.dart';
import '../widgets/ui/motion.dart';
import 'app_theme.dart';
import '../../features/templates/domain/models/template_model.dart';

// ─── Section Header (legacy → SectionHeader) ──────────────────────────────────

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final String seeAllText;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllText = 'सभी देखें',
  });

  @override
  Widget build(BuildContext context) =>
      SectionHeader(title: title, subtitle: subtitle, onAction: onSeeAll, actionLabel: seeAllText);
}

// ─── Template Card (legacy; needs bounded height — prefer TemplateCard) ───────

class AppTemplateCard extends StatelessWidget {
  final TemplateModel template;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Widget? actionOverlay;

  const AppTemplateCard({
    super.key,
    required this.template,
    this.width,
    this.height,
    this.onTap,
    this.actionOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final imgUrl = template.imageThumbUrl ?? template.imageUrl ?? template.videoThumbUrl;
    final name = template.nameHi ?? template.nameEn ?? '';
    final isPremium = template.isPremium == true;
    final isLocked = template.isLocked;

    return PressableScale(
      onTap: onTap ?? () => context.push(isLocked ? '/premium' : '/template/${template.id}'),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
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
                        placeholder: (_, __) => const ShimmerBox(radius: 0),
                        errorWidget: (_, __, ___) => _FallbackGradient(template),
                      )
                    else
                      _FallbackGradient(template),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.scrimBottom)),
                    ),
                    if (isPremium)
                      const Positioned(top: 8, left: 8, child: PremiumBadge(compact: true)),
                    if (isLocked) const TemplateLock(),
                    if (actionOverlay != null) Positioned(top: 8, right: 8, child: actionOverlay!),
                  ],
                ),
              ),
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 14, weight: FontWeight.w700, color: p.textPrimary, height: 1.2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackGradient extends StatelessWidget {
  final TemplateModel template;
  const _FallbackGradient(this.template);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.parseGradient(template.gradient);
    return Container(
      decoration: BoxDecoration(
        gradient: colors != null
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)
            : AppColors.brandGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        (template.nameHi?.trim().isNotEmpty == true) ? template.nameHi!.trim().characters.first : '🙏',
        style: const TextStyle(fontSize: 32),
      ),
    );
  }
}

// ─── Search Bar Trigger (Home Header) ─────────────────────────────────────────

class AppSearchBarTrigger extends StatelessWidget {
  final VoidCallback onTap;
  final String hintText;

  const AppSearchBarTrigger({
    super.key,
    required this.onTap,
    this.hintText = 'सुप्रभात, महाकाल, त्योहार स्टेटस खोजें...',
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'खोजें',
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: p.border, width: 1),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 24, color: p.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hintText,
                style: AppText.body(size: 15, color: p.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WhatsApp Action Button (legacy → GradientButton) ─────────────────────────

class AppWhatsAppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const AppWhatsAppButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'व्हाट्सएप स्टेटस लगाएं',
  });

  @override
  Widget build(BuildContext context) => GradientButton(
        label: label,
        icon: Icons.share_rounded,
        variant: GradientButtonVariant.whatsapp,
        isLoading: isLoading,
        onPressed: onPressed,
      );
}

// ─── Infinite Scroll Footer ───────────────────────────────────────────────────

class PagingFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  const PagingFooter({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.8)),
        ),
      );
    }
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('और स्टेटस लोड नहीं हो सके — पुनः प्रयास करें'),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}
