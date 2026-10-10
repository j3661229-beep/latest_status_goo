// src/lib/auth/jwt.service.ts
import { SignJWT, jwtVerify, type JWTPayload as JosePayload } from 'jose';
import { randomUUID } from 'crypto';
import { env } from '../../config/env';

export const TOKEN_ISSUER = 'statusgo.app';

export interface AppJWTPayload extends JosePayload {
  userId: string;
  role: string;
  plan: string;
  type: 'access';
}

export interface RefreshTokenPayload extends JosePayload {
  userId: string;
  tokenVersion?: number;
  type: 'refresh';
}

const accessSecret = new TextEncoder().encode(env.JWT_SECRET);
const refreshSecret = new TextEncoder().encode(env.JWT_REFRESH_SECRET);

export class JWTService {
  static async signAccessToken(payload: { userId: string; role: string; plan: string }): Promise<string> {
    return new SignJWT({ ...payload, sub: payload.userId, type: 'access' })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(payload.userId)
      .setJti(randomUUID())
      .setIssuedAt()
      .setExpirationTime('15m')
      .setIssuer(TOKEN_ISSUER)
      .sign(accessSecret);
  }

  static async signRefreshToken(userId: string, tokenVersion = 1): Promise<string> {
    // jti guarantees two tokens minted in the same second are distinct (rotation relies on it)
    return new SignJWT({ userId, tokenVersion, type: 'refresh' })
      .setProtectedHeader({ alg: 'HS256' })
      .setJti(randomUUID())
      .setIssuedAt()
      .setExpirationTime('30d')
      .setIssuer(TOKEN_ISSUER)
      .sign(refreshSecret);
  }

  static async verifyAccessToken(token: string): Promise<AppJWTPayload | null> {
    try {
      const { payload } = await jwtVerify(token, accessSecret, { issuer: TOKEN_ISSUER });
      if (payload.type !== 'access') return null;
      return payload as AppJWTPayload;
    } catch {
      return null;
    }
  }

  static async verifyRefreshToken(token: string): Promise<RefreshTokenPayload | null> {
    try {
      const { payload } = await jwtVerify(token, refreshSecret, { issuer: TOKEN_ISSUER });
      if (payload.type !== 'refresh' || typeof payload.userId !== 'string') return null;
      return payload as RefreshTokenPayload;
    } catch {
      return null;
    }
  }
}
