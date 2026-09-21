// src/modules/creator/creator.route.ts
import { FastifyInstance } from 'fastify';
import { TemplateStatus } from '@prisma/client';
import { CloudinaryService } from '../../lib/storage/cloudinary.service';
import { OneSignalService } from '../../lib/notification/onesignal.service';

export async function creatorRoutes(fastify: FastifyInstance) {
  const CREATOR_ROLES = ['CREATOR', 'MANAGER', 'SUPER_ADMIN'];

  const requireCreator = fastify.requireRole(CREATOR_ROLES);

  // GET /creator/templates
  fastify.get('/templates', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { status, type, page = '1', limit = '20' } = req.query as any;
    const p = parseInt(page);
    const l = Math.min(parseInt(limit), 50);

    const where: any = { creatorId: userId };
    if (status) where.status = status;
    if (type) where.type = type;

    const [data, total] = await Promise.all([
      fastify.prisma.template.findMany({
        where,
        include: { category: true },
        orderBy: { createdAt: 'desc' },
        skip: (p - 1) * l,
        take: l,
      }),
      fastify.prisma.template.count({ where }),
    ]);

    return reply.send({ data, total, page: p, limit: l });
  });

  // POST /creator/templates
  fastify.post('/templates', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;
    const body = req.body as any;

    const template = await fastify.prisma.template.create({
      data: {
        type: body.type,
        categoryId: body.categoryId,
        primaryLanguage: body.primaryLanguage ?? 'HINDI',
        status: TemplateStatus.DRAFT,
        creatorId: userId,
        gradient: body.gradient,
        tags: body.tags ?? [],
      },
    });

    return reply.status(201).send({ template });
  });

  // PUT /creator/templates/:id
  fastify.put('/templates/:id', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };
    const body = req.body as any;

    const existing = await fastify.prisma.template.findUnique({ where: { id } });
    if (!existing) return reply.status(404).send({ error: 'Template not found' });
    if (existing.creatorId !== userId) return reply.status(403).send({ error: 'Not your template' });
    if (!['DRAFT', 'REJECTED'].includes(existing.status)) {
      return reply.status(400).send({ error: 'Can only edit DRAFT or REJECTED templates' });
    }

    const template = await fastify.prisma.template.update({
      where: { id },
      data: {
        nameHi: body.nameHi, nameMr: body.nameMr, nameEn: body.nameEn,
        quoteHi: body.quoteHi, quoteMr: body.quoteMr, quoteEn: body.quoteEn,
        tags: body.tags,
        isPremium: body.isPremium,
        photoZoneEnabled: body.photoZoneEnabled,
        photoZoneX: body.photoZoneX, photoZoneY: body.photoZoneY,
        photoZoneSize: body.photoZoneSize, photoZoneShape: body.photoZoneShape,
        nameZoneEnabled: body.nameZoneEnabled,
        nameZoneX: body.nameZoneX, nameZoneY: body.nameZoneY,
        nameFontSize: body.nameFontSize, nameColor: body.nameColor,
        nameFont: body.nameFont, gradient: body.gradient,
        imageUrl: body.imageUrl, imageThumbUrl: body.imageThumbUrl,
        videoUrl: body.videoUrl, videoThumbUrl: body.videoThumbUrl,
        videoDuration: body.videoDuration, videoStreamId: body.videoStreamId,
      },
    });

    return reply.send({ template });
  });

  // POST /creator/templates/:id/submit
  fastify.post('/templates/:id/submit', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };

    const existing = await fastify.prisma.template.findUnique({ where: { id } });
    if (!existing) return reply.status(404).send({ error: 'Template not found' });
    if (existing.creatorId !== userId) return reply.status(403).send({ error: 'Not your template' });
    if (existing.status !== TemplateStatus.DRAFT) {
      return reply.status(400).send({ error: 'Only DRAFT templates can be submitted' });
    }

    // Validate required fields before submission
    const missing = [];
    if (!existing.nameHi) missing.push('nameHi');
    if (!existing.categoryId) missing.push('categoryId');
    // Must have either image or video URL
    if (!existing.imageUrl && !existing.videoUrl) missing.push('imageUrl or videoUrl');

    if (missing.length > 0) {
      return reply.status(400).send({ error: 'Missing required fields', missing });
    }

    const template = await fastify.prisma.template.update({
      where: { id },
      data: { status: TemplateStatus.PENDING, submittedAt: new Date() },
    });

    // Notify all admins
    const admins = await fastify.prisma.user.findMany({
      where: { role: { in: ['MANAGER', 'SUPER_ADMIN'] }, isActive: true },
      select: { oneSignalPlayerId: true },
    });

    const playerIds = admins.map(a => a.oneSignalPlayerId).filter(Boolean) as string[];
    if (playerIds.length > 0) {
      OneSignalService.send({
        heading: '📋 New Template Pending Review',
        content: `A new template "${existing.nameEn ?? existing.nameHi}" needs review`,
        playerIds,
        data: { screen: 'review_queue' },
      }).catch(() => {});
    }

    // Update creator stats
    await fastify.prisma.creatorProfile.updateMany({
      where: { userId },
      data: { pendingCount: { increment: 1 }, totalUploads: { increment: 1 } },
    });

    return reply.send({ template });
  });

  // DELETE /creator/templates/:id
  fastify.delete('/templates/:id', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };

    const existing = await fastify.prisma.template.findUnique({ where: { id } });
    if (!existing) return reply.status(404).send({ error: 'Template not found' });
    if (existing.creatorId !== userId) return reply.status(403).send({ error: 'Not your template' });
    if (existing.status !== 'DRAFT') return reply.status(400).send({ error: 'Only DRAFT templates can be deleted' });

    await fastify.prisma.template.delete({ where: { id } });
    return reply.send({ success: true });
  });

  // POST /creator/upload/sign-cloudinary
  fastify.post('/upload/sign-cloudinary', { 
    preHandler: [requireCreator],
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { folder = 'templates', tags } = req.body as any;

    // Security: validate folder is one of the allowed values (prevent path traversal)
    const ALLOWED_FOLDERS = ['templates', 'thumbnails'];
    const safeFolder = ALLOWED_FOLDERS.includes(folder) ? folder : 'templates';

    const timestamp = Math.round(new Date().getTime() / 1000);
    const params: Record<string, any> = {
      timestamp,
      folder: `status-go/${safeFolder}`,
      // Restrict allowed formats server-side so Cloudinary rejects invalid types
      allowed_formats: 'jpg,jpeg,png,webp,mp4',
    };

    if (Array.isArray(tags) && tags.length > 0) {
      // Validate tags are simple strings, max 20 chars each
      const safeTags = tags
        .filter((t: any) => typeof t === 'string')
        .map((t: string) => t.trim().slice(0, 20))
        .filter(Boolean)
        .slice(0, 10);
      if (safeTags.length > 0) params.tags = safeTags.join(',');
    }

    // CloudinaryService.getSignature() reads from server-side CLOUDINARY_URL env var
    // Do NOT use NEXT_PUBLIC_ prefixed vars here — they don't exist in Node.js
    const signData = await CloudinaryService.getSignature(params);

    if (!signData.apiKey || !signData.cloudName) {
      fastify.log.error('Cloudinary not configured: CLOUDINARY_URL env var is missing or invalid');
      return reply.status(503).send({ error: 'Upload service not configured' });
    }

    return reply.send({
      signature: signData.signature,
      apiKey: signData.apiKey,        // from server CLOUDINARY_URL — correct
      cloudName: signData.cloudName,  // from server CLOUDINARY_URL — correct
      folder: params.folder,
      timestamp,
    });
  });

  // GET /creator/stats
  fastify.get('/stats', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;

    const profile = await fastify.prisma.creatorProfile.findUnique({ where: { userId } });

    const topTemplates = await fastify.prisma.template.findMany({
      where: { creatorId: userId, status: 'APPROVED' },
      orderBy: { useCount: 'desc' },
      take: 5,
      include: { category: true },
    });

    return reply.send({
      totalUploads: profile?.totalUploads ?? 0,
      approved: profile?.approvedCount ?? 0,
      rejected: profile?.rejectedCount ?? 0,
      pending: profile?.pendingCount ?? 0,
      approvalRate: profile?.approvalRate ?? 0,
      totalAppUses: profile?.totalAppUses ?? 0,
      isVerified: profile?.isVerified ?? false,
      topTemplates,
    });
  });

  // GET /creator/profile
  fastify.get('/profile', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;
    const profile = await fastify.prisma.creatorProfile.findUnique({ 
      where: { userId },
      include: { user: { select: { name: true, email: true, profilePhoto: true } } }
    });
    return reply.send(profile || {});
  });

  // PATCH /creator/profile
  fastify.patch('/profile', { preHandler: [requireCreator] }, async (req, reply) => {
    const { userId } = req.user as any;
    const body = req.body as any;

    const profile = await fastify.prisma.creatorProfile.upsert({
      where: { userId },
      update: {
        displayName: body.displayName,
        bio: body.bio,
        portfolioUrl: body.portfolioUrl,
        specialization: body.specialization,
      },
      create: {
        userId,
        displayName: body.displayName || 'Anonymous Creator',
        bio: body.bio,
        portfolioUrl: body.portfolioUrl,
        specialization: body.specialization || [],
      }
    });
    return reply.send(profile);
  });
}
