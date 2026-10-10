// src/lib/auth/token.store.ts
// Stores hashed refresh tokens in Redis
// Pattern from §LLD-01: SHA-256 hash, not plaintext

import type { Redis } from 'ioredis';
import { createHash, timingSafeEqual } from 'crypto';

const TTL_30_DAYS = 60 * 60 * 24 * 30; // seconds
// After a successful rotation the old token keeps resolving to the *same* new pair
// for a few seconds, so two concurrent refreshes (e.g. parallel app requests)
// don't log the user out — but they also never mint two different token pairs.
const ROTATION_GRACE_SECONDS = 10;

/**
 * Atomic compare-and-delete: deletes KEYS[1] only when it equals ARGV[1].
 * Returns 1 when this caller won the rotation, 0 otherwise.
 * (The in-memory Redis fallback implements this exact script.)
 */
export const CAS_DEL_SCRIPT =
  "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end";

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export class RefreshTokenStore {
  constructor(private redis: Redis) {}

  async save(userId: string, token: string): Promise<void> {
    const key = `rt:${userId}`;
    const hashed = hashToken(token);
    await this.redis.setex(key, TTL_30_DAYS, hashed);
  }

  async validate(userId: string, token: string): Promise<boolean> {
    const key = `rt:${userId}`;
    const stored = await this.redis.get(key);
    if (!stored) return false;

    const incoming = hashToken(token);
    // Constant-time comparison to prevent timing attacks
    try {
      return timingSafeEqual(Buffer.from(stored, 'hex'), Buffer.from(incoming, 'hex'));
    } catch {
      return false;
    }
  }

  /**
   * Atomically consume the current refresh token. Exactly one concurrent caller
   * presenting the stored token gets `true`.
   */
  async consume(userId: string, token: string): Promise<boolean> {
    const result = await this.redis.eval(CAS_DEL_SCRIPT, 1, `rt:${userId}`, hashToken(token));
    return Number(result) === 1;
  }

  /** Remember the pair issued for `oldToken` so a racing duplicate refresh gets the same pair. */
  async rememberRotation(oldToken: string, pair: TokenPair): Promise<void> {
    await this.redis.setex(`rt:grace:${hashToken(oldToken)}`, ROTATION_GRACE_SECONDS, JSON.stringify(pair));
  }

  async getRotation(oldToken: string): Promise<TokenPair | null> {
    const raw = await this.redis.get(`rt:grace:${hashToken(oldToken)}`);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as TokenPair;
    } catch {
      return null;
    }
  }

  async invalidate(userId: string): Promise<void> {
    await this.redis.del(`rt:${userId}`);
  }
}
