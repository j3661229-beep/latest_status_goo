// src/plugins/redis.plugin.ts
import fp from 'fastify-plugin';
import { FastifyPluginAsync } from 'fastify';
import Redis from 'ioredis';
import { env } from '../config/env';

class MemoryRedis {
  private store = new Map<string, { value: string; expiry?: number }>();

  async get(key: string): Promise<string | null> {
    const item = this.store.get(key);
    if (!item) return null;
    if (item.expiry && Date.now() > item.expiry) {
      this.store.delete(key);
      return null;
    }
    return item.value;
  }

  async set(key: string, value: string): Promise<'OK'> {
    this.store.set(key, { value });
    return 'OK';
  }

  async setex(key: string, seconds: number, value: string): Promise<'OK'> {
    this.store.set(key, { value, expiry: Date.now() + seconds * 1000 });
    return 'OK';
  }

  async del(...keys: string[]): Promise<number> {
    let count = 0;
    for (const k of keys) {
      if (this.store.delete(k)) count++;
    }
    return count;
  }

  async expire(key: string, seconds: number): Promise<number> {
    const item = this.store.get(key);
    if (!item) return 0;
    item.expiry = Date.now() + seconds * 1000;
    return 1;
  }

  async keys(pattern: string): Promise<string[]> {
    const regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
    const now = Date.now();
    const result: string[] = [];
    for (const [key, item] of this.store.entries()) {
      if (item.expiry && now > item.expiry) {
        this.store.delete(key);
        continue;
      }
      if (regex.test(key)) result.push(key);
    }
    return result;
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

