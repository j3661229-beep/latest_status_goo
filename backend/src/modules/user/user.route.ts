// src/modules/user/user.route.ts
import { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import type { Redis } from 'ioredis';
import { CacheService } from '../../lib/cache/cache.service';
import { CK, TTL } from '../../lib/cache/keys';

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
    const {
      name, displayName, language, timezone, profilePhoto,
      state, region,
      businessName, businessPhone, businessAddress, businessDesignation, businessLogo, frameType,
    } = req.body as any;

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
    });

    await cache.del(CK.userProfile(userId));
    return reply.send({ user });
  });

  // PUT /user/player-id
  fastify.put('/player-id', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { playerId } = req.body as { playerId: string };

    await fastify.prisma.user.update({
      where: { id: userId },
      data: { oneSignalPlayerId: playerId },
    });

    return reply.send({ success: true });
  });

  // GET /user/saved
  fastify.get('/saved', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { page = '1', limit = '20' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 50);

    const cacheKey = CK.userSaved(userId, p);
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

    await fastify.prisma.savedStatus.upsert({
      where: { userId_templateId: { userId, templateId } },
      update: {},
      create: { userId, templateId },
    });

    fastify.prisma.template.update({
      where: { id: templateId },
      data: { saveCount: { increment: 1 } },
    }).catch(() => {});

    await cache.invalidatePattern(CK.userSaved(userId, 0).replace(':p0', ':p*'));
    return reply.send({ saved: true });
  });

  // DELETE /user/saved/:templateId
  fastify.delete('/saved/:templateId', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { templateId } = req.params as { templateId: string };

    await fastify.prisma.savedStatus.deleteMany({ where: { userId, templateId } });

    // Use GREATEST(0, saveCount-1) to prevent saveCount going negative
    // This is safe even if called multiple times (idempotent floor at 0)
    fastify.prisma.$executeRaw`
      UPDATE "Template"
      SET "saveCount" = GREATEST(0, "saveCount" - 1)
      WHERE id = ${templateId}
    `.catch((err: Error) => fastify.log.warn({ err, templateId }, 'saveCount decrement failed'));

    return reply.send({ saved: false });
  });

  // GET /user/history
  fastify.get('/history', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { page = '1', limit = '20' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 50);

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
