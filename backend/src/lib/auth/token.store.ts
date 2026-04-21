// src/lib/auth/token.store.ts
// Stores hashed refresh tokens in Redis
// Pattern from §LLD-01: SHA-256 hash, not plaintext

import type { Redis } from 'ioredis';
import { createHash, timingSafeEqual } from 'crypto';

const TTL_30_DAYS = 60 * 60 * 24 * 30; // seconds

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
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

  async invalidate(userId: string): Promise<void> {
    await this.redis.del(`rt:${userId}`);
  }
}
