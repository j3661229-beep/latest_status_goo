// src/modules/creator/creator.route.ts
import { FastifyInstance } from 'fastify';
import { TemplateStatus, TemplateType, Language } from '@prisma/client';
import { z } from 'zod';
import { CloudinaryService } from '../../lib/storage/cloudinary.service';
import { OneSignalService } from '../../lib/notification/onesignal.service';
import { CacheService } from '../../lib/cache/cache.service';
import { CREATOR_ROLES, requireNotSuspended } from '../../lib/auth/guards';
import { invalidateUserCaches } from '../../lib/auth/auth-state';
import { env } from '../../config/env';
import {
  httpsUrl, optionalEnum, parsePagination, sendValidationError,
} from '../../lib/http/validation';

// Formats Cloudinary will accept for creator signed uploads
const CLOUDINARY_ALLOWED_FORMATS = 'jpg,jpeg,png,webp,mp4';

const tagsSchema = z.array(z.string().trim().min(1).max(50)).max(20);
/** Optional nullable text ('' → null). */
const text = (max: number) => z.preprocess((v) => (v === '' ? null : v), z.string().max(max).nullable().optional());
/** Optional nullable media URL ('' → null). */
const mediaUrl = z.preprocess((v) => (v === '' ? null : v), httpsUrl.nullable().optional());
const ratio = z.number().min(0).max(1).nullable().optional();

