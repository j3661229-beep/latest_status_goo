// src/lib/content/state-locator.ts
// Offline, high-speed Indian state resolver from coordinates (latitude, longitude)
// and state name / state code normalizer.

export interface IndianStateLocation {
  code: string;
  nameEn: string;
  nameHi: string;
  lat: number;
  lng: number;
}

export const INDIAN_STATES: IndianStateLocation[] = [
  { code: 'MH', nameEn: 'Maharashtra', nameHi: 'महाराष्ट्र', lat: 19.75, lng: 75.71 },
  { code: 'UP', nameEn: 'Uttar Pradesh', nameHi: 'उत्तर प्रदेश', lat: 26.84, lng: 80.94 },
  { code: 'MP', nameEn: 'Madhya Pradesh', nameHi: 'मध्य प्रदेश', lat: 22.97, lng: 78.65 },
  { code: 'RJ', nameEn: 'Rajasthan', nameHi: 'राजस्थान', lat: 27.02, lng: 74.21 },
  { code: 'BR', nameEn: 'Bihar', nameHi: 'बिहार', lat: 25.09, lng: 85.31 },
  { code: 'GJ', nameEn: 'Gujarat', nameHi: 'गुजरात', lat: 22.25, lng: 71.19 },
  { code: 'DL', nameEn: 'Delhi', nameHi: 'दिल्ली', lat: 28.70, lng: 77.10 },
  { code: 'PB', nameEn: 'Punjab', nameHi: 'पंजाब', lat: 31.14, lng: 75.34 },
  { code: 'HR', nameEn: 'Haryana', nameHi: 'हरियाणा', lat: 29.05, lng: 76.08 },
  { code: 'WB', nameEn: 'West Bengal', nameHi: 'पश्चिम बंगाल', lat: 22.98, lng: 87.85 },
  { code: 'KA', nameEn: 'Karnataka', nameHi: 'कर्नाटक', lat: 15.31, lng: 75.71 },
  { code: 'TN', nameEn: 'Tamil Nadu', nameHi: 'तमिलनाडु', lat: 11.12, lng: 78.65 },
  { code: 'AP', nameEn: 'Andhra Pradesh', nameHi: 'आंध्र प्रदेश', lat: 15.91, lng: 79.74 },
  { code: 'TS', nameEn: 'Telangana', nameHi: 'तेलंगाना', lat: 18.11, lng: 79.01 },
  { code: 'KL', nameEn: 'Kerala', nameHi: 'केरल', lat: 10.85, lng: 76.27 },
  { code: 'OD', nameEn: 'Odisha', nameHi: 'ओडिशा', lat: 20.95, lng: 85.09 },
  { code: 'JH', nameEn: 'Jharkhand', nameHi: 'झारखंड', lat: 23.61, lng: 85.27 },
  { code: 'CG', nameEn: 'Chhattisgarh', nameHi: 'छत्तीसगढ़', lat: 21.27, lng: 81.86 },
  { code: 'AS', nameEn: 'Assam', nameHi: 'असम', lat: 26.20, lng: 92.93 },
  { code: 'UK', nameEn: 'Uttarakhand', nameHi: 'उत्तराखंड', lat: 30.06, lng: 79.01 },
  { code: 'HP', nameEn: 'Himachal Pradesh', nameHi: 'हिमाचल प्रदेश', lat: 31.10, lng: 77.17 },
  { code: 'JK', nameEn: 'Jammu & Kashmir', nameHi: 'जम्मू और कश्मीर', lat: 33.77, lng: 76.57 },
];

/**
 * Finds the closest Indian state given latitude and longitude.
 */
export function resolveStateFromCoords(lat: number, lng: number): IndianStateLocation | null {
  if (typeof lat !== 'number' || typeof lng !== 'number') return null;
  // Bounding box check for India
  if (lat < 6.0 || lat > 38.0 || lng < 67.0 || lng > 98.0) return null;

  let closest: IndianStateLocation = INDIAN_STATES[0];
  let minDistanceSq = Number.MAX_VALUE;

  for (const s of INDIAN_STATES) {
    const dLat = lat - s.lat;
    const dLng = lng - s.lng;
    const distSq = dLat * dLat + dLng * dLng;
    if (distSq < minDistanceSq) {
      minDistanceSq = distSq;
      closest = s;
    }
  }

  return closest;
}

/**
 * Normalizes state code or name (e.g. 'Maharashtra' -> 'MH', 'UP' -> 'UP').
 */
export function normalizeStateCode(input: string | null | undefined): string | null {
  if (!input) return null;
  const clean = input.trim().toUpperCase();
  const direct = INDIAN_STATES.find((s) => s.code === clean);
  if (direct) return direct.code;

  const lower = input.trim().toLowerCase();
  const byName = INDIAN_STATES.find(
    (s) => s.nameEn.toLowerCase() === lower || s.nameHi === input.trim(),
  );
  return byName ? byName.code : null;
}
