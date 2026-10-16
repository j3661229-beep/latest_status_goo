// src/modules/content-admin/content.admin.route.ts
// Admin API for the AI Shorts editorial workflow (Sarkari Yojana + Daily News).
// Every route requires MANAGER / SUPER_ADMIN. Creators have no access.
// Every state change goes through `move()`: lifecycle rules + hard publish blockers +
// optimistic locking + append-only ContentReview + AuditLog.
import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { ContentStatus, Prisma } from '@prisma/client';
import { z } from 'zod';
import { optionalEnum, optionalString, parsePagination, sendValidationError, httpsUrl } from '../../lib/http/validation';
import { resolveAssetUrl } from '../../lib/content/assets';
import { contentConfig } from '../../lib/content/config';
import { hostAllowed } from '../../lib/content/safe-fetch';
import { collectAttention } from '../../lib/content/freshness';
import { loadSettings, saveSettings, SettingsPatchSchema } from '../../lib/content/settings';
import { canTransition, publishBlockers } from '../../lib/content/lifecycle';
import {
  contentWarnings, newsFreshnessBlocker, DEFAULT_THRESHOLDS, WarningThresholds,
} from '../../lib/content/warnings';

export const CONTENT_ADMIN_ROLES = ['MANAGER', 'SUPER_ADMIN'];

const STATUSES = [
  'DRAFT', 'SOURCE_VERIFIED', 'SCRIPT_READY', 'GENERATING', 'GENERATED', 'NEEDS_REVIEW', 'APPROVED',
  'PUBLISHED', 'FAILED', 'REJECTED', 'EXPIRED', 'CORRECTION_REQUIRED', 'UNPUBLISHED',
] as const;

const IdParams = z.object({ id: z.string().min(1).max(64) });
const ReasonBody = z.object({ reason: z.string().trim().min(10).max(1000) });
const OptReasonBody = z.object({ reason: z.string().trim().max(1000).optional() });

const QueueQuery = z.object({
  status: optionalEnum([...STATUSES]),
  kind: optionalEnum(['SCHEME', 'NEWS']),
  category: optionalString(64),
  search: optionalString(100),
});

const EditBody = z
  .object({
    title: z.string().trim().min(3).max(200),
    hook: z.string().trim().max(300).nullable(),
    description: z.string().trim().max(2000).nullable(),
    attribution: z.string().trim().max(500).nullable(),
    script: z.object({ narration: z.string().trim().min(10).max(2500) }).passthrough(),
    captions: z
      .array(z.object({ start: z.number().min(0).optional(), end: z.number().min(0).optional(), text: z.string().trim().min(1).max(200) }))
      .max(200),
    claims: z
      .array(z.object({ text: z.string().min(1).max(500), sourceUrl: httpsUrl, sourceQuote: z.string().max(1000).optional() }))
      .max(50),
    expiresAt: z.string().datetime().nullable(),
  })
  .partial()
  .refine((b) => Object.keys(b).length > 0, { message: 'No fields to update' });

const PublishBody = z.object({
  reason: z.string().trim().max(1000).optional(),
  scheduledAt: z.string().datetime().optional(),
});

const CorrectBody = z.object({
  note: z.string().trim().min(10).max(1000),
  /** true → withdraw entirely (unpublish + mark source withdrawn); false → take down for correction. */
  withdraw: z.boolean().default(false),
});

const SchemeBody = z.object({
  slug: z.string().trim().min(3).max(100).regex(/^[a-z0-9-]+$/),
  officialName: z.string().trim().min(3).max(300),
  nameHi: z.string().trim().min(2).max(300),
  category: z.string().trim().min(2).max(64),
  scope: z.enum(['CENTRAL', 'STATE']).default('CENTRAL'),
  stateCode: z.string().trim().max(8).nullable().optional(),
  department: z.string().trim().max(300).nullable().optional(),
  benefits: z.array(z.string().trim().min(1).max(500)).max(30).default([]),
  eligibility: z.array(z.string().trim().min(1).max(500)).max(30).default([]),
  documents: z.array(z.string().trim().min(1).max(300)).max(30).default([]),
  applicationSteps: z.array(z.string().trim().min(1).max(500)).max(30).default([]),
  applicationMode: z.enum(['ONLINE', 'OFFLINE', 'BOTH']).nullable().optional(),
  applicationUrl: httpsUrl.nullable().optional(),
  sourceUrls: z.array(httpsUrl).max(20).default([]),
  sourceUpdatedAt: z.string().datetime().nullable().optional(),
  nextReviewAt: z.string().datetime().nullable().optional(),
  expiresAt: z.string().datetime().nullable().optional(),
});

