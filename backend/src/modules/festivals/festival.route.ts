// src/modules/festivals/festival.route.ts
import { FastifyInstance } from 'fastify';
import { CacheService } from '../../lib/cache/cache.service';
import { CK, TTL } from '../../lib/cache/keys';
import { clampInt } from '../../lib/http/validation';

export async function festivalRoutes(fastify: FastifyInstance) {
  const cache = new CacheService(fastify.redis);

  // GET /festivals/upcoming?days=30
  fastify.get('/upcoming', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const daysAhead = clampInt((req.query as any)?.days, 30, 1, 365);
    const cacheKey = CK.festivals(daysAhead);

    const cached = await cache.get(cacheKey);
    if (cached) return reply.send(cached);

    const futureDate = new Date(Date.now() + daysAhead * 24 * 60 * 60 * 1000);

    const data = await fastify.prisma.festival.findMany({
      where: {
        isActive: true,
        date: { gte: new Date(), lte: futureDate },
      },
      include: { category: true },
      orderBy: { date: 'asc' },
    });

    const result = { data };
    // Admin festival edits invalidate `festivals:upcoming:*`
    await cache.set(cacheKey, result, TTL.festivals);
    return reply.send(result);
  });
}
