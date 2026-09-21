// lib/core/data/indian_festivals_calendar.dart
import 'package:flutter/material.dart';

class IndianFestivalItem {
  final String id;
  final String nameHi;
  final String nameEn;
  final String emoji;
  final int month; // 1-12
  final int day;   // 1-31
  final String categorySlug;
  final List<Color> gradient;

  const IndianFestivalItem({
    required this.id,
    required this.nameHi,
    required this.nameEn,
    required this.emoji,
    required this.month,
    required this.day,
    required this.categorySlug,
    required this.gradient,
  });

  /// Calculates days remaining from today
  int getDaysRemaining() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var targetDate = DateTime(now.year, month, day);

    if (targetDate.isBefore(today)) {
      // If already passed this year, point to next year
      targetDate = DateTime(now.year + 1, month, day);
    }

    return targetDate.difference(today).inDays;
  }

  String getCountdownBadge() {
    final days = getDaysRemaining();
    if (days == 0) return '🎉 आज (Today)';
    if (days == 1) return '🔥 कल (Tomorrow)';
    return '$days दिन बाकी';
  }

  String getFormattedDate() {
    const months = [
      '', 'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
    ];
    return '$day ${months[month]}';
  }
}

class IndianFestivalsCalendar {
  IndianFestivalsCalendar._();

  static const List<IndianFestivalItem> upcomingFestivals = [
    IndianFestivalItem(
      id: 'navratri',
      nameHi: 'शारदीय नवरात्रि',
      nameEn: 'Navratri',
      emoji: '🪔',
      month: 10,
      day: 11,
      categorySlug: 'festivals',
      gradient: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    ),
    IndianFestivalItem(
      id: 'dussehra',
      nameHi: 'विजयादशमी (दशहरा)',
      nameEn: 'Dussehra',
      emoji: '🏹',
      month: 10,
      day: 20,
      categorySlug: 'festivals',
      gradient: [Color(0xFFF7971E), Color(0xFFFFD200)],
    ),
    IndianFestivalItem(
      id: 'karwa_chauth',
      nameHi: 'करवा चौथ',
      nameEn: 'Karwa Chauth',
      emoji: '🌕',
      month: 10,
      day: 29,
      categorySlug: 'festivals',
      gradient: [Color(0xFF8A2387), Color(0xFFE94057)],
    ),
    IndianFestivalItem(
      id: 'dhanteras',
      nameHi: 'धनतेरस',
      nameEn: 'Dhanteras',
      emoji: '🪙',
      month: 11,
      day: 8,
      categorySlug: 'festivals',
      gradient: [Color(0xFFFFB75E), Color(0xFFED8F03)],
    ),
    IndianFestivalItem(
      id: 'diwali',
      nameHi: 'दीपावली (दिवाली)',
      nameEn: 'Diwali',
      emoji: '🪔',
      month: 11,
      day: 10,
      categorySlug: 'festivals',
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
    ),
    IndianFestivalItem(
      id: 'govardhan',
      nameHi: 'गोवर्धन पूजा',
      nameEn: 'Govardhan Puja',
      emoji: '🏔️',
      month: 11,
      day: 11,
      categorySlug: 'festivals',
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    IndianFestivalItem(
      id: 'bhai_dooj',
      nameHi: 'भाई दूज',
      nameEn: 'Bhai Dooj',
      emoji: '🌸',
      month: 11,
      day: 12,
      categorySlug: 'festivals',
      gradient: [Color(0xFFDA22FF), Color(0xFF9733EE)],
    ),
    IndianFestivalItem(
      id: 'chhath',
      nameHi: 'छठ पूजा',
      nameEn: 'Chhath Puja',
      emoji: '🌅',
      month: 11,
      day: 16,
      categorySlug: 'festivals',
      gradient: [Color(0xFFFF8008), Color(0xFFFFC837)],
    ),
    IndianFestivalItem(
      id: 'guru_nanak',
      nameHi: 'गुरु नानक जयंती',
      nameEn: 'Guru Nanak Jayanti',
      emoji: 'ੴ',
      month: 11,
      day: 24,
      categorySlug: 'festivals',
      gradient: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
    ),
    IndianFestivalItem(
      id: 'new_year',
      nameHi: 'नव वर्ष 2027',
      nameEn: 'New Year',
      emoji: '🎊',
      month: 1,
      day: 1,
      categorySlug: 'festivals',
      gradient: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
    ),
    IndianFestivalItem(
      id: 'makar_sankranti',
      nameHi: 'मकर संक्रांति',
      nameEn: 'Makar Sankranti',
      emoji: '🪁',
      month: 1,
      day: 14,
      categorySlug: 'festivals',
      gradient: [Color(0xFF00B4DB), Color(0xFF0083B0)],
    ),
    IndianFestivalItem(
      id: 'republic_day',
      nameHi: 'गणतंत्र दिवस',
      nameEn: 'Republic Day',
      emoji: '🇮🇳',
      month: 1,
      day: 26,
      categorySlug: 'festivals',
      gradient: [Color(0xFFFF9933), Color(0xFF138808)],
    ),
    IndianFestivalItem(
      id: 'maha_shivratri',
      nameHi: 'महाशिवरात्रि',
      nameEn: 'Maha Shivratri',
      emoji: '🔱',
      month: 3,
      day: 6,
      categorySlug: 'festivals',
      gradient: [Color(0xFF3A6073), Color(0xFF3A7BD5)],
    ),
    IndianFestivalItem(
      id: 'holi',
      nameHi: 'होली उत्सव',
      nameEn: 'Holi Festival',
      emoji: '🎨',
      month: 3,
      day: 23,
      categorySlug: 'festivals',
      gradient: [Color(0xFFFF0844), Color(0xFFFFB199)],
    ),
  ];

  static List<IndianFestivalItem> getSortedUpcoming() {
    final list = List<IndianFestivalItem>.from(upcomingFestivals);
    list.sort((a, b) => a.getDaysRemaining().compareTo(b.getDaysRemaining()));
    return list;
  }
}
