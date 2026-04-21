// src/lib/auth/jwt.service.ts
import { SignJWT, jwtVerify, type JWTPayload as JosePayload } from 'jose';
import { env } from '../../config/env';

export interface AppJWTPayload extends JosePayload {
  userId: string;
  role: string;
  plan: string;
}

export interface RefreshTokenPayload extends JosePayload {
  userId: string;
  tokenVersion?: number;
}

const accessSecret = new TextEncoder().encode(env.JWT_SECRET);
const refreshSecret = new TextEncoder().encode(env.JWT_REFRESH_SECRET);

export class JWTService {
  static async signAccessToken(payload: { userId: string; role: string; plan: string }): Promise<string> {
    return new SignJWT({ ...payload, type: 'access' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime('15m')
      .setIssuer('statusgo.app')
      .sign(accessSecret);
  }

  static async signRefreshToken(userId: string, tokenVersion = 1): Promise<string> {
    return new SignJWT({ userId, tokenVersion, type: 'refresh' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime('30d')
      .setIssuer('statusgo.app')
      .sign(refreshSecret);
  }

  static async verifyAccessToken(token: string): Promise<AppJWTPayload | null> {
    try {
      const { payload } = await jwtVerify(token, accessSecret, {
        issuer: 'statusgo.app',
      });
      return payload as AppJWTPayload;
    } catch {
      return null;
    }
  }

  static async verifyRefreshToken(token: string): Promise<RefreshTokenPayload | null> {
    try {
      const { payload } = await jwtVerify(token, refreshSecret, {
        issuer: 'statusgo.app',
      });
      return payload as RefreshTokenPayload;
    } catch {
      return null;
    }
  }
}
