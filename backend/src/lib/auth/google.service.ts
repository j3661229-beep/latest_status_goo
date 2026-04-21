// src/lib/auth/google.service.ts
import axios from 'axios';
import { env } from '../../config/env';

export interface GooglePayload {
  sub: string;         // Google user ID
  email: string;
  name: string;
  picture?: string;
  email_verified: boolean;
  exp: number;
  aud: string;
}

export class GoogleAuthService {
  private static readonly TOKENINFO_URL = 'https://oauth2.googleapis.com/tokeninfo';

  static async verifyIdToken(idToken: string): Promise<GooglePayload> {
    let payload: GooglePayload;

    try {
      const res = await axios.get<GooglePayload>(
        `${this.TOKENINFO_URL}?id_token=${idToken}`,
        { timeout: 5000 }
      );
      payload = res.data;
    } catch (err) {
      throw new Error('Google token verification failed');
    }

    // Validate audience (must match our client ID)
    if (payload.aud !== env.GOOGLE_CLIENT_ID) {
      throw new Error('Invalid Google token audience');
    }

    // Validate expiry
    if (payload.exp < Math.floor(Date.now() / 1000)) {
      throw new Error('Google token has expired');
    }

    return payload;
  }
}
