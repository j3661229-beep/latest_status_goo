// src/modules/daily-content/daily-content.route.ts
import { FastifyInstance } from 'fastify';
import { getTodayContent } from './daily-content.service';

export async function dailyContentRoutes(fastify: FastifyInstance) {
  // Public endpoint for Today's Panchang & Suvichar
  fastify.get('/today', async (_req, reply) => {
    const data = getTodayContent();
    return reply.send({ data });
  });

  // Public endpoint for Scheme Eligibility Checker (also available via /schemes/check-eligibility)
  fastify.get('/status-quote', async (_req, reply) => {
    const data = getTodayContent();
    return reply.send({
      data: {
        suvichar: data.suvichar,
        panchang: data.panchang,
        timestamp: new Date().toISOString(),
      },
    });
  });
}
