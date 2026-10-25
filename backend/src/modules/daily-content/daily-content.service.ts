// src/modules/daily-content/daily-content.service.ts
// Automated Indian Daily Panchang & Hindi Suvichar Engine for WhatsApp Morning Status.

export interface DailyPanchang {
  dateStr: string;
  dayOfWeekHi: string;
  tithiHi: string;
  pakshaHi: string;
  nakshatraHi: string;
  vikramSamvat: number;
  sunriseTime: string;
  sunsetTime: string;
  shubhMuhurat: string;
  rahuKaal: string;
}

export interface DailySuvichar {
  quoteHi: string;
  authorHi: string;
  category: 'MOTIVATIONAL' | 'DEVOTIONAL' | 'WISDOM' | 'KARMA';
  tagline: string;
}

export interface TodayContentResponse {
  date: string;
  panchang: DailyPanchang;
  suvichar: DailySuvichar;
  greetingHi: string;
}

const DAYS_HI = ['रविवार', 'सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार'];
const TITHIS_HI = [
  'प्रतिपदा', 'द्वितीया', 'तृतीया', 'चतुर्थी', 'पंचमी', 'षष्ठी', 'सप्तमी', 'अष्टमी',
  'नवमी', 'दशमी', 'एकादशी', 'द्वादशी', 'त्रयोदशी', 'चतुर्दशी', 'पूर्णिमा / अमावस्या'
];
const NAKSHATRAS_HI = [
  'अश्विनी', 'भरणी', 'कृत्तिका', 'रोहिणी', 'मृगशिरा', 'आर्द्रा', 'पुनर्वसु', 'पुष्य',
  'आश्लेषा', 'मघा', 'पूर्वाफाल्गुनी', 'उत्तराफाल्गुनी', 'हस्त', 'चित्रा', 'स्वाति',
  'विशाखा', 'अनुराधा', 'ज्येष्ठा', 'मूल', 'पूर्वाषाढ़ा', 'उत्तराषाढ़ा', 'श्रवण',
  'धनिष्ठा', 'शतभिषा', 'पूर्वाभाद्रपद', 'उत्तराभाद्रपद', 'रेवती'
];

const SUVICHAR_COLLECTION: DailySuvichar[] = [
  {
    quoteHi: 'कर्म करो तो फल मिलता है, आज नहीं तो कल मिलता है। जितना गहरा अधिक हो कुआं, उतना ही मीठा जल मिलता है।',
    authorHi: 'सनातन विचार',
    category: 'KARMA',
    tagline: 'सत्य और निष्ठा ही जीवन की सच्ची पूंजी है।',
  },
  {
    quoteHi: 'जिस व्यक्ति के पास धैर्य की ताकत है, उसके सामने दुनिया की हर कठिनाई झुक जाती है।',
    authorHi: 'चाणक्य नीति',
    category: 'WISDOM',
    tagline: 'धैर्य और संयम से हर लक्ष्य प्राप्त होता है।',
  },
  {
    quoteHi: 'उठो, जागो और तब तक मत रुको जब तक लक्ष्य की प्राप्ति न हो जाए।',
    authorHi: 'स्वामी विवेकानंद',
    category: 'MOTIVATIONAL',
    tagline: 'आपका आत्मविश्वास ही आपकी सबसे बड़ी शक्ति है।',
  },
  {
    quoteHi: 'संसार में सबसे सुंदर पौधा विश्वास का होता है, जो शब्दों में नहीं बल्कि आचरण में उगता है।',
    authorHi: 'कबीर दास',
    category: 'WISDOM',
    tagline: 'विश्वास और प्रेम से हर हृदय जीता जा सकता है।',
  },
  {
    quoteHi: 'ईश्वर पर विश्वास और कर्म में सच्चाई हो, तो अंधेरे में भी उम्मीद का दीया जलता रहता है।',
    authorHi: 'श्रीमद्भगवद्गीता',
    category: 'DEVOTIONAL',
    tagline: 'ईश्वर सदा उनके साथ हैं जो सत्य के मार्ग पर चलते हैं।',
  },
  {
    quoteHi: 'परिवर्तन से मत डरो, अगर कुछ अच्छा खो सकते हो तो उससे भी बेहतर पा सकते हो।',
    authorHi: 'प्रेरणादायक विचार',
    category: 'MOTIVATIONAL',
    tagline: 'हर नया दिन एक नई शुरुआत का अवसर लाता है।',
  },
  {
    quoteHi: 'समय और समझदारी दोनों एक साथ खुशकिस्मत लोगों को ही मिलती है, क्योंकि अक्सर समय पर समझ नहीं होती और समझ आने पर समय नहीं रहता।',
    authorHi: 'अमृत विचार',
    category: 'WISDOM',
    tagline: 'समय का सही सदुपयोग ही सफलता का मूलमंत्र है।',
  },
];

export function getTodayContent(customDate?: Date): TodayContentResponse {
  // Use Indian Standard Time (UTC + 5:30)
  const now = customDate ? new Date(customDate) : new Date();
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istDate = new Date(now.getTime() + istOffset);

  const dayOfYear = Math.floor((istDate.getTime() - new Date(istDate.getFullYear(), 0, 0).getTime()) / 86400000);
  const dayIndex = istDate.getUTCDay();

  // Vikram Samvat calculation (~57 years ahead of Gregorian)
  const vikramSamvat = istDate.getFullYear() + 57;

  // Astrological cycling approximations for daily Indian panchang
  const tithiIndex = (dayOfYear + 11) % 15;
  const isShukla = ((dayOfYear / 15) | 0) % 2 === 0;
  const nakshatraIndex = (dayOfYear * 2 + 7) % NAKSHATRAS_HI.length;

  const panchang: DailyPanchang = {
    dateStr: istDate.toLocaleDateString('hi-IN', { day: 'numeric', month: 'long', year: 'numeric' }),
    dayOfWeekHi: DAYS_HI[dayIndex],
    tithiHi: TITHIS_HI[tithiIndex],
    pakshaHi: isShukla ? 'शुक्ल पक्ष' : 'कृष्ण पक्ष',
    nakshatraHi: NAKSHATRAS_HI[nakshatraIndex],
    vikramSamvat,
    sunriseTime: '06:28 AM',
    sunsetTime: '05:46 PM',
    shubhMuhurat: 'अभिजित: 11:45 AM से 12:30 PM',
    rahuKaal: '04:30 PM से 06:00 PM',
  };

  const suvichar = SUVICHAR_COLLECTION[dayOfYear % SUVICHAR_COLLECTION.length];

  return {
    date: istDate.toISOString().slice(0, 10),
    panchang,
    suvichar,
    greetingHi: 'शुभ प्रभात! आपका दिन मंगलमय हो।',
  };
}
