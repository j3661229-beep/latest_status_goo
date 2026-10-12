// src/modules/admin/admin.route.ts
import { FastifyInstance, FastifyRequest } from 'fastify';
import { Prisma, TemplateStatus, Plan, UserRole, NotifType } from '@prisma/client';
import { z } from 'zod';
import { CacheService } from '../../lib/cache/cache.service';
import { CK } from '../../lib/cache/keys';
import { OneSignalService } from '../../lib/notification/onesignal.service';
import { RefreshTokenStore } from '../../lib/auth/token.store';
import { invalidateUserCaches, safeUserSelect, userSummarySelect } from '../../lib/auth/auth-state';
import {
  clampInt, dateString, optionalBoolString, optionalEnum, optionalString,
  parsePagination, sendValidationError,
} from '../../lib/http/validation';

const ADMIN_ROLES = ['MANAGER', 'SUPER_ADMIN'];
const PAID_PLANS: Plan[] = ['PREMIUM', 'ANNUAL'];
const DAY_MS = 24 * 60 * 60 * 1000;

// ── Query / body schemas ─────────────────────────────────────
const TEMPLATE_SORT_FIELDS = [
  'createdAt', 'updatedAt', 'submittedAt', 'reviewedAt', 'sortOrder',
  'useCount', 'shareCount', 'saveCount', 'viewCount', 'downloadCount',
] as const;
const USER_SORT_FIELDS = [
  'createdAt', 'updatedAt', 'lastActiveAt', 'name', 'planExpiresAt',
  'streakCount', 'totalShares', 'totalSaves',
] as const;

