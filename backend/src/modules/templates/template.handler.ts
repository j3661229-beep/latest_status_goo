// src/modules/templates/template.handler.ts
import { FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient, SharePlatform } from '@prisma/client';
import type { Redis } from 'ioredis';
import { TemplateService } from './template.service';
import { CK, TTL } from '../../lib/cache/keys';
import { CacheService } from '../../lib/cache/cache.service';

// Reusable Prisma select for template list items (avoids over-fetching)
const templateSelect = {
  id: true,
  type: true,
  status: true,
  nameHi: true,
  nameMr: true,
  nameEn: true,
  quoteHi: true,
  quoteMr: true,
  quoteEn: true,
  imageUrl: true,
  imageThumbUrl: true,
  videoThumbUrl: true,
  gradient: true,
  tags: true,
  isFeatured: true,
  isTrending: true,
  isPremium: true,
  isNew: true,
  isCoordinatorPick: true,
  useCount: true,
  shareCount: true,
  primaryLanguage: true,
  photoZoneEnabled: true,
  photoZoneX: true,
  photoZoneY: true,
  photoZoneSize: true,
  photoZoneShape: true,
  nameZoneEnabled: true,
  nameZoneX: true,
  nameZoneY: true,
  nameFontSize: true,
  nameColor: true,
  nameFont: true,
  category: { select: { id: true, slug: true, nameHi: true, nameEn: true, emoji: true } },
} as const;

export class TemplateHandler {
  private service: TemplateService;
  private prisma: PrismaClient;
  private cache: CacheService;

  constructor(prisma: PrismaClient, redis: Redis) {
    this.service = new TemplateService(prisma, redis);
    this.prisma = prisma;
    this.cache = new CacheService(redis);
  }

  // GET /templates/home?state=&lang=
  async getHomeFeed(req: FastifyRequest, reply: FastifyReply) {
    const { state = 'all', lang = 'HINDI' } = req.query as any;
    const cacheKey = CK.homeFeed(state, lang);
    const cached = await this.cache.get(cacheKey);
    if (cached) return reply.send(cached);

    const [featured, trending, coordinatorPicks, festivalToday, categories] = await Promise.all([
      // Featured: isFeatured=true, max 10
      this.prisma.template.findMany({
        where: { status: 'APPROVED', isFeatured: true },
        orderBy: [{ sortOrder: 'asc' }, { useCount: 'desc' }],
        take: 10,
        select: templateSelect,
      }),
      // Trending: high use count, max 15
      this.prisma.template.findMany({
        where: { status: 'APPROVED', isTrending: true },
        orderBy: { useCount: 'desc' },
        take: 15,
        select: templateSelect,
      }),
      // Coordinator picks: those with null state (all users) OR matching user's state
      this.prisma.template.findMany({
        where: {
          status: 'APPROVED',
          isCoordinatorPick: true,
          ...(state && state !== 'all'
            ? { OR: [{ coordinatorState: null }, { coordinatorState: state }] }
            : { coordinatorState: null }),
        },
        orderBy: { sortOrder: 'asc' },
        take: 8,
        select: { ...templateSelect, coordinatorNote: true },
      }),
      // Festival today or tomorrow
      this.prisma.festival.findFirst({
        where: {
          isActive: true,
          date: {
            gte: new Date(new Date().setHours(0, 0, 0, 0)),
            lt: new Date(new Date().setHours(0, 0, 0, 0) + 2 * 86400000),
          },
        },
        orderBy: { date: 'asc' },
      }),
      // Categories
      this.prisma.category.findMany({
        where: { isActive: true },
        orderBy: { sortOrder: 'asc' },
        take: 12,
        select: { id: true, slug: true, nameHi: true, nameEn: true, nameMr: true, emoji: true, gradient: true, templateCount: true },
      }),
    ]);

    const result = { featured, trending, coordinatorPicks, festivalToday, categories };
    await this.cache.set(cacheKey, result, TTL.homeFeed);
    return reply.send(result);
  }

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
