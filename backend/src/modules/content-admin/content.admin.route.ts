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
import { extractYoutubeId } from '../../lib/content/youtube';
import { ingestNews } from '../../lib/content/ingest';
import { contentConfig } from '../../lib/content/config';
import { hostAllowed } from '../../lib/content/safe-fetch';
import { collectAttention } from '../../lib/content/freshness';
import { loadSettings, saveSettings, SettingsPatchSchema } from '../../lib/content/settings';
import { canTransition, publishBlockers, videoApprovalBlockers } from '../../lib/content/lifecycle';
import { requestVideoGeneration } from '../../lib/content/video-request';
import { newsCardDefaults, schemeCardDefaults } from '../../lib/content/card-defaults';
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
  format: optionalEnum(['CARD_ONLY', 'CARD_WITH_VIDEO']),
  videoState: optionalEnum(['NOT_REQUESTED', 'QUEUED', 'GENERATING', 'READY', 'FAILED']),
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
    youtubeUrl: z.string().trim().url().nullable().optional(),
  })
  .partial()
  .refine((b) => Object.keys(b).length > 0, { message: 'No fields to update' });

const FormatBody = z.object({ format: z.enum(['CARD_ONLY', 'CARD_WITH_VIDEO']) });

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
  youtubeUrl: z.string().trim().url().nullable().optional(),
});

const SchemeUpdateBody = SchemeBody.partial();

const SchemeQuery = z.object({
  search: optionalString(100),
  category: optionalString(64),
  scope: optionalEnum(['CENTRAL', 'STATE']),
  reviewStatus: optionalEnum([...STATUSES]),
});