const ListQuerySchema = z.object({
  status: optionalEnum(['DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'ARCHIVED']),
  type: optionalEnum(['IMAGE', 'VIDEO']),
});

// NOTE: creators can never set isPremium / isFeatured / isTrending / coordinator fields —
// unknown keys are stripped by zod, so those flags stay admin-only.
const CreateTemplateSchema = z.object({
  type: z.nativeEnum(TemplateType),
  categoryId: z.string().min(1).max(64),
  primaryLanguage: z.nativeEnum(Language).optional(),
  gradient: text(500),
  tags: tagsSchema.optional(),
});

const UpdateTemplateSchema = z.object({
  type: z.nativeEnum(TemplateType).optional(),
  categoryId: z.string().min(1).max(64).optional(),
  primaryLanguage: z.nativeEnum(Language).optional(),
  nameHi: text(100), nameMr: text(100), nameEn: text(100),
  quoteHi: text(5000), quoteMr: text(5000), quoteEn: text(5000),
  tags: tagsSchema.optional(),
  photoZoneEnabled: z.boolean().optional(),
  photoZoneX: ratio, photoZoneY: ratio, photoZoneSize: ratio,
  photoZoneShape: text(20),
  fitMode: z.enum(['contain', 'cover']).optional(),
  nameZoneEnabled: z.boolean().optional(),
  nameZoneX: ratio, nameZoneY: ratio,
  nameFontSize: z.number().min(0).max(1).nullable().optional(),
  nameColor: text(20),
  nameFont: text(50),
  gradient: text(500),
  imageUrl: mediaUrl, imageThumbUrl: mediaUrl,
  videoUrl: mediaUrl, videoThumbUrl: mediaUrl,
  videoDuration: z.number().int().min(0).max(600).nullable().optional(),
  videoStreamId: text(200),
});

const ProfileSchema = z.object({
  displayName: z.string().trim().min(1).max(100).optional(),
  bio: text(500),
  portfolioUrl: z.preprocess((v) => (v === '' ? null : v), httpsUrl.nullable().optional()),
  specialization: z.array(z.string().trim().min(1).max(50)).max(10).optional(),
});

export async function creatorRoutes(fastify: FastifyInstance) {
  const requireCreator = [fastify.requireRole(CREATOR_ROLES), requireNotSuspended];
  const cache = new CacheService(fastify.redis);

  // GET /creator/templates
  fastify.get('/templates', { preHandler: requireCreator }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = ListQuerySchema.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid query');
    const { page: p, limit: l } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });

    const where: any = { creatorId: userId };
    if (parsed.data.status) where.status = parsed.data.status;
    if (parsed.data.type) where.type = parsed.data.type;

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
  fastify.post('/templates', { preHandler: requireCreator }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = CreateTemplateSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid template');
    const body = parsed.data;

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
  fastify.put('/templates/:id', { preHandler: requireCreator }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };
    const parsed = UpdateTemplateSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid template');
    const body = parsed.data;

    const existing = await fastify.prisma.template.findUnique({ where: { id } });
    if (!existing) return reply.status(404).send({ error: 'Template not found' });
    if (existing.creatorId !== userId) return reply.status(403).send({ error: 'Not your template' });
    if (!['DRAFT', 'REJECTED'].includes(existing.status)) {
      return reply.status(400).send({ error: 'Can only edit DRAFT or REJECTED templates' });
    }

    // Prisma ignores `undefined`, so omitted fields (incl. tags) are left untouched
    const template = await fastify.prisma.template.update({
      where: { id },
      data: {
        type: body.type,
        categoryId: body.categoryId,
        primaryLanguage: body.primaryLanguage,
        nameHi: body.nameHi, nameMr: body.nameMr, nameEn: body.nameEn,
        quoteHi: body.quoteHi, quoteMr: body.quoteMr, quoteEn: body.quoteEn,
        tags: body.tags,
        photoZoneEnabled: body.photoZoneEnabled,
        photoZoneX: body.photoZoneX, photoZoneY: body.photoZoneY,
        photoZoneSize: body.photoZoneSize, photoZoneShape: body.photoZoneShape,
        fitMode: body.fitMode,
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
  fastify.post('/templates/:id/submit', { preHandler: requireCreator }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };

    const existing = await fastify.prisma.template.findUnique({ where: { id } });
    if (!existing) return reply.status(404).send({ error: 'Template not found' });
    if (existing.creatorId !== userId) return reply.status(403).send({ error: 'Not your template' });
    if (!['DRAFT', 'REJECTED'].includes(existing.status)) {
      return reply.status(400).send({ error: 'Only DRAFT or REJECTED templates can be submitted' });
    }

    // Validate required fields before submission
    const missing = [];
    if (!existing.nameHi && !existing.nameEn && !existing.nameMr) missing.push('name (nameHi, nameEn or nameMr)');
    if (!existing.categoryId) missing.push('categoryId');
    // Must have either image or video URL
    if (!existing.imageUrl && !existing.videoUrl) missing.push('imageUrl or videoUrl');

    if (missing.length > 0) {
      return reply.status(400).send({ error: 'Missing required fields', missing });
    }

    const autoApprove = env.AUTO_APPROVE_TEMPLATES;
    const isFirstSubmission = existing.status === 'DRAFT';

    // Default: send to the moderation queue. AUTO_APPROVE_TEMPLATES=true publishes immediately.
    // Conditional on the status we read, so concurrent double-submits can't both count
    const { count: moved } = await fastify.prisma.template.updateMany({
      where: { id, creatorId: userId, status: existing.status },
      data: autoApprove
        ? { status: TemplateStatus.APPROVED, submittedAt: new Date(), reviewedAt: new Date(), reviewNote: null }
        : { status: TemplateStatus.PENDING, submittedAt: new Date(), reviewedAt: null, reviewNote: null },
    });
    if (moved === 0) return reply.status(409).send({ error: 'Template was already submitted' });
    const template = await fastify.prisma.template.findUniqueOrThrow({ where: { id } });

    // Update creator stats
    await fastify.prisma.creatorProfile.updateMany({
      where: { userId },
      data: {
        ...(autoApprove ? { approvedCount: { increment: 1 } } : { pendingCount: { increment: 1 } }),
        ...(isFirstSubmission && { totalUploads: { increment: 1 } }),
      },
    });

    if (autoApprove) {
      await cache.invalidateTemplateCache(id);
    }

    // Notify all admins
    const admins = await fastify.prisma.user.findMany({
      where: { role: { in: ['MANAGER', 'SUPER_ADMIN'] }, isActive: true },
      select: { oneSignalPlayerId: true },
    });

    const playerIds = admins.map(a => a.oneSignalPlayerId).filter(Boolean) as string[];
    if (playerIds.length > 0) {
      const name = existing.nameEn ?? existing.nameHi;
      OneSignalService.send(autoApprove
        ? {
            heading: '📋 New Template Live',
            content: `A new template "${name}" is now live`,
            playerIds,
            data: { screen: 'templates' },
          }
        : {
            heading: '📋 New Template Pending Review',
            content: `A new template "${name}" needs review`,
            playerIds,
            data: { screen: 'review_queue' },
          }).catch(() => {});
    }

    return reply.send({ template });
  });

  // DELETE /creator/templates/:id
  fastify.delete('/templates/:id', { preHandler: requireCreator }, async (req, reply) => {
    const { userId } = req.user as any;
    const { id } = req.params as { id: string };

    const existing = await fastify.prisma.template.findUnique({ where: { id } });
    if (!existing) return reply.status(404).send({ error: 'Template not found' });
    if (existing.creatorId !== userId) return reply.status(403).send({ error: 'Not your template' });
    if (existing.status !== 'DRAFT') return reply.status(400).send({ error: 'Only DRAFT templates can be deleted' });

    await fastify.prisma.template.delete({ where: { id } });
    await cache.invalidateTemplateCache(id);
    return reply.send({ success: true });
  });

  // POST /creator/upload/sign-cloudinary
  fastify.post('/upload/sign-cloudinary', {
    preHandler: requireCreator,
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
  }, async (req, reply) => {
    const { folder = 'templates', tags } = (req.body as any) ?? {};

    // Security: validate folder is one of the allowed values (prevent path traversal)
    const ALLOWED_FOLDERS = ['templates', 'thumbnails'];
    const safeFolder = ALLOWED_FOLDERS.includes(folder) ? folder : 'templates';

    const timestamp = Math.round(new Date().getTime() / 1000);
    const params: Record<string, any> = {
      timestamp,
      folder: `status-go/${safeFolder}`,
      // Restrict allowed formats server-side so Cloudinary rejects invalid types.
      // Clients must send `allowed_formats` (returned below) with the upload.
      allowed_formats: CLOUDINARY_ALLOWED_FORMATS,
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
      allowedFormats: CLOUDINARY_ALLOWED_FORMATS,
      ...(params.tags && { tags: params.tags }),
    });
  });

  // GET /creator/stats
  fastify.get('/stats', { preHandler: requireCreator }, async (req, reply) => {
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
  fastify.get('/profile', { preHandler: requireCreator }, async (req, reply) => {
    const { userId } = req.user as any;
    const profile = await fastify.prisma.creatorProfile.findUnique({
      where: { userId },
      include: { user: { select: { name: true, email: true, profilePhoto: true } } }
    });
    return reply.send(profile || {});
  });

  // PATCH /creator/profile
  fastify.patch('/profile', { preHandler: requireCreator }, async (req, reply) => {
    const { userId } = req.user as any;
    const parsed = ProfileSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error, 'Invalid profile');
    const body = parsed.data;

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
    await invalidateUserCaches(fastify.redis, userId);
    return reply.send(profile);
  });
}
