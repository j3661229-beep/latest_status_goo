// src/modules/search/search.route.ts
import { FastifyInstance } from 'fastify';
import { SearchService } from './search.service';

export async function searchRoutes(fastify: FastifyInstance) {
  const service = new SearchService(fastify.prisma, fastify.redis);

  fastify.get('/', { 
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 60, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { q, lang, type, page = '1' } = req.query as any;
    if (!q || q.length < 2) {
      return reply.status(400).send({ error: 'Query must be at least 2 characters' });
    }
    if (q.length > 100) {
      return reply.status(400).send({ error: 'Query too long (max 100 characters)' });
    }
    const result = await service.search(q, lang, type, parseInt(page));
    return reply.send(result);
  });

  fastify.get('/suggestions', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { q } = req.query as { q?: string };
    if (!q || q.length < 2) return reply.send({ suggestions: [] });
    const suggestions = await service.getSuggestions(q);
    return reply.send({ suggestions });
  });

  fastify.get('/trending', { preHandler: [fastify.authenticate] }, async (_req, reply) => {
    const terms = await service.getTrendingTerms();
    return reply.send({ terms });
  });
}
