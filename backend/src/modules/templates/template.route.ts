// src/modules/templates/template.route.ts
import { FastifyInstance } from 'fastify';
import { TemplateHandler } from './template.handler';

export async function templateRoutes(fastify: FastifyInstance) {
  const handler = new TemplateHandler(fastify.prisma, fastify.redis);

  // GET /templates/home — single call home feed (featured + trending + coordinator picks)
  fastify.get('/home', { preHandler: [fastify.authenticate] }, handler.getHomeFeed.bind(handler));

  // Public + authenticated list endpoints
  fastify.get('/', { preHandler: [fastify.authenticate] }, handler.list.bind(handler));
  fastify.get('/featured', { preHandler: [fastify.authenticate] }, handler.featured.bind(handler));
  fastify.get('/trending', { preHandler: [fastify.authenticate] }, handler.trending.bind(handler));
  fastify.get('/new', { preHandler: [fastify.authenticate] }, handler.newTemplates.bind(handler));
  fastify.get('/:id', { preHandler: [fastify.authenticate] }, handler.getById.bind(handler));

  // Engagement tracking (fire-and-forget, no meaningful response)
  fastify.post('/:id/view', { preHandler: [fastify.authenticate] }, handler.recordView.bind(handler));
  fastify.post('/:id/use', { preHandler: [fastify.authenticate] }, handler.recordUse.bind(handler));
  fastify.post('/:id/share', { preHandler: [fastify.authenticate] }, handler.recordShare.bind(handler));
}
