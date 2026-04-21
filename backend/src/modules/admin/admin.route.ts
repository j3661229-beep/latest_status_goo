// src/modules/admin/admin.route.ts
import { FastifyInstance } from 'fastify';
import { TemplateStatus } from '@prisma/client';
import { CacheService } from '../../lib/cache/cache.service';
import { CK } from '../../lib/cache/keys';
import { OneSignalService } from '../../lib/notification/onesignal.service';

export async function adminRoutes(fastify: FastifyInstance) {
  const ADMIN_ROLES = ['MANAGER', 'SUPER_ADMIN'];
  const requireAdmin = fastify.requireRole(ADMIN_ROLES);
  const cache = new CacheService(fastify.redis);

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
      fastify.prisma.user.count({ where: { plan: { in: ['PREMIUM', 'ANNUAL'] } } }),
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
      // Recent Users
      fastify.prisma.user.findMany({
        orderBy: { createdAt: 'desc' }, take: 4
      }),
      // Top Creators
      fastify.prisma.creatorProfile.findMany({
        orderBy: { approvalRate: 'desc' }, take: 3, include: { user: true }
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
    const { status, type, categoryId, isPremium, isFeatured, page = '1', limit = '20', sortBy = 'createdAt', sortOrder = 'desc' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 100);

    const where: any = {};
    if (status) where.status = status;
    if (type) where.type = type;
    if (categoryId) where.categoryId = categoryId;
    if (isPremium !== undefined) where.isPremium = isPremium === 'true';
    if (isFeatured !== undefined) where.isFeatured = isFeatured === 'true';

    const [data, total] = await Promise.all([
      fastify.prisma.template.findMany({
        where,
        include: {
          category: true,
          creator: { select: { id: true, name: true, profilePhoto: true } },
          reviewer: { select: { id: true, name: true } },
        },
        orderBy: { [sortBy]: sortOrder },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.template.count({ where }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  fastify.get('/templates/pending', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { page = '1', limit = '20', sortBy = 'oldest' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 50);

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

    const updated = await fastify.prisma.template.update({
      where: { id },
      data: {
        status: TemplateStatus.APPROVED,
        reviewedAt: new Date(),
        reviewerId: adminId,
        ...(note && { reviewNote: note }),
      },
    });

    // Invalidate all template caches
    await cache.invalidateTemplateCache();

    // Create audit log
    await fastify.prisma.auditLog.create({
      data: {
        adminId,
        action: 'approve_template',
        entityType: 'Template',
        entityId: id,
        after: { status: 'APPROVED' },
      },
    });

    // Update creator stats
    await fastify.prisma.creatorProfile.updateMany({
      where: { userId: template.creatorId },
      data: {
        approvedCount: { increment: 1 },
        pendingCount: { decrement: 1 },
      },
    });

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
    const { note } = req.body as { note: string };

    if (!note || note.length < 10) {
      return reply.status(400).send({ error: 'Rejection reason is required (min 10 chars)' });
    }

    const template = await fastify.prisma.template.findUnique({ where: { id } });
    if (!template) return reply.status(404).send({ error: 'Template not found' });

    const updated = await fastify.prisma.template.update({
      where: { id },
      data: {
        status: TemplateStatus.REJECTED,
        reviewedAt: new Date(),
        reviewerId: adminId,
        reviewNote: note,
      },
    });

    await fastify.prisma.auditLog.create({
      data: {
        adminId, action: 'reject_template', entityType: 'Template', entityId: id,
        after: { status: 'REJECTED', note },
      },
    });

    await fastify.prisma.creatorProfile.updateMany({
      where: { userId: template.creatorId },
      data: { rejectedCount: { increment: 1 }, pendingCount: { decrement: 1 } },
    });

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
    const { isFeatured } = req.body as { isFeatured: boolean };

    const template = await fastify.prisma.template.update({
      where: { id },
      data: { isFeatured },
    });

    await cache.del(CK.featured);
    return reply.send({ template });
  });

  // PATCH /admin/templates/:id
  fastify.patch('/templates/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = req.body as any;

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

    await cache.invalidateTemplateCache();
    return reply.send({ template });
  });

  // DELETE /admin/templates/:id (soft delete)
  fastify.delete('/templates/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    await fastify.prisma.template.update({
      where: { id },
      data: { status: TemplateStatus.ARCHIVED },
    });
    await cache.invalidateTemplateCache();
    return reply.send({ success: true });
  });

  // ── USER MANAGEMENT ────────────────────────────────────────
  fastify.get('/users', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { search, plan, language, role, isActive, page = '1', limit = '20', sortBy = 'createdAt' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 100);

    const where: any = {};
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (plan) where.plan = plan;
    if (language) where.language = language;
    if (role) where.role = role;
    if (isActive !== undefined) where.isActive = isActive === 'true';

    const [data, total] = await Promise.all([
      fastify.prisma.user.findMany({
        where,
        select: {
          id: true, name: true, email: true, plan: true, role: true,
          language: true, isActive: true, streakCount: true, totalShares: true,
          totalSaves: true, lastActiveAt: true, createdAt: true, planExpiresAt: true,
        },
        orderBy: { [sortBy]: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.user.count({ where }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  fastify.patch('/users/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = req.body as any;

    const user = await fastify.prisma.user.update({
      where: { id },
      data: {
        plan: body.plan,
        planExpiresAt: body.planExpiresAt ? new Date(body.planExpiresAt) : undefined,
        role: body.role,
        isActive: body.isActive,
      },
    });

    await cache.del(CK.userProfile(id));
    await cache.del(CK.userPlan(id));
    return reply.send({ user });
  });

  // ── CREATOR MANAGEMENT ────────────────────────────────────
  fastify.get('/creators', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { isVerified, isSuspended, page = '1', limit = '20' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 100);

    const where: any = {};
    if (isVerified !== undefined) where.isVerified = isVerified === 'true';
    if (isSuspended !== undefined) where.isSuspended = isSuspended === 'true';

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
    const body = req.body as any;

    const profile = await fastify.prisma.creatorProfile.update({
      where: { id },
      data: {
        isVerified: body.isVerified,
        verifiedAt: body.isVerified ? new Date() : undefined,
        isSuspended: body.isSuspended,
        suspendedReason: body.suspendedReason,
      },
    });

    return reply.send({ creatorProfile: profile });
  });

  // ── FESTIVAL MANAGEMENT ───────────────────────────────────
  fastify.get('/festivals', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const data = await fastify.prisma.festival.findMany({ orderBy: { date: 'asc' } });
    return reply.send({ data });
  });

  fastify.post('/festivals', { preHandler: [requireAdmin] }, async (req, reply) => {
    const body = req.body as any;
    const festival = await fastify.prisma.festival.create({
      data: {
        nameHi: body.nameHi, nameMr: body.nameMr, nameEn: body.nameEn,
        emoji: body.emoji, date: new Date(body.date),
        notifyDaysBefore: body.notifyDaysBefore ?? 2,
        isActive: true, isRecurring: body.isRecurring ?? true,
      },
    });
    await cache.del(CK.festivals);
    return reply.status(201).send({ festival });
  });

  fastify.put('/festivals/:id', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const body = req.body as any;
    const festival = await fastify.prisma.festival.update({
      where: { id },
      data: {
        nameHi: body.nameHi, nameMr: body.nameMr, nameEn: body.nameEn,
        emoji: body.emoji, isActive: body.isActive,
        date: body.date ? new Date(body.date) : undefined,
        notifyDaysBefore: body.notifyDaysBefore,
      },
    });
    await cache.del(CK.festivals);
    return reply.send({ festival });
  });

  // ── PUSH CAMPAIGNS ─────────────────────────────────────────
  fastify.get('/campaigns', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const data = await fastify.prisma.pushCampaign.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return reply.send({ data });
  });

  fastify.post('/campaigns/send', { preHandler: [requireAdmin] }, async (req, reply) => {
    const adminId = (req.user as any).userId;
    const { title, body, imageUrl, deepLink, targetSegment, scheduledAt } = req.body as any;

    const filters = OneSignalService.buildFilters(targetSegment);
    const segment = filters.length === 0 ? 'All' : undefined;

    const notifId = await OneSignalService.send({
      heading: title,
      content: body,
      imageUrl,
      data: deepLink ? { deepLink } : undefined,
      filters: filters.length > 0 ? filters : undefined,
      segment,
      scheduledAt: scheduledAt ? new Date(scheduledAt) : undefined,
    });

    const campaign = await fastify.prisma.pushCampaign.create({
      data: {
        title, body, imageUrl, deepLink, targetSegment,
        scheduledAt: scheduledAt ? new Date(scheduledAt) : null,
        sentAt: !scheduledAt ? new Date() : null,
        status: scheduledAt ? 'scheduled' : 'sent',
        oneSignalId: notifId,
        createdBy: adminId,
      },
    });

    return reply.send({ campaign, oneSignalId: notifId });
  });

  // ── ANALYTICS ─────────────────────────────────────────────
  fastify.get('/analytics/dau', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { days = '30' } = req.query as any;
    const daysAgo = new Date(Date.now() - parseInt(days) * 24 * 60 * 60 * 1000);

    const results: any[] = await fastify.prisma.$queryRaw`
      SELECT DATE("lastActiveAt") as date, COUNT(*) as count
      FROM "User"
      WHERE "lastActiveAt" >= ${daysAgo} AND "isActive" = true
      GROUP BY DATE("lastActiveAt")
      ORDER BY date ASC
    `;

    return reply.send({ data: results });
  });

  fastify.get('/analytics/searches', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { limit = '20' } = req.query as any;
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const results: any[] = await fastify.prisma.$queryRaw`
      SELECT metadata->>'query' as term, COUNT(*) as count
      FROM "AnalyticsEvent"
      WHERE event = 'search' AND "createdAt" > ${sevenDaysAgo}
        AND metadata->>'query' IS NOT NULL
      GROUP BY metadata->>'query'
      ORDER BY count DESC
      LIMIT ${parseInt(limit)}
    `;

    return reply.send({ data: results });
  });

  fastify.get('/analytics/shares', { preHandler: [requireAdmin] }, async (_req, reply) => {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const results: any[] = await fastify.prisma.$queryRaw`
      SELECT platform, COUNT(*) as count
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
    const { key, value } = req.body as { key: string; value: string };

    const config = await fastify.prisma.appConfig.update({
      where: { key },
      data: { value, updatedBy: adminId },
    });

    await cache.del(CK.appConfig);
    return reply.send({ config });
  });

  // ── AUDIT LOG ─────────────────────────────────────────────
  fastify.get('/audit-log', { preHandler: [requireAdmin] }, async (req, reply) => {
    const { page = '1', limit = '50' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 100);

    const data = await fastify.prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      skip: (p - 1) * l,
      take: l,
    });

    return reply.send({ data });
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
    const { email, name, displayName, bio } = req.body as {
      email: string;
      name: string;
      displayName?: string;
      bio?: string;
    };

    if (!email || !name) {
      return reply.status(400).send({ error: 'email and name are required' });
    }

    // Check if email already exists
    const existing = await fastify.prisma.user.findUnique({ where: { email } });

    if (existing) {
      if (existing.role === 'CREATOR') {
        return reply.status(409).send({ error: 'This email is already a Creator.' });
      }
      // Upgrade existing user to CREATOR
      const updated = await fastify.prisma.user.update({
        where: { email },
        data: { role: 'CREATOR' },
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
    });

    await fastify.prisma.creatorProfile.create({
      data: {
        userId: newUser.id,
        displayName: displayName || name,
        bio: bio || null,
        specialization: [],
      },
    });

    return reply.status(201).send({
      message: 'Creator invited successfully. They can now sign in with Google.',
      userId: newUser.id,
      email: newUser.email,
    });
  });
}
