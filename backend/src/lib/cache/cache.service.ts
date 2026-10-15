// src/lib/cache/cache.service.ts
import type { Redis } from 'ioredis';
import { CK } from './keys';

let lastWarn = 0;
function warnOnce(op: string, err: unknown) {
  // Rate-limited: a Redis outage must be visible, not a log flood.
  if (Date.now() - lastWarn < 60_000) return;
  lastWarn = Date.now();
  console.warn(`[cache] ${op} failed, degrading to uncached: ${(err as Error)?.message ?? err}`);
}

/**
 * Read/write-through cache over Redis. A cache is an optimisation, never a dependency: every operation
 * degrades to a miss / no-op when Redis errors, so a Redis blip slows the API down instead of 500-ing it.
 * (Security-sensitive state — sessions, OTPs, webhook idempotency — uses Redis directly and fails closed.)
 */
export class CacheService {
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    let value: string | null;
    try {
      value = await this.redis.get(key);
    } catch (err) {
      warnOnce('get', err);
      return null;
    }
    if (!value) return null;
    try {
      return JSON.parse(value) as T;
    } catch {
      return null;
    }
  }

  async set(key: string, value: unknown, ttlSeconds: number): Promise<void> {
    try {
      await this.redis.setex(key, ttlSeconds, JSON.stringify(value));
    } catch (err) {
      warnOnce('set', err);
    }
  }

  async del(key: string): Promise<void> {
    try {
      await this.redis.del(key);
    } catch (err) {
      warnOnce('del', err);
    }
  }

  async delMany(keys: string[]): Promise<void> {
    if (keys.length === 0) return;
    try {
      await this.redis.del(...keys);
    } catch (err) {
      warnOnce('delMany', err);
    }
  }

  // Scan and delete by pattern (safe for production — no KEYS command).
  // Works against the in-memory fallback too (it implements SCAN).
  async invalidatePattern(pattern: string): Promise<number> {
    let cursor = '0';
    let totalDeleted = 0;

    try {
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
    } catch (err) {
      warnOnce('invalidatePattern', err);
    }

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
