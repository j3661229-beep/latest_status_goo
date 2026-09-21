// lib/core/data/indian_states.dart
// Static list of all Indian states and UTs with associated default language

class IndianState {
  final String name;
  final String code;
  final String defaultLanguage; // matches backend Language enum
  final List<String> regions;
  final String emoji;

  const IndianState({
    required this.name,
    required this.code,
    required this.defaultLanguage,
    required this.regions,
    required this.emoji,
  });
}

class IndianStates {
  IndianStates._();

  static const List<IndianState> all = [
    IndianState(name: 'Andhra Pradesh', code: 'AP', defaultLanguage: 'TELUGU', regions: ['Coastal Andhra', 'Rayalaseema', 'North Andhra'], emoji: '🏖️'),
    IndianState(name: 'Arunachal Pradesh', code: 'AR', defaultLanguage: 'ENGLISH', regions: ['East', 'West', 'Central'], emoji: '🏔️'),
    IndianState(name: 'Assam', code: 'AS', defaultLanguage: 'ENGLISH', regions: ['Barak Valley', 'Brahmaputra Valley', 'North Bank'], emoji: '🍵'),
    IndianState(name: 'Bihar', code: 'BR', defaultLanguage: 'HINDI', regions: ['Patna', 'Bhagalpur', 'Darbhanga', 'Munger', 'Purnia'], emoji: '🏯'),
    IndianState(name: 'Chhattisgarh', code: 'CG', defaultLanguage: 'HINDI', regions: ['Raipur', 'Bilaspur', 'Bastar'], emoji: '🌿'),
    IndianState(name: 'Goa', code: 'GA', defaultLanguage: 'ENGLISH', regions: ['North Goa', 'South Goa'], emoji: '🌊'),
    IndianState(name: 'Gujarat', code: 'GJ', defaultLanguage: 'GUJARATI', regions: ['Saurashtra', 'Kutch', 'Central Gujarat', 'South Gujarat', 'North Gujarat'], emoji: '🦁'),
    IndianState(name: 'Haryana', code: 'HR', defaultLanguage: 'HINDI', regions: ['Gurugram', 'Faridabad', 'Rohtak', 'Ambala', 'Hisar'], emoji: '🌾'),
    IndianState(name: 'Himachal Pradesh', code: 'HP', defaultLanguage: 'HINDI', regions: ['Shimla', 'Kullu-Manali', 'Dharamshala', 'Hamirpur'], emoji: '🏔️'),
    IndianState(name: 'Jharkhand', code: 'JH', defaultLanguage: 'HINDI', regions: ['Ranchi', 'Dhanbad', 'Jamshedpur', 'Hazaribagh'], emoji: '⛏️'),
    IndianState(name: 'Karnataka', code: 'KA', defaultLanguage: 'ENGLISH', regions: ['Bengaluru Urban', 'Mysuru', 'Belagavi', 'Kalburgi', 'Dharwad'], emoji: '🏛️'),
    IndianState(name: 'Kerala', code: 'KL', defaultLanguage: 'ENGLISH', regions: ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kottayam'], emoji: '🌴'),
    IndianState(name: 'Madhya Pradesh', code: 'MP', defaultLanguage: 'HINDI', regions: ['Bhopal', 'Indore', 'Gwalior', 'Jabalpur', 'Ujjain'], emoji: '🕌'),
    IndianState(name: 'Maharashtra', code: 'MH', defaultLanguage: 'MARATHI', regions: ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Kolhapur', 'Solapur', 'Konkan', 'Vidarbha', 'Marathwada'], emoji: '🏙️'),
    IndianState(name: 'Manipur', code: 'MN', defaultLanguage: 'ENGLISH', regions: ['Imphal', 'Churachandpur', 'Bishnupur'], emoji: '🥊'),
    IndianState(name: 'Meghalaya', code: 'ML', defaultLanguage: 'ENGLISH', regions: ['Shillong', 'Tura', 'Jowai'], emoji: '☁️'),
    IndianState(name: 'Mizoram', code: 'MZ', defaultLanguage: 'ENGLISH', regions: ['Aizawl', 'Lunglei', 'Champhai'], emoji: '🌿'),
    IndianState(name: 'Nagaland', code: 'NL', defaultLanguage: 'ENGLISH', regions: ['Kohima', 'Dimapur', 'Mokokchung'], emoji: '🌲'),
    IndianState(name: 'Odisha', code: 'OD', defaultLanguage: 'ENGLISH', regions: ['Bhubaneswar', 'Cuttack', 'Berhampur', 'Sambalpur'], emoji: '🎭'),
    IndianState(name: 'Punjab', code: 'PB', defaultLanguage: 'PUNJABI', regions: ['Amritsar', 'Ludhiana', 'Jalandhar', 'Patiala', 'Bathinda'], emoji: '🌾'),
    IndianState(name: 'Rajasthan', code: 'RJ', defaultLanguage: 'HINDI', regions: ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer', 'Bikaner'], emoji: '🏜️'),
    IndianState(name: 'Sikkim', code: 'SK', defaultLanguage: 'ENGLISH', regions: ['East Sikkim', 'West Sikkim', 'North Sikkim', 'South Sikkim'], emoji: '🏔️'),
    IndianState(name: 'Tamil Nadu', code: 'TN', defaultLanguage: 'TAMIL', regions: ['Chennai', 'Coimbatore', 'Madurai', 'Salem', 'Tiruchirappalli'], emoji: '🏛️'),
    IndianState(name: 'Telangana', code: 'TS', defaultLanguage: 'TELUGU', regions: ['Hyderabad', 'Warangal', 'Karimnagar', 'Nizamabad'], emoji: '💎'),
    IndianState(name: 'Tripura', code: 'TR', defaultLanguage: 'ENGLISH', regions: ['West Tripura', 'Gomati', 'South Tripura'], emoji: '🎋'),
    IndianState(name: 'Uttar Pradesh', code: 'UP', defaultLanguage: 'HINDI', regions: ['Lucknow', 'Kanpur', 'Agra', 'Varanasi', 'Allahabad', 'Meerut', 'Ghaziabad', 'Noida', 'Mathura', 'Bareilly'], emoji: '🕌'),
    IndianState(name: 'Uttarakhand', code: 'UK', defaultLanguage: 'HINDI', regions: ['Dehradun', 'Haridwar', 'Rishikesh', 'Nainital', 'Mussoorie'], emoji: '🏔️'),
    IndianState(name: 'West Bengal', code: 'WB', defaultLanguage: 'ENGLISH', regions: ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri', 'Darjeeling'], emoji: '🌸'),
    // Union Territories
    IndianState(name: 'Delhi', code: 'DL', defaultLanguage: 'HINDI', regions: ['Central Delhi', 'North Delhi', 'South Delhi', 'East Delhi', 'West Delhi', 'Noida', 'Gurugram'], emoji: '🏛️'),
    IndianState(name: 'Jammu & Kashmir', code: 'JK', defaultLanguage: 'HINDI', regions: ['Jammu', 'Kashmir Valley', 'Ladakh'], emoji: '🏔️'),
    IndianState(name: 'Chandigarh', code: 'CH', defaultLanguage: 'HINDI', regions: ['Chandigarh City'], emoji: '🌷'),
    IndianState(name: 'Puducherry', code: 'PY', defaultLanguage: 'TAMIL', regions: ['Puducherry', 'Karaikal', 'Yanam', 'Mahé'], emoji: '🌊'),
    IndianState(name: 'Andaman & Nicobar Islands', code: 'AN', defaultLanguage: 'ENGLISH', regions: ['South Andaman', 'North & Middle Andaman', 'Nicobar'], emoji: '🏝️'),
    IndianState(name: 'Lakshadweep', code: 'LD', defaultLanguage: 'ENGLISH', regions: ['Kavaratti', 'Minicoy', 'Agatti'], emoji: '🌺'),
    IndianState(name: 'Dadra & Nagar Haveli and Daman & Diu', code: 'DD', defaultLanguage: 'GUJARATI', regions: ['Daman', 'Diu', 'Dadra & Nagar Haveli'], emoji: '⚓'),
    IndianState(name: 'Ladakh', code: 'LA', defaultLanguage: 'HINDI', regions: ['Leh', 'Kargil'], emoji: '🏔️'),
  ];

  static IndianState? findByName(String name) {
    try {
      return all.firstWhere((s) => s.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  static String languageForState(String stateName) {
    return findByName(stateName)?.defaultLanguage ?? 'HINDI';
  }
}
