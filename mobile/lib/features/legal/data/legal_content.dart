// lib/features/legal/data/legal_content.dart
//
// Structured legal copy (English + Hindi) for Privacy Policy, Terms & Conditions
// and Refund & Cancellation Policy. Rendered by LegalDocumentScreen.
//
// Conventions inside a body list:
//   * each String is one paragraph;
//   * a paragraph starting with "• " renders as a bullet.
//
// OWNER: have these texts reviewed by your legal counsel before publishing and
// fill the TODO placeholders in AppConstants (company name, address, grievance
// officer, URLs).
import '../../../core/constants/app_constants.dart';

class LegalSection {
  final String id;
  final String titleEn;
  final String titleHi;
  final List<String> bodyEn;
  final List<String> bodyHi;

  const LegalSection({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.bodyEn,
    required this.bodyHi,
  });
}

class LegalDocument {
  final String id;
  final String titleEn;
  final String titleHi;
  final String introEn;
  final String introHi;
  final List<LegalSection> sections;
  final String lastUpdated;

  const LegalDocument({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.introEn,
    required this.introHi,
    required this.sections,
    required this.lastUpdated,
  });
}

class LegalContent {
  LegalContent._();

  static const String _app = AppConstants.appName;
  static const String _company = AppConstants.companyName;
  static const String _email = AppConstants.supportEmail;

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVACY POLICY
  // ═══════════════════════════════════════════════════════════════════════════
  static const LegalDocument privacy = LegalDocument(
    id: 'privacy',
    titleEn: 'Privacy Policy',
    titleHi: 'गोपनीयता नीति',
    lastUpdated: AppConstants.policyLastUpdated,
    introEn:
        'This Privacy Policy explains how $_company ("we", "us", "our") collects, uses, stores and shares your '
        'personal data when you use the $_app mobile application ("App"). We process personal data in accordance '
        'with the Digital Personal Data Protection Act, 2023 (DPDP Act), the Information Technology Act, 2000 and the '
        'rules made under it. By creating an account or using the App you agree to this Policy.',
    introHi:
        'यह गोपनीयता नीति बताती है कि जब आप $_app मोबाइल ऐप ("ऐप") का उपयोग करते हैं, तब $_company ("हम") आपकी '
        'व्यक्तिगत जानकारी कैसे एकत्र करता है, उपयोग करता है, सुरक्षित रखता है और साझा करता है। हम डिजिटल '
        'व्यक्तिगत डेटा संरक्षण अधिनियम, 2023 (DPDP Act), सूचना प्रौद्योगिकी अधिनियम, 2000 और उसके नियमों के '
        'अनुसार आपका डेटा संसाधित करते हैं। खाता बनाकर या ऐप का उपयोग करके आप इस नीति से सहमत होते हैं।',
    sections: [
      LegalSection(
        id: 'collect',
        titleEn: 'Information we collect',
        titleHi: 'हम कौन-सी जानकारी एकत्र करते हैं',
        bodyEn: [
          'We collect only the information needed to run the App and personalise your daily status posters.',
          '• Account details: mobile phone number (when you log in with OTP) or your Google account name, email address and Google ID (when you sign in with Google).',
          '• Profile details: your name, profile photo, state, region and preferred language.',
          '• Business branding (optional): business name, phone number, address, designation and logo that you choose to show on your posters.',
          '• Content you create: templates you save, statuses you share or download, and your share history and streak.',
          '• Device and technical data: device model, operating system, app version, push-notification (OneSignal) identifier, crash and diagnostic information.',
          '• Usage analytics: screens viewed, templates opened, shared or saved, and similar in-app events.',
          '• Payment metadata: when you buy Premium, Razorpay shares with us the order ID, payment ID, amount, status and payment method type. We do NOT receive or store your card, UPI PIN or net-banking credentials.',
          'Photos you pick are used only to create your posters. We do not access your gallery or contacts beyond the files you explicitly choose.',
        ],
        bodyHi: [
          'हम केवल वही जानकारी लेते हैं जो ऐप चलाने और आपके रोज़ के स्टेटस पोस्टर को आपके अनुसार बनाने के लिए ज़रूरी है।',
          '• खाते की जानकारी: मोबाइल नंबर (OTP से लॉगिन करने पर) या आपके Google खाते का नाम, ईमेल और Google ID (Google से साइन-इन करने पर)।',
          '• प्रोफ़ाइल की जानकारी: आपका नाम, प्रोफ़ाइल फ़ोटो, राज्य, क्षेत्र और पसंदीदा भाषा।',
          '• बिज़नेस ब्रांडिंग (वैकल्पिक): बिज़नेस का नाम, फ़ोन नंबर, पता, पद और लोगो, जो आप अपने पोस्टर पर दिखाना चाहें।',
          '• आपके द्वारा बनाई सामग्री: सेव किए गए टेम्पलेट, शेयर या डाउनलोड किए गए स्टेटस, शेयर इतिहास और स्ट्रीक।',
          '• डिवाइस व तकनीकी जानकारी: फ़ोन का मॉडल, ऑपरेटिंग सिस्टम, ऐप वर्शन, पुश-नोटिफ़िकेशन (OneSignal) आईडी, क्रैश व डायग्नोस्टिक जानकारी।',
          '• उपयोग का विश्लेषण: देखी गई स्क्रीन, खोले/शेयर/सेव किए गए टेम्पलेट जैसी ऐप-के-भीतर की गतिविधियाँ।',
          '• भुगतान संबंधी जानकारी: प्रीमियम खरीदने पर Razorpay हमें ऑर्डर ID, पेमेंट ID, राशि, स्थिति और भुगतान का प्रकार बताता है। आपके कार्ड, UPI PIN या नेट-बैंकिंग की जानकारी हमें न मिलती है, न हम उसे रखते हैं।',
          'आपके चुने हुए फ़ोटो का उपयोग केवल आपके पोस्टर बनाने में होता है। जो फ़ाइलें आप खुद नहीं चुनते, उन तक या आपके कॉन्टैक्ट तक हम नहीं पहुँचते।',
        ],
      ),
      LegalSection(
        id: 'use',
        titleEn: 'How we use your information',
        titleHi: 'हम आपकी जानकारी का उपयोग कैसे करते हैं',
        bodyEn: [
          '• To create and secure your account and verify you with OTP.',
          '• To place your name, photo and business details on posters and to show templates in your language and region.',
          '• To process Premium purchases, activate your plan and keep accounting records.',
          '• To send notifications you have allowed (daily statuses, festival reminders, offers, account messages).',
          '• To improve the App, fix bugs, prevent fraud and abuse, and understand which content is useful.',
          '• To respond to your support requests and to comply with legal obligations.',
          'We do not sell your personal data and we do not use it for third-party advertising profiles.',
        ],
        bodyHi: [
          '• आपका खाता बनाने, सुरक्षित रखने और OTP से आपकी पहचान जाँचने के लिए।',
          '• पोस्टर पर आपका नाम, फ़ोटो और बिज़नेस जानकारी लगाने तथा आपकी भाषा व क्षेत्र के अनुसार टेम्पलेट दिखाने के लिए।',
          '• प्रीमियम की खरीद प्रोसेस करने, आपका प्लान चालू करने और लेखा-जोखा रखने के लिए।',
          '• आपकी अनुमति से सूचनाएँ भेजने के लिए (रोज़ के स्टेटस, त्योहार की याद, ऑफ़र, खाते से जुड़े संदेश)।',
          '• ऐप को बेहतर बनाने, गड़बड़ियाँ ठीक करने, धोखाधड़ी रोकने और यह समझने के लिए कि कौन-सी सामग्री उपयोगी है।',
          '• आपके सहायता अनुरोधों का जवाब देने और कानूनी ज़िम्मेदारियाँ निभाने के लिए।',
          'हम आपका व्यक्तिगत डेटा बेचते नहीं हैं और न ही उसका उपयोग तीसरे पक्ष के विज्ञापन-प्रोफ़ाइल बनाने में करते हैं।',
        ],
      ),
      LegalSection(
        id: 'consent',
        titleEn: 'Consent and legal basis',
        titleHi: 'सहमति और कानूनी आधार',
        bodyEn: [
          'We process your data based on your consent (given when you sign up and when you allow permissions such as notifications), to perform our service to you, and for legitimate uses permitted by the DPDP Act such as security, fraud prevention and legal compliance.',
          'You can withdraw consent at any time from Settings or by writing to us. Withdrawal does not affect processing already done, but some features may stop working.',
        ],
        bodyHi: [
          'हम आपका डेटा आपकी सहमति (साइन-अप करते समय और नोटिफ़िकेशन जैसी अनुमति देते समय दी गई) के आधार पर, आपको सेवा देने के लिए, तथा सुरक्षा, धोखाधड़ी की रोकथाम और कानूनी पालन जैसे DPDP अधिनियम द्वारा मान्य वैध उद्देश्यों के लिए संसाधित करते हैं।',
          'आप किसी भी समय सेटिंग्स से या हमें लिखकर अपनी सहमति वापस ले सकते हैं। सहमति वापस लेने से पहले हो चुकी प्रक्रिया पर असर नहीं पड़ता, लेकिन कुछ सुविधाएँ बंद हो सकती हैं।',
        ],
      ),
      LegalSection(
        id: 'sharing',
        titleEn: 'Who we share data with',
        titleHi: 'हम डेटा किसके साथ साझा करते हैं',
        bodyEn: [
          'We share data only with service providers who help us run the App, under contracts that require them to protect it:',
          '• Cloud storage and media delivery (Cloudinary, Google Cloud Storage): your uploaded profile photo, business logo and template images.',
          '• OneSignal: push-notification identifier, language, state/region and plan tags to deliver notifications.',
          '• Razorpay: payment processing for Premium. Razorpay acts under its own privacy policy for payment data.',
          '• 2Factor (SMS provider): your mobile number to deliver the login OTP.',
          '• Google: Google Sign-In, and Google Play services used by the App.',
          'We may also disclose information if required by law, court order or a government authority, or to protect the rights, safety and property of our users and the App. If our business is merged or acquired, your data may be transferred to the successor under the same protections.',
          'Your name and photo appear only on posters you create and choose to share; we do not publish them anywhere else.',
        ],
        bodyHi: [
          'हम डेटा केवल उन सेवा-प्रदाताओं के साथ साझा करते हैं जो ऐप चलाने में हमारी मदद करते हैं और अनुबंध के तहत डेटा की सुरक्षा के लिए बाध्य हैं:',
          '• क्लाउड स्टोरेज व मीडिया डिलीवरी (Cloudinary, Google Cloud Storage): आपकी अपलोड की गई प्रोफ़ाइल फ़ोटो, बिज़नेस लोगो और टेम्पलेट इमेज।',
          '• OneSignal: नोटिफ़िकेशन भेजने के लिए पुश-आईडी, भाषा, राज्य/क्षेत्र और प्लान टैग।',
          '• Razorpay: प्रीमियम का भुगतान प्रोसेस करने के लिए। भुगतान डेटा पर Razorpay की अपनी गोपनीयता नीति लागू होती है।',
          '• 2Factor (SMS सेवा): लॉगिन OTP भेजने के लिए आपका मोबाइल नंबर।',
          '• Google: Google साइन-इन और ऐप द्वारा उपयोग की जाने वाली Google Play सेवाएँ।',
          'कानून, अदालत के आदेश या सरकारी प्राधिकरण की माँग पर, या अपने उपयोगकर्ताओं और ऐप के अधिकारों, सुरक्षा व संपत्ति की रक्षा के लिए हमें जानकारी देनी पड़ सकती है। यदि हमारा व्यवसाय किसी में विलय हो या बिके, तो आपका डेटा उसी सुरक्षा के साथ उत्तराधिकारी को सौंपा जा सकता है।',
          'आपका नाम और फ़ोटो केवल उन्हीं पोस्टर पर दिखते हैं जो आप बनाते और शेयर करते हैं; हम उन्हें कहीं और प्रकाशित नहीं करते।',
        ],
      ),
      LegalSection(
        id: 'permissions',
        titleEn: 'App permissions',
        titleHi: 'ऐप की अनुमतियाँ',
        bodyEn: [
          '• Photos / camera: only when you choose to set a profile photo or logo, or save a poster to your gallery.',
          '• Notifications: to send daily statuses and festival reminders. You can turn this off in Settings or your phone settings.',
          '• Internet: to load templates and sync your profile.',
          'We do not read your SMS, contacts, call logs or precise location.',
        ],
        bodyHi: [
          '• फ़ोटो / कैमरा: केवल तब जब आप प्रोफ़ाइल फ़ोटो या लोगो लगाना चाहें, या पोस्टर गैलरी में सेव करना चाहें।',
          '• नोटिफ़िकेशन: रोज़ के स्टेटस और त्योहार की याद भेजने के लिए। आप इसे सेटिंग्स या फ़ोन की सेटिंग्स में बंद कर सकते हैं।',
          '• इंटरनेट: टेम्पलेट लोड करने और प्रोफ़ाइल सिंक करने के लिए।',
          'हम आपके SMS, कॉन्टैक्ट, कॉल लॉग या सटीक लोकेशन नहीं पढ़ते।',
        ],
      ),
      LegalSection(
        id: 'retention',
        titleEn: 'How long we keep data',
        titleHi: 'डेटा कितने समय तक रखा जाता है',
        bodyEn: [
          'We keep your account data while your account is active. When you delete your account, we remove or anonymise your name, phone number, email, Google ID, photos, business details, notification identifier, saved items and notification history, and sign you out everywhere.',
          'We may retain limited records after deletion where the law requires, such as payment and invoice records (up to 8 years under Indian tax and company law), anonymised usage statistics, and logs needed to prevent fraud or settle disputes.',
        ],
        bodyHi: [
          'जब तक आपका खाता चालू है, हम आपका खाता-डेटा रखते हैं। खाता हटाने पर हम आपका नाम, फ़ोन नंबर, ईमेल, Google ID, फ़ोटो, बिज़नेस जानकारी, नोटिफ़िकेशन आईडी, सेव की गई सामग्री और नोटिफ़िकेशन इतिहास हटा देते या गुमनाम कर देते हैं, और आपको हर जगह से साइन-आउट कर देते हैं।',
          'कानून के अनुसार ज़रूरी होने पर हटाने के बाद भी सीमित रिकॉर्ड रखे जा सकते हैं, जैसे भुगतान व इनवॉइस रिकॉर्ड (भारतीय कर व कंपनी कानून के अनुसार अधिकतम 8 वर्ष), गुमनाम उपयोग-आँकड़े, और धोखाधड़ी रोकने या विवाद सुलझाने के लिए ज़रूरी लॉग।',
        ],
      ),
      LegalSection(
        id: 'rights',
        titleEn: 'Your rights',
        titleHi: 'आपके अधिकार',
        bodyEn: [
          'Under the DPDP Act, 2023 you have the right to:',
          '• Access a summary of the personal data we hold about you and how it is used.',
          '• Correct or update inaccurate or incomplete data (Settings → Edit Profile).',
          '• Erase your data by deleting your account (Settings → Delete Account).',
          '• Withdraw consent at any time.',
          '• Grievance redressal: raise a complaint with our Grievance Officer (below). If you are not satisfied, you may approach the Data Protection Board of India.',
          '• Nominate another person to exercise your rights in case of death or incapacity.',
        ],
        bodyHi: [
          'DPDP अधिनियम, 2023 के अंतर्गत आपको ये अधिकार हैं:',
          '• हमारे पास रखे आपके व्यक्तिगत डेटा और उसके उपयोग का सार जानने का अधिकार।',
          '• गलत या अधूरी जानकारी सुधारने/अपडेट करने का अधिकार (सेटिंग्स → प्रोफ़ाइल संपादित करें)।',
          '• खाता हटाकर अपना डेटा मिटाने का अधिकार (सेटिंग्स → खाता हटाएं)।',
          '• किसी भी समय सहमति वापस लेने का अधिकार।',
          '• शिकायत निवारण का अधिकार: नीचे दिए गए शिकायत अधिकारी को शिकायत करें। संतुष्ट न होने पर आप भारत के डेटा संरक्षण बोर्ड से संपर्क कर सकते हैं।',
          '• मृत्यु या अक्षमता की स्थिति में अपने अधिकारों का प्रयोग करने के लिए किसी अन्य व्यक्ति को नामित करने का अधिकार।',
        ],
      ),
      LegalSection(
        id: 'children',
        titleEn: "Children's privacy",
        titleHi: 'बच्चों की गोपनीयता',
        bodyEn: [
          'The App is meant for users aged 18 years or older, because it includes paid subscriptions. We do not knowingly collect personal data of anyone under 18 without verifiable consent of a parent or lawful guardian. If you believe a child has given us data, write to us and we will delete it.',
        ],
        bodyHi: [
          'ऐप में भुगतान वाली सदस्यता होने के कारण यह 18 वर्ष या उससे अधिक आयु के उपयोगकर्ताओं के लिए है। हम माता-पिता या कानूनी अभिभावक की सत्यापित सहमति के बिना 18 वर्ष से कम आयु के किसी व्यक्ति का व्यक्तिगत डेटा जानबूझकर एकत्र नहीं करते। यदि आपको लगे कि किसी बच्चे ने हमें डेटा दिया है, तो हमें लिखें; हम उसे हटा देंगे।',
        ],
      ),
      LegalSection(
        id: 'security',
        titleEn: 'Security',
        titleHi: 'सुरक्षा',
        bodyEn: [
          'We use reasonable safeguards: encrypted (HTTPS) connections, hashed refresh tokens, access controls and limited staff access. No system is completely secure, so please keep your phone and OTP private. If a personal data breach occurs we will notify the Data Protection Board and affected users as required by law.',
        ],
        bodyHi: [
          'हम उचित सुरक्षा उपाय अपनाते हैं: एन्क्रिप्टेड (HTTPS) कनेक्शन, हैश किए गए रिफ़्रेश टोकन, एक्सेस नियंत्रण और कर्मचारियों की सीमित पहुँच। कोई भी प्रणाली पूरी तरह सुरक्षित नहीं होती, इसलिए कृपया अपना फ़ोन और OTP गोपनीय रखें। व्यक्तिगत डेटा का उल्लंघन होने पर हम कानून के अनुसार डेटा संरक्षण बोर्ड और प्रभावित उपयोगकर्ताओं को सूचित करेंगे।',
        ],
      ),
      LegalSection(
        id: 'cookies',
        titleEn: 'Cookies and tracking',
        titleHi: 'कुकीज़ और ट्रैकिंग',
        bodyEn: [
          'The App does not use browser cookies. We use device identifiers and analytics events described above only to operate and improve the App.',
        ],
        bodyHi: [
          'ऐप ब्राउज़र कुकीज़ का उपयोग नहीं करता। ऊपर बताए गए डिवाइस आईडी और एनालिटिक्स इवेंट का उपयोग केवल ऐप चलाने और सुधारने के लिए होता है।',
        ],
      ),
      LegalSection(
        id: 'transfer',
        titleEn: 'Storage and transfers',
        titleHi: 'डेटा का भंडारण और स्थानांतरण',
        bodyEn: [
          'Your data may be processed on servers operated by our providers, which may be located outside India. We transfer data only to countries and providers permitted under the DPDP Act and apply the safeguards described in this Policy.',
        ],
        bodyHi: [
          'आपका डेटा हमारे सेवा-प्रदाताओं के सर्वरों पर संसाधित हो सकता है, जो भारत के बाहर भी हो सकते हैं। हम डेटा केवल DPDP अधिनियम द्वारा अनुमत देशों व प्रदाताओं को भेजते हैं और इस नीति में बताई सुरक्षा लागू रखते हैं।',
        ],
      ),
      LegalSection(
        id: 'changes',
        titleEn: 'Changes to this Policy',
        titleHi: 'नीति में बदलाव',
        bodyEn: [
          'We may update this Policy from time to time. We will show the new "last updated" date and, for material changes, notify you in the App. Continued use after the update means you accept the revised Policy.',
        ],
        bodyHi: [
          'हम समय-समय पर इस नीति को अपडेट कर सकते हैं। नई "अंतिम अपडेट" तिथि दिखाई जाएगी और बड़े बदलावों की सूचना ऐप में दी जाएगी। अपडेट के बाद भी ऐप का उपयोग जारी रखने का अर्थ है कि आप संशोधित नीति स्वीकार करते हैं।',
        ],
      ),
      LegalSection(
        id: 'contact',
        titleEn: 'Contact and Grievance Officer',
        titleHi: 'संपर्क और शिकायत अधिकारी',
        bodyEn: [
          'For any privacy question, request or complaint, contact:',
          '• Company: ${AppConstants.companyName}',
          '• Address: ${AppConstants.companyAddress}',
          '• Grievance Officer: ${AppConstants.grievanceOfficerName}',
          '• Email: ${AppConstants.grievanceOfficerEmail} (general support: $_email)',
          'We will acknowledge your complaint within 48 hours and aim to resolve it within 15 days.',
        ],
        bodyHi: [
          'गोपनीयता से जुड़े किसी भी प्रश्न, अनुरोध या शिकायत के लिए संपर्क करें:',
          '• कंपनी: ${AppConstants.companyName}',
          '• पता: ${AppConstants.companyAddress}',
          '• शिकायत अधिकारी: ${AppConstants.grievanceOfficerName}',
          '• ईमेल: ${AppConstants.grievanceOfficerEmail} (सामान्य सहायता: $_email)',
          'हम आपकी शिकायत की प्राप्ति 48 घंटे में स्वीकार करेंगे और 15 दिनों के भीतर समाधान का प्रयास करेंगे।',
        ],
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TERMS & CONDITIONS
  // ═══════════════════════════════════════════════════════════════════════════
  static const LegalDocument terms = LegalDocument(
    id: 'terms',
    titleEn: 'Terms & Conditions',
    titleHi: 'नियम और शर्तें',
    lastUpdated: AppConstants.policyLastUpdated,
    introEn:
        'These Terms & Conditions ("Terms") form a legal agreement between you and $_company ("we", "us") for '
        'your use of the $_app app. Please read them carefully. By creating an account or using the App you '
        'confirm that you are 18 or older and agree to these Terms and our Privacy Policy.',
    introHi:
        'ये नियम और शर्तें ("शर्तें") आपके और $_company ("हम") के बीच $_app ऐप के उपयोग के लिए एक कानूनी '
        'समझौता हैं। कृपया इन्हें ध्यान से पढ़ें। खाता बनाकर या ऐप का उपयोग करके आप पुष्टि करते हैं कि आप 18 '
        'वर्ष या उससे अधिक के हैं और इन शर्तों तथा हमारी गोपनीयता नीति से सहमत हैं।',
    sections: [
      LegalSection(
        id: 'service',
        titleEn: 'The service',
        titleHi: 'हमारी सेवा',
        bodyEn: [
          '$_app lets you browse festival, quote and motivational templates, add your name, photo and business details, and download or share the resulting images and videos, for example as a WhatsApp Status. Some templates and features are free; others need a paid Premium plan.',
          'We may add, change or remove features and content at any time.',
        ],
        bodyHi: [
          '$_app आपको त्योहार, सुविचार और प्रेरक टेम्पलेट देखने, उनमें अपना नाम, फ़ोटो और बिज़नेस जानकारी जोड़ने, और बने हुए चित्र/वीडियो को डाउनलोड या शेयर करने (जैसे WhatsApp स्टेटस) की सुविधा देता है। कुछ टेम्पलेट व सुविधाएँ मुफ़्त हैं; बाकी के लिए प्रीमियम प्लान चाहिए।',
          'हम किसी भी समय सुविधाएँ और सामग्री जोड़, बदल या हटा सकते हैं।',
        ],
      ),
      LegalSection(
        id: 'account',
        titleEn: 'Your account',
        titleHi: 'आपका खाता',
        bodyEn: [
          '• You must give accurate information and keep your login (OTP / Google account) secure.',
          '• You are responsible for all activity under your account.',
          '• One person may not operate accounts for the purpose of abusing free limits or offers.',
          '• You can delete your account anytime from Settings → Delete Account.',
        ],
        bodyHi: [
          '• आपको सही जानकारी देनी होगी और अपना लॉगिन (OTP / Google खाता) सुरक्षित रखना होगा।',
          '• आपके खाते से होने वाली सभी गतिविधियों के लिए आप ज़िम्मेदार हैं।',
          '• मुफ़्त सीमा या ऑफ़र का दुरुपयोग करने के लिए एक व्यक्ति कई खाते नहीं चला सकता।',
          '• आप कभी भी सेटिंग्स → खाता हटाएं से अपना खाता हटा सकते हैं।',
        ],
      ),
      LegalSection(
        id: 'use',
        titleEn: 'Acceptable use',
        titleHi: 'स्वीकार्य उपयोग',
        bodyEn: [
          'You agree not to:',
          '• copy, scrape, resell or redistribute our templates as a template library or competing service;',
          '• reverse-engineer, hack, overload or interfere with the App or its servers;',
          '• use bots or automation, or bypass download limits and Premium locks;',
          '• use the App for any unlawful purpose.',
        ],
        bodyHi: [
          'आप सहमत हैं कि आप ये नहीं करेंगे:',
          '• हमारे टेम्पलेट को टेम्पलेट-लाइब्रेरी या प्रतिस्पर्धी सेवा के रूप में कॉपी, स्क्रैप, बेचना या वितरित करना;',
          '• ऐप या उसके सर्वर को रिवर्स-इंजीनियर, हैक, ओवरलोड करना या उनमें बाधा डालना;',
          '• बॉट/ऑटोमेशन का उपयोग करना, या डाउनलोड सीमा व प्रीमियम लॉक को बायपास करना;',
          '• ऐप का किसी गैरकानूनी उद्देश्य के लिए उपयोग करना।',
        ],
      ),
      LegalSection(
        id: 'content',
        titleEn: 'Your content',
        titleHi: 'आपकी सामग्री',
        bodyEn: [
          'You keep ownership of the photos, names, logos and text you add ("User Content"). You grant us a limited, non-exclusive licence to store, process and display it only to operate the App for you (for example to place it on your posters). You confirm you have the right to use your photos and logos and that they do not violate anyone else\'s rights.',
          'Posters you create may be shared by you on WhatsApp and other platforms. You are responsible for what you share.',
        ],
        bodyHi: [
          'आपके द्वारा जोड़े गए फ़ोटो, नाम, लोगो और टेक्स्ट ("उपयोगकर्ता सामग्री") के स्वामी आप ही रहते हैं। आप हमें इसे केवल आपके लिए ऐप चलाने (जैसे आपके पोस्टर पर लगाने) हेतु संग्रहीत, संसाधित और प्रदर्शित करने का सीमित, गैर-विशिष्ट लाइसेंस देते हैं। आप पुष्टि करते हैं कि आपको अपने फ़ोटो व लोगो के उपयोग का अधिकार है और वे किसी अन्य के अधिकारों का उल्लंघन नहीं करते।',
          'आपके बनाए पोस्टर आप WhatsApp व अन्य प्लेटफ़ॉर्म पर शेयर कर सकते हैं। आप जो शेयर करते हैं उसकी ज़िम्मेदारी आपकी है।',
        ],
      ),
      LegalSection(
        id: 'ip',
        titleEn: 'Templates and intellectual property',
        titleHi: 'टेम्पलेट और बौद्धिक संपदा',
        bodyEn: [
          'Templates, designs, artwork, quotes, logos, software and other App content are owned by $_company, its creators or licensors and are protected by copyright and other laws. We grant you a personal, non-exclusive, non-transferable licence to use templates to make and share personalised statuses for your personal or your own business promotion.',
          'You may not sell the templates themselves, remove our credits or watermarks where applicable, or claim them as your own work. If you believe content in the App infringes your copyright, email $_email with details and we will review it promptly.',
        ],
        bodyHi: [
          'टेम्पलेट, डिज़ाइन, आर्टवर्क, सुविचार, लोगो, सॉफ़्टवेयर और ऐप की अन्य सामग्री के स्वामी $_company, उसके क्रिएटर या लाइसेंसदाता हैं और ये कॉपीराइट व अन्य कानूनों से संरक्षित हैं। हम आपको व्यक्तिगत या अपने व्यवसाय के प्रचार हेतु टेम्पलेट से निजीकृत स्टेटस बनाने व शेयर करने का व्यक्तिगत, गैर-विशिष्ट, अहस्तांतरणीय लाइसेंस देते हैं।',
          'आप टेम्पलेट को स्वयं बेच नहीं सकते, जहाँ लागू हो वहाँ हमारे क्रेडिट/वॉटरमार्क हटा नहीं सकते, या उन्हें अपनी रचना नहीं बता सकते। यदि आपको लगे कि ऐप की कोई सामग्री आपके कॉपीराइट का उल्लंघन करती है, तो विवरण के साथ $_email पर लिखें; हम शीघ्र समीक्षा करेंगे।',
        ],
      ),
      LegalSection(
        id: 'prohibited',
        titleEn: 'Prohibited content',
        titleHi: 'प्रतिबंधित सामग्री',
        bodyEn: [
          'You must not create or share content that:',
          '• promotes hatred or violence, or insults any religion, caste, community, gender or region;',
          '• is obscene, defamatory, harassing or harmful to children;',
          '• misuses political or religious figures or symbols, spreads misinformation, or impersonates another person or organisation;',
          '• infringes copyright, trademarks or privacy of others;',
          '• violates the Information Technology Act, 2000, the Indian Penal Code / Bharatiya Nyaya Sanhita or any other Indian law.',
          'We may remove content, restrict features or suspend accounts that break these rules, and may report unlawful content to authorities.',
        ],
        bodyHi: [
          'आप ऐसी सामग्री नहीं बनाएँगे या शेयर नहीं करेंगे जो:',
          '• घृणा या हिंसा को बढ़ावा दे, या किसी धर्म, जाति, समुदाय, लिंग या क्षेत्र का अपमान करे;',
          '• अश्लील, मानहानिकारक, उत्पीड़क या बच्चों के लिए हानिकारक हो;',
          '• राजनीतिक या धार्मिक व्यक्तियों/प्रतीकों का दुरुपयोग करे, गलत जानकारी फैलाए, या किसी अन्य व्यक्ति/संस्था का रूप धारण करे;',
          '• दूसरों के कॉपीराइट, ट्रेडमार्क या निजता का उल्लंघन करे;',
          '• सूचना प्रौद्योगिकी अधिनियम, 2000, भारतीय न्याय संहिता या किसी अन्य भारतीय कानून का उल्लंघन करे।',
          'इन नियमों को तोड़ने वाली सामग्री हम हटा सकते हैं, सुविधाएँ सीमित कर सकते हैं या खाते निलंबित कर सकते हैं, और गैरकानूनी सामग्री की सूचना अधिकारियों को दे सकते हैं।',
        ],
      ),
      LegalSection(
        id: 'plans',
        titleEn: 'Premium plans and billing',
        titleHi: 'प्रीमियम प्लान और बिलिंग',
        bodyEn: [
          '• Free plan: limited daily downloads (currently 10 images and 3 videos per day) and access to free templates.',
          '• Premium Monthly: valid for 30 days from activation. Premium Annual: valid for 365 days from activation. Current prices are shown in the App (inclusive of applicable taxes unless stated otherwise).',
          '• Plans are PREPAID, ONE-TIME payments for the chosen period. They do NOT renew automatically and we do not store your card for recurring charges. When a plan ends you return to the Free plan unless you buy again.',
          '• If you buy while a plan is still active, the new period is added after your current expiry date, so you do not lose remaining days.',
          '• Payments are processed securely by Razorpay (UPI, cards, net banking, wallets). Your plan is activated after the payment is confirmed. If money is debited but the plan is not activated, it is usually fixed automatically within a short time; otherwise contact support.',
          '• We may change prices for future purchases; this never affects a plan you have already paid for.',
        ],
        bodyHi: [
          '• फ़्री प्लान: रोज़ सीमित डाउनलोड (अभी 10 इमेज और 3 वीडियो प्रतिदिन) और मुफ़्त टेम्पलेट तक पहुँच।',
          '• प्रीमियम मासिक: चालू होने से 30 दिन तक मान्य। प्रीमियम वार्षिक: चालू होने से 365 दिन तक मान्य। वर्तमान कीमतें ऐप में दिखाई जाती हैं (जब तक अन्यथा न लिखा हो, लागू कर सहित)।',
          '• प्लान चुनी हुई अवधि के लिए अग्रिम (प्रीपेड), एकमुश्त भुगतान हैं। ये अपने-आप रिन्यू नहीं होते और हम बार-बार कटौती के लिए आपका कार्ड सेव नहीं करते। प्लान खत्म होने पर आप दोबारा खरीदे बिना फ़्री प्लान पर लौट जाते हैं।',
          '• यदि प्लान चालू रहते हुए आप दोबारा खरीदते हैं, तो नई अवधि आपकी वर्तमान समाप्ति तिथि के बाद जुड़ती है, इसलिए बचे हुए दिन नहीं जाते।',
          '• भुगतान Razorpay द्वारा सुरक्षित रूप से प्रोसेस होता है (UPI, कार्ड, नेट बैंकिंग, वॉलेट)। भुगतान की पुष्टि के बाद आपका प्लान चालू होता है। यदि पैसे कट गए पर प्लान चालू नहीं हुआ, तो आमतौर पर कुछ ही समय में अपने-आप ठीक हो जाता है; नहीं तो सहायता से संपर्क करें।',
          '• हम भविष्य की खरीद के लिए कीमतें बदल सकते हैं; इसका असर आपके पहले से चुकाए प्लान पर नहीं पड़ता।',
        ],
      ),
      LegalSection(
        id: 'cancel',
        titleEn: 'Cancellation and refunds',
        titleHi: 'रद्दीकरण और रिफ़ंड',
        bodyEn: [
          'Because plans do not auto-renew, there is nothing to cancel; your plan simply ends on its expiry date. Refunds are governed by our Refund & Cancellation Policy, available in the App under Settings → Privacy & Legal.',
        ],
        bodyHi: [
          'चूँकि प्लान अपने-आप रिन्यू नहीं होते, रद्द करने के लिए कुछ नहीं होता; आपका प्लान समाप्ति तिथि पर खुद खत्म हो जाता है। रिफ़ंड हमारी रिफ़ंड व रद्दीकरण नीति के अधीन हैं, जो ऐप में सेटिंग्स → गोपनीयता व कानूनी में उपलब्ध है।',
        ],
      ),
      LegalSection(
        id: 'termination',
        titleEn: 'Suspension and termination',
        titleHi: 'निलंबन और समाप्ति',
        bodyEn: [
          'You may stop using the App and delete your account at any time. We may suspend or terminate your access, with or without notice, if you break these Terms or the law, or to protect the App and other users. Paid time may not be refunded when an account is terminated for violating these Terms.',
        ],
        bodyHi: [
          'आप कभी भी ऐप का उपयोग बंद कर सकते हैं और अपना खाता हटा सकते हैं। यदि आप इन शर्तों या कानून का उल्लंघन करें, या ऐप और अन्य उपयोगकर्ताओं की सुरक्षा के लिए, हम सूचना के साथ या बिना आपकी पहुँच निलंबित या समाप्त कर सकते हैं। शर्तों के उल्लंघन पर खाता समाप्त होने पर चुकाई गई अवधि का रिफ़ंड नहीं भी हो सकता है।',
        ],
      ),
      LegalSection(
        id: 'disclaimer',
        titleEn: 'Disclaimers',
        titleHi: 'अस्वीकरण',
        bodyEn: [
          'The App and content are provided "as is" and "as available". We do not guarantee uninterrupted or error-free service, that every festival date or quote is free of errors, or that third-party services (WhatsApp, payment gateways, networks) will always work. WhatsApp is a trademark of its owner; $_app is not affiliated with or endorsed by WhatsApp.',
        ],
        bodyHi: [
          'ऐप और सामग्री "जैसी है" और "जैसी उपलब्ध है" के आधार पर दी जाती है। हम निर्बाध या त्रुटिहीन सेवा, हर त्योहार-तिथि या सुविचार के त्रुटिरहित होने, या तृतीय-पक्ष सेवाओं (WhatsApp, पेमेंट गेटवे, नेटवर्क) के हमेशा चलने की गारंटी नहीं देते। WhatsApp उसके स्वामी का ट्रेडमार्क है; $_app का WhatsApp से कोई संबंध या अनुमोदन नहीं है।',
        ],
      ),
      LegalSection(
        id: 'liability',
        titleEn: 'Limitation of liability',
        titleHi: 'दायित्व की सीमा',
        bodyEn: [
          'To the fullest extent permitted by law, we are not liable for indirect, incidental or consequential losses, loss of profits or data, or for content you create or share. Our total liability for any claim relating to the App is limited to the amount you paid us in the 12 months before the claim. Nothing in these Terms limits liability that cannot be limited under Indian law, including your rights under the Consumer Protection Act, 2019.',
        ],
        bodyHi: [
          'कानून द्वारा अनुमत अधिकतम सीमा तक, हम अप्रत्यक्ष, आकस्मिक या परिणामी हानि, लाभ या डेटा की हानि, या आपके द्वारा बनाई/शेयर की गई सामग्री के लिए उत्तरदायी नहीं हैं। ऐप से जुड़े किसी भी दावे के लिए हमारा कुल दायित्व दावे से पहले के 12 महीनों में आपके द्वारा हमें चुकाई राशि तक सीमित है। इन शर्तों की कोई बात उस दायित्व को सीमित नहीं करती जिसे भारतीय कानून में सीमित नहीं किया जा सकता, जिसमें उपभोक्ता संरक्षण अधिनियम, 2019 के तहत आपके अधिकार शामिल हैं।',
        ],
      ),
      LegalSection(
        id: 'law',
        titleEn: 'Governing law and disputes',
        titleHi: 'लागू कानून और विवाद',
        bodyEn: [
          'These Terms are governed by the laws of India. Please first write to us at $_email so we can try to resolve the issue amicably. Any dispute that remains unresolved will be subject to the exclusive jurisdiction of the courts at the city of our registered office in India, without affecting your rights under consumer protection law to approach the appropriate consumer forum.',
        ],
        bodyHi: [
          'ये शर्तें भारत के कानूनों द्वारा शासित हैं। कृपया पहले $_email पर हमें लिखें ताकि हम मामले को आपसी सहमति से सुलझाने का प्रयास कर सकें। जो विवाद फिर भी न सुलझे, वह भारत में हमारे पंजीकृत कार्यालय के शहर की अदालतों के विशेष क्षेत्राधिकार में होगा; इससे उपभोक्ता संरक्षण कानून के तहत उचित उपभोक्ता मंच जाने का आपका अधिकार प्रभावित नहीं होता।',
        ],
      ),
      LegalSection(
        id: 'changes',
        titleEn: 'Changes to these Terms',
        titleHi: 'शर्तों में बदलाव',
        bodyEn: [
          'We may update these Terms. The latest version is always available in the App. If you continue to use the App after a change, you accept the updated Terms.',
        ],
        bodyHi: [
          'हम इन शर्तों को अपडेट कर सकते हैं। नवीनतम संस्करण हमेशा ऐप में उपलब्ध रहेगा। बदलाव के बाद भी ऐप का उपयोग जारी रखने पर आप अपडेट की गई शर्तें स्वीकार करते हैं।',
        ],
      ),
      LegalSection(
        id: 'contact',
        titleEn: 'Contact us',
        titleHi: 'संपर्क करें',
        bodyEn: [
          '• Company: ${AppConstants.companyName}',
          '• Address: ${AppConstants.companyAddress}',
          '• Email: $_email',
        ],
        bodyHi: [
          '• कंपनी: ${AppConstants.companyName}',
          '• पता: ${AppConstants.companyAddress}',
          '• ईमेल: $_email',
        ],
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // REFUND & CANCELLATION
  // ═══════════════════════════════════════════════════════════════════════════
  static const LegalDocument refund = LegalDocument(
    id: 'refund',
    titleEn: 'Refund & Cancellation Policy',
    titleHi: 'रिफ़ंड और रद्दीकरण नीति',
    lastUpdated: AppConstants.policyLastUpdated,
    introEn:
        'This policy explains how cancellations and refunds work for $_app Premium plans purchased through '
        'Razorpay. We want you to be happy with your purchase and will always treat genuine problems fairly.',
    introHi:
        'यह नीति बताती है कि Razorpay के माध्यम से खरीदे गए $_app प्रीमियम प्लान के लिए रद्दीकरण और रिफ़ंड कैसे '
        'काम करते हैं। हम चाहते हैं कि आप अपनी खरीद से संतुष्ट रहें और असली समस्याओं का हम हमेशा निष्पक्षता से समाधान करेंगे।',
    sections: [
      LegalSection(
        id: 'nature',
        titleEn: 'Nature of our plans',
        titleHi: 'हमारे प्लान का स्वरूप',
        bodyEn: [
          'Premium Monthly (30 days) and Premium Annual (365 days) are prepaid, one-time purchases of digital access. Access starts as soon as payment is confirmed. They do not renew automatically.',
        ],
        bodyHi: [
          'प्रीमियम मासिक (30 दिन) और प्रीमियम वार्षिक (365 दिन) डिजिटल एक्सेस की अग्रिम, एकमुश्त खरीद हैं। भुगतान की पुष्टि होते ही एक्सेस शुरू हो जाता है। ये अपने-आप रिन्यू नहीं होते।',
        ],
      ),
      LegalSection(
        id: 'cancellation',
        titleEn: 'Cancellation',
        titleHi: 'रद्दीकरण',
        bodyEn: [
          'Since there is no auto-renewal, you never need to cancel to avoid future charges. Your plan stays active until its expiry date and then moves to the Free plan. You can delete your account at any time (Settings → Delete Account); this does not by itself create a refund for the remaining period.',
        ],
        bodyHi: [
          'चूँकि ऑटो-रिन्यूअल नहीं है, भविष्य की कटौती से बचने के लिए आपको कुछ रद्द करने की ज़रूरत नहीं। आपका प्लान समाप्ति तिथि तक चालू रहता है और फिर फ़्री प्लान पर आ जाता है। आप कभी भी खाता हटा सकते हैं (सेटिंग्स → खाता हटाएं); इससे शेष अवधि का रिफ़ंड अपने-आप नहीं बनता।',
        ],
      ),
      LegalSection(
        id: 'eligible',
        titleEn: 'When you are eligible for a refund',
        titleHi: 'रिफ़ंड कब मिलेगा',
        bodyEn: [
          '• Duplicate payment: you were charged more than once for the same order.',
          '• Payment debited but plan not activated: money left your account but Premium was not activated and could not be fixed by us within 48 hours.',
          '• Technical failure: Premium features were not usable because of a fault on our side, we could not fix it, and you contact us within 7 days of purchase.',
          '• Wrong amount charged compared to the price shown in the App at the time of purchase.',
        ],
        bodyHi: [
          '• दोहरा भुगतान: एक ही ऑर्डर के लिए आपसे एक से अधिक बार राशि कटी।',
          '• पैसे कटे पर प्लान चालू नहीं हुआ: आपके खाते से पैसे गए पर प्रीमियम चालू नहीं हुआ और हम 48 घंटे में उसे ठीक नहीं कर सके।',
          '• तकनीकी खराबी: हमारी ओर की खराबी के कारण प्रीमियम सुविधाएँ उपयोग नहीं हो सकीं, हम उसे ठीक नहीं कर सके, और आपने खरीद के 7 दिन के भीतर हमसे संपर्क किया।',
          '• ऐप में खरीद के समय दिखाई गई कीमत से अलग राशि वसूली गई।',
        ],
      ),
      LegalSection(
        id: 'not-eligible',
        titleEn: 'When refunds are not available',
        titleHi: 'रिफ़ंड कब नहीं मिलेगा',
        bodyEn: [
          '• You changed your mind or no longer need the plan after it was activated and working.',
          '• You did not use, or only partly used, the plan period (no pro-rata refunds).',
          '• Your account was suspended or terminated for breaking our Terms.',
          '• Problems caused by your device, internet connection, or third-party apps such as WhatsApp.',
        ],
        bodyHi: [
          '• प्लान चालू और ठीक चलने के बाद आपने मन बदल लिया या अब उसकी ज़रूरत नहीं रही।',
          '• आपने प्लान की अवधि का उपयोग नहीं किया या आंशिक उपयोग किया (आनुपातिक रिफ़ंड नहीं होता)।',
          '• हमारी शर्तों के उल्लंघन पर आपका खाता निलंबित या समाप्त किया गया।',
          '• आपके डिवाइस, इंटरनेट या WhatsApp जैसे तृतीय-पक्ष ऐप से हुई समस्याएँ।',
        ],
      ),
      LegalSection(
        id: 'how',
        titleEn: 'How to request a refund',
        titleHi: 'रिफ़ंड का अनुरोध कैसे करें',
        bodyEn: [
          'Email $_email (or use Help & Support → Report a problem) with:',
          '• your registered mobile number or Google email;',
          '• the Razorpay payment ID / order ID and date of payment;',
          '• a short description of the problem and, if possible, a screenshot.',
          'We acknowledge requests within 48 hours and decide within 5 working days.',
        ],
        bodyHi: [
          '$_email पर ईमेल करें (या सहायता → समस्या बताएं का उपयोग करें) और साथ में दें:',
          '• आपका पंजीकृत मोबाइल नंबर या Google ईमेल;',
          '• Razorpay पेमेंट ID / ऑर्डर ID और भुगतान की तारीख;',
          '• समस्या का संक्षिप्त विवरण और संभव हो तो स्क्रीनशॉट।',
          'हम अनुरोध की प्राप्ति 48 घंटे में स्वीकार करते हैं और 5 कार्य-दिवसों में निर्णय देते हैं।',
        ],
      ),
      LegalSection(
        id: 'processing',
        titleEn: 'Refund timeline',
        titleHi: 'रिफ़ंड की समय-सीमा',
        bodyEn: [
          'Approved refunds are issued through Razorpay to the original payment method (UPI / card / bank / wallet). After we initiate it, your bank usually takes 5 to 7 working days to show the credit; some banks may take up to 10 working days.',
          'If a refund is approved, your Premium access for that purchase may be removed.',
        ],
        bodyHi: [
          'स्वीकृत रिफ़ंड Razorpay के ज़रिए मूल भुगतान माध्यम (UPI / कार्ड / बैंक / वॉलेट) में भेजा जाता है। हमारे शुरू करने के बाद आपका बैंक आमतौर पर 5 से 7 कार्य-दिवस में राशि दिखाता है; कुछ बैंकों में 10 कार्य-दिवस तक लग सकते हैं।',
          'रिफ़ंड स्वीकृत होने पर उस खरीद का प्रीमियम एक्सेस हटाया जा सकता है।',
        ],
      ),
      LegalSection(
        id: 'contact',
        titleEn: 'Contact',
        titleHi: 'संपर्क',
        bodyEn: [
          '• Email: $_email',
          '• Company: ${AppConstants.companyName}',
          '• Address: ${AppConstants.companyAddress}',
        ],
        bodyHi: [
          '• ईमेल: $_email',
          '• कंपनी: ${AppConstants.companyName}',
          '• पता: ${AppConstants.companyAddress}',
        ],
      ),
    ],
  );
}
