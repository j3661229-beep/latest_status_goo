// lib/features/home/presentation/widgets/discover_widgets.dart
//
// Small building blocks shared by Discover and Search.
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../../templates/domain/models/template_model.dart';

/// Large rounded search "entry" (tap-only, not a text field).
class DiscoverSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;

  const DiscoverSearchBar({
    super.key,
    required this.onTap,
    this.hint = 'सुप्रभात, महाकाल, त्योहार खोजें...',
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
          border: Border.all(color: p.border),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 24, color: p.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 15.5, color: p.textMuted, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented pills: सभी / फोटो / वीडियो. `value` is null (all), 'IMAGE' or 'VIDEO'.
class TemplateTypeSegment extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final EdgeInsetsGeometry padding;

  const TemplateTypeSegment({
    super.key,
    required this.value,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
  });

  static const _options = <(String?, String, IconData)>[
    (null, 'सभी', Icons.apps_rounded),
    ('IMAGE', 'फोटो', Icons.image_rounded),
    ('VIDEO', 'वीडियो', Icons.play_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: AppRadius.pillAll),
        child: Row(
          children: [
            for (final o in _options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == o.$1,
                  label: o.$2,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(o.$1),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        gradient: value == o.$1 ? AppColors.brandGradient : null,
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(o.$3, size: 18, color: value == o.$1 ? AppColors.white : p.textSecondary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              o.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(
                                size: 14.5,
                                weight: FontWeight.w700,
                                color: value == o.$1 ? AppColors.white : p.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Titled horizontal carousel of [TemplateCard]s.
class TemplateCarouselSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<TemplateModel> templates;
  final int staggerIndex;

  const TemplateCarouselSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.templates,
    this.staggerIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    return FadeSlideIn(
      index: staggerIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => SizedBox(
                width: 158,
                child: TemplateCard(template: templates[i], aspectRatio: 0.74),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
