// src/lib/auth/google.service.ts
import axios from 'axios';
import { env } from '../../config/env';

export interface GooglePayload {
  sub: string;         // Google user ID
  email: string;
  name: string;
  picture?: string;
  // tokeninfo returns booleans as strings ("true"/"false")
  email_verified: boolean | string;
  exp: number | string;
  aud: string;
}

export class GoogleAuthError extends Error {
  statusCode = 401;
}

export class GoogleAuthService {
  private static readonly TOKENINFO_URL = 'https://oauth2.googleapis.com/tokeninfo';

  static async verifyIdToken(idToken: string): Promise<GooglePayload> {
    let payload: GooglePayload;

    try {
      const res = await axios.get<GooglePayload>(this.TOKENINFO_URL, {
        // axios URL-encodes params (the raw token must not be concatenated into the URL)
        params: { id_token: idToken },
        timeout: 5000,
      });
      payload = res.data;
    } catch {
      throw new GoogleAuthError('Google token verification failed');
    }

    // Validate audience (must match our client ID)
    if (payload.aud !== env.GOOGLE_CLIENT_ID) {
      throw new GoogleAuthError('Invalid Google token audience');
    }

    // Validate expiry
    if (Number(payload.exp) < Math.floor(Date.now() / 1000)) {
      throw new GoogleAuthError('Google token has expired');
    }

    // Only accept verified email addresses (prevents linking accounts via unverified emails)
    if (!payload.email || !(payload.email_verified === true || payload.email_verified === 'true')) {
      throw new GoogleAuthError('Google account email is not verified');
    }

    return payload;
  }
}
