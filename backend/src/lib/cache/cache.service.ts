// src/lib/cache/cache.service.ts
import type { Redis } from 'ioredis';
import { CK } from './keys';

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

  // Scan and delete by pattern (safe for production — no KEYS command).
  // Works against the in-memory fallback too (it implements SCAN).
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

  /**
   * Invalidate every cache that can contain template data after any change to a
   * template's status / flags: lists, featured/trending/new, home feeds, search
   * results, admin stats and (optionally) the template's own detail entry.
   */
  async invalidateTemplateCache(templateId?: string): Promise<void> {
    const patterns = ['tpl:list:*', 'tpl:new:*', 'home:feed:*', 'search:q:*', 'suggest:*'];
    const keys: string[] = [CK.featured, CK.trending, CK.adminStats];
    if (templateId) keys.push(CK.templateById(templateId));

    try {
      await this.delMany(keys);
      for (const pattern of patterns) {
        await this.invalidatePattern(pattern);
      }
    } catch {
      // Cache invalidation must never fail the request; TTLs bound staleness.
    }
  }
}
