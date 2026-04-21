// src/modules/festivals/festival.route.ts
import { FastifyInstance } from 'fastify';
import { CacheService } from '../../lib/cache/cache.service';
import { CK, TTL } from '../../lib/cache/keys';

export async function festivalRoutes(fastify: FastifyInstance) {
  const cache = new CacheService(fastify.redis);

  // GET /festivals/upcoming
  fastify.get('/upcoming', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { days = '30' } = req.query as any;

    const cached = await cache.get(CK.festivals);
    if (cached) return reply.send(cached);

    const daysAhead = Math.min(parseInt(days), 365);
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
    await cache.set(CK.festivals, result, TTL.festivals);
    return reply.send(result);
  });
}