const DraftBody = z
  .object({
    kind: z.enum(['SCHEME', 'NEWS']),
    schemeId: z.string().max(64).optional(),
    newsStoryId: z.string().max(64).optional(),
    title: z.string().trim().min(3).max(200),
    category: z.string().trim().min(2).max(64),
    region: z.string().trim().max(8).nullable().optional(),
  })
  .refine((b) => (b.kind === 'SCHEME' ? !!b.schemeId : !!b.newsStoryId), {
    message: 'schemeId (SCHEME) or newsStoryId (NEWS) is required',
  });

const fullInclude = { scheme: true, newsStory: true } satisfies Prisma.ShortVideoInclude;
type Full = Prisma.ShortVideoGetPayload<{ include: typeof fullInclude }>;

/** Fields whose change invalidates already-rendered audio/video. */
const RENDER_AFFECTING = ['script', 'captions', 'title', 'hook'] as const;
/** States where the script/claims may be edited. */
const EDITABLE: ContentStatus[] = ['DRAFT', 'SOURCE_VERIFIED', 'SCRIPT_READY', 'NEEDS_REVIEW', 'CORRECTION_REQUIRED', 'FAILED'];

export interface ContentAdminOptions {
  /** Queues the next pipeline stage; defaults to BullMQ. Injectable so tests need no Redis. */
  startGeneration?: (videoId: string) => Promise<string | null>;
  /** Asks the worker to ingest now; defaults to BullMQ. */
  requestIngest?: () => Promise<void>;
}

