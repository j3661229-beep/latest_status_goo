// src/modules/user/user.route.ts
import { FastifyInstance } from 'fastify';
import { Prisma, Language } from '@prisma/client';
import { z } from 'zod';
import { CacheService } from '../../lib/cache/cache.service';
import { CK, TTL } from '../../lib/cache/keys';
import { invalidateUserCaches, safeUserSelect } from '../../lib/auth/auth-state';
import { httpsUrl, parsePagination, sendValidationError } from '../../lib/http/validation';

/** Optional, nullable text field with a max length ('' clears the value). */
const text = (max: number) =>
  z.preprocess((v) => (v === '' ? null : v), z.string().trim().max(max).nullable().optional());

/** Optional, nullable https image URL ('' clears the value). */
const imageUrl = z.preprocess((v) => (v === '' ? null : v), httpsUrl.nullable().optional());

const UpdateMeSchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  displayName: text(100),
  language: z.preprocess(
    (v) => (typeof v === 'string' ? v.toUpperCase() : v),
    z.nativeEnum(Language).optional(),
  ),
  timezone: z.string().max(64).optional(),
  profilePhoto: imageUrl,
  state: text(100),
  region: text(100),
  businessName: text(150),
  businessPhone: text(20),
  businessAddress: text(255),
  businessDesignation: text(100),
  businessLogo: imageUrl,
  frameType: text(30),
});

const PlayerIdSchema = z.object({
  playerId: z.string().min(1).max(200),
  deviceModel: z.string().max(100).optional(),
  appVersion: z.string().max(30).optional(),
});