const SEED_SCHEMES = [
  {
    slug: 'pm-kisan-samman-nidhi',
    officialName: 'Pradhan Mantri Kisan Samman Nidhi',
    nameHi: 'प्रधानमंत्री किसान सम्मान निधि योजना',
    category: 'FARMER',
    scope: 'CENTRAL' as const,
    department: 'कृषि एवं किसान कल्याण मंत्रालय (Ministry of Agriculture)',
    benefits: ['₹6,000 प्रति वर्ष 3 समान किस्तों में प्रत्यक्ष बैंक खाते में (DBT) हस्तांतरित किए जाते हैं।'],
    eligibility: ['सभी भूमिधारक किसान परिवार जिनके नाम कृषि योग्य भूमि दर्ज है। संस्थागत भूमिधारक अपात्र हैं।'],
    documents: ['आधार कार्ड', 'बैंक खाता पासबुक (आधार से लिंक)', 'भूमि स्वामित्व दस्तावेज (खतौनी/भूलेख)', 'सक्रिय मोबाइल नंबर'],
    applicationSteps: ['1. आधिकारिक पोर्टल pmkisan.gov.in पर जाएं', '2. New Farmer Registration विकल्प चुनें', '3. आधार और मोबाइल नंबर दर्ज करें', '4. राज्य, जिला व जमीन का विवरण भरकर सबमिट करें'],
    applicationMode: 'ONLINE',
    applicationUrl: 'https://pmkisan.gov.in',
    sourceUrls: ['https://pmkisan.gov.in', 'https://myscheme.gov.in'],
  },
  {
    slug: 'ayushman-bharat-pm-jay',
    officialName: 'Ayushman Bharat Pradhan Mantri Jan Arogya Yojana',
    nameHi: 'आयुष्मान भारत - प्रधानमंत्री जन आरोग्य योजना (PM-JAY)',
    category: 'HEALTHCARE',
    scope: 'CENTRAL' as const,
    department: 'राष्ट्रीय स्वास्थ्य प्राधिकरण (NHA) / स्वास्थ्य एवं परिवार कल्याण मंत्रालय',
    benefits: ['प्रति परिवार प्रति वर्ष ₹5 लाख तक का कैशलेस एवं पेपरलेस स्वास्थ्य बीमा कवर।', '70 वर्ष या उससे अधिक आयु के सभी वरिष्ठ नागरिकों के लिए आयुष्मान वय वंदना कवर।'],
    eligibility: ['SECC डेटाबेस के अनुसार ग्रामीण एवं शहरी गरीब परिवार। 70 वर्ष से अधिक आयु के सभी भारतीय नागरिक।'],
    documents: ['आधार कार्ड', 'राशन कार्ड', 'मोबाइल नंबर'],
    applicationSteps: ['1. beneficiary.nha.gov.in पोर्टल पर जाएं', '2. मोबाइल नंबर और OTP से लॉगिन करें', '3. परिवार का नाम खोजें व e-KYC पूरा करें', '4. आयुष्मान कार्ड तुरंत डाउनलोड करें'],
    applicationMode: 'ONLINE',
    applicationUrl: 'https://beneficiary.nha.gov.in',
    sourceUrls: ['https://nha.gov.in', 'https://myscheme.gov.in'],
  },
  {
    slug: 'pm-awas-yojana',
    officialName: 'Pradhan Mantri Awas Yojana (PMAY)',
    nameHi: 'प्रधानमंत्री आवास योजना (ग्रामीण एवं शहरी)',
    category: 'HOUSING',
    scope: 'CENTRAL' as const,
    department: 'ग्रामीण विकास मंत्रालय / आवास और शहरी कार्य मंत्रालय',
    benefits: ['पक्का मकान बनाने के लिए ₹1.20 लाख से ₹1.30 लाख की सीधी वित्तीय सहायता।', 'शहरी क्षेत्रों में गृह ऋण पर ब्याज सब्सिडी।'],
    eligibility: ['ऐसे परिवार जिनके पास भारत में कहीं भी अपना पक्का मकान नहीं है। BPL / EWS श्रेणी के पात्र परिवार।'],
    documents: ['आधार कार्ड', 'बैंक खाता पासबुक', 'जमीन के कागजात या पट्टा', 'आय प्रमाण पत्र / राशन कार्ड'],
    applicationSteps: ['1. pmaymis.gov.in (शहरी) या ग्राम पंचायत (ग्रामीण) से संपर्क करें', '2. ऑनलाइन या CSC के माध्यम से आवेदन फॉर्म भरें', '3. जियो-टैगिंग सत्यापन के बाद खाते में किस्त प्राप्त करें'],
    applicationMode: 'BOTH',
    applicationUrl: 'https://pmaymis.gov.in',
    sourceUrls: ['https://pmaymis.gov.in', 'https://pmayg.nic.in'],
  },
  {
    slug: 'pm-vishwakarma-yojana',
    officialName: 'PM Vishwakarma Scheme',
    nameHi: 'पीएम विश्वकर्मा योजना',
    category: 'SKILLS',
    scope: 'CENTRAL' as const,
    department: 'सूक्ष्म, लघु एवं मध्यम उद्यम मंत्रालय (MSME)',
    benefits: ['₹15,000 का आधुनिक टूलकिट प्रोत्साहन वाउचर।', '5-7 दिन का बेसिक कौशल प्रशिक्षण व ₹500/दिन स्टाइपेंड।', 'बिना गारंटी ₹3 लाख तक का सस्ता लोन (मात्र 5% ब्याज दर)।'],
    eligibility: ['18 पारंपरिक शिल्पों में हाथों और औजारों से कार्य करने वाले कारीगर (बढ़ई, लोहार, कुम्हार, दर्जी, सुनार आदि)।'],
    documents: ['आधार कार्ड', 'सक्रिय बैंक खाता पासबुक', 'मोबाइल नंबर', 'पारंपरिक शिल्प व्यवसाय का प्रमाण'],
    applicationSteps: ['1. नजदीकी कॉमन सर्विस सेंटर (CSC) पर जाएं', '2. बायोमेट्रिक सत्यापन और आधार e-KYC कराएं', '3. शिल्प श्रेणी चुनकर पंजीकरण पूरा करें'],
    applicationMode: 'ONLINE',
    applicationUrl: 'https://pmvishwakarma.gov.in',
    sourceUrls: ['https://pmvishwakarma.gov.in', 'https://myscheme.gov.in'],
  },
  {
    slug: 'sukanya-samriddhi-yojana',
    officialName: 'Sukanya Samriddhi Yojana (SSY)',
    nameHi: 'सुकन्या समृद्धि योजना',
    category: 'WOMEN',
    scope: 'CENTRAL' as const,
    department: 'डाक विभाग (India Post) / वित्त मंत्रालय',
    benefits: ['8.2% की सुरक्षित एवं उच्च वार्षिक चक्रवृद्धि ब्याज दर।', 'धारा 80C के तहत आयकर में छूट और मैच्योरिटी पर पूरी तरह टैक्स-फ्री रिटर्न।'],
    eligibility: ['10 वर्ष या उससे कम आयु की बेटियों के नाम पर माता-पिता या अभिभावक द्वारा खाता खोला जा सकता है।'],
    documents: ['बेटी का जन्म प्रमाण पत्र', 'माता-पिता / अभिभावक का आधार कार्ड व पैन कार्ड', 'पते का प्रमाण', 'पासपोर्ट साइज फोटो'],
    applicationSteps: ['1. निकटतम डाकघर या अधिकृत बैंक शाखा में जाएं', '2. SSY खाता खोलने का फॉर्म भरें', '3. आवश्यक दस्तावेज व न्यूनतम ₹250 जमा करें'],
    applicationMode: 'OFFLINE',
    applicationUrl: 'https://www.indiapost.gov.in',
    sourceUrls: ['https://www.indiapost.gov.in', 'https://myscheme.gov.in'],
  },
];

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
const EDITABLE: ContentStatus[] = ['DRAFT', 'SOURCE_VERIFIED', 'SCRIPT_READY', 'NEEDS_REVIEW', 'APPROVED', 'CORRECTION_REQUIRED', 'FAILED'];

