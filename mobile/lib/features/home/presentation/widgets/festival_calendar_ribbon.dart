// lib/features/home/presentation/widgets/festival_calendar_ribbon.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/data/indian_festivals_calendar.dart';

class FestivalCalendarRibbon extends StatelessWidget {
  final ValueChanged<IndianFestivalItem>? onFestivalSelected;

  const FestivalCalendarRibbon({
    super.key,
    this.onFestivalSelected,
  });

  @override
  Widget build(BuildContext context) {
    final festivals = IndianFestivalsCalendar.getSortedUpcoming();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🗓️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'आगामी त्योहार • Festivals',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Text(
                'कैलेंडर',
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Horizontal Ribbon
        SizedBox(
          height: 124,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: festivals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = festivals[index];
              final isTodayOrTomorrow = item.getDaysRemaining() <= 1;

              return InkWell(
                onTap: () => onFestivalSelected?.call(item),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 155,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: item.gradient,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: item.gradient.first.withOpacity(isTodayOrTomorrow ? 0.45 : 0.25),
                        blurRadius: isTodayOrTomorrow ? 14 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Emoji & Countdown Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.emoji, style: const TextStyle(fontSize: 22)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.getCountdownBadge(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Bottom: Festival Name & Date
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nameHi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.nameEn,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                item.getFormattedDate(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