export async function userRoutes(fastify: FastifyInstance) {
  const cache = new CacheService(fastify.redis);

  // GET /user/me
  fastify.get('/me', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const cacheKey = CK.userProfile(userId);
    const cached = await cache.get(cacheKey);
    if (cached) return reply.send(cached);

    const user = await fastify.prisma.user.findUnique({
      where: { id: userId },
      include: {
        subscriptions: {
          where: { status: 'ACTIVE' },
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
        creatorProfile: true,
      },
    });

    if (!user) return reply.status(404).send({ error: 'User not found' });

    const planExpiresAt = user.planExpiresAt;
    const daysRemaining = planExpiresAt
      ? Math.ceil((planExpiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
      : null;

    const result = {
      user: {
        id: user.id, name: user.name, email: user.email,
        displayName: user.displayName, profilePhoto: user.profilePhoto,
        customPhotoUrl: user.customPhotoUrl, language: user.language,
        state: user.state, region: user.region,
        businessName: user.businessName, businessPhone: user.businessPhone,
        businessAddress: user.businessAddress, businessDesignation: user.businessDesignation,
        businessLogo: user.businessLogo, frameType: user.frameType,
        plan: user.plan, role: user.role, streakCount: user.streakCount,
        totalShares: user.totalShares, totalSaves: user.totalSaves,
        lastActiveAt: user.lastActiveAt, createdAt: user.createdAt,
      },
      plan: {
        status: user.plan,
        expiresAt: planExpiresAt,
        daysRemaining,
        features: {
          unlimitedImages: user.plan !== 'FREE',
          unlimitedVideos: user.plan !== 'FREE',
          festivalPacks: user.plan !== 'FREE',
          noAds: true,
        },
      },
      streak: user.streakCount,
      isCreator: !!user.creatorProfile,
    };

    await cache.set(cacheKey, result, TTL.userProfile);
    return reply.send(result);
  });

  // PUT /user/me
  fastify.put('/me', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = UpdateMeSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid profile data');
    const {
      name, displayName, language, timezone, profilePhoto,
      state, region,
      businessName, businessPhone, businessAddress, businessDesignation, businessLogo, frameType,
    } = parsed.data;

    const user = await fastify.prisma.user.update({
      where: { id: userId },
      data: {
        ...(name !== undefined && { name }),
        ...(displayName !== undefined && { displayName }),
        ...(language !== undefined && { language }),
        ...(timezone !== undefined && { timezone }),
        ...(profilePhoto !== undefined && { profilePhoto }),
        ...(state !== undefined && { state }),
        ...(region !== undefined && { region }),
        ...(businessName !== undefined && { businessName }),
        ...(businessPhone !== undefined && { businessPhone }),
        ...(businessAddress !== undefined && { businessAddress }),
        ...(businessDesignation !== undefined && { businessDesignation }),
        ...(businessLogo !== undefined && { businessLogo }),
        ...(frameType !== undefined && { frameType }),
        updatedAt: new Date(),
      },
      select: safeUserSelect, // never return the password hash
    });

    await invalidateUserCaches(fastify.redis, userId);
    return reply.send({ user });
  });

  // PUT /user/player-id
  fastify.put('/player-id', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = PlayerIdSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { playerId, deviceModel, appVersion } = parsed.data;

    await fastify.prisma.user.update({
      where: { id: userId },
      data: {
        oneSignalPlayerId: playerId,
        ...(deviceModel && { deviceModel }),
        ...(appVersion && { appVersion }),
      },
    });

    return reply.send({ success: true });
  });

  // GET /user/notifications
  fastify.get('/notifications', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });

    const [notifications, total, unreadCount] = await Promise.all([
      fastify.prisma.notificationLog.findMany({
        where: { userId },
        orderBy: { sentAt: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.notificationLog.count({ where: { userId } }),
      fastify.prisma.notificationLog.count({ where: { userId, isRead: false } }),
    ]);

    return reply.send({
      data: notifications,
      total,
      unreadCount,
      page: p,
      limit: l,
      hasMore: (p - 1) * l + notifications.length < total,
    });
  });

  // PUT /user/notifications/:id/read
  fastify.put('/notifications/:id/read', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };

    await fastify.prisma.notificationLog.updateMany({
      where: { id, userId },
      data: { isRead: true, readAt: new Date() },
    });

    const unreadCount = await fastify.prisma.notificationLog.count({
      where: { userId, isRead: false },
    });

    return reply.send({ success: true, unreadCount });
  });

  // PUT /user/notifications/read-all
  fastify.put('/notifications/read-all', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;

    await fastify.prisma.notificationLog.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });

    return reply.send({ success: true, unreadCount: 0 });
  });

  // DELETE /user/notifications/:id
  fastify.delete('/notifications/:id', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };

    await fastify.prisma.notificationLog.deleteMany({
      where: { id, userId },
    });

    return reply.send({ success: true });
  });

  // GET /user/saved
  fastify.get('/saved', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });

    const cacheKey = CK.userSaved(userId, p, l);
    const cached = await cache.get(cacheKey);
    if (cached) return reply.send(cached);

    const [data, total] = await Promise.all([
      fastify.prisma.savedStatus.findMany({
        where: { userId },
        include: { template: { include: { category: true } } },
        orderBy: { savedAt: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.savedStatus.count({ where: { userId } }),
    ]);

    const result = {
      data: data.map(s => s.template),
      total, page: p, limit: l,
      hasMore: (p - 1) * l + data.length < total,
    };
    await cache.set(cacheKey, result, TTL.userSaved);
    return reply.send(result);
  });

  // POST /user/saved/:templateId
  fastify.post('/saved/:templateId', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { templateId } = req.params as { templateId: string };

    try {
      await fastify.prisma.savedStatus.create({ data: { userId, templateId } });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError) {
        // Already saved → idempotent success without bumping saveCount again
        if (err.code === 'P2002') return reply.send({ saved: true });
        // Unknown template id
        if (err.code === 'P2003') return reply.status(404).send({ error: 'Template not found' });
      }
      throw err;
    }

    fastify.prisma.template.update({
      where: { id: templateId },
      data: { saveCount: { increment: 1 } },
    }).catch(() => {});

    await cache.invalidatePattern(CK.userSavedPattern(userId)).catch(() => 0);
    return reply.send({ saved: true });
  });

  // DELETE /user/saved/:templateId
  fastify.delete('/saved/:templateId', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { templateId } = req.params as { templateId: string };

    const { count } = await fastify.prisma.savedStatus.deleteMany({ where: { userId, templateId } });

    // Only decrement when something was actually removed; GREATEST keeps it >= 0
    if (count > 0) {
      fastify.prisma.$executeRaw`
        UPDATE "Template"
        SET "saveCount" = GREATEST(0, "saveCount" - 1)
        WHERE id = ${templateId}
      `.catch((err: Error) => fastify.log.warn({ err, templateId }, 'saveCount decrement failed'));
    }

    await cache.invalidatePattern(CK.userSavedPattern(userId)).catch(() => 0);

    return reply.send({ saved: false });
  });

  // GET /user/history
  fastify.get('/history', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });

    const [data, total] = await Promise.all([
      fastify.prisma.shareHistory.findMany({
        where: { userId },
        include: { template: { include: { category: true } } },
        orderBy: { sharedAt: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.shareHistory.count({ where: { userId } }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });
}
