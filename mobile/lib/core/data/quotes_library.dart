// lib/core/data/quotes_library.dart

class StatusQuote {
  final String textHi;
  final String? textMr;
  final String? textEn;
  final String category;
  final String emoji;

  const StatusQuote({
    required this.textHi,
    this.textMr,
    this.textEn,
    required this.category,
    required this.emoji,
  });
}

class QuotesLibrary {
  QuotesLibrary._();

  static const List<String> categories = [
    'सभी (All)',
    'भक्ति (Devotional)',
    'सुविचार (Suvichar)',
    'प्रेरणा (Motivation)',
    'जन्मदिन (Birthday)',
    'मित्रता (Friendship)',
    'शुभकामनाएं (Wishes)',
  ];

  static const List<StatusQuote> all = [
    // 🕉️ भक्ति (Devotional)
    StatusQuote(
      category: 'भक्ति (Devotional)',
      emoji: '🕉️',
      textHi: 'हर हर महादेव! जिनके रोम-रोम में शिव हैं, वही विष पिया करते हैं। जमाना उन्हें क्या जलाएगा, जो भस्म से श्रृंगार करते हैं।',
      textMr: 'हर हर महादेव! ज्यांच्या नसानसात शिव आहेत, त्यांना जग काय जाळणार जे भस्माने शृंगार करतात.',
      textEn: 'Har Har Mahadev! May Lord Shiva bless you with inner peace, strength, and unwavering courage today.',
    ),
    StatusQuote(
      category: 'भक्ति (Devotional)',
      emoji: '🪷',
      textHi: 'कर्म तेरे अच्छे हैं तो किस्मत तेरी दासी है, नीयत तेरी अच्छी है तो घर में मथुरा काशी है। जय श्री कृष्णा!',
      textMr: 'कर्म चांगले असतील तर नशीब दासी आहे, हेतू चांगला असेल तर घरातच पंढरपूर काशी आहे. जय श्री कृष्ण!',
      textEn: 'If your deeds are pure, divinity resides in your heart. Jai Shri Krishna!',
    ),
    StatusQuote(
      category: 'भक्ति (Devotional)',
      emoji: '🚩',
      textHi: 'मंगल भवन अमंगल हारी, द्रवहु सुदसरथ अजिर बिहारी। जय श्री राम! आपका दिन मंगलमय हो।',
      textMr: 'जय श्री राम! प्रभू श्रीरामाच्या कृपेने आपल्या जीवनात सुख, समृद्धी आणि आनंद नांदो.',
      textEn: 'May Lord Rama bestow auspiciousness, harmony, and wisdom upon you and your loved ones.',
    ),
    StatusQuote(
      category: 'भक्ति (Devotional)',
      emoji: '🐘',
      textHi: 'वक्रतुण्ड महाकाय सूर्यकोटि समप्रभ। निर्विघ्नं कुरु मे देव सर्वकार्येषु सर्वदा॥ गणपति बाप्पा मोरया!',
      textMr: 'वक्रतुंड महाकाय सूर्यकोटी समप्रभ। निर्विघ्नं कुरु मे देव सर्वकार्येषु सर्वदा॥ गणपती बाप्पा मोरया!',
      textEn: 'May Lord Ganesha remove all obstacles and shower prosperity upon all your endeavors.',
    ),
    StatusQuote(
      category: 'भक्ति (Devotional)',
      emoji: '🙏',
      textHi: 'मनोजवं मारुततुल्यवेगं जितेन्द्रियं बुद्धिमतां वरिष्ठम्। जय बजरंग बली, संकट मोचन कृपा करो!',
      textMr: 'जय हनुमान! पवनपुत्र हनुमान आपल्या सर्व संकटांचे निवारण करोत.',
      textEn: 'Jai Hanuman! May the mighty Pawanputra grant you immense strength, health, and protection.',
    ),

    // 💡 सुविचार (Suvichar)
    StatusQuote(
      category: 'सुविचार (Suvichar)',
      emoji: '💡',
      textHi: 'सुंदरता सस्ती है, चरित्र महंगा है। घड़ी सस्ती है, समय महंगा है। शरीर सस्ता है, जीवन अनमोल है। सुप्रभात!',
      textMr: 'सौंदर्य स्वस्त आहे, चारित्र्य अनमोल आहे. घड्याळ स्वस्त आहे, वेळ अमूल्य आहे. शुभ सकाळ!',
      textEn: 'Beauty is cheap, character is priceless. Clocks are cheap, time is precious. Value what truly matters.',
    ),
    StatusQuote(
      category: 'सुविचार (Suvichar)',
      emoji: '🌱',
      textHi: 'पेड़ की शाखा पर बैठा पक्षी कभी डाल टूटने से नहीं डरता, क्योंकि उसका विश्वास डाल पर नहीं अपने पंखों पर होता है।',
      textMr: 'झाडाच्या फांदीवर बसलेला पक्षी फांदी तुटायला कधीच घाबरत नाही, कारण त्याचा विश्वास फांदीवर नसून पंखांवर असतो.',
      textEn: 'A bird sitting on a branch never fears the branch breaking, because its trust is in its own wings.',
    ),
    StatusQuote(
      category: 'सुविचार (Suvichar)',
      emoji: '💎',
      textHi: 'संबंध मोतियों की तरह होते हैं, यदि कोई गिर भी जाए तो झुक कर उठा लेना चाहिए। सुप्रभात!',
      textMr: 'नातेसंबंध मोत्यांसारखे असतात, जर खाली पडले तरी वाकून उचलले पाहिजेत. शुभ सकाळ!',
      textEn: 'Relationships are like pearls; even if they drop, stoop down with humility and pick them up.',
    ),
    StatusQuote(
      category: 'सुविचार (Suvichar)',
      emoji: '☀️',
      textHi: 'उम्मीद और विश्वास का छोटा सा बीज, खुशियों के विशाल बाग को जन्म दे सकता है। आपका दिन शुभ हो!',
      textMr: 'आशा आणि विश्वासाची एक छोटी बीसुद्धा सुखाच्या अथांग बागेला जन्म देऊ शकते. शुभ दिवस!',
      textEn: 'A tiny seed of hope and faith can blossom into a boundless garden of joy.',
    ),

    // 🚀 प्रेरणा (Motivation)
    StatusQuote(
      category: 'प्रेरणा (Motivation)',
      emoji: '🚀',
      textHi: 'संघर्ष जितना कठिन होगा, जीत उतनी ही शानदार होगी! तब तक मेहनत करो जब तक तुम्हारा परिचय देने की जरूरत न पड़े।',
      textMr: 'संघर्ष जितका खडतर असेल, विजय तितकाच भव्य असेल! तोपर्यंत कष्ट करा जोपर्यंत स्वतःची ओळख सांगावी लागणार नाही.',
      textEn: 'The harder the struggle, the more glorious the triumph. Work until your name becomes your brand.',
    ),
    StatusQuote(
      category: 'प्रेरणा (Motivation)',
      emoji: '🔥',
      textHi: 'अगर सूरज की तरह चमकना चाहते हो, तो पहले सूरज की तरह जलना सीखो। हर नया दिन एक नया अवसर है!',
      textMr: 'जर सूर्यासारखं चमकायचं असेल, तर आधी सूर्यासारखं जळायला शिका. प्रत्येक नवा दिवस नवी संधी आहे!',
      textEn: 'If you want to shine like the sun, first burn like the sun. Every new dawn is a fresh opportunity.',
    ),
    StatusQuote(
      category: 'प्रेरणा (Motivation)',
      emoji: '🎯',
      textHi: 'सफलता की शुरुआत हमेशा एक सपने से होती है। डर को अपने सपनों से बड़ा कभी मत होने दो!',
      textMr: 'यशाची सुरुवात नेहमी एका स्वप्नाने होते. भीतीला कधीही आपल्या स्वप्नांपेक्षा मोठे होऊ देऊ नका!',
      textEn: 'Success always begins with a dream. Never let fear be bigger than your ambition!',
    ),

    // 🎂 जन्मदिन (Birthday)
    StatusQuote(
      category: 'जन्मदिन (Birthday)',
      emoji: '🎂',
      textHi: 'जन्मदिन की हार्दिक शुभकामनाएं! ईश्वर आपको दीर्घायु, उत्तम स्वास्थ्य और अपार खुशियां प्रदान करे। 💐🎉',
      textMr: 'वाढदिवसाच्या हार्दिक शुभेच्छा! ईश्वराच्या कृपेने आपणास दीर्घायुष्य, उत्तम आरोग्य आणि भरभरून आनंद मिळो.',
      textEn: 'Wishing you a very Happy Birthday! May God shower you with radiant health, long life, and endless joy.',
    ),
    StatusQuote(
      category: 'जन्मदिन (Birthday)',
      emoji: '🎉',
      textHi: 'हर खुशी मिले आपको, हर मंजिल चूमे आपके कदम। जन्मदिन बहुत-बहुत मुबारक हो भाई! 🎂🎊',
      textMr: 'आपल्या सर्व मनोकामना पूर्ण होवोत, वाढदिवसाच्या मनःपूर्वक शुभेच्छा!',
      textEn: 'May every step you take lead to triumph and happiness. Wishing you a fabulous birthday celebration!',
    ),

    // 🤝 मित्रता (Friendship)
    StatusQuote(
      category: 'मित्रता (Friendship)',
      emoji: '🤝',
      textHi: 'दोस्ती कोई खोज नहीं होती, ये हर किसी से हर रोज़ नहीं होती। जो साथ दे बुरा वक्त आने पर, वही सच्ची दोस्ती होती है।',
      textMr: 'मैत्री ही अशी गोष्ट आहे जी शब्दांपलीकडची असते. संकटात जो पाठीशी उभा राहतो, तोच खरा मित्र असतो.',
      textEn: 'True friendship is not about who you have known the longest; it is about who came and never left your side.',
    ),

    // 🌟 शुभकामनाएं (Wishes)
    StatusQuote(
      category: 'शुभकामनाएं (Wishes)',
      emoji: '🌟',
      textHi: 'नई शुरुआत के लिए आपको बहुत-बहुत शुभकामनाएं! आपका हर प्रयास सफलता की नई ऊंचाइयों को छुए।',
      textMr: 'नवीन प्रवासासाठी आणि यशासाठी मनःपूर्वक शुभेच्छा!',
      textEn: 'Heartiest congratulations and best wishes for your new beginning. May you reach unprecedented heights!',
    ),
  ];
}
