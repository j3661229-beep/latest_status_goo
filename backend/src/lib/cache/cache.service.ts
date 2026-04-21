// src/lib/cache/cache.service.ts
import type { Redis } from 'ioredis';

export class CacheService {
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    const value = await this.redis.get(key);
    if (!value) return null;
    try {
      return JSON.parse(value) as T;
    } catch {
      return null;
    }
  }

  async set(key: string, value: unknown, ttlSeconds: number): Promise<void> {
    await this.redis.setex(key, ttlSeconds, JSON.stringify(value));
  }

  async del(key: string): Promise<void> {
    await this.redis.del(key);
  }

  async delMany(keys: string[]): Promise<void> {
    if (keys.length === 0) return;
    await this.redis.del(...keys);
  }

  // Scan and delete by pattern (safe for production — no KEYS command)
  async invalidatePattern(pattern: string): Promise<number> {
    let cursor = '0';
    let totalDeleted = 0;

    do {
      const [nextCursor, keys] = await this.redis.scan(
        cursor,
        'MATCH',
        pattern,
        'COUNT',
        '100'
      );
      cursor = nextCursor;
      if (keys.length > 0) {
        await this.redis.del(...keys);
        totalDeleted += keys.length;
      }
    } while (cursor !== '0');

    return totalDeleted;
  }

  // Invalidate all template list caches after any admin action
  async invalidateTemplateCache(): Promise<void> {
    const patterns = ['tpl:list:*', 'tpl:featured', 'tpl:trending', 'tpl:new'];
    for (const pattern of patterns) {
      await this.invalidatePattern(pattern);
    }
  }

  // Sliding window rate limiter (100 req/min per IP by default)
  async checkRateLimit(
    key: string,
    windowMs = 60_000,
    limit = 100
  ): Promise<{ allowed: boolean; remaining: number }> {
    const now = Date.now();
    const windowStart = now - windowMs;

    const pipe = this.redis.pipeline();
    pipe.zremrangebyscore(key, '-inf', windowStart);
    pipe.zadd(key, now, `${now}-${Math.random()}`);
    pipe.zcard(key);
    pipe.expire(key, Math.ceil(windowMs / 1000));

    const results = await pipe.exec();
    const count = (results?.[2]?.[1] as number) ?? 0;

    return {
      allowed: count <= limit,
      remaining: Math.max(0, limit - count),
    };
  }
}