const TemplateListQuery = z.object({
  status: optionalEnum(['DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'ARCHIVED']),
  type: optionalEnum(['IMAGE', 'VIDEO']),
  categoryId: optionalString(64),
  isPremium: optionalBoolString,
  isFeatured: optionalBoolString,
  search: optionalString(100),
  sortBy: optionalEnum([...TEMPLATE_SORT_FIELDS]),
  sortOrder: optionalEnum(['asc', 'desc']),
});

const UserListQuery = z.object({
  search: optionalString(100),
  plan: optionalEnum(['FREE', 'PREMIUM', 'ANNUAL']),
  language: optionalEnum(['HINDI', 'MARATHI', 'ENGLISH', 'GUJARATI', 'PUNJABI', 'TAMIL', 'TELUGU']),
  role: optionalEnum(['USER', 'CREATOR', 'MANAGER', 'SUPER_ADMIN']),
  isActive: optionalBoolString,
  sortBy: optionalEnum([...USER_SORT_FIELDS]),
});

const CreatorListQuery = z.object({
  isVerified: optionalBoolString,
  isSuspended: optionalBoolString,
});

const AuditLogQuery = z.object({
  action: optionalString(64),
  entityType: optionalString(64),
});

const TemplatePatchSchema = z.object({
  sortOrder: z.number().int().min(-100000).max(100000).optional(),
  isPremium: z.boolean().optional(),
  isFeatured: z.boolean().optional(),
  isTrending: z.boolean().optional(),
  tags: z.array(z.string().trim().min(1).max(50)).max(30).optional(),
});

const UserPatchSchema = z.object({
  plan: z.nativeEnum(Plan).optional(),
  role: z.nativeEnum(UserRole).optional(),
  isActive: z.boolean().optional(),
  planExpiresAt: dateString.nullable().optional(),
});

const CreatorPatchSchema = z.object({
  isVerified: z.boolean().optional(),
  isSuspended: z.boolean().optional(),
  suspendedReason: z.string().max(500).nullable().optional(),
});

const FestivalCreateSchema = z.object({
  nameHi: z.string().trim().min(1).max(100),
  nameMr: z.string().trim().min(1).max(100),
  nameEn: z.string().trim().min(1).max(100),
  emoji: z.string().min(1).max(16),
  date: dateString,
  notifyDaysBefore: z.number().int().min(0).max(30).optional(),
  isRecurring: z.boolean().optional(),
  categoryId: z.string().max(64).nullable().optional(),
});

const FestivalUpdateSchema = z.object({
  nameHi: z.string().trim().min(1).max(100).optional(),
  nameMr: z.string().trim().min(1).max(100).optional(),
  nameEn: z.string().trim().min(1).max(100).optional(),
  emoji: z.string().min(1).max(16).optional(),
  isActive: z.boolean().optional(),
  date: dateString.optional(),
  notifyDaysBefore: z.number().int().min(0).max(30).optional(),
  isRecurring: z.boolean().optional(),
});

const CategoryCreateSchema = z.object({
  nameEn: z.string().trim().min(1).max(100),
  nameHi: z.string().trim().min(1).max(100),
  nameMr: z.string().trim().min(1).max(100),
  nameGu: z.string().trim().max(100).optional().nullable(),
  namePa: z.string().trim().max(100).optional().nullable(),
  slug: z.string().trim().min(1).max(100).optional(),
  emoji: z.string().min(1).max(16).default('✨'),
  gradient: z.string().max(100).default('from-indigo-500 to-purple-600'),
  coverImage: z.string().url().max(2048).nullable().optional(),
  description: z.string().max(500).nullable().optional(),
  sortOrder: z.number().int().default(0),
  isActive: z.boolean().default(true),
});

const CategoryUpdateSchema = z.object({
  nameEn: z.string().trim().min(1).max(100).optional(),
  nameHi: z.string().trim().min(1).max(100).optional(),
  nameMr: z.string().trim().min(1).max(100).optional(),
  nameGu: z.string().trim().max(100).nullable().optional(),
  namePa: z.string().trim().max(100).nullable().optional(),
  slug: z.string().trim().min(1).max(100).optional(),
  emoji: z.string().min(1).max(16).optional(),
  gradient: z.string().max(100).optional(),
  coverImage: z.string().url().max(2048).nullable().optional(),
  description: z.string().max(500).nullable().optional(),
  sortOrder: z.number().int().optional(),
  isActive: z.boolean().optional(),
});

const CAMPAIGN_SEGMENTS = [
  'all', 'hindi', 'marathi', 'hindi_free', 'free', 'premium', 'inactive_7d', 'premium_expiring',
] as const;
type CampaignSegment = typeof CAMPAIGN_SEGMENTS[number];

const CampaignSendSchema = z.object({
  title: z.string().trim().min(1).max(200),
  body: z.string().trim().min(1).max(2000),
  imageUrl: z.preprocess((v) => (v === '' ? undefined : v), z.string().url().max(2048).optional()),
  deepLink: z.preprocess((v) => (v === '' ? undefined : v), z.string().max(500).optional()),
  targetSegment: z.preprocess((v) => (v === '' || v == null ? 'all' : v), z.enum(CAMPAIGN_SEGMENTS)),
  scheduledAt: z.preprocess((v) => (v === '' ? undefined : v), dateString.optional()),
  notifType: z.preprocess(
    (v) => (v === '' ? undefined : v),
    z.enum(['DAILY_STATUS', 'FESTIVAL_ALERT', 'NEW_CONTENT', 'PREMIUM_OFFER', 'WELCOME']).optional(),
  ),
});

const ConfigPutSchema = z.object({
  key: z.string().min(1).max(100),
  value: z.string().max(10_000),
});

const InviteSchema = z.object({
  email: z.string().trim().email().max(254),
  name: z.string().trim().min(1).max(100),
  displayName: z.string().trim().max(100).optional(),
  bio: z.string().max(500).optional(),
});

const CoordinatorPickSchema = z.object({
  isCoordinatorPick: z.boolean(),
  coordinatorNote: z.string().max(300).nullable().optional(),
  coordinatorState: z.string().max(100).nullable().optional(),
});

/** Prisma filter for the in-app notification fan-out of a campaign segment. */
function segmentWhere(segment: CampaignSegment): Prisma.UserWhereInput {
  const now = new Date();
  const where: Prisma.UserWhereInput = { isActive: true };
  switch (segment) {
    case 'hindi':
      return { ...where, language: 'HINDI' };
    case 'marathi':
      return { ...where, language: 'MARATHI' };
    case 'hindi_free':
      return { ...where, language: 'HINDI', plan: 'FREE' };
    case 'free':
      return { ...where, plan: 'FREE' };
    case 'premium':
      return { ...where, plan: { in: PAID_PLANS } };
    case 'inactive_7d':
      return {
        ...where,
        OR: [{ lastActiveAt: { lt: new Date(now.getTime() - 7 * DAY_MS) } }, { lastActiveAt: null }],
      };
    case 'premium_expiring':
      return {
        ...where,
        plan: { in: PAID_PLANS },
        planExpiresAt: { gte: now, lte: new Date(now.getTime() + 3 * DAY_MS) },
      };
    case 'all':
    default:
      return where;
  }
}

export async function adminRoutes(fastify: FastifyInstance) {
  const requireAdmin = fastify.requireRole(ADMIN_ROLES);
  const cache = new CacheService(fastify.redis);
  const tokenStore = new RefreshTokenStore(fastify.redis);

  /** JSON-normalise (Dates → ISO strings, drop undefined) for Json columns. */
  const toJson = (v: unknown) => JSON.parse(JSON.stringify(v ?? null)) as Prisma.InputJsonValue;

  /** Append an audit-log entry; never fails the request. */
  async function audit(
    req: FastifyRequest,
    action: string,
    entityType: string,
    entityId: string,
    before?: unknown,
    after?: unknown,
  ) {
    try {
      await fastify.prisma.auditLog.create({
        data: {
          adminId: (req.user as any).userId,
          action,
          entityType,
          entityId,
          ...(before !== undefined && { before: toJson(before) }),
          ...(after !== undefined && { after: toJson(after) }),
          ip: req.ip,
          userAgent: (req.headers['user-agent'] ?? '').slice(0, 500) || null,
        },
      });
    } catch (err) {
      req.log.warn({ err }, `Failed to write audit log (${action})`);
    }
  }

  /** Recompute approvalRate (percentage) for a creator after review counters change. */
  const approvalRateSql = (userId: string) => fastify.prisma.$executeRaw`
    UPDATE "CreatorProfile"
    SET "approvalRate" = CASE
      WHEN ("approvedCount" + "rejectedCount") > 0
      THEN ROUND(("approvedCount" * 100.0 / ("approvedCount" + "rejectedCount"))::numeric, 1)::float
      ELSE 0 END
    WHERE "userId" = ${userId}
  `;

  // ── STATS ──────────────────────────────────────────────────
  fastify.get('/stats', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const cached = await cache.get(CK.adminStats);
    if (cached) return reply.send(cached);

    const now = new Date();
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [
      totalUsers, new24h, new7d, active30d, premiumUsers,
      totalTemplates, approved, pending, rejected, images, videos,
      activeSubscriptions,
      totalCreators, verifiedCreators,
      topTemplates, recentUsers, topCreators,
      languageDist,
    ] = await Promise.all([
      fastify.prisma.user.count(),
      fastify.prisma.user.count({ where: { createdAt: { gte: yesterday } } }),
      fastify.prisma.user.count({ where: { createdAt: { gte: sevenDaysAgo } } }),
      fastify.prisma.user.count({ where: { lastActiveAt: { gte: thirtyDaysAgo } } }),
      fastify.prisma.user.count({ where: { plan: { in: PAID_PLANS } } }),
      fastify.prisma.template.count(),
      fastify.prisma.template.count({ where: { status: 'APPROVED' } }),
      fastify.prisma.template.count({ where: { status: 'PENDING' } }),
      fastify.prisma.template.count({ where: { status: 'REJECTED' } }),
      fastify.prisma.template.count({ where: { type: 'IMAGE' } }),
      fastify.prisma.template.count({ where: { type: 'VIDEO' } }),
      fastify.prisma.subscription.count({ where: { status: 'ACTIVE' } }),
      fastify.prisma.creatorProfile.count(),
      fastify.prisma.creatorProfile.count({ where: { isVerified: true } }),

      // Top Templates
      fastify.prisma.template.findMany({
        where: { status: 'APPROVED' }, orderBy: { useCount: 'desc' }, take: 5, include: { category: true }
      }),
      // Recent Users (explicit select — never expose password hashes)
      fastify.prisma.user.findMany({
        orderBy: { createdAt: 'desc' }, take: 4, select: userSummarySelect,
      }),
      // Top Creators
      fastify.prisma.creatorProfile.findMany({
        orderBy: { approvalRate: 'desc' }, take: 3,
        include: { user: { select: userSummarySelect } },
      }),
      // Language distribution
      fastify.prisma.user.groupBy({
        by: ['language'],
        _count: { language: true },
        orderBy: { _count: { language: 'desc' } },
      }),
    ]);

    const stats = {
      users: { total: totalUsers, new24h, new7d, active30d, premium: premiumUsers },
      templates: { total: totalTemplates, approved, pending, rejected, images, videos },
      revenue: { activeSubscriptions },
      creators: { total: totalCreators, verified: verifiedCreators, pendingReview: pending },
      topTemplates,
      recentUsers,
      topCreators,
      languageDist: languageDist.map((l: any) => ({ language: l.language, count: l._count.language })),
    };

    await cache.set(CK.adminStats, stats, 300);
    return reply.send(stats);
  });

  // ── TEMPLATE MANAGEMENT ────────────────────────────────────
  fastify.get('/templates', { preHandler: [requireAdmin] }, async (req, reply) => {
    const parsed = TemplateListQuery.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid query');
    const q = parsed.data;
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });

    const where: Prisma.TemplateWhereInput = {};
    if (q.status) where.status = q.status;
    if (q.type) where.type = q.type;
    if (q.categoryId) where.categoryId = q.categoryId;
    if (q.isPremium !== undefined) where.isPremium = q.isPremium;
    if (q.isFeatured !== undefined) where.isFeatured = q.isFeatured;
    if (q.search) {
      where.OR = [
        { nameEn: { contains: q.search, mode: 'insensitive' } },
        { nameHi: { contains: q.search, mode: 'insensitive' } },
        { nameMr: { contains: q.search, mode: 'insensitive' } },
        { tags: { has: q.search.toLowerCase() } },
      ];
    }

    const [data, total] = await Promise.all([
      fastify.prisma.template.findMany({
        where,
        include: {
          category: true,
          creator: { select: { id: true, name: true, profilePhoto: true } },
          reviewer: { select: { id: true, name: true } },
        },
        orderBy: { [q.sortBy ?? 'createdAt']: q.sortOrder ?? 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.template.count({ where }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  fastify.get('/templates/pending', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { sortBy = 'oldest' } = req.query as any;
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });

    const [data, total] = await Promise.all([
      fastify.prisma.template.findMany({
        where: { status: TemplateStatus.PENDING },
        include: {
          category: true,
          creator: { select: { id: true, name: true, profilePhoto: true, creatorProfile: true } },
        },
        orderBy: { submittedAt: sortBy === 'oldest' ? 'asc' : 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.template.count({ where: { status: TemplateStatus.PENDING } }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  // POST /admin/templates/:id/approve
  fastify.post('/templates/:id/approve', { preHandler: [requireAdmin] }, async (req, reply) => {
    const adminId = (req.user as any).userId;
    const { id } = req.params as { id: string };
    const { note } = (req.body as any) ?? {};

    const template = await fastify.prisma.template.findUnique({ where: { id } });
    if (!template) return reply.status(404).send({ error: 'Template not found' });
    if (template.status === TemplateStatus.APPROVED) {
      return reply.send({ template }); // idempotent — don't double count
    }

    const prev = template.status;
    const ops: Prisma.PrismaPromise<unknown>[] = [
      fastify.prisma.template.update({
        where: { id },
        data: {
          status: TemplateStatus.APPROVED,
          reviewedAt: new Date(),
          reviewerId: adminId,
          ...(typeof note === 'string' && note && { reviewNote: note.slice(0, 2000) }),
        },
      }),
      fastify.prisma.creatorProfile.updateMany({
        where: { userId: template.creatorId },
        data: { approvedCount: { increment: 1 } },
      }),
    ];
    if (prev === TemplateStatus.PENDING) {
      // Conditional decrement keeps pendingCount >= 0
      ops.push(fastify.prisma.creatorProfile.updateMany({
        where: { userId: template.creatorId, pendingCount: { gt: 0 } },
        data: { pendingCount: { decrement: 1 } },
      }));
    }
    const [updated] = await fastify.prisma.$transaction(ops);
    await approvalRateSql(template.creatorId).catch(() => 0);

    // Invalidate all template caches (lists, home feed, detail)
    await cache.invalidateTemplateCache(id);

    await audit(req, 'approve_template', 'Template', id, { status: prev }, { status: 'APPROVED' });

    // Notify creator
    const creator = await fastify.prisma.user.findUnique({
      where: { id: template.creatorId },
      select: { oneSignalPlayerId: true },
    });

    if (creator?.oneSignalPlayerId) {
      OneSignalService.send({
        heading: '✅ Template Approved!',
        content: `"${template.nameEn ?? template.nameHi}" is now live in the app!`,
        playerIds: [creator.oneSignalPlayerId],
        data: { screen: 'creator_templates' },
      }).catch(() => {});
    }

    return reply.send({ template: updated });
  });

  // POST /admin/templates/:id/reject
  fastify.post('/templates/:id/reject', { preHandler: [requireAdmin] }, async (req, reply) => {
    const adminId = (req.user as any).userId;
    const { id } = req.params as { id: string };
    const { note } = ((req.body as any) ?? {}) as { note?: unknown };

    if (typeof note !== 'string' || note.trim().length < 10) {
      return reply.status(400).send({ error: 'Rejection reason is required (min 10 chars)' });
    }

    const template = await fastify.prisma.template.findUnique({ where: { id } });
    if (!template) return reply.status(404).send({ error: 'Template not found' });

    const prev = template.status;
    const ops: Prisma.PrismaPromise<unknown>[] = [
      fastify.prisma.template.update({
        where: { id },
        data: {
          status: TemplateStatus.REJECTED,
          reviewedAt: new Date(),
          reviewerId: adminId,
          reviewNote: note.slice(0, 2000),
        },
      }),
    ];
    if (prev !== TemplateStatus.REJECTED) {
      ops.push(fastify.prisma.creatorProfile.updateMany({
        where: { userId: template.creatorId },
        data: { rejectedCount: { increment: 1 } },
      }));
    }
    if (prev === TemplateStatus.PENDING) {
      ops.push(fastify.prisma.creatorProfile.updateMany({
        where: { userId: template.creatorId, pendingCount: { gt: 0 } },
        data: { pendingCount: { decrement: 1 } },
      }));
    }
    if (prev === TemplateStatus.APPROVED) {
      ops.push(fastify.prisma.creatorProfile.updateMany({
        where: { userId: template.creatorId, approvedCount: { gt: 0 } },
        data: { approvedCount: { decrement: 1 } },
      }));
    }
    const [updated] = await fastify.prisma.$transaction(ops);
    await approvalRateSql(template.creatorId).catch(() => 0);

    // A previously-live template must disappear from feeds immediately
    await cache.invalidateTemplateCache(id);

    await audit(req, 'reject_template', 'Template', id, { status: prev }, { status: 'REJECTED', note });

    const creator = await fastify.prisma.user.findUnique({
      where: { id: template.creatorId },
      select: { oneSignalPlayerId: true },
    });

    if (creator?.oneSignalPlayerId) {
      OneSignalService.send({
        heading: '❌ Template Needs Changes',
        content: `"${template.nameEn ?? template.nameHi}": ${note.slice(0, 80)}`,
        playerIds: [creator.oneSignalPlayerId],
        data: { screen: 'creator_templates' },
      }).catch(() => {});
    }

    return reply.send({ template: updated });
  });

  // POST /admin/templates/:id/feature
  fastify.post('/templates/:id/feature', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = z.object({ isFeatured: z.boolean() }).safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { isFeatured } = parsed.data;

    const template = await fastify.prisma.template.update({
      where: { id },
      data: { isFeatured },
    });

    await cache.invalidateTemplateCache(id);
    await audit(req, 'feature_template', 'Template', id, undefined, { isFeatured });
    return reply.send({ template });
  });

  // PATCH /admin/templates/:id
  fastify.patch('/templates/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = TemplatePatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const body = parsed.data;

    const template = await fastify.prisma.template.update({
      where: { id },
      data: {
        sortOrder: body.sortOrder,
        isPremium: body.isPremium,
        isFeatured: body.isFeatured,
        isTrending: body.isTrending,
        tags: body.tags,
      },
    });

    await cache.invalidateTemplateCache(id);
    await audit(req, 'update_template', 'Template', id, undefined, body);
    return reply.send({ template });
  });

  // DELETE /admin/templates/:id (soft delete)
  fastify.delete('/templates/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const existing = await fastify.prisma.template.findUnique({ where: { id }, select: { status: true } });
    if (!existing) return reply.status(404).send({ error: 'Template not found' });

    await fastify.prisma.template.update({
      where: { id },
      data: { status: TemplateStatus.ARCHIVED },
    });
    await cache.invalidateTemplateCache(id);
    await audit(req, 'archive_template', 'Template', id, { status: existing.status }, { status: 'ARCHIVED' });
    return reply.send({ success: true });
  });

  // ── USER MANAGEMENT ────────────────────────────────────────
  fastify.get('/users', { preHandler: [requireAdmin] }, async (req, reply) => {
    const parsed = UserListQuery.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid query');
    const q = parsed.data;
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });

    const where: Prisma.UserWhereInput = {};
    if (q.search) {
      where.OR = [
        { name: { contains: q.search, mode: 'insensitive' } },
        { email: { contains: q.search, mode: 'insensitive' } },
        { phoneNumber: { contains: q.search } },
      ];
    }
    if (q.plan) where.plan = q.plan;
    if (q.language) where.language = q.language;
    if (q.role) where.role = q.role;
    if (q.isActive !== undefined) where.isActive = q.isActive;

    const [data, total] = await Promise.all([
      fastify.prisma.user.findMany({
        where,
        select: {
          id: true, name: true, email: true, phoneNumber: true, plan: true, role: true,
          language: true, isActive: true, streakCount: true, totalShares: true,
          totalSaves: true, lastActiveAt: true, createdAt: true, planExpiresAt: true,
        },
        orderBy: { [q.sortBy ?? 'createdAt']: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.user.count({ where }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  fastify.patch('/users/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const actor = req.user as { userId: string; role: string };
    const parsed = UserPatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const body = parsed.data;

    const target = await fastify.prisma.user.findUnique({
      where: { id },
      select: { id: true, role: true, plan: true, isActive: true, planExpiresAt: true, name: true, email: true },
    });
    if (!target) return reply.status(404).send({ error: 'User not found' });

    const isSuperAdmin = actor.role === UserRole.SUPER_ADMIN;
    const targetIsAdmin = target.role === UserRole.MANAGER || target.role === UserRole.SUPER_ADMIN;
    const roleChange = body.role !== undefined && body.role !== target.role;

    if (targetIsAdmin && !isSuperAdmin) {
      return reply.status(403).send({ error: 'Only a SUPER_ADMIN can modify admin accounts' });
    }
    if (roleChange && id === actor.userId) {
      return reply.status(403).send({ error: 'You cannot change your own role' });
    }
    if (roleChange && !isSuperAdmin) {
      return reply.status(403).send({ error: 'Only a SUPER_ADMIN can change user roles' });
    }
    if (body.isActive === false && id === actor.userId) {
      return reply.status(403).send({ error: 'You cannot deactivate your own account' });
    }

    const user = await fastify.prisma.user.update({
      where: { id },
      data: {
        plan: body.plan,
        planExpiresAt: body.planExpiresAt === null
          ? null
          : body.planExpiresAt ? new Date(body.planExpiresAt) : undefined,
        role: body.role,
        isActive: body.isActive,
      },
      select: safeUserSelect,
    });

    // Promoted to creator → make sure the creator profile exists
    if (roleChange && body.role === UserRole.CREATOR) {
      await fastify.prisma.creatorProfile.upsert({
        where: { userId: id },
        update: {},
        create: { userId: id, displayName: target.name || target.email || 'Creator', specialization: [] },
      });
    }

    // Deactivation or role change: kill the refresh token so the session can't be renewed
    const deactivated = body.isActive === false && target.isActive;
    if (deactivated || roleChange) {
      await tokenStore.invalidate(id).catch(() => {});
    }
    await invalidateUserCaches(fastify.redis, id);

    const changed = Object.fromEntries(
      Object.entries(body).filter(([, v]) => v !== undefined),
    );
    await audit(
      req,
      deactivated ? 'suspend_user' : 'update_user',
      'User',
      id,
      { role: target.role, plan: target.plan, isActive: target.isActive, planExpiresAt: target.planExpiresAt },
      changed,
    );

    return reply.send({ user });
  });

  // ── CREATOR MANAGEMENT ────────────────────────────────────
  fastify.get('/creators', { preHandler: [requireAdmin] }, async (req, reply) => {
    const parsed = CreatorListQuery.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid query');
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });

    // '' (as sent by dashboard filters) means "no filter"
    const where: Prisma.CreatorProfileWhereInput = {};
    if (parsed.data.isVerified !== undefined) where.isVerified = parsed.data.isVerified;
    if (parsed.data.isSuspended !== undefined) where.isSuspended = parsed.data.isSuspended;

    const [data, total] = await Promise.all([
      fastify.prisma.creatorProfile.findMany({
        where,
        include: { user: { select: { id: true, name: true, email: true, profilePhoto: true } } },
        orderBy: { approvalRate: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.creatorProfile.count({ where }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  fastify.patch('/creators/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = CreatorPatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const body = parsed.data;

    const before = await fastify.prisma.creatorProfile.findUnique({ where: { id } });
    if (!before) return reply.status(404).send({ error: 'Creator not found' });

    const profile = await fastify.prisma.creatorProfile.update({
      where: { id },
      data: {
        isVerified: body.isVerified,
        verifiedAt: body.isVerified === true ? new Date() : body.isVerified === false ? null : undefined,
        isSuspended: body.isSuspended,
        suspendedReason: body.isSuspended === false ? null : body.suspendedReason,
      },
    });

    // Suspension is enforced from the cached auth state → drop it now
    await invalidateUserCaches(fastify.redis, profile.userId);

    const action = body.isSuspended === true && !before.isSuspended
      ? 'suspend_creator'
      : body.isSuspended === false && before.isSuspended
        ? 'unsuspend_creator'
        : body.isVerified === true && !before.isVerified
          ? 'verify_creator'
          : 'update_creator';
    await audit(
      req, action, 'CreatorProfile', id,
      { isVerified: before.isVerified, isSuspended: before.isSuspended, suspendedReason: before.suspendedReason },
      body,
    );

    return reply.send({ creatorProfile: profile });
  });

  // ── FESTIVAL MANAGEMENT ───────────────────────────────────
  fastify.get('/festivals', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const data = await fastify.prisma.festival.findMany({ orderBy: { date: 'asc' } });
    return reply.send({ data });
  });

  fastify.post('/festivals', { preHandler: [requireAdmin] }, async (req, reply) => {
    const parsed = FestivalCreateSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid festival');
    const body = parsed.data;

    const festival = await fastify.prisma.festival.create({
      data: {
        nameHi: body.nameHi, nameMr: body.nameMr, nameEn: body.nameEn,
        emoji: body.emoji, date: new Date(body.date),
        notifyDaysBefore: body.notifyDaysBefore ?? 2,
        isActive: true, isRecurring: body.isRecurring ?? true,
        ...(body.categoryId && { categoryId: body.categoryId }),
      },
    });
    await cache.invalidatePattern('festivals:upcoming:*').catch(() => 0);
    await audit(req, 'create_festival', 'Festival', festival.id, undefined, body);
    return reply.status(201).send({ festival });
  });

  fastify.put('/festivals/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = FestivalUpdateSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid festival');
    const body = parsed.data;

    const festival = await fastify.prisma.festival.update({
      where: { id },
      data: {
        nameHi: body.nameHi, nameMr: body.nameMr, nameEn: body.nameEn,
        emoji: body.emoji, isActive: body.isActive,
        date: body.date ? new Date(body.date) : undefined,
        notifyDaysBefore: body.notifyDaysBefore,
        isRecurring: body.isRecurring,
      },
    });
    await cache.invalidatePattern('festivals:upcoming:*').catch(() => 0);
    await audit(req, 'update_festival', 'Festival', id, undefined, body);
    return reply.send({ festival });
  });

  // ── CATEGORY MANAGEMENT ───────────────────────────────────
  fastify.get('/categories', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const data = await fastify.prisma.category.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameEn: 'asc' }],
      include: {
        _count: {
          select: { templates: true, festivals: true },
        },
      },
    });
    return reply.send({ data });
  });

  fastify.post('/categories', { preHandler: [requireAdmin] }, async (req, reply) => {
    const parsed = CategoryCreateSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid category data');
    const body = parsed.data;

    const baseSlug = (body.slug || body.nameEn).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)+/g, '') || 'category';
    let slug = baseSlug;
    let suffix = 1;
    while (await fastify.prisma.category.findUnique({ where: { slug } })) {
      slug = `${baseSlug}-${suffix++}`;
    }

    const category = await fastify.prisma.category.create({
      data: {
        slug,
        nameEn: body.nameEn,
        nameHi: body.nameHi,
        nameMr: body.nameMr,
        nameGu: body.nameGu,
        namePa: body.namePa,
        emoji: body.emoji || '✨',
        gradient: body.gradient || 'from-indigo-500 to-purple-600',
        coverImage: body.coverImage,
        description: body.description,
        sortOrder: body.sortOrder ?? 0,
        isActive: body.isActive ?? true,
      },
      include: {
        _count: {
          select: { templates: true, festivals: true },
        },
      },
    });

    await cache.invalidatePattern('categories:*').catch(() => 0);
    await audit(req, 'create_category', 'Category', category.id, undefined, body);
    return reply.status(201).send({ category });
  });

  fastify.put('/categories/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = CategoryUpdateSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid category update');
    const body = parsed.data;

    if (body.slug) {
      const existing = await fastify.prisma.category.findFirst({
        where: { slug: body.slug, NOT: { id } },
      });
      if (existing) {
        return reply.status(409).send({ error: `Another category already has slug "${body.slug}".` });
      }
    }

    const category = await fastify.prisma.category.update({
      where: { id },
      data: {
        ...(body.nameEn !== undefined && { nameEn: body.nameEn }),
        ...(body.nameHi !== undefined && { nameHi: body.nameHi }),
        ...(body.nameMr !== undefined && { nameMr: body.nameMr }),
        ...(body.nameGu !== undefined && { nameGu: body.nameGu }),
        ...(body.namePa !== undefined && { namePa: body.namePa }),
        ...(body.slug !== undefined && { slug: body.slug }),
        ...(body.emoji !== undefined && { emoji: body.emoji }),
        ...(body.gradient !== undefined && { gradient: body.gradient }),
        ...(body.coverImage !== undefined && { coverImage: body.coverImage }),
        ...(body.description !== undefined && { description: body.description }),
        ...(body.sortOrder !== undefined && { sortOrder: body.sortOrder }),
        ...(body.isActive !== undefined && { isActive: body.isActive }),
      },
      include: {
        _count: {
          select: { templates: true, festivals: true },
        },
      },
    });

    await cache.invalidatePattern('categories:*').catch(() => 0);
    await audit(req, 'update_category', 'Category', id, undefined, body);
    return reply.send({ category });
  });

  fastify.delete('/categories/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };

    const count = await fastify.prisma.template.count({ where: { categoryId: id } });
    if (count > 0) {
      return reply.status(400).send({
        error: `Cannot delete category: ${count} templates are linked to it. Toggle "Inactive" instead.`,
      });
    }

    await fastify.prisma.category.delete({ where: { id } });
    await cache.invalidatePattern('categories:*').catch(() => 0);
    await audit(req, 'delete_category', 'Category', id);
    return reply.send({ success: true, message: 'Category deleted successfully' });
  });

  // ── PUSH CAMPAIGNS ─────────────────────────────────────────
  fastify.get('/campaigns', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const data = await fastify.prisma.pushCampaign.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return reply.send({ data });
  });

  /**
   * Write the in-app inbox entries for every user in the segment, in batches of
   * 1000 (keyset pagination), so large segments don't exhaust memory.
   */
  async function fanOutInAppNotifications(
    where: Prisma.UserWhereInput,
    notif: { title: string; body: string; type: NotifType; data: Prisma.InputJsonValue; oneSignalId: string | null },
  ): Promise<number> {
    const BATCH = 1000;
    let cursor: string | undefined;
    let total = 0;
    for (;;) {
      const batch = await fastify.prisma.user.findMany({
        where,
        select: { id: true },
        orderBy: { id: 'asc' },
        take: BATCH,
        ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      });
      if (batch.length === 0) break;

      const sentAt = new Date();
      await fastify.prisma.notificationLog.createMany({
        data: batch.map((u) => ({ userId: u.id, ...notif, sentAt })),
      });
      total += batch.length;
      cursor = batch[batch.length - 1].id;
      if (batch.length < BATCH) break;
    }
    return total;
  }

  fastify.post('/campaigns/send', {
    preHandler: [requireAdmin],
    config: { rateLimit: { max: 20, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const adminId = (req.user as any).userId;
    const parsed = CampaignSendSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid campaign');
    const { title, body, imageUrl, deepLink, targetSegment, scheduledAt, notifType } = parsed.data;

    const filters = OneSignalService.buildFilters(targetSegment);
    const segment = filters.length === 0 ? 'All' : undefined;

    const notifId = await OneSignalService.send({
      heading: title,
      content: body,
      imageUrl: imageUrl || undefined,
      data: deepLink ? { deepLink, screen: deepLink } : undefined,
      filters: filters.length > 0 ? filters : undefined,
      segment,
      scheduledAt: scheduledAt ? new Date(scheduledAt) : undefined,
    });

    const campaign = await fastify.prisma.pushCampaign.create({
      data: {
        title,
        body,
        imageUrl: imageUrl || null,
        deepLink: deepLink || null,
        targetSegment,
        scheduledAt: scheduledAt ? new Date(scheduledAt) : null,
        sentAt: !scheduledAt && notifId ? new Date() : null,
        status: !notifId ? 'failed' : scheduledAt ? 'scheduled' : 'sent',
        oneSignalId: notifId,
        createdBy: adminId,
      },
    });

    await audit(req, 'send_campaign', 'PushCampaign', campaign.id, undefined, {
      title, targetSegment, scheduledAt: scheduledAt ?? null, oneSignalId: notifId,
    });

    // Populate the in-app NotificationLog for every user in the segment (runs in the
    // background — large segments are written in batches of 1000).
    fanOutInAppNotifications(segmentWhere(targetSegment), {
      title,
      body,
      type: (notifType ?? 'NEW_CONTENT') as NotifType,
      data: {
        deepLink: deepLink || null,
        imageUrl: imageUrl || null,
        screen: deepLink || 'home',
      },
      oneSignalId: notifId,
    })
      .then((count) => fastify.log.info({ campaignId: campaign.id, count }, 'In-app notifications created'))
      .catch((err) => fastify.log.warn({ err, campaignId: campaign.id }, 'Failed to populate in-app NotificationLog'));

    return reply.send({ campaign, oneSignalId: notifId, success: !!notifId });
  });

  // POST /admin/campaigns/test — Send test push notification to a specific test phone/email/playerId
  fastify.post('/campaigns/test', {
    preHandler: [requireAdmin],
  }, async (req, reply) => {
    const parsed = z.object({
      title: z.string().min(1).max(200),
      body: z.string().min(1).max(2000),
      imageUrl: z.string().max(2048).optional(),
      deepLink: z.string().max(500).optional(),
      testTarget: z.string().trim().min(1).max(200),
      targetType: z.enum(['phone', 'email', 'userId', 'playerId']).optional(),
    }).safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { title, body, imageUrl, deepLink, testTarget, targetType } = parsed.data;

    let playerId: string | undefined;
    let targetUserId: string | undefined;

    if (targetType === 'playerId' || testTarget.startsWith('player:')) {
      playerId = testTarget.replace('player:', '').trim();
    } else {
      const user = await fastify.prisma.user.findFirst({
        where: {
          OR: [
            { id: testTarget },
            { phoneNumber: testTarget },
            { phoneNumber: `+91${testTarget.replace('+91', '')}` },
            { email: testTarget },
          ],
        },
        select: { id: true, name: true, phoneNumber: true, oneSignalPlayerId: true },
      });

      if (user) {
        targetUserId = user.id;
        playerId = user.oneSignalPlayerId || undefined;
      }
    }

    const notifId = await OneSignalService.send({
      heading: `[TEST] ${title}`,
      content: body,
      imageUrl: imageUrl || undefined,
      data: deepLink ? { deepLink, screen: deepLink, isTest: 'true' } : { isTest: 'true' },
      playerIds: playerId ? [playerId] : undefined,
      userIds: targetUserId ? [targetUserId] : undefined,
    });

    if (targetUserId) {
      await fastify.prisma.notificationLog.create({
        data: {
          userId: targetUserId,
          title: `[TEST] ${title}`,
          body,
          type: 'NEW_CONTENT',
          data: {
            deepLink: deepLink || null,
            imageUrl: imageUrl || null,
            screen: deepLink || 'home',
            isTest: true,
          },
          oneSignalId: notifId,
          sentAt: new Date(),
        },
      }).catch(() => {});
    }

    return reply.send({
      success: !!notifId,
      oneSignalId: notifId,
      deliveredTo: playerId ? `PlayerID: ${playerId}` : (targetUserId ? `User: ${targetUserId}` : 'Simulated device'),
    });
  });

  // ── ANALYTICS ─────────────────────────────────────────────
  // All aggregates are cast to ::int so Postgres bigint never reaches JSON serialization.
  fastify.get('/analytics/dau', { preHandler: [requireAdmin] }, async (req, reply) => {
    const days = clampInt((req.query as any)?.days, 30, 1, 365);
    const daysAgo = new Date(Date.now() - days * DAY_MS);

    const results: any[] = await fastify.prisma.$queryRaw`
      SELECT DATE_TRUNC('day', "lastActiveAt") as date, COUNT(*)::int as count
      FROM "User"
      WHERE "lastActiveAt" >= ${daysAgo} AND "isActive" = true
      GROUP BY DATE_TRUNC('day', "lastActiveAt")
      ORDER BY date ASC
    `;

    return reply.send({ data: results });
  });

  fastify.get('/analytics/searches', { preHandler: [requireAdmin] }, async (req, reply) => {
    const sevenDaysAgo = new Date(Date.now() - 7 * DAY_MS);
    const limitInt = clampInt((req.query as any)?.limit, 20, 1, 100);

    const results: any[] = await fastify.prisma.$queryRaw`
      SELECT (metadata::jsonb ->> 'query') as term, COUNT(*)::int as count
      FROM "AnalyticsEvent"
      WHERE event = 'search' AND "createdAt" > ${sevenDaysAgo}
        AND (metadata::jsonb ->> 'query') IS NOT NULL
      GROUP BY (metadata::jsonb ->> 'query')
      ORDER BY count DESC
      LIMIT ${limitInt}
    `;

    return reply.send({ data: results });
  });

  fastify.get('/analytics/shares', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const thirtyDaysAgo = new Date(Date.now() - 30 * DAY_MS);

    const results: any[] = await fastify.prisma.$queryRaw`
      SELECT platform, COUNT(*)::int as count
      FROM "ShareHistory"
      WHERE "sharedAt" >= ${thirtyDaysAgo}
      GROUP BY platform
      ORDER BY count DESC
    `;

    return reply.send({ data: results });
  });

  // ── APP CONFIG ────────────────────────────────────────────
  fastify.get('/config', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const cached = await cache.get(CK.appConfig);
    if (cached) return reply.send({ data: cached });

    const config = await fastify.prisma.appConfig.findMany({ orderBy: { key: 'asc' } });
    await cache.set(CK.appConfig, config, 1800);
    return reply.send({ data: config });
  });

  fastify.put('/config', { preHandler: [requireAdmin] }, async (req, reply) => {
    const adminId = (req.user as any).userId;
    const parsed = ConfigPutSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { key, value } = parsed.data;

    const before = await fastify.prisma.appConfig.findUnique({ where: { key } });
    if (!before) return reply.status(404).send({ error: 'Config key not found' });

    const config = await fastify.prisma.appConfig.update({
      where: { key },
      data: { value, updatedBy: adminId },
    });

    await cache.delMany([CK.appConfig, CK.publicAppConfig]);
    await audit(req, 'update_config', 'AppConfig', key, { value: before.value }, { value });
    return reply.send({ config });
  });

  // ── AUDIT LOG ─────────────────────────────────────────────
  fastify.get('/audit-log', { preHandler: [requireAdmin] }, async (req, reply) => {
    const parsed = AuditLogQuery.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid query');
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 50, maxLimit: 100 });

    const where: Prisma.AuditLogWhereInput = {};
    if (parsed.data.action) where.action = parsed.data.action;
    if (parsed.data.entityType) where.entityType = parsed.data.entityType;

    const [data, total] = await Promise.all([
      fastify.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.auditLog.count({ where }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  // ── REVENUE SUMMARY ────────────────────────────────────────
  fastify.get('/revenue', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const [activeSubs, premiumUsers, annualUsers, totalRevenue] = await Promise.all([
      fastify.prisma.subscription.findMany({
        where: { status: 'ACTIVE' },
        select: { plan: true, amount: true },
      }),
      fastify.prisma.user.count({ where: { plan: 'PREMIUM' } }),
      fastify.prisma.user.count({ where: { plan: 'ANNUAL' } }),
      fastify.prisma.subscription.aggregate({
        where: { status: { in: ['ACTIVE', 'EXPIRED', 'CANCELLED'] } },
        _sum: { amount: true },
        _count: true,
      }),
    ]);

    const mrr = activeSubs.reduce((sum, s) => {
      if (s.plan === 'ANNUAL') return sum + Math.round(s.amount / 12);
      return sum + s.amount;
    }, 0);

    const planBreakdown = activeSubs.reduce((acc: Record<string, number>, s) => {
      acc[s.plan] = (acc[s.plan] || 0) + 1;
      return acc;
    }, {});

    return reply.send({
      activeSubs: activeSubs.length,
      premiumUsers,
      annualUsers,
      mrr,
      arr: mrr * 12,
      planBreakdown,
      totalRevenue: totalRevenue._sum.amount ?? 0,
      totalTransactions: totalRevenue._count,
    });
  });

  // ── INVITE CREATOR ─────────────────────────────────────────
  fastify.post('/creators/invite', { preHandler: [requireAdmin] }, async (req, reply) => {
    const parsed = InviteSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      return reply.status(400).send({ error: 'email and name are required', details: parsed.error.flatten() });
    }
    const { email, name, displayName, bio } = parsed.data;

    // Check if email already exists
    const existing = await fastify.prisma.user.findUnique({ where: { email } });

    if (existing) {
      if (existing.role === 'CREATOR') {
        return reply.status(409).send({ error: 'This email is already a Creator.' });
      }
      // Never demote an admin account through the invite flow
      if (existing.role === 'MANAGER' || existing.role === 'SUPER_ADMIN') {
        return reply.status(409).send({ error: 'This email belongs to an admin account and cannot be invited as a Creator.' });
      }
      // Upgrade existing user to CREATOR
      const updated = await fastify.prisma.user.update({
        where: { email },
        data: { role: 'CREATOR' },
        select: { id: true },
      });
      // Ensure creator profile exists
      await fastify.prisma.creatorProfile.upsert({
        where: { userId: updated.id },
        update: {},
        create: {
          userId: updated.id,
          displayName: displayName || name,
          bio: bio || null,
          specialization: [],
        },
      });
      await invalidateUserCaches(fastify.redis, updated.id);
      await audit(req, 'invite_creator', 'User', updated.id, { role: existing.role }, { role: 'CREATOR' });
      return reply.send({ message: 'Existing user upgraded to Creator.', userId: updated.id });
    }

    // Create new user with CREATOR role
    const newUser = await fastify.prisma.user.create({
      data: {
        email,
        name,
        displayName: displayName || name,
        role: 'CREATOR',
        plan: 'FREE',
        language: 'HINDI',
        isActive: true,
      },
      select: { id: true, email: true },
    });

    await fastify.prisma.creatorProfile.create({
      data: {
        userId: newUser.id,
        displayName: displayName || name,
        bio: bio || null,
        specialization: [],
      },
    });

    await audit(req, 'invite_creator', 'User', newUser.id, undefined, { email, role: 'CREATOR' });

    return reply.status(201).send({
      message: 'Creator invited successfully. They can now sign in with Google.',
      userId: newUser.id,
      email: newUser.email,
    });
  });

  // ── COORDINATOR PICKS ─────────────────────────────────────────────────────
  // PATCH /admin/templates/:id/coordinator-pick
  fastify.patch('/templates/:id/coordinator-pick', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const parsed = CoordinatorPickSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { isCoordinatorPick, coordinatorNote, coordinatorState } = parsed.data;

    const template = await fastify.prisma.template.findUnique({ where: { id } });
    if (!template) return reply.status(404).send({ error: 'Template not found' });
    if (template.status !== 'APPROVED') {
      return reply.status(400).send({ error: 'Only approved templates can be coordinator picks' });
    }

    const updated = await fastify.prisma.template.update({
      where: { id },
      data: {
        isCoordinatorPick,
        coordinatorNote: coordinatorNote ?? null,
        coordinatorState: coordinatorState ?? null,
      },
      select: {
        id: true, nameHi: true, nameEn: true, isCoordinatorPick: true,
        coordinatorNote: true, coordinatorState: true,
      },
    });

    // Coordinator picks are served from the home feed (home:feed:*) — invalidate it
    await cache.invalidateTemplateCache(id);
    await audit(
      req, 'coordinator_pick', 'Template', id,
      {
        isCoordinatorPick: template.isCoordinatorPick,
        coordinatorNote: template.coordinatorNote,
        coordinatorState: template.coordinatorState,
      },
      { isCoordinatorPick, coordinatorNote: coordinatorNote ?? null, coordinatorState: coordinatorState ?? null },
    );

    return reply.send({ success: true, template: updated });
  });

  // GET /admin/coordinator-picks — list all coordinator-picked templates
  fastify.get('/coordinator-picks', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const picks = await fastify.prisma.template.findMany({
      where: { isCoordinatorPick: true },
      orderBy: { sortOrder: 'asc' },
      select: {
        id: true, nameHi: true, nameEn: true, nameMr: true,
        imageThumbUrl: true, gradient: true, isCoordinatorPick: true,
        coordinatorNote: true, coordinatorState: true, status: true,
        useCount: true, shareCount: true,
        category: { select: { nameEn: true, emoji: true } },
      },
    });
    return reply.send({ data: picks, total: picks.length });
  });
}
