// src/modules/templates/template.handler.ts
import { FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient, Prisma, SharePlatform, Language, TemplateType } from '@prisma/client';
import type { Redis } from 'ioredis';
import { z } from 'zod';
import { TemplateService } from './template.service';
import { CK, TTL } from '../../lib/cache/keys';
import { CacheService } from '../../lib/cache/cache.service';
import { emptyToUndefined, optionalBoolString, optionalString, parsePagination, clampInt, sendValidationError } from '../../lib/http/validation';

const ADMIN_ROLES = ['MANAGER', 'SUPER_ADMIN'];
const PAID_PLANS = ['PREMIUM', 'ANNUAL'];

/** Case-insensitive optional enum query param ('' → not provided). */
const upperEnum = <T extends Record<string, string>>(e: T) =>
  z.preprocess(
    (v) => (typeof v === 'string' ? v.trim().toUpperCase() || undefined : emptyToUndefined(v)),
    z.nativeEnum(e).optional(),
  );

const ListQuerySchema = z.object({
  lang: upperEnum(Language),
  cat: optionalString(64),
  type: upperEnum(TemplateType),
  isPremium: optionalBoolString,
});

const NewQuerySchema = z.object({
  lang: upperEnum(Language),
  type: upperEnum(TemplateType),
});

const ShareBodySchema = z.object({
  platform: z.nativeEnum(SharePlatform),
});

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
  videoUrl: true,
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
  fitMode: true,
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
    const q = req.query as any;
    // Bound user-controlled values that end up in the cache key / query
    const state = typeof q.state === 'string' && q.state.trim() ? q.state.trim().slice(0, 100) : 'all';
    const lang = typeof q.lang === 'string' && q.lang.trim() ? q.lang.trim().toUpperCase().slice(0, 20) : 'HINDI';
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

    let featuredList = featured;
    let trendingList = trending;

    // Fallback: If no templates are explicitly tagged featured or trending, show recent approved templates
    if (featuredList.length === 0 && trendingList.length === 0) {
      const recentApproved = await this.prisma.template.findMany({
        where: { status: 'APPROVED' },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
        take: 20,
        select: templateSelect,
      });
      featuredList = recentApproved;
      trendingList = recentApproved;
    } else if (featuredList.length === 0) {
      featuredList = trendingList;
    } else if (trendingList.length === 0) {
      trendingList = featuredList;
    }

    const result = {
      featured: featuredList,
      trending: trendingList,
      coordinatorPicks,
      festivalToday,
      categories,
    };
    await this.cache.set(cacheKey, result, TTL.homeFeed);
    return reply.send(result);
  }

  // GET /templates
  async list(req: FastifyRequest, reply: FastifyReply) {
    const parsed = ListQuerySchema.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid query');
    const { page, limit } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });
    const result = await this.service.list({
      lang: parsed.data.lang,
      categoryId: parsed.data.cat,
      type: parsed.data.type,
      page,
      limit,
      isPremium: parsed.data.isPremium,
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
    const parsed = NewQuerySchema.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid query');
    const page = clampInt((req.query as any)?.page, 1, 1, 1000);
    const result = await this.service.getNew(parsed.data.type, parsed.data.lang, page);
    return reply.send(result);
  }

  // GET /templates/:id
  async getById(req: FastifyRequest, reply: FastifyReply) {
    const { id } = req.params as { id: string };
    const template = (await this.service.getById(id)) as any;
    if (!template) return reply.status(404).send({ error: 'Template not found' });

    const user = req.user as { userId?: string; role?: string; plan?: string } | undefined;
    const isAdmin = !!user?.role && ADMIN_ROLES.includes(user.role);
    const isOwner = !!user?.userId && user.userId === template.creatorId;

    // Unpublished templates are only visible to their creator and to admins
    if (template.status !== 'APPROVED' && !isAdmin && !isOwner) {
      return reply.status(404).send({ error: 'Template not found' });
    }

    // Premium templates stay visible (thumbnail, metadata, media URLs are kept for
    // backward compatibility with the current app) but are flagged so clients can
    // gate editing/sharing behind the paywall. `user.plan` is the live DB plan.
    const isLocked = !!template.isPremium && !isAdmin && !isOwner && !PAID_PLANS.includes(user?.plan ?? 'FREE');

    return reply.send({ ...template, isLocked });
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
    const parsed = ShareBodySchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid platform');
    const { platform } = parsed.data;
    const userId = (req.user as any)?.userId;

    if (userId) {
      try {
        await this.prisma.shareHistory.create({
          data: { userId, templateId: id, platform },
        });
      } catch (err) {
        // Unknown template id → foreign key violation
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2003') {
          return reply.status(404).send({ error: 'Template not found' });
        }
        throw err;
      }
    }
    this.prisma.template.update({
      where: { id },
      data: { shareCount: { increment: 1 } },
    }).catch(() => {});

    return reply.send({ success: true });
  }
}