export async function contentAdminRoutes(fastify: FastifyInstance, opts: ContentAdminOptions = {}) {
  const prisma = fastify.prisma;
  const guard = { preHandler: [fastify.requireRole(CONTENT_ADMIN_ROLES)] };
  const toJson = (v: unknown) => JSON.parse(JSON.stringify(v ?? null)) as Prisma.InputJsonValue;
  const start = opts.startGeneration ?? (async (id: string) => (await import('../../lib/content/queue')).startGeneration(prisma, id));
  const requestIngest = opts.requestIngest ?? (async () => (await import('../../lib/content/queue')).requestIngestNow());
  const actor = (req: FastifyRequest) => (req.user as any).userId as string;

  async function thresholds(): Promise<WarningThresholds> {
    const rows = await prisma.appConfig.findMany({ where: { key: { startsWith: 'content.' } } });
    const num = (k: string, d: number) => {
      const n = Number(rows.find((r) => r.key === k)?.value);
      return Number.isFinite(n) && n > 0 ? n : d;
    };
    return {
      schemeVerifyMaxAgeDays: num('content.scheme_verify_max_age_days', DEFAULT_THRESHOLDS.schemeVerifyMaxAgeDays),
      newsStaleHours: num('content.news_stale_hours', DEFAULT_THRESHOLDS.newsStaleHours),
      developingFreshHours: num('content.developing_fresh_hours', DEFAULT_THRESHOLDS.developingFreshHours),
    };
  }

  async function audit(req: FastifyRequest, action: string, id: string, before?: unknown, after?: unknown, entityType = 'ShortVideo') {
    try {
      await prisma.auditLog.create({
        data: {
          adminId: actor(req), action, entityType, entityId: id,
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

  const err = (reply: FastifyReply, code: number, message: string, extra: object = {}) =>
    reply.status(code).send({ statusCode: code, error: code === 404 ? 'Not Found' : code === 409 ? 'Conflict' : 'Unprocessable', message, ...extra });

  const present = async (v: Full) => ({
    ...v,
    warnings: contentWarnings(v as any, await thresholds()),
    publishBlockers: publishBlockers(v as any),
  });

  /**
   * Single entry point for every status change.
   * Idempotent: repeating a request that already reached the target state returns 200.
   */
  async function move(
    req: FastifyRequest, reply: FastifyReply, id: string, to: ContentStatus, action: string,
    opts: { reason?: string; data?: Prisma.ShortVideoUpdateInput; check?: (v: Full) => string[] | Promise<string[]> } = {},
  ) {
    const v = await prisma.shortVideo.findUnique({ where: { id }, include: fullInclude });
    if (!v) return err(reply, 404, 'Content not found');
    if (v.status === to) return reply.send({ data: await present(v), unchanged: true });
    if (!canTransition(v.status, to)) return err(reply, 409, `Cannot move content from ${v.status} to ${to}`);
    const problems = (await opts.check?.(v)) ?? [];
    if (problems.length) return err(reply, 422, 'Content failed pre-flight checks', { problems });

    const updated = await prisma.$transaction(async (tx) => {
      // Optimistic lock: only succeeds if nobody else moved it since we read it.
      const res = await tx.shortVideo.updateMany({ where: { id, status: v.status }, data: { status: to } });
      if (res.count === 0) return null;
      if (opts.data) await tx.shortVideo.update({ where: { id }, data: opts.data });
      await tx.contentReview.create({
        data: { shortVideoId: id, actorId: actor(req), action, reason: opts.reason ?? null,
                before: { status: v.status }, after: { status: to } },
      });
      return tx.shortVideo.findUnique({ where: { id }, include: fullInclude });
    });
    if (!updated) return err(reply, 409, 'Content was changed by someone else — reload and retry');
    await audit(req, `content.${action}`, id, { status: v.status }, { status: to, reason: opts.reason });
    return reply.send({ data: await present(updated) });
  }

  // ── Queue / detail ───────────────────────────────────────────
  fastify.get('/content/review-queue', guard, async (req, reply) => {
    const q = QueueQuery.safeParse(req.query ?? {});
    if (!q.success) return sendValidationError(reply, q.error);
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const where: Prisma.ShortVideoWhereInput = {
      status: q.data.status ?? 'NEEDS_REVIEW',
      ...(q.data.kind && { kind: q.data.kind }),
      ...(q.data.category && { category: q.data.category }),
      ...(q.data.search && { title: { contains: q.data.search, mode: 'insensitive' } }),
    };
    const [rows, total] = await Promise.all([
      prisma.shortVideo.findMany({ where, include: fullInclude, orderBy: { updatedAt: 'asc' }, skip, take: limit }),
      prisma.shortVideo.count({ where }),
    ]);
    const t = await thresholds();
    const data = rows.map((r) => ({ ...r, warnings: contentWarnings(r as any, t) }));
    return reply.send({ data, meta: { page, limit, total } });
  });

  fastify.get('/content/status-counts', guard, async (_req, reply) => {
    const groups = await prisma.shortVideo.groupBy({ by: ['status', 'kind'], _count: { _all: true } });
    return reply.send({ data: groups.map((g) => ({ status: g.status, kind: g.kind, count: g._count._all })) });
  });

  fastify.get('/content/reports', guard, async (req, reply) => {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const status = (req.query as any)?.status === 'RESOLVED' ? 'RESOLVED' : (req.query as any)?.status === 'DISMISSED' ? 'DISMISSED' : 'OPEN';
    const data = await prisma.contentReport.findMany({
      where: { status }, orderBy: { createdAt: 'desc' }, skip, take: limit,
      include: { shortVideo: { select: { id: true, title: true, kind: true, status: true } } },
    });
    return reply.send({ data, meta: { page, limit } });
  });

  fastify.post('/content/reports/:id/resolve', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    const b = z.object({ status: z.enum(['RESOLVED', 'DISMISSED']) }).safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const res = await prisma.contentReport.updateMany({ where: { id: p.data.id }, data: { status: b.data.status } });
    if (res.count === 0) return err(reply, 404, 'Report not found');
    await audit(req, `content.report.${b.data.status.toLowerCase()}`, p.data.id);
    return reply.send({ ok: true });
  });

  fastify.get('/content/jobs', guard, async (req, reply) => {
    const q = z.object({
      state: optionalEnum(['QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED']),
      shortVideoId: optionalString(64),
    }).safeParse(req.query ?? {});
    if (!q.success) return sendValidationError(reply, q.error);
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 30, maxLimit: 100 });
    const where: Prisma.ContentJobWhereInput = { ...(q.data.state && { state: q.data.state }), ...(q.data.shortVideoId && { shortVideoId: q.data.shortVideoId }) };
    const [data, total] = await Promise.all([
      prisma.contentJob.findMany({ where, orderBy: { queuedAt: 'desc' }, skip, take: limit }),
      prisma.contentJob.count({ where }),
    ]);
    return reply.send({ data, meta: { page, limit, total } });
  });

  fastify.get('/content/costs', guard, async (_req, reply) => {
    const monthStart = new Date(); monthStart.setUTCDate(1); monthStart.setUTCHours(0, 0, 0, 0);
    const [byStatus, jobs, month, published] = await Promise.all([
      prisma.shortVideo.groupBy({ by: ['status'], _sum: { costMicroUsd: true }, _count: { _all: true } }),
      prisma.contentJob.aggregate({ _sum: { costMicroUsd: true }, where: { state: 'FAILED' } }),
      prisma.shortVideo.aggregate({ _sum: { costMicroUsd: true }, where: { createdAt: { gte: monthStart } } }),
      prisma.shortVideo.aggregate({ _sum: { costMicroUsd: true, viewCount: true }, _count: { _all: true }, where: { status: 'PUBLISHED' } }),
    ]);
    const pubCost = published._sum.costMicroUsd ?? 0;
    const views = published._sum.viewCount ?? 0;
    return reply.send({
      data: {
        unit: 'micro-USD (estimates; pricing is configurable, not authoritative billing)',
        byStatus: byStatus.map((g) => ({ status: g.status, count: g._count._all, costMicroUsd: g._sum.costMicroUsd ?? 0 })),
        failedJobsCostMicroUsd: jobs._sum.costMicroUsd ?? 0,
        thisMonthMicroUsd: month._sum.costMicroUsd ?? 0,
        perPublishedVideoMicroUsd: published._count._all ? Math.round(pubCost / published._count._all) : null,
        per1000ViewsMicroUsd: views > 0 ? Math.round((pubCost / views) * 1000) : null,
      },
    });
  });

  // ── Schedule / freshness settings ────────────────────────────
  fastify.get('/content/settings', guard, async (_req, reply) => {
    const settings = await loadSettings(prisma);
    const hosts = contentConfig().sourceHosts;
    return reply.send({
      data: settings,
      // Feeds only work if their host is on the operator allowlist (CONTENT_SOURCE_HOSTS env).
      sourceHostsConfigured: hosts.length > 0,
      blockedFeeds: settings.feeds.filter((f) => { try { return !hostAllowed(new URL(f.url).hostname, hosts); } catch { return true; } }).map((f) => f.url),
    });
  });

  fastify.put('/content/settings', guard, async (req, reply) => {
    const b = SettingsPatchSchema.safeParse(req.body ?? {});
    if (!b.success) return sendValidationError(reply, b.error);
    const before = await loadSettings(prisma);
    await saveSettings(prisma, b.data, actor(req));
    await audit(req, 'content.settings.update', 'content', before, b.data, 'ContentSettings');
    return reply.send({ data: await loadSettings(prisma) });
  });

  fastify.post('/content/ingest/run', { ...guard, config: { rateLimit: { max: 6, timeWindow: '1 minute' } } }, async (req, reply) => {
    const s = await loadSettings(prisma);
    if (s.feeds.length === 0) return err(reply, 422, 'No news feeds configured', { problems: ['Add at least one feed in settings first'] });
    try {
      await requestIngest();
    } catch (e) {
      req.log.error({ err: e }, 'failed to enqueue ingest');
      return err(reply, 503, 'Worker queue unavailable');
    }
    await audit(req, 'content.ingest.run', 'ingest', undefined, undefined, 'ContentSettings');
    return reply.status(202).send({ queued: true });
  });

  /** What needs a human: overdue scheme verification, slow review queue, open user reports. */
  fastify.get('/content/attention', guard, async (_req, reply) => {
    const s = await loadSettings(prisma);
    return reply.send({ data: await collectAttention(prisma, s, new Date()) });
  });

  /** Is the always-on worker alive, and is the pipeline failing? Drives the dashboard health banner. */
  fastify.get('/content/health', guard, async (_req, reply) => {
    let heartbeat: { at: string; report?: unknown } | null = null;
    try {
      const raw = await fastify.redis?.get('content:worker:heartbeat');
      heartbeat = raw ? JSON.parse(raw) : null;
    } catch { /* redis down → reported as no heartbeat */ }
    const lastTickAt = heartbeat?.at ? new Date(heartbeat.at) : null;
    const since = new Date(Date.now() - 24 * 3_600_000);
    const [failedJobs24h, stuckGenerating] = await Promise.all([
      prisma.contentJob.count({ where: { state: 'FAILED', queuedAt: { gte: since } } }),
      prisma.shortVideo.count({ where: { status: 'GENERATING', updatedAt: { lt: new Date(Date.now() - 3_600_000) } } }),
    ]);
    return reply.send({
      data: {
        // Ticks run every 5 minutes; allow three missed before calling the worker down.
        workerAlive: !!lastTickAt && Date.now() - lastTickAt.getTime() < 15 * 60_000,
        lastTickAt, lastReport: heartbeat?.report ?? null, failedJobs24h, stuckGenerating,
      },
    });
  });

  fastify.get('/content/:id', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, include: fullInclude });
    if (!v) return err(reply, 404, 'Content not found');
    const [jobs, reviews, reports] = await Promise.all([
      prisma.contentJob.findMany({ where: { shortVideoId: v.id }, orderBy: { queuedAt: 'desc' }, take: 50 }),
      prisma.contentReview.findMany({ where: { shortVideoId: v.id }, orderBy: { createdAt: 'desc' }, take: 100 }),
      prisma.contentReport.findMany({ where: { shortVideoId: v.id }, orderBy: { createdAt: 'desc' }, take: 50 }),
    ]);
    const [videoUrl, thumbnailUrl, audioUrl] = await Promise.all([
      resolveAssetUrl(v.videoKey), resolveAssetUrl(v.thumbnailKey), resolveAssetUrl(v.audioKey),
    ]);
    return reply.send({ data: { ...(await present(v)), videoUrl, thumbnailUrl, audioUrl }, jobs, reviews, reports });
  });

  // ── Manual source entry ──────────────────────────────────────
  fastify.post('/content/schemes', guard, async (req, reply) => {
    const b = SchemeBody.safeParse(req.body ?? {});
    if (!b.success) return sendValidationError(reply, b.error);
    const d = b.data;
    try {
      const scheme = await prisma.scheme.create({
        data: {
          ...d,
          sourceUpdatedAt: d.sourceUpdatedAt ? new Date(d.sourceUpdatedAt) : null,
          nextReviewAt: d.nextReviewAt ? new Date(d.nextReviewAt) : null,
          expiresAt: d.expiresAt ? new Date(d.expiresAt) : null,
          lastCheckedAt: new Date(),
        },
      });
      await audit(req, 'content.scheme.create', scheme.id, undefined, { slug: scheme.slug });
      return reply.status(201).send({ data: scheme });
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') return err(reply, 409, 'A scheme with this slug already exists');
      throw e;
    }
  });

  fastify.post('/content/schemes/:id/verify', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const s = await prisma.scheme.findUnique({ where: { id: p.data.id } });
    if (!s) return err(reply, 404, 'Scheme not found');
    const problems: string[] = [];
    if (s.sourceUrls.length === 0) problems.push('Add at least one official source URL before verifying');
    if (!s.applicationUrl) problems.push('Add the official application URL before verifying');
    if (problems.length) return err(reply, 422, 'Scheme cannot be verified yet', { problems });
    const now = new Date();
    const u = await prisma.scheme.update({ where: { id: s.id }, data: { lastVerifiedAt: now, lastCheckedAt: now, reviewStatus: 'SOURCE_VERIFIED' } });
    await audit(req, 'content.scheme.verify', s.id, { lastVerifiedAt: s.lastVerifiedAt }, { lastVerifiedAt: now });
    return reply.send({ data: u });
  });

  fastify.post('/content/drafts', guard, async (req, reply) => {
    const b = DraftBody.safeParse(req.body ?? {});
    if (!b.success) return sendValidationError(reply, b.error);
    const d = b.data;
    const src = d.kind === 'SCHEME'
      ? await prisma.scheme.findUnique({ where: { id: d.schemeId! }, select: { id: true } })
      : await prisma.newsStory.findUnique({ where: { id: d.newsStoryId! }, select: { id: true } });
    if (!src) return err(reply, 404, 'Source record not found');
    const v = await prisma.shortVideo.create({
      data: { kind: d.kind, schemeId: d.schemeId, newsStoryId: d.newsStoryId, title: d.title, category: d.category, region: d.region ?? null },
    });
    await audit(req, 'content.draft.create', v.id, undefined, { kind: d.kind });
    return reply.status(201).send({ data: v });
  });

  // ── Edit (script / captions / claims) ────────────────────────
  fastify.patch('/content/:id', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    const b = EditBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, include: fullInclude });
    if (!v) return err(reply, 404, 'Content not found');
    if (!EDITABLE.includes(v.status)) return err(reply, 409, `Content in ${v.status} cannot be edited — unpublish or correct it first`);

    const d = b.data;
    const needsRerender = RENDER_AFFECTING.some((k) => d[k] !== undefined);
    const data: Prisma.ShortVideoUpdateInput = {
      ...(d.title !== undefined && { title: d.title }),
      ...(d.hook !== undefined && { hook: d.hook }),
      ...(d.description !== undefined && { description: d.description }),
      ...(d.attribution !== undefined && { attribution: d.attribution }),
      // Merge, never replace: a narration-only edit must keep scenes/key facts the renderer needs.
      ...(d.script !== undefined && { script: toJson({ ...((v.script as object | null) ?? {}), ...d.script }) }),
      ...(d.captions !== undefined && { captions: toJson(d.captions) }),
      ...(d.claims !== undefined && { claims: toJson(d.claims) }),
      ...(d.expiresAt !== undefined && { expiresAt: d.expiresAt ? new Date(d.expiresAt) : null }),
      ...(needsRerender && {
        scriptVersion: { increment: 1 },
        // Old render no longer matches the edited text: force regeneration before it can be approved.
        videoKey: null, audioKey: null,
        status: v.status === 'DRAFT' || v.status === 'SOURCE_VERIFIED' ? v.status : 'SCRIPT_READY',
      }),
    };
    const updated = await prisma.$transaction(async (tx) => {
      // Optimistic lock. NB: updateMany with empty `data` matches 0 rows in Prisma, so touch updatedAt.
      const res = await tx.shortVideo.updateMany({ where: { id: v.id, status: v.status }, data: { updatedAt: new Date() } });
      if (res.count === 0) return null;
      await tx.shortVideo.update({ where: { id: v.id }, data });
      await tx.contentReview.create({
        data: { shortVideoId: v.id, actorId: actor(req), action: 'edit',
                before: toJson({ title: v.title, script: v.script, captions: v.captions, claims: v.claims }),
                after: toJson(d) },
      });
      return tx.shortVideo.findUnique({ where: { id: v.id }, include: fullInclude });
    });
    if (!updated) return err(reply, 409, 'Content was changed by someone else — reload and retry');
    await audit(req, 'content.edit', v.id, undefined, { fields: Object.keys(d), needsRerender });
    return reply.send({ data: await present(updated), needsRerender });
  });

  // ── Lifecycle actions ────────────────────────────────────────
  fastify.post('/content/:id/approve', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = OptReasonBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    return move(req, reply, p.data.id, 'APPROVED', 'approve', {
      reason: b.data.reason,
      data: { approvedById: actor(req) },
      check: (v) => publishBlockers(v as any),
    });
  });

  /** Send expired / unpublished / corrected / generated content (back) to the review queue. */
  fastify.post('/content/:id/request-review', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = OptReasonBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    return move(req, reply, p.data.id, 'NEEDS_REVIEW', 'request_review', {
      reason: b.data.reason,
      check: (v) => publishBlockers(v as any),
    });
  });

  fastify.post('/content/:id/reject', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = ReasonBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    return move(req, reply, p.data.id, 'REJECTED', 'reject', { reason: b.data.reason });
  });

  fastify.post('/content/:id/recheck', guard, async (req, reply) => {
    // Reviewer attests they re-checked the live source just now (Phase 5 automates this).
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, select: { newsStoryId: true } });
    if (!v?.newsStoryId) return err(reply, 404, 'News story not found for this content');
    const now = new Date();
    await prisma.newsStory.update({ where: { id: v.newsStoryId }, data: { lastVerifiedAt: now } });
    await audit(req, 'content.recheck', p.data.id, undefined, { lastVerifiedAt: now });
    return reply.send({ ok: true, lastVerifiedAt: now });
  });

  fastify.post('/content/:id/publish', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = PublishBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const at = b.data.scheduledAt ? new Date(b.data.scheduledAt) : new Date();
    if (b.data.scheduledAt && at.getTime() < Date.now() - 60_000) return err(reply, 422, 'scheduledAt must be in the future');
    const t = await thresholds();
    return move(req, reply, p.data.id, 'PUBLISHED', b.data.scheduledAt ? 'schedule' : 'publish', {
      reason: b.data.reason,
      // A future publishedAt keeps the item out of the public feed until then (feed filters publishedAt <= now).
      data: { publishedAt: at, scheduledAt: b.data.scheduledAt ? at : null, publishedById: actor(req) },
      check: (v) => {
        const out = publishBlockers(v as any);
        if (v.expiresAt && v.expiresAt <= new Date()) out.push('Content has already expired');
        if (v.kind === 'NEWS' && v.newsStory) {
          const f = newsFreshnessBlocker(v.newsStory, t);
          if (f) out.push(f);
        }
        return out;
      },
    });
  });

  fastify.post('/content/:id/unpublish', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = ReasonBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const cur = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, select: { status: true } });
    if (cur?.status === 'APPROVED') return err(reply, 409, 'Approved-but-unpublished content is already hidden; reject it instead');
    return move(req, reply, p.data.id, 'UNPUBLISHED', 'unpublish', { reason: b.data.reason });
  });

  fastify.post('/content/:id/expire', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = ReasonBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    return move(req, reply, p.data.id, 'EXPIRED', 'expire', { reason: b.data.reason, data: { expiresAt: new Date() } });
  });

  fastify.post('/content/:id/correct', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = CorrectBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, select: { newsStoryId: true } });
    const res = await move(req, reply, p.data.id, b.data.withdraw ? 'UNPUBLISHED' : 'CORRECTION_REQUIRED', b.data.withdraw ? 'withdraw' : 'correct', {
      reason: b.data.note,
      data: { correctionNote: b.data.note },
    });
    if (reply.statusCode < 300 && v?.newsStoryId) {
      await prisma.newsStory.update({ where: { id: v.newsStoryId }, data: { correctionStatus: b.data.withdraw ? 'WITHDRAWN' : 'CORRECTED' } });
    }
    return res;
  });

  /** Queue generation (script → narration → render). Idempotent: duplicate requests share one queued job. */
  fastify.post('/content/generate', { ...guard, config: { rateLimit: { max: 20, timeWindow: '1 minute' } } }, async (req, reply) => {
    const b = z.object({ shortVideoId: z.string().min(1).max(64) }).safeParse(req.body ?? {});
    if (!b.success) return sendValidationError(reply, b.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: b.data.shortVideoId }, select: { id: true, status: true } });
    if (!v) return err(reply, 404, 'Content not found');
    if (!['DRAFT', 'SOURCE_VERIFIED', 'SCRIPT_READY', 'GENERATING'].includes(v.status)) {
      return err(reply, 409, `Cannot generate from status ${v.status}`);
    }
    try {
      const stage = await start(v.id);
      await audit(req, 'content.generate', v.id, undefined, { stage });
      return reply.status(202).send({ queued: true, stage });
    } catch (e) {
      req.log.error({ err: e }, 'failed to enqueue generation');
      return err(reply, 503, 'Generation queue unavailable');
    }
  });

  /** Failed content → back to SCRIPT_READY, and its failed jobs back to QUEUED (worker enqueues in Phase 3). */
  fastify.post('/content/:id/retry', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const res = await move(req, reply, p.data.id, 'SCRIPT_READY', 'retry', {
      check: async () => {
        const maxRetries = Number((await prisma.appConfig.findUnique({ where: { key: 'content.max_manual_retries' } }))?.value) || 5;
        const failed = await prisma.contentJob.count({ where: { shortVideoId: p.data.id, state: 'FAILED' } });
        return failed >= maxRetries ? [`Retry limit reached (${maxRetries} failed jobs) — edit or reject the content`] : [];
      },
    });
    if (reply.statusCode < 300) {
      start(p.data.id).catch((e) => req.log.error({ err: e }, 'retry enqueue failed'));
      await prisma.contentJob.updateMany({
        where: { shortVideoId: p.data.id, state: 'FAILED' },
        data: { state: 'QUEUED', attempts: 0, failureReason: null, startedAt: null, finishedAt: null },
      });
    }
    return res;
  });

  fastify.post('/content/jobs/:id/cancel', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const r = await prisma.contentJob.updateMany({
      where: { id: p.data.id, state: { in: ['QUEUED', 'RUNNING'] } },
      data: { state: 'CANCELLED', finishedAt: new Date(), failureReason: 'Cancelled by admin' },
    });
    if (r.count === 0) return err(reply, 409, 'Job not found or already finished');
    await audit(req, 'content.job.cancel', p.data.id);
    return reply.send({ ok: true });
  });
}
