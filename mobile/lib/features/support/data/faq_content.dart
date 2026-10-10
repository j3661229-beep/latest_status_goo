// lib/features/support/data/faq_content.dart
import '../../../core/constants/app_constants.dart';

class FaqItem {
  final String qHi;
  final String qEn;
  final String aHi;
  final String aEn;

  const FaqItem({required this.qHi, required this.qEn, required this.aHi, required this.aEn});

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return qHi.toLowerCase().contains(q) ||
        qEn.toLowerCase().contains(q) ||
        aHi.toLowerCase().contains(q) ||
        aEn.toLowerCase().contains(q);
  }
}

class FaqContent {
  FaqContent._();

  static const List<FaqItem> items = [
    FaqItem(
      qHi: 'स्टेटस कैसे बनाएं?',
      qEn: 'How do I make a status?',
      aHi: 'होम पर अपना पसंदीदा स्टेटस चुनें। आपका नाम और फ़ोटो अपने-आप लग जाएंगे। फिर "व्हाट्सएप स्टेटस लगाएं" बटन दबाएं।',
      aEn: 'Pick any status on Home. Your name and photo are added automatically. Then tap the WhatsApp Status button.',
    ),
    FaqItem(
      qHi: 'स्टेटस पर अपना नाम कैसे बदलें?',
      qEn: 'How do I change the name on my status?',
      aHi: 'सेटिंग्स → प्रोफ़ाइल संपादित करें में जाकर नाम बदलें और "सेव करें" दबाएं। किसी स्टेटस को खोलकर भी "नाम बदलें" चुन सकते हैं।',
      aEn: 'Go to Settings → Edit Profile, change your name and tap Save. You can also tap "Change name" while previewing a status.',
    ),
    FaqItem(
      qHi: 'अपनी फ़ोटो कैसे बदलें?',
      qEn: 'How do I change my photo?',
      aHi: 'सेटिंग्स → प्रोफ़ाइल संपादित करें खोलें, फ़ोटो के ऊपर कैमरा आइकन दबाएं और कैमरा या गैलरी से नई फ़ोटो चुनें।',
      aEn: 'Open Settings → Edit Profile, tap the camera icon on your photo and choose a new one from camera or gallery.',
    ),
    FaqItem(
      qHi: 'व्हाट्सएप स्टेटस पर कैसे लगाएं?',
      qEn: 'How do I share to WhatsApp Status?',
      aHi: 'स्टेटस खोलें → "व्हाट्सएप स्टेटस लगाएं" दबाएं → शेयर लिस्ट में WhatsApp चुनें → "My Status" चुनकर भेजें।',
      aEn: 'Open a status → tap the WhatsApp Status button → choose WhatsApp → select "My Status" and post.',
    ),
    FaqItem(
      qHi: 'डाउनलोड की हुई फ़ोटो कहाँ मिलेगी?',
      qEn: 'Where is my downloaded status saved?',
      aHi: 'फ़ोन की गैलरी (Photos / Gallery) में। अगर न दिखे तो ऐप को फ़ोटो सेव करने की अनुमति दें।',
      aEn: 'In your phone gallery (Photos). If you cannot see it, allow the app permission to save photos.',
    ),
    FaqItem(
      qHi: 'रोज़ कितने स्टेटस डाउनलोड कर सकते हैं?',
      qEn: 'How many downloads do I get per day?',
      aHi: 'फ़्री प्लान में रोज़ ${AppConstants.freeImageDownloadsPerDay} इमेज और ${AppConstants.freeVideoDownloadsPerDay} वीडियो। प्रीमियम में असीमित।',
      aEn: 'Free plan: ${AppConstants.freeImageDownloadsPerDay} images and ${AppConstants.freeVideoDownloadsPerDay} videos per day. Premium: unlimited.',
    ),
    FaqItem(
      qHi: 'प्रीमियम कैसे लें?',
      qEn: 'How do I get Premium?',
      aHi: 'सेटिंग्स → मेरा प्लान → "प्रीमियम में अपग्रेड करें" दबाएं, मासिक या वार्षिक प्लान चुनें और UPI/कार्ड से भुगतान करें।',
      aEn: 'Go to Settings → My Plan → Upgrade to Premium, pick a monthly or annual plan and pay by UPI / card.',
    ),
    FaqItem(
      qHi: 'क्या प्रीमियम अपने-आप रिन्यू होता है?',
      qEn: 'Does Premium renew automatically?',
      aHi: 'नहीं। प्लान एकमुश्त भुगतान है और अवधि खत्म होने पर अपने-आप बंद हो जाता है। कोई छिपी हुई कटौती नहीं होती।',
      aEn: 'No. Plans are one-time prepaid payments and simply end when the period is over. There are no hidden charges.',
    ),
    FaqItem(
      qHi: 'पैसे कट गए पर प्रीमियम चालू नहीं हुआ',
      qEn: 'Money was debited but Premium is not active',
      aHi: 'कुछ मिनट रुकें और ऐप दोबारा खोलें। फिर भी चालू न हो तो पेमेंट ID के साथ ${AppConstants.supportEmail} पर लिखें — हम जाँचकर प्लान चालू करेंगे या रिफ़ंड देंगे।',
      aEn: 'Wait a few minutes and reopen the app. If it is still inactive, email ${AppConstants.supportEmail} with your payment ID and we will activate it or refund you.',
    ),
    FaqItem(
      qHi: 'रिफ़ंड कैसे मिलेगा?',
      qEn: 'How do I get a refund?',
      aHi: 'दोहरे भुगतान या तकनीकी खराबी की स्थिति में रिफ़ंड मिलता है। विवरण के लिए सेटिंग्स → रिफ़ंड नीति देखें और हमें ईमेल करें।',
      aEn: 'Refunds are given for duplicate payments or technical faults. See Settings → Refund Policy and email us.',
    ),
    FaqItem(
      qHi: 'अपना खाता कैसे हटाएं?',
      qEn: 'How do I delete my account?',
      aHi: 'सेटिंग्स → नीचे "खाता हटाएं" दबाएं और पुष्टि करें। आपका नाम, फ़ोटो, सेव किए स्टेटस आदि हमेशा के लिए हट जाएंगे।',
      aEn: 'Settings → scroll down → Delete Account → confirm. Your name, photos and saved items are permanently removed.',
    ),
    FaqItem(
      qHi: 'सूचनाएं (नोटिफ़िकेशन) कैसे बंद या चालू करें?',
      qEn: 'How do I turn notifications on or off?',
      aHi: 'सेटिंग्स → सूचनाएं में "पुश सूचनाएं" का स्विच बदलें। रोज़ की याद और त्योहार अलर्ट अलग से बंद कर सकते हैं।',
      aEn: 'Settings → Notifications → toggle Push notifications. Daily reminder and festival alerts can be switched separately.',
    ),
    FaqItem(
      qHi: 'भाषा कैसे बदलें?',
      qEn: 'How do I change the language?',
      aHi: 'सेटिंग्स → भाषा में हिंदी, मराठी, English आदि चुनें। होम पर स्टेटस उसी भाषा में दिखेंगे।',
      aEn: 'Settings → Language and choose Hindi, Marathi, English etc. Statuses on Home will follow your choice.',
    ),
    FaqItem(
      qHi: 'अपना बिज़नेस नाम और लोगो कैसे लगाएं?',
      qEn: 'How do I add my business name and logo?',
      aHi: 'सेटिंग्स → प्रोफ़ाइल संपादित करें → "बिज़नेस ब्रांडिंग" में नाम, फ़ोन, पता और लोगो जोड़ें। यह आपके पोस्टर के नीचे दिखेगा।',
      aEn: 'Settings → Edit Profile → Business Branding: add name, phone, address and logo. It appears at the bottom of your posters.',
    ),
    FaqItem(
      qHi: 'OTP नहीं आ रहा है',
      qEn: 'I am not receiving the OTP',
      aHi: 'सही मोबाइल नंबर जांचें, नेटवर्क देखें और 30 सेकंड बाद "दोबारा भेजें" दबाएं। फिर भी न आए तो Google से लॉगिन आज़माएं।',
      aEn: 'Check your mobile number and network, then tap Resend after 30 seconds. If it still fails, try signing in with Google.',
    ),
  ];
}
