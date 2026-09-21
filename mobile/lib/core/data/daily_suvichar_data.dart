// lib/core/data/daily_suvichar_data.dart
import 'package:flutter/material.dart';

enum TimeOfDaySlot {
  morning,
  afternoon,
  evening,
  night,
}

class DailySuvichar {
  final String id;
  final String textHi;
  final String? textMr;
  final String? textEn;
  final String author;
  final TimeOfDaySlot slot;
  final String emoji;
  final List<Color> gradientColors;

  const DailySuvichar({
    required this.id,
    required this.textHi,
    this.textMr,
    this.textEn,
    this.author = 'अनमोल विचार',
    required this.slot,
    required this.emoji,
    required this.gradientColors,
  });
}

class DailySuvicharData {
  DailySuvicharData._();

  static TimeOfDaySlot getCurrentSlot() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) {
      return TimeOfDaySlot.morning;
    } else if (hour >= 12 && hour < 17) {
      return TimeOfDaySlot.afternoon;
    } else if (hour >= 17 && hour < 21) {
      return TimeOfDaySlot.evening;
    } else {
      return TimeOfDaySlot.night;
    }
  }

  static String getSlotTitle(TimeOfDaySlot slot) {
    switch (slot) {
      case TimeOfDaySlot.morning:
        return 'आज का सुविचार • शुभ प्रभात';
      case TimeOfDaySlot.afternoon:
        return 'दोपहर की प्रेरणा • शुभ दोपहर';
      case TimeOfDaySlot.evening:
        return 'संध्या वंदन • शुभ संध्या';
      case TimeOfDaySlot.night:
        return 'शांति संदेश • शुभ रात्रि';
    }
  }

  static String getSlotSubtitle(TimeOfDaySlot slot) {
    switch (slot) {
      case TimeOfDaySlot.morning:
        return '🌅 Good Morning Inspiration';
      case TimeOfDaySlot.afternoon:
        return '☀️ Afternoon Wisdom';
      case TimeOfDaySlot.evening:
        return '🌇 Peaceful Evening Blessings';
      case TimeOfDaySlot.night:
        return '🌙 Restful Night Thoughts';
    }
  }

  static List<Color> getSlotGradient(TimeOfDaySlot slot) {
    switch (slot) {
      case TimeOfDaySlot.morning:
        return [
          const Color(0xFFFF6A00),
          const Color(0xFFEE0979),
        ];
      case TimeOfDaySlot.afternoon:
        return [
          const Color(0xFFF7971E),
          const Color(0xFFFFD200),
        ];
      case TimeOfDaySlot.evening:
        return [
          const Color(0xFF8A2387),
          const Color(0xFFE94057),
          const Color(0xFFF27121),
        ];
      case TimeOfDaySlot.night:
        return [
          const Color(0xFF0F2027),
          const Color(0xFF203A43),
          const Color(0xFF2C5364),
        ];
    }
  }

  static final List<DailySuvichar> allSuvichars = [
    // ── Morning (शुभ प्रभात) ──
    DailySuvichar(
      id: 'm1',
      slot: TimeOfDaySlot.morning,
      emoji: '🌅',
      textHi: 'हर नया दिन एक नया अवसर लेकर आता है। अपने सपनों की ओर एक कदम और बढ़ाइए। आपका दिन मंगलमय हो!',
      textMr: 'प्रत्येक नवीन दिवस एक नवीन संधी घेऊन येतो. आपल्या स्वप्नांच्या दिशेने आणखी एक पाऊल टाका. तुमचा दिवस शुभ जावो!',
      textEn: 'Every sunrise brings a new opportunity. Take one step closer to your dreams today. Have a blessed day!',
      author: 'शुभ प्रभात',
      gradientColors: [const Color(0xFFFF512F), const Color(0xFFDD2476)],
    ),
    DailySuvichar(
      id: 'm2',
      slot: TimeOfDaySlot.morning,
      emoji: '🪷',
      textHi: 'प्रसन्नता वह इत्र है जिसे आप दूसरों पर छिड़कते हैं तो कुछ बूंदें आपके ऊपर भी गिरती हैं। सुप्रभात!',
      textMr: 'आनंद हा तो अत्तर आहे जो इतरांवर शिंपडला तर काही थेंब आपल्यावरही पडतात. शुभ प्रभात!',
      textEn: 'Happiness is a perfume you cannot pour on others without getting a few drops on yourself. Good morning!',
      author: 'अनमोल मोती',
      gradientColors: [const Color(0xFFF857A6), const Color(0xFFFF5858)],
    ),
    DailySuvichar(
      id: 'm3',
      slot: TimeOfDaySlot.morning,
      emoji: '☕',
      textHi: 'ईश्वर कहते हैं उदास मत होना, मैं तेरे साथ हूँ। सामने नहीं पर आस-पास हूँ। हर हर महादेव!',
      textMr: 'देव म्हणतात निराश होऊ नकोस, मी तुझ्या सोबत आहे. डोळ्यांसमोर नाही पण आजूबाजूला आहे. हर हर महादेव!',
      textEn: 'Trust in the divine journey. You are guided, protected, and blessed at every step. Have a wonderful morning!',
      author: 'भक्ति प्रभात',
      gradientColors: [const Color(0xFFFF6A00), const Color(0xFFEE0979)],
    ),
    DailySuvichar(
      id: 'm4',
      slot: TimeOfDaySlot.morning,
      emoji: '🌞',
      textHi: 'विश्वास वह शक्ति है जिससे उजड़ी हुई दुनिया में भी प्रकाश किया जा सकता है। जय श्री कृष्णा!',
      textMr: 'विश्वास ही अशी शक्ती आहे ज्याने उद्ध्वस्त झालेल्या जगातही प्रकाश निर्माण करता येतो. जय श्री कृष्ण!',
      textEn: 'Faith is the bird that feels the light when the dawn is still dark. Jai Shri Krishna!',
      author: 'दिव्य संदेश',
      gradientColors: [const Color(0xFFFF7E5F), const Color(0xFFFEB47B)],
    ),

    // ── Afternoon (शुभ दोपहर) ──
    DailySuvichar(
      id: 'a1',
      slot: TimeOfDaySlot.afternoon,
      emoji: '☀️',
      textHi: 'कर्म करो तो फल मिलता है, आज नहीं तो कल मिलता है। जितना गहरा अधिक हो कुआँ, उतना मीठा जल मिलता है।',
      textMr: 'कर्म केले तर फळ मिळते, आज नाही तर उद्या मिळते. विहीर जितकी खोल असेल, तितके पाणी गोड मिळते.',
      textEn: 'Hard work never goes in vain. The deeper the effort, the sweeter the reward. Stay motivated!',
      author: 'कर्म योग',
      gradientColors: [const Color(0xFFF7971E), const Color(0xFFFFD200)],
    ),
    DailySuvichar(
      id: 'a2',
      slot: TimeOfDaySlot.afternoon,
      emoji: '💼',
      textHi: 'सफलता की शुरुआत हमेशा सोच से होती है। सकारात्मक सोचें, कर्मठ बनें, प्रगति अपने आप कदम चूमेगी।',
      textMr: 'यशाची सुरुवात नेहमी विचाराने होते. सकारात्मक विचार करा, यश आपोआप मिळेल.',
      textEn: 'Success begins with your mindset. Think positively, work diligently, and achieve greatness.',
      author: 'प्रेरणादायक विचार',
      gradientColors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
    ),

    // ── Evening (शुभ संध्या) ──
    DailySuvichar(
      id: 'e1',
      slot: TimeOfDaySlot.evening,
      emoji: '🌇',
      textHi: 'ढलते सूरज के साथ आज की सभी चिंताओं को ढल जाने दें। कल एक नया सवेरा फिर से इंतजार कर रहा है। शुभ संध्या!',
      textMr: 'मावळत्या सूर्यासोबत आजच्या सर्व चिंता विसरून जा. उद्याची नवीन पहाट पुन्हा तुमची वाट पाहत आहे. शुभ संध्याकाळ!',
      textEn: 'As the sun sets, release today’s worries. Tomorrow is another fresh beginning. Peaceful evening!',
      author: 'शुभ संध्या',
      gradientColors: [const Color(0xFF8A2387), const Color(0xFFE94057)],
    ),
    DailySuvichar(
      id: 'e2',
      slot: TimeOfDaySlot.evening,
      emoji: '✨',
      textHi: 'परिवार के साथ बिताया गया हर पल जीवन की सबसे बड़ी दौलत है। अपने अपनों के साथ आनंदमय संध्या बिताएं।',
      textMr: 'कुटुंबासोबत घालवलेला प्रत्येक क्षण ही जीवनातील सर्वात मोठी संपत्ती आहे. शुभ संध्या!',
      textEn: 'Family time is life’s greatest treasure. Enjoy a wonderful, blessed evening with loved ones.',
      author: 'परिवार संदेश',
      gradientColors: [const Color(0xFF654EA3), const Color(0xFFEAAFC8)],
    ),

    // ── Night (शुभ रात्रि) ──
    DailySuvichar(
      id: 'n1',
      slot: TimeOfDaySlot.night,
      emoji: '🌙',
      textHi: 'सपनों की दुनिया में खो जाने से पहले, ईश्वर का धन्यवाद करें जिन्होंने आज का सुंदर दिन दिया। शुभ रात्रि, मीठे सपने!',
      textMr: 'स्वप्नांच्या दुनियेत जाण्यापूर्वी, देवाला धन्यवाद द्या ज्याने आजचा सुंदर दिवस दिला. शुभ रात्री!',
      textEn: 'Count your blessings before you close your eyes. May peace and sweet dreams fill your night. Good night!',
      author: 'शुभ रात्रि',
      gradientColors: [const Color(0xFF0F2027), const Color(0xFF2C5364)],
    ),
    DailySuvichar(
      id: 'n2',
      slot: TimeOfDaySlot.night,
      emoji: '⭐',
      textHi: 'अंधेरा चाहे कितना भी गहरा हो, एक नन्हा तारा भी उसे चीरने का हौसला रखता है। सकारात्मक मन से सोएं। शुभ रात्रि!',
      textMr: 'अंधार कितीही दाट असला तरी एक छोटा ताराही त्याला भेदण्याची ताकद ठेवतो. शुभ रात्री!',
      textEn: 'No matter how dark the night, stars will always shine. Rest your mind with hope. Sleep well!',
      author: 'शांति विचार',
      gradientColors: [const Color(0xFF141E30), const Color(0xFF243B55)],
    ),
  ];

  static List<DailySuvichar> getForCurrentTime() {
    final currentSlot = getCurrentSlot();
    final list = allSuvichars.where((s) => s.slot == currentSlot).toList();
    return list.isNotEmpty ? list : allSuvichars;
  }
}
