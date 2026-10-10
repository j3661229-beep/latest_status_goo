// lib/google.ts — Google Sign-In configuration. Empty id ⇒ Google login is hidden.
export const GOOGLE_CLIENT_ID = (process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ?? '').trim();
export const GOOGLE_ENABLED = GOOGLE_CLIENT_ID.length > 0;
