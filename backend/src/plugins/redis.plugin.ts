// src/plugins/redis.plugin.ts
import fp from 'fastify-plugin';
import { FastifyPluginAsync } from 'fastify';
import Redis from 'ioredis';
import { env } from '../config/env';
import { CAS_DEL_SCRIPT } from '../lib/auth/token.store';

const MEMORY_MAX_KEYS = 10_000;

/** Convert a Redis glob pattern (*, ?) into an anchored RegExp. */
function globToRegex(pattern: string): RegExp {
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  return new RegExp('^' + escaped.replace(/\*/g, '.*').replace(/\?/g, '.') + '$');
}

/**
 * Minimal in-process stand-in used while Redis is unreachable.
 * Implements only the commands the API uses; bounded to MEMORY_MAX_KEYS entries
 * (oldest-inserted keys are evicted first).
 */
export class MemoryRedis {
  private store = new Map<string, { value: string; expiry?: number }>();

  private live(key: string) {
    const item = this.store.get(key);
    if (!item) return undefined;
    if (item.expiry && Date.now() > item.expiry) {
      this.store.delete(key);
      return undefined;
    }
    return item;
  }

  private write(key: string, value: string, expiry?: number) {
    // Re-insert so Map order reflects recency of writes
    this.store.delete(key);
    this.store.set(key, { value, expiry });
    while (this.store.size > MEMORY_MAX_KEYS) {
      const oldest = this.store.keys().next().value;
      if (oldest === undefined) break;
      this.store.delete(oldest);
    }
  }

  async get(key: string): Promise<string | null> {
    return this.live(key)?.value ?? null;
  }

  // Supports: set(key, value [, 'EX', seconds | 'PX', ms] [, 'NX' | 'XX'])
  async set(key: string, value: string | number, ...args: (string | number)[]): Promise<'OK' | null> {
    let expiry: number | undefined;
    let nx = false;
    let xx = false;
    for (let i = 0; i < args.length; i++) {
      const flag = String(args[i]).toUpperCase();
      if (flag === 'EX') expiry = Date.now() + Number(args[++i]) * 1000;
      else if (flag === 'PX') expiry = Date.now() + Number(args[++i]);
      else if (flag === 'NX') nx = true;
      else if (flag === 'XX') xx = true;
    }
    const exists = this.live(key) !== undefined;
    if ((nx && exists) || (xx && !exists)) return null;
    this.write(key, String(value), expiry);
    return 'OK';
  }

  async setex(key: string, seconds: number, value: string): Promise<'OK'> {
    this.write(key, value, Date.now() + seconds * 1000);
    return 'OK';
  }

  async incr(key: string): Promise<number> {
    const item = this.live(key);
    const next = (item ? parseInt(item.value, 10) || 0 : 0) + 1;
    if (item) item.value = String(next);
    else this.write(key, String(next));
    return next;
  }

  async del(...keys: string[]): Promise<number> {
    let count = 0;
    for (const k of keys.flat()) {
      if (this.store.delete(k)) count++;
    }
    return count;
  }

  async expire(key: string, seconds: number): Promise<number> {
    const item = this.live(key);
    if (!item) return 0;
    item.expiry = Date.now() + seconds * 1000;
    return 1;
  }

  async ttl(key: string): Promise<number> {
    const item = this.live(key);
    if (!item) return -2;
    if (!item.expiry) return -1;
    return Math.max(0, Math.ceil((item.expiry - Date.now()) / 1000));
  }

  async keys(pattern: string): Promise<string[]> {
    const regex = globToRegex(pattern);
    const result: string[] = [];
    for (const key of Array.from(this.store.keys())) {
      if (this.live(key) && regex.test(key)) result.push(key);
    }
    return result;
  }

  // Single-pass SCAN: returns every match with cursor '0'
  async scan(_cursor: string | number, ...args: (string | number)[]): Promise<[string, string[]]> {
    let pattern = '*';
    for (let i = 0; i < args.length; i++) {
      if (String(args[i]).toUpperCase() === 'MATCH') pattern = String(args[++i]);
    }
    return ['0', await this.keys(pattern)];
  }

  // Only the refresh-token compare-and-delete script is supported.
  async eval(script: string, numKeys: number, ...args: (string | number)[]): Promise<number> {
    if (script !== CAS_DEL_SCRIPT || numKeys !== 1) {
      throw new Error('MemoryRedis.eval: unsupported script');
    }
    const [key, expected] = args.map(String);
    const item = this.live(key);
    if (item && item.value === expected) {
      this.store.delete(key);
      return 1;
    }
    return 0;
  }

  async quit(): Promise<'OK'> {
    this.store.clear();
    return 'OK';
  }
}

const redisPlugin: FastifyPluginAsync = async (fastify) => {
  const memoryFallback = new MemoryRedis();
  let isRedisConnected = false;

  const redis = new Redis(env.REDIS_URL, {
    maxRetriesPerRequest: 1,
    enableReadyCheck: false,
    lazyConnect: true,
    connectTimeout: 3000,
    retryStrategy: (times) => {
      if (times > 2) {
        fastify.log.warn('⚠️ Redis unavailable — falling back to fast in-memory cache');
        return null;
      }
      return 1000;
    },
  });

  redis.on('connect', () => {
    isRedisConnected = true;
    fastify.log.info('✅ Redis connected');
  });

  redis.on('error', (err) => {
    isRedisConnected = false;
    // Log as warning rather than flooding errors
    fastify.log.warn(`Redis connection note: ${err.message}. Using fallback cache.`);
  });

  // Try initial connect in background without blocking server startup
  redis.connect().catch(() => {
    fastify.log.warn('Redis not reachable at start, using fast in-memory cache.');
  });

  // Transparent proxy: uses real Redis when connected, falls back to memory cache
  const client = new Proxy(redis, {
    get(target: any, prop: string) {
      if (!isRedisConnected && prop in memoryFallback) {
        return (memoryFallback as any)[prop].bind(memoryFallback);
      }
      const val = target[prop];
      if (typeof val === 'function') {
        return (...args: any[]) => {
          if (!isRedisConnected && prop in memoryFallback) {
            return (memoryFallback as any)[prop](...args);
          }
          return val.apply(target, args);
        };
      }
      return val;
    },
  });

  fastify.decorate('redis', client as unknown as Redis);

  fastify.addHook('onClose', async () => {
    try {
      await redis.quit();
    } catch {
      await memoryFallback.quit();
    }
  });
};

export default fp(redisPlugin, { name: 'redis' });

