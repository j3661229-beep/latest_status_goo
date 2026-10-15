// src/modules/search/search.route.ts
import { FastifyInstance } from 'fastify';
import { SearchService } from './search.service';
import { parsePagination } from '../../lib/http/validation';

export async function searchRoutes(fastify: FastifyInstance) {
  const service = new SearchService(fastify.prisma, fastify.redis);

  fastify.get('/', { 
    config: { rateLimit: { max: 60, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { q, lang, type } = req.query as any;
    if (typeof q !== 'string' || q.trim().length < 2) {
      return reply.status(400).send({ error: 'Query must be at least 2 characters' });
    }
    if (q.length > 100) {
      return reply.status(400).send({ error: 'Query too long (max 100 characters)' });
    }
    const { page, limit } = parsePagination(req.query, { defaultLimit: 30, maxLimit: 50 });
    const safeLang = typeof lang === 'string' ? lang.slice(0, 20) : undefined;
    const result = await service.search(q, safeLang, typeof type === 'string' ? type.toUpperCase() : undefined, page, limit);
    return reply.send(result);
  });

  fastify.get('/suggestions', { config: { rateLimit: { max: 60, timeWindow: '1 minute' } } }, async (req, reply) => {
    const { q } = req.query as { q?: string };
    if (typeof q !== 'string' || q.trim().length < 2) return reply.send({ suggestions: [] });
    if (q.length > 100) return reply.status(400).send({ error: 'Query too long (max 100 characters)' });
    const suggestions = await service.getSuggestions(q);
    return reply.send({ suggestions });
  });

  fastify.get('/trending', { config: { rateLimit: { max: 30, timeWindow: '1 minute' } } }, async (_req, reply) => {
    const terms = await service.getTrendingTerms();
    return reply.send({ terms });
  });
}
