// src/plugins/redis.plugin.ts
import fp from 'fastify-plugin';
import { FastifyPluginAsync } from 'fastify';
import Redis from 'ioredis';
import { env } from '../config/env';

const redisPlugin: FastifyPluginAsync = async (fastify) => {
  const redis = new Redis(env.REDIS_URL, {
    maxRetriesPerRequest: 3,
    enableReadyCheck: true,
    reconnectOnError: (err) => {
      const targetError = 'READONLY';
      return err.message.includes(targetError);
    },
    lazyConnect: false,
  });

  redis.on('connect', () => fastify.log.info('✅ Redis connected'));
  redis.on('error', (err) => fastify.log.error({ err }, 'Redis error'));
  redis.on('reconnecting', () => fastify.log.warn('Redis reconnecting...'));

  fastify.decorate('redis', redis);

  fastify.addHook('onClose', async () => {
    await redis.quit();
  });
};

export default fp(redisPlugin, { name: 'redis' });
