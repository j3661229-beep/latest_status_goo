// src/lib/auth/phone.ts
// Phone numbers are stored in one canonical E.164 form (+91XXXXXXXXXX for India)
// so "+919876543210", "919876543210", "09876543210" and "9876543210" are the same account.

/**
 * Normalise a user-supplied phone number.
 * - Indian numbers (10 digits, optionally prefixed by 0 / 91 / +91) → "+91XXXXXXXXXX"
 * - Other numbers given in explicit "+<country><number>" form → "+<digits>"
 * Returns null when the input cannot be a valid phone number.
 */
export function normalizePhone(input: string): string | null {
  if (typeof input !== 'string') return null;
  const trimmed = input.trim();
  const digits = trimmed.replace(/\D/g, '');

  // Explicit international format (e.g. Firebase E.164 "+919876543210" / "+14155550100")
  if (trimmed.startsWith('+')) {
    if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
    if (digits.length >= 8 && digits.length <= 15 && !digits.startsWith('91')) return `+${digits}`;
    return null;
  }

  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 11 && digits.startsWith('0')) return `+91${digits.slice(1)}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+91${digits.slice(2)}`;

  return null;
}

/** All legacy spellings a canonical +91 number may have been stored under. */
export function phoneLookupVariants(canonical: string): string[] {
  if (!canonical.startsWith('+91') || canonical.length !== 13) return [canonical];
  const ten = canonical.slice(3);
  return [canonical, ten, `91${ten}`, `0${ten}`];
}

/** The 10-digit local part used by Indian SMS gateways. */
export function localIndianNumber(canonical: string): string {
  return canonical.startsWith('+91') ? canonical.slice(3) : canonical.replace(/\D/g, '');
}
