// src/modules/user/user.route.ts
import { FastifyInstance } from 'fastify';
import { Prisma, Language } from '@prisma/client';
import { z } from 'zod';
import { CacheService } from '../../lib/cache/cache.service';
import { CK, TTL } from '../../lib/cache/keys';
import { invalidateUserCaches, safeUserSelect } from '../../lib/auth/auth-state';
import { RazorpayService } from '../../lib/payment/razorpay.service';
import { RefreshTokenStore } from '../../lib/auth/token.store';
import { httpsUrl, parsePagination, sendValidationError } from '../../lib/http/validation';
import { resolveStateFromCoords, normalizeStateCode } from '../../lib/content/state-locator';

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
  city: text(100),
  district: text(100),
  latitude: z.coerce.number().min(-90).max(90).nullable().optional(),
  longitude: z.coerce.number().min(-180).max(180).nullable().optional(),
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
        city: user.city, district: user.district,
        latitude: user.latitude, longitude: user.longitude,
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
      state, region, city, district, latitude, longitude,
      businessName, businessPhone, businessAddress, businessDesignation, businessLogo, frameType,
    } = parsed.data;

    let finalState = state;
    let finalRegion = region;
    if ((finalState === undefined || finalState === null) && latitude != null && longitude != null) {
      const detected = resolveStateFromCoords(latitude, longitude);
      if (detected) {
        finalState = detected.code;
        finalRegion = finalRegion ?? detected.code;
      }
    } else if (finalState) {
      finalState = normalizeStateCode(finalState);
    }

    const user = await fastify.prisma.user.update({
      where: { id: userId },
      data: {
        ...(name !== undefined && { name }),
        ...(displayName !== undefined && { displayName }),
        ...(language !== undefined && { language }),
        ...(timezone !== undefined && { timezone }),
        ...(profilePhoto !== undefined && { profilePhoto }),
        ...(finalState !== undefined && { state: finalState }),
        ...(finalRegion !== undefined && { region: finalRegion }),
        ...(city !== undefined && { city }),
        ...(district !== undefined && { district }),
        ...(latitude !== undefined && { latitude }),
        ...(longitude !== undefined && { longitude }),
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

  // DELETE /user/me — in-app account deletion (Google Play policy).
  // Anonymises PII, revokes sessions, removes personal content. Subscription and
  // ShareHistory rows are retained (userId kept) for accounting.
  fastify.delete('/me', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;

    const existing = await fastify.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, isActive: true, plan: true, activeRzpSubId: true },
    });
    if (!existing) return reply.status(404).send({ error: 'User not found' });
    if (existing.role !== 'USER') {
      return reply.status(403).send({
        error: 'Creator and admin accounts cannot be deleted in the app. Please contact support.',
      });
    }

    // Stop AutoPay first — a deleted account must never be charged again
    if (existing.activeRzpSubId) {
      try {
        await RazorpayService.cancelSubscription(existing.activeRzpSubId, false);
      } catch (err: any) {
        // Already cancelled / completed on Razorpay's side → nothing left to stop
        const desc = String(err?.error?.description ?? err?.message ?? '');
        if (!/cancel|complet|expired/i.test(desc)) {
          req.log.error({ err, userId }, 'Razorpay cancel failed during account deletion');
          return reply.status(502).send({ error: 'Could not cancel your active subscription. Please try again or contact support.' });
        }
      }
    }

    await new RefreshTokenStore(fastify.redis).invalidate(userId).catch(() => {});

    await fastify.prisma.$transaction([
      fastify.prisma.savedStatus.deleteMany({ where: { userId } }),
      fastify.prisma.notificationLog.deleteMany({ where: { userId } }),
      fastify.prisma.analyticsEvent.updateMany({ where: { userId }, data: { userId: null } }),
      fastify.prisma.user.update({
        where: { id: userId },
        data: {
          isActive: false,
          name: 'Deleted User',
          displayName: null,
          email: null,
          phoneNumber: null,
          googleId: null,
          password: null,
          profilePhoto: null,
          customPhotoUrl: null,
          businessName: null,
          businessPhone: null,
          businessAddress: null,
          businessDesignation: null,
          businessLogo: null,
          oneSignalPlayerId: null,
          activeRzpSubId: null,
          deviceModel: null,
          state: null,
          region: null,
          updatedAt: new Date(),
        },
      }),
      fastify.prisma.auditLog.create({
        data: {
          adminId: userId,
          action: 'USER_SELF_DELETE',
          entityType: 'User',
          entityId: userId,
          ip: req.ip,
          userAgent: (req.headers['user-agent'] ?? '').slice(0, 500) || null,
        },
      }),
    ]);

    await invalidateUserCaches(fastify.redis, userId);
    await cache.invalidatePattern(CK.userSavedPattern(userId)).catch(() => 0);
    return reply.send({ success: true });
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
