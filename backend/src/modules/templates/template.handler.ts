// src/modules/templates/template.handler.ts
import { FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient, SharePlatform } from '@prisma/client';
import type { Redis } from 'ioredis';
import { TemplateService } from './template.service';

export class TemplateHandler {
  private service: TemplateService;

  constructor(prisma: PrismaClient, redis: Redis) {
    this.service = new TemplateService(prisma, redis);
    this.prisma = prisma;
  }

  private prisma: PrismaClient;

  // GET /templates
  async list(req: FastifyRequest, reply: FastifyReply) {
    const { lang, cat, type, page = '1', limit = '20', isPremium } = req.query as any;
    const result = await this.service.list({
      lang,
      categoryId: cat,
      type,
      page: parseInt(page),
      limit: parseInt(limit),
      isPremium: isPremium === 'true' ? true : isPremium === 'false' ? false : undefined,
    });
    return reply.send(result);
  }

  // GET /templates/featured
  async featured(_req: FastifyRequest, reply: FastifyReply) {
    const data = await this.service.getFeatured();
    return reply.send({ data });
  }

  // GET /templates/trending
  async trending(_req: FastifyRequest, reply: FastifyReply) {
    const data = await this.service.getTrending();
    return reply.send({ data });
  }

  // GET /templates/new
  async newTemplates(req: FastifyRequest, reply: FastifyReply) {
    const { type, lang, page = '1' } = req.query as any;
    const result = await this.service.getNew(type, lang, parseInt(page));
    return reply.send(result);
  }

  // GET /templates/:id
  async getById(req: FastifyRequest, reply: FastifyReply) {
    const { id } = req.params as { id: string };
    const template = await this.service.getById(id);
    if (!template) return reply.status(404).send({ error: 'Template not found' });
    return reply.send(template);
  }

  // POST /templates/:id/view
  async recordView(req: FastifyRequest, reply: FastifyReply) {
    const { id } = req.params as { id: string };
    const userId = (req.user as any)?.userId;
    // Fire and forget — don't await
    this.prisma.template.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
    }).catch(() => {});
    if (userId) {
      this.prisma.analyticsEvent.create({
        data: { event: 'template_view', userId, templateId: id },
      }).catch(() => {});
    }
    return reply.status(200).send();
  }

  // POST /templates/:id/use
  async recordUse(req: FastifyRequest, reply: FastifyReply) {
    const { id } = req.params as { id: string };
    const userId = (req.user as any)?.userId;
    this.prisma.template.update({
      where: { id },
      data: { useCount: { increment: 1 } },
    }).catch(() => {});
    if (userId) {
      this.prisma.analyticsEvent.create({
        data: { event: 'template_use', userId, templateId: id },
      }).catch(() => {});
    }
    return reply.status(200).send();
  }

  // POST /templates/:id/share
  async recordShare(req: FastifyRequest, reply: FastifyReply) {
    const { id } = req.params as { id: string };
    const { platform } = req.body as { platform: SharePlatform };
    const userId = (req.user as any)?.userId;

    if (userId) {
      await this.prisma.shareHistory.create({
        data: { userId, templateId: id, platform },
      });
    }
    this.prisma.template.update({
      where: { id },
      data: { shareCount: { increment: 1 } },
    }).catch(() => {});

    return reply.send({ success: true });
  }
}