export interface ContentAdminOptions {
  /** Queues the next video pipeline stage (only ever from an explicit admin video request); defaults to BullMQ. Injectable so tests need no Redis. */
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
      ...(q.data.format && { format: q.data.format }),
      ...(q.data.videoState && { videoState: q.data.videoState }),
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

  fastify.post('/content/ingest/run', { ...guard, config: { rateLimit: { max: 12, timeWindow: '1 minute' } } }, async (req, reply) => {
    const s = await loadSettings(prisma);
    if (s.feeds.length === 0) return err(reply, 422, 'No news feeds configured', { problems: ['Add at least one feed in settings first'] });

    const cfg = contentConfig();
    const lockRedis = fastify.redis;
    try {
      const { runMaintenanceTick, redisLocker } = await import('../../lib/content/maintenance');
      const locker = lockRedis ? redisLocker(lockRedis) : (async () => async () => {});
      const report = await runMaintenanceTick(
        {
          prisma,
          cfg,
          lock: locker,
          log: (m, x) => req.log.info({ extra: x }, `[content-ingest] ${m}`),
        },
        { forceIngest: true },
      );
      if (lockRedis) {
        const { HEARTBEAT_KEY } = await import('../../lib/content/queue');
        await lockRedis.set(HEARTBEAT_KEY, JSON.stringify({ at: new Date().toISOString(), report }), 'EX', 3600).catch(() => undefined);
      }
      await audit(req, 'content.ingest.run', 'ingest', undefined, report, 'ContentSettings');
      return reply.send({ ok: true, report });
    } catch (e: any) {
      req.log.error({ err: e }, 'direct ingest run failed, falling back to background worker queue');
      try {
        await requestIngest();
        return reply.status(202).send({ queued: true, message: 'Ingest queued to background worker' });
      } catch (queueErr: any) {
        return err(reply, 503, 'Worker queue unavailable', { original: queueErr?.message ?? e?.message });
      }
    }
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
      prisma.shortVideo.count({ where: { videoState: { in: ['QUEUED', 'GENERATING'] }, updatedAt: { lt: new Date(Date.now() - 3_600_000) } } }),
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

  // ── Schemes (Yojana) Management ──────────────────────────────
  fastify.get('/content/schemes', guard, async (req, reply) => {
    const q = SchemeQuery.safeParse(req.query ?? {});
    if (!q.success) return sendValidationError(reply, q.error);
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 100 });
    const where: Prisma.SchemeWhereInput = {
      ...(q.data.category && { category: q.data.category }),
      ...(q.data.scope && { scope: q.data.scope }),
      ...(q.data.reviewStatus && { reviewStatus: q.data.reviewStatus }),
      ...(q.data.search && {
        OR: [
          { officialName: { contains: q.data.search, mode: 'insensitive' } },
          { nameHi: { contains: q.data.search, mode: 'insensitive' } },
          { department: { contains: q.data.search, mode: 'insensitive' } },
          { slug: { contains: q.data.search, mode: 'insensitive' } },
        ],
      }),
    };
    const [data, total] = await Promise.all([
      prisma.scheme.findMany({
        where,
        include: { _count: { select: { videos: true } } },
        orderBy: [{ lastVerifiedAt: 'desc' }, { createdAt: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.scheme.count({ where }),
    ]);
    return reply.send({ data, meta: { page, limit, total } });
  });

  fastify.get('/content/schemes/:id', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const scheme = await prisma.scheme.findUnique({
      where: { id: p.data.id },
      include: {
        videos: {
          select: { id: true, title: true, status: true, publishedAt: true, category: true, createdAt: true },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!scheme) return err(reply, 404, 'Scheme not found');
    return reply.send({ data: scheme });
  });

  fastify.post('/content/schemes', guard, async (req, reply) => {
    const b = SchemeBody.safeParse(req.body ?? {});
    if (!b.success) return sendValidationError(reply, b.error);
    const d = b.data;
    try {
      const youtubeId = d.youtubeUrl ? extractYoutubeId(d.youtubeUrl) : null;
      const scheme = await prisma.scheme.create({
        data: {
          ...d,
          youtubeId,
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

  fastify.put('/content/schemes/:id', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    const b = SchemeUpdateBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const existing = await prisma.scheme.findUnique({ where: { id: p.data.id } });
    if (!existing) return err(reply, 404, 'Scheme not found');
    const d = b.data;
    const youtubeId = d.youtubeUrl !== undefined ? (d.youtubeUrl ? extractYoutubeId(d.youtubeUrl) : null) : undefined;
    const updated = await prisma.scheme.update({
      where: { id: p.data.id },
      data: {
        ...d,
        ...(youtubeId !== undefined && { youtubeId }),
        sourceUpdatedAt: d.sourceUpdatedAt !== undefined ? (d.sourceUpdatedAt ? new Date(d.sourceUpdatedAt) : null) : undefined,
        nextReviewAt: d.nextReviewAt !== undefined ? (d.nextReviewAt ? new Date(d.nextReviewAt) : null) : undefined,
        expiresAt: d.expiresAt !== undefined ? (d.expiresAt ? new Date(d.expiresAt) : null) : undefined,
      },
    });
    if (youtubeId !== undefined) {
      await prisma.shortVideo.updateMany({
        where: { schemeId: p.data.id },
        data: {
          youtubeUrl: d.youtubeUrl || null,
          youtubeId,
          format: youtubeId ? 'CARD_WITH_VIDEO' : 'CARD_ONLY',
        },
      });
    }
    await audit(req, 'content.scheme.update', p.data.id, existing, updated);
    return reply.send({ data: updated });
  });

  fastify.delete('/content/schemes/:id', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const existing = await prisma.scheme.findUnique({ where: { id: p.data.id }, include: { _count: { select: { videos: true } } } });
    if (!existing) return err(reply, 404, 'Scheme not found');
    if (existing._count.videos > 0) {
      await prisma.shortVideo.updateMany({ where: { schemeId: p.data.id }, data: { schemeId: null } });
    }
    await prisma.scheme.delete({ where: { id: p.data.id } });
    await audit(req, 'content.scheme.delete', p.data.id, existing);
    return reply.send({ ok: true, deleted: true });
  });

  fastify.post('/content/schemes/:id/draft', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const scheme = await prisma.scheme.findUnique({ where: { id: p.data.id } });
    if (!scheme) return err(reply, 404, 'Scheme not found');
    const title = scheme.nameHi ? scheme.nameHi.slice(0, 200) : scheme.officialName.slice(0, 200);
    const format = scheme.youtubeId ? 'CARD_WITH_VIDEO' : 'CARD_ONLY';
    const video = await prisma.shortVideo.create({
      data: {
        kind: 'SCHEME',
        schemeId: scheme.id,
        title,
        category: scheme.category,
        region: scheme.stateCode ?? null,
        language: scheme.language,
        status: 'DRAFT',
        format,
        youtubeUrl: scheme.youtubeUrl,
        youtubeId: scheme.youtubeId,
        ...schemeCardDefaults(scheme),
      },
    });
    await audit(req, 'content.scheme.draft', video.id, undefined, { schemeId: scheme.id });
    return reply.status(201).send({ data: video });
  });

  fastify.post('/content/schemes/seed', guard, async (req, reply) => {
    let created = 0;
    let existing = 0;
    const now = new Date();
    for (const s of SEED_SCHEMES) {
      const found = await prisma.scheme.findUnique({ where: { slug: s.slug } });
      if (found) {
        existing++;
        continue;
      }
      await prisma.scheme.create({
        data: {
          ...s,
          lastVerifiedAt: now,
          lastCheckedAt: now,
          reviewStatus: 'SOURCE_VERIFIED',
        },
      });
      created++;
    }
    await audit(req, 'content.schemes.seed', 'schemes', undefined, { created, existing });
    return reply.send({ ok: true, created, existing });
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
      ? await prisma.scheme.findUnique({ where: { id: d.schemeId! } })
      : await prisma.newsStory.findUnique({ where: { id: d.newsStoryId! } });
    if (!src) return err(reply, 404, 'Source record not found');
    const defaults = d.kind === 'SCHEME' ? schemeCardDefaults(src as any) : newsCardDefaults(src as any);
    const v = await prisma.shortVideo.create({
      data: {
        kind: d.kind, schemeId: d.schemeId, newsStoryId: d.newsStoryId, title: d.title, category: d.category,
        region: d.region ?? null, format: 'CARD_ONLY', ...defaults,
      },
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
    const hasVideoWork = v.videoState !== 'NOT_REQUESTED';
    if (needsRerender && hasVideoWork && (v.videoState === 'QUEUED' || v.videoState === 'GENERATING')) {
      return err(reply, 409, 'A video is being generated for this item — cancel it before editing the script, captions or title');
    }
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
      // The old render no longer matches the edited text: drop it (and its approval). The card is unaffected.
      ...(needsRerender && hasVideoWork && {
        scriptVersion: { increment: 1 },
        videoKey: null, audioKey: null, thumbnailKey: null,
        videoState: 'NOT_REQUESTED' as const, videoApprovedAt: null, videoApprovedById: null, videoFailureReason: null,
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
    return reply.send({ data: await present(updated), needsRerender: needsRerender && hasVideoWork });
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
      // A correction/withdrawal also revokes the video approval: the video must be re-approved after re-review.
      data: { correctionNote: b.data.note, videoApprovedAt: null, videoApprovedById: null },
    });
    if (reply.statusCode < 300 && v?.newsStoryId) {
      await prisma.newsStory.update({ where: { id: v.newsStoryId }, data: { correctionStatus: b.data.withdraw ? 'WITHDRAWN' : 'CORRECTED' } });
    }
    return res;
  });

  // ── Content format + card publishing (never enqueue anything) ──
  const heavy = { ...guard, config: { rateLimit: { max: 20, timeWindow: '1 minute' } } };

  /** Choose Card only / Card + Video. Changing the format never starts a job. */
  fastify.patch('/content/:id/format', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = FormatBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, include: fullInclude });
    if (!v) return err(reply, 404, 'Content not found');
    if (v.format === b.data.format) return reply.send({ data: await present(v), unchanged: true });
    if (v.videoState === 'QUEUED' || v.videoState === 'GENERATING') {
      return err(reply, 409, 'A video is being generated — cancel the job before changing the format');
    }
    if (v.status === 'REJECTED') return err(reply, 409, 'Rejected content cannot be changed');
    const res = await prisma.shortVideo.updateMany({
      where: { id: v.id, format: v.format, videoState: v.videoState },
      data: {
        format: b.data.format,
        // Leaving video mode pulls any video out of the public feed; it must be re-approved if ever re-enabled.
        ...(b.data.format === 'CARD_ONLY' && { videoApprovedAt: null, videoApprovedById: null }),
      },
    });
    if (res.count === 0) return err(reply, 409, 'Content was changed by someone else — reload and retry');
    await prisma.contentReview.create({
      data: { shortVideoId: v.id, actorId: actor(req), action: 'set_format', before: { format: v.format }, after: { format: b.data.format } },
    });
    await audit(req, 'content.format', v.id, { format: v.format }, { format: b.data.format });
    return reply.send({ data: await present((await prisma.shortVideo.findUnique({ where: { id: v.id }, include: fullInclude }))!) });
  });

  /** Publish as a normal news card in one step (review → approve → publish). Enqueues NO job. */
  fastify.post('/content/:id/publish-card', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params); const b = PublishBody.safeParse(req.body ?? {});
    if (!p.success) return sendValidationError(reply, p.error);
    if (!b.success) return sendValidationError(reply, b.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, include: fullInclude });
    if (!v) return err(reply, 404, 'Content not found');
    if (v.status === 'PUBLISHED') return reply.send({ data: await present(v), unchanged: true });
    const FROM: ContentStatus[] = ['DRAFT', 'SOURCE_VERIFIED', 'NEEDS_REVIEW', 'APPROVED'];
    if (!FROM.includes(v.status)) return err(reply, 409, `Cannot publish a card from status ${v.status}`);

    const at = b.data.scheduledAt ? new Date(b.data.scheduledAt) : new Date();
    if (b.data.scheduledAt && at.getTime() < Date.now() - 60_000) return err(reply, 422, 'scheduledAt must be in the future');
    const t = await thresholds();
    const problems = publishBlockers(v as any);
    if (v.expiresAt && v.expiresAt <= new Date()) problems.push('Content has already expired');
    if (v.kind === 'NEWS' && v.newsStory) {
      const f = newsFreshnessBlocker(v.newsStory, t);
      if (f) problems.push(f);
    }
    if (problems.length) return err(reply, 422, 'Content failed pre-flight checks', { problems });

    const actorId = actor(req);
    const updated = await prisma.$transaction(async (tx) => {
      const res = await tx.shortVideo.updateMany({
        where: { id: v.id, status: v.status },
        data: { status: 'PUBLISHED', approvedById: actorId, publishedById: actorId, publishedAt: at, scheduledAt: b.data.scheduledAt ? at : null },
      });
      if (res.count === 0) return null;
      await tx.contentReview.create({
        data: { shortVideoId: v.id, actorId, action: b.data.scheduledAt ? 'schedule' : 'publish_card', reason: b.data.reason ?? null,
                before: { status: v.status }, after: { status: 'PUBLISHED', format: v.format } },
      });
      return tx.shortVideo.findUnique({ where: { id: v.id }, include: fullInclude });
    });
    if (!updated) return err(reply, 409, 'Content was changed by someone else — reload and retry');
    await audit(req, 'content.publish_card', v.id, { status: v.status }, { status: 'PUBLISHED', format: v.format });
    return reply.send({ data: await present(updated) });
  });

  // ── Video (explicit admin actions only) ───────────────────────
  async function videoRequest(req: FastifyRequest, reply: FastifyReply, id: string, action: string) {
    const maxManualRetries = Number((await prisma.appConfig.findUnique({ where: { key: 'content.max_manual_retries' } }))?.value) || 5;
    const r = await requestVideoGeneration({ prisma, start, maxManualRetries }, id, actor(req));
    if (!r.ok) {
      if (r.code === 503) req.log.error('failed to enqueue video generation');
      return err(reply, r.code, r.message, r.problems ? { problems: r.problems } : {});
    }
    if (r.queued) await audit(req, action, id, undefined, { stage: r.stage });
    return reply.status(r.queued ? 202 : 200).send({ queued: r.queued, duplicate: r.duplicate, videoState: r.state, stage: r.stage ?? null });
  }

  /** The only way to request a video. Idempotent: repeated clicks never create a second job. */
  fastify.post('/content/:id/video/generate', heavy, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    return videoRequest(req, reply, p.data.id, 'content.video.generate');
  });

  fastify.post('/content/:id/video/retry', heavy, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, select: { videoState: true } });
    if (!v) return err(reply, 404, 'Content not found');
    if (v.videoState !== 'FAILED') return err(reply, 409, 'Only a failed video can be retried');
    return videoRequest(req, reply, p.data.id, 'content.video.retry');
  });

  /** Approve a finished video so it becomes publicly playable (after previewing it). */
  fastify.post('/content/:id/video/approve', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, include: fullInclude });
    if (!v) return err(reply, 404, 'Content not found');
    if (v.videoApprovedAt && v.videoState === 'READY' && v.format === 'CARD_WITH_VIDEO') {
      return reply.send({ data: await present(v), unchanged: true });
    }
    const problems = videoApprovalBlockers(v as any);
    if (problems.length) return err(reply, 422, 'Video cannot be approved', { problems });
    const res = await prisma.shortVideo.updateMany({
      where: { id: v.id, format: 'CARD_WITH_VIDEO', videoState: 'READY', videoKey: v.videoKey },
      data: { videoApprovedAt: new Date(), videoApprovedById: actor(req) },
    });
    if (res.count === 0) return err(reply, 409, 'Video changed — reload and retry');
    await prisma.contentReview.create({
      data: { shortVideoId: v.id, actorId: actor(req), action: 'video_approve', before: { videoApproved: false }, after: { videoApproved: true } },
    });
    await audit(req, 'content.video.approve', v.id);
    return reply.send({ data: await present((await prisma.shortVideo.findUnique({ where: { id: v.id }, include: fullInclude }))!) });
  });

  /** Pull a video out of the public feed (the card stays published). */
  fastify.post('/content/:id/video/unapprove', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const res = await prisma.shortVideo.updateMany({
      where: { id: p.data.id, videoApprovedAt: { not: null } },
      data: { videoApprovedAt: null, videoApprovedById: null },
    });
    if (res.count > 0) {
      await prisma.contentReview.create({
        data: { shortVideoId: p.data.id, actorId: actor(req), action: 'video_unapprove', before: { videoApproved: true }, after: { videoApproved: false } },
      });
      await audit(req, 'content.video.unapprove', p.data.id);
    }
    return reply.send({ ok: true, changed: res.count > 0 });
  });

  /** Throw a finished/failed video away so a new one can be requested. Never touches the card. */
  fastify.post('/content/:id/video/discard', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const v = await prisma.shortVideo.findUnique({ where: { id: p.data.id }, select: { videoState: true } });
    if (!v) return err(reply, 404, 'Content not found');
    if (v.videoState === 'QUEUED' || v.videoState === 'GENERATING') return err(reply, 409, 'Cancel the running job first');
    if (v.videoState === 'NOT_REQUESTED') return reply.send({ ok: true, changed: false });
    await prisma.shortVideo.updateMany({
      where: { id: p.data.id, videoState: { in: ['READY', 'FAILED'] } },
      data: {
        videoState: 'NOT_REQUESTED', videoKey: null, audioKey: null, thumbnailKey: null, durationSec: null,
        videoApprovedAt: null, videoApprovedById: null, videoFailureReason: null, scriptVersion: { increment: 1 },
      },
    });
    await audit(req, 'content.video.discard', p.data.id);
    return reply.send({ ok: true, changed: true });
  });

  /** Back-compat alias for older clients: same explicit, idempotent video request. */
  fastify.post('/content/generate', heavy, async (req, reply) => {
    const b = z.object({ shortVideoId: z.string().min(1).max(64) }).safeParse(req.body ?? {});
    if (!b.success) return sendValidationError(reply, b.error);
    return videoRequest(req, reply, b.data.shortVideoId, 'content.video.generate');
  });

  fastify.post('/content/:id/retry', heavy, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    return videoRequest(req, reply, p.data.id, 'content.video.retry');
  });

  fastify.post('/content/ingest-now', guard, async (req, reply) => {
    const settings = await loadSettings(prisma);
    const result = await ingestNews(prisma, { feeds: settings.feeds, staleHours: settings.newsStaleHours, maxIngest: 100 });
    await audit(req, 'content.ingest_now', 'news', undefined, result);
    return reply.send({ ok: true, result });
  });

  fastify.post('/content/ingest/run', guard, async (req, reply) => {
    const settings = await loadSettings(prisma);
    const result = await ingestNews(prisma, { feeds: settings.feeds, staleHours: settings.newsStaleHours, maxIngest: 100 });
    await audit(req, 'content.ingest_run', 'news', undefined, result);
    return reply.send({ ok: true, result });
  });

  fastify.post('/content/jobs/:id/cancel', guard, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const r = await prisma.contentJob.updateMany({
      where: { id: p.data.id, state: { in: ['QUEUED', 'RUNNING'] } },
      data: { state: 'CANCELLED', finishedAt: new Date(), failureReason: 'Cancelled by admin' },
    });
    if (r.count === 0) return err(reply, 409, 'Job not found or already finished');
    const job = await prisma.contentJob.findUnique({ where: { id: p.data.id }, select: { shortVideoId: true } });
    if (job?.shortVideoId) {
      // The request is withdrawn: the card is unaffected and the admin may request again.
      await prisma.shortVideo.updateMany({
        where: { id: job.shortVideoId, videoState: { in: ['QUEUED', 'GENERATING'] } },
        data: { videoState: 'NOT_REQUESTED', videoFailureReason: null },
      });
    }
    await audit(req, 'content.job.cancel', p.data.id);
    return reply.send({ ok: true });
  });
}
