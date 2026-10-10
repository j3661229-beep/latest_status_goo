// lib/features/home/presentation/widgets/festival_calendar_ribbon.dart
import 'package:flutter/material.dart';

import '../../../../core/data/indian_festivals_calendar.dart';
import '../../../../core/widgets/app_ui.dart';

/// Horizontal ribbon of upcoming festivals as vibrant gradient cards with a
/// days-left countdown.
class FestivalCalendarRibbon extends StatelessWidget {
  final ValueChanged<IndianFestivalItem>? onFestivalSelected;

  /// Festivals to show (e.g. from GET /festivals/upcoming). Defaults to the
  /// bundled static calendar (offline fallback).
  final List<IndianFestivalItem>? festivals;

  /// Header text colour override (null = theme-adaptive). Use [AppColors.onDark]
  /// on dark backgrounds.
  final Color? headerColor;

  /// Show the "त्योहार विशेष" section header.
  final bool showHeader;

  const FestivalCalendarRibbon({
    super.key,
    this.onFestivalSelected,
    this.festivals,
    this.headerColor,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = festivals ?? IndianFestivalsCalendar.getSortedUpcoming();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          SectionHeader(
            title: 'त्योहार विशेष',
            subtitle: 'आगामी त्योहारों के लिए स्टेटस तैयार करें',
            onDark: headerColor == AppColors.onDark || headerColor == AppColors.white,
          ),
        SizedBox(
          height: 156,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => FadeSlideIn(
              index: index,
              dy: 0,
              dx: 18,
              child: _FestivalCard(
                item: items[index],
                onTap: onFestivalSelected == null ? null : () => onFestivalSelected!(items[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FestivalCard extends StatelessWidget {
  final IndianFestivalItem item;
  final VoidCallback? onTap;

  const _FestivalCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = item.getDaysRemaining();
    final soon = days <= 1;
    final String countdown = days == 0
        ? 'आज'
        : days == 1
            ? 'कल'
            : '$days दिन';

    return PressableScale(
      onTap: onTap,
      semanticLabel: '${item.nameHi}, ${item.getFormattedDate()}, ${days == 0 ? 'आज' : '$days दिन बाकी'}',
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: item.gradient,
          ),
          borderRadius: AppRadius.lgAll,
          boxShadow: [
            BoxShadow(
              color: item.gradient.first.withValues(alpha: soon ? 0.45 : 0.28),
              blurRadius: soon ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -10,
              child: ExcludeSemantics(
                child: Text(
                  item.emoji,
                  style: TextStyle(fontSize: 64, color: AppColors.white.withValues(alpha: 0.22)),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 26)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.scrim,
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text(
                        countdown,
                        style: AppText.body(size: 12.5, weight: FontWeight.w800, color: AppColors.white, height: 1.1),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.nameHi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.heading(size: 16, weight: FontWeight.w700, color: AppColors.white, height: 1.25)
                      .copyWith(shadows: const [Shadow(color: AppColors.scrim, blurRadius: 4)]),
                ),
                const SizedBox(height: 2),
                Text(
                  item.getFormattedDate(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 13, weight: FontWeight.w700, color: AppColors.white, height: 1.2)
                      .copyWith(shadows: const [Shadow(color: AppColors.scrim, blurRadius: 4)]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
