// src/modules/shorts/shorts.route.ts
// Public/authenticated read APIs for Sarkari Yojana & Daily News shorts.
// Only PUBLISHED, non-expired content is ever returned. Everything here is free to
// read — no subscription checks (public-benefit information must not be paywalled).
import { FastifyInstance } from 'fastify';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { optionalEnum, optionalString, parsePagination, sendValidationError } from '../../lib/http/validation';
import { serializeShort, shortInclude } from './shorts.serializer';
import { checkSchemeEligibility, EligibilityInputSchema } from './schemes.calculator';
import { resolveStateFromCoords, normalizeStateCode } from '../../lib/content/state-locator';

const KINDS = ['SCHEME', 'NEWS'] as const;

const SUB_KINDS = ['TOP', 'REGIONAL'] as const;

const ListQuery = z.object({
  kind: optionalEnum([...KINDS]),
  subKind: optionalEnum([...SUB_KINDS]),
  category: optionalString(64),
  region: optionalString(16),
  state: optionalString(32),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});

const EventBody = z.object({ type: z.enum(['VIEW', 'COMPLETE', 'SHARE', 'OPEN_LINK']) });
const ReportBody = z.object({
  reason: z.enum(['INCORRECT', 'OUTDATED', 'MISLEADING', 'OFFENSIVE', 'OTHER']),
  note: z.string().trim().max(500).optional(),
});
const IdParams = z.object({ id: z.string().min(1).max(64) });

export function publicWhere(extra: Prisma.ShortVideoWhereInput = {}): Prisma.ShortVideoWhereInput {
  const now = new Date();
  return {
    status: 'PUBLISHED',
    AND: [
      { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
      { OR: [{ publishedAt: null }, { publishedAt: { lte: now } }] },
      extra,
    ],
  };
}

const todayKey = () => new Date().toISOString().slice(0, 10);
const notFound = (reply: any) =>
  reply.status(404).send({ statusCode: 404, error: 'Not Found', message: 'Content not found' });
const isDuplicate = (e: unknown) => e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002';

async function registerRoutes(fastify: FastifyInstance, forcedKind?: 'SCHEME' | 'NEWS') {
  const prisma = fastify.prisma;

  async function list(req: any, reply: any) {
    const parsed = ListQuery.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 10, maxLimit: 30 });
    const { kind, subKind, category, region, state, lat, lng } = parsed.data;
    const effectiveKind = forcedKind ?? kind;

    const userId = (req.user as any)?.userId as string | undefined;

    // Resolve user's state / region from params, coordinates, or profile
    let resolvedState: string | null = null;
    if (state || region) {
      resolvedState = normalizeStateCode(state || region);
    } else if (lat != null && lng != null) {
      resolvedState = resolveStateFromCoords(lat, lng)?.code ?? null;
    } else if (userId) {
      const u = await prisma.user.findUnique({
        where: { id: userId },
        select: { state: true, region: true, latitude: true, longitude: true },
      });
      if (u?.state || u?.region) {
        resolvedState = normalizeStateCode(u.state || u.region);
      } else if (u?.latitude != null && u?.longitude != null) {
        resolvedState = resolveStateFromCoords(u.latitude, u.longitude)?.code ?? null;
      }
    }

    let extraWhere: Prisma.ShortVideoWhereInput = {};

    if (effectiveKind === 'NEWS') {
      if (subKind === 'TOP') {
        extraWhere = {
          kind: 'NEWS',
          ...(category && { category }),
          OR: [{ subKind: 'TOP' }, { region: null }],
        };
      } else if (subKind === 'REGIONAL') {
        if (resolvedState) {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
            OR: [
              { subKind: 'REGIONAL', region: resolvedState },
              { region: resolvedState },
            ],
          };
        } else {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
            subKind: 'REGIONAL',
          };
        }
      } else {
        if (resolvedState) {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
            OR: [{ subKind: 'TOP' }, { region: resolvedState }, { region: null }],
          };
        } else {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
          };
        }
      }
    } else if (effectiveKind === 'SCHEME') {
      extraWhere = {
        kind: 'SCHEME',
        ...(category && { category }),
        ...(resolvedState ? { OR: [{ region: resolvedState }, { region: null }] } : {}),
      };
    } else {
      extraWhere = {
        ...(effectiveKind ? { kind: effectiveKind as any } : {}),
        ...(category ? { category } : {}),
        ...(resolvedState ? { OR: [{ region: resolvedState }, { region: null }] } : {}),
      };
    }

    const where = publicWhere(extraWhere);

    let [rows, total] = await Promise.all([
      prisma.shortVideo.findMany({
        where,
        include: shortInclude,
        orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.shortVideo.count({ where }),
    ]);

    // If regional news specifically requested but nothing found for this specific state yet,
    // fallback to all regional news so the user gets fresh content
    if (rows.length === 0 && effectiveKind === 'NEWS' && subKind === 'REGIONAL' && resolvedState) {
      const fallbackWhere = publicWhere({
        kind: 'NEWS',
        ...(category && { category }),
        subKind: 'REGIONAL',
      });
      const [fRows, fTotal] = await Promise.all([
        prisma.shortVideo.findMany({
          where: fallbackWhere,
          include: shortInclude,
          orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
          skip,
          take: limit,
        }),
        prisma.shortVideo.count({ where: fallbackWhere }),
      ]);
      if (fRows.length > 0) {
        rows = fRows;
        total = fTotal;
      }
    }

    const saved = new Set<string>();
    if (userId && rows.length) {
      const marks = await prisma.contentBookmark.findMany({
        where: { userId, shortVideoId: { in: rows.map((r) => r.id) } },
        select: { shortVideoId: true },
      });
      marks.forEach((m) => saved.add(m.shortVideoId));
    }

    const data = await Promise.all(rows.map((r) => serializeShort(r, { saved: saved.has(r.id) })));
    return reply.send({ data, meta: { page, limit, total, hasMore: skip + rows.length < total } });
  }

  async function detail(req: any, reply: any) {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const row = await prisma.shortVideo.findFirst({
      where: publicWhere({ id: p.data.id, ...(forcedKind && { kind: forcedKind }) }),
      include: shortInclude,
    });
    if (!row) return notFound(reply);

    const userId = (req.user as any)?.userId as string | undefined;
    const saved = userId
      ? !!(await prisma.contentBookmark.findUnique({
          where: { userId_shortVideoId: { userId, shortVideoId: row.id } },
          select: { id: true },
        }))
      : false;

    // Related: same kind + category, newest first.
    const related = await prisma.shortVideo.findMany({
      where: publicWhere({ id: { not: row.id }, kind: row.kind, category: row.category }),
      include: shortInclude,
      orderBy: { publishedAt: 'desc' },
      take: 5,
    });
    return reply.send({
      data: await serializeShort(row, { detail: true, saved }),
      related: await Promise.all(related.map((r) => serializeShort(r))),
    });
  }

  fastify.get('/', { preHandler: [fastify.optionalAuthenticate] }, list);
  // find-my-way prefers static segments, so '/bookmarks/list' never collides with '/:id'.
  fastify.get('/:id', { preHandler: [fastify.optionalAuthenticate] }, detail);
  if (forcedKind) return; // /schemes and /news expose read-only list + detail

  // ── Authenticated interactions ─────────────────────────────
  fastify.get('/bookmarks/list', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 20, maxLimit: 50 });
    const marks = await prisma.contentBookmark.findMany({
      where: { userId: (req.user as any).userId, shortVideo: publicWhere() },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
      include: { shortVideo: { include: shortInclude } },
    });
    const data = await Promise.all(marks.map((m) => serializeShort(m.shortVideo, { saved: true })));
    return reply.send({ data, meta: { page, limit, hasMore: marks.length === limit } });
  });

  fastify.post(
    '/:id/events',
    { preHandler: [fastify.authenticate], config: { rateLimit: { max: 120, timeWindow: '1 minute' } } },
    async (req, reply) => {
      const p = IdParams.safeParse(req.params);
      const b = EventBody.safeParse(req.body ?? {});
      if (!p.success) return sendValidationError(reply, p.error);
      if (!b.success) return sendValidationError(reply, b.error);

      const exists = await prisma.shortVideo.findFirst({ where: publicWhere({ id: p.data.id }), select: { id: true } });
      if (!exists) return notFound(reply);

      try {
        await prisma.contentEvent.create({
          data: { shortVideoId: p.data.id, userId: (req.user as any).userId, type: b.data.type, dayKey: todayKey() },
        });
      } catch (e) {
        // Duplicate (same user/type/day) → idempotent no-op, counters untouched.
        if (isDuplicate(e)) return reply.send({ counted: false });
        throw e;
      }
      if (b.data.type === 'VIEW') {
        await prisma.shortVideo.update({ where: { id: p.data.id }, data: { viewCount: { increment: 1 } } });
      } else if (b.data.type === 'SHARE') {
        await prisma.shortVideo.update({ where: { id: p.data.id }, data: { shareCount: { increment: 1 } } });
      }
      return reply.send({ counted: true });
    },
  );

  fastify.post(
    '/:id/report',
    { preHandler: [fastify.authenticate], config: { rateLimit: { max: 10, timeWindow: '1 minute' } } },
    async (req, reply) => {
      const p = IdParams.safeParse(req.params);
      const b = ReportBody.safeParse(req.body ?? {});
      if (!p.success) return sendValidationError(reply, p.error);
      if (!b.success) return sendValidationError(reply, b.error);

      const exists = await prisma.shortVideo.findFirst({ where: publicWhere({ id: p.data.id }), select: { id: true } });
      if (!exists) return notFound(reply);

      try {
        await prisma.contentReport.create({
          data: { shortVideoId: p.data.id, userId: (req.user as any).userId, reason: b.data.reason, note: b.data.note },
        });
      } catch (e) {
        if (isDuplicate(e)) return reply.send({ received: true, duplicate: true });
        throw e;
      }
      await prisma.shortVideo.update({ where: { id: p.data.id }, data: { reportCount: { increment: 1 } } });
      return reply.status(201).send({ received: true });
    },
  );

  fastify.post('/:id/bookmark', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const exists = await prisma.shortVideo.findFirst({ where: publicWhere({ id: p.data.id }), select: { id: true } });
    if (!exists) return notFound(reply);
    try {
      await prisma.contentBookmark.create({ data: { shortVideoId: p.data.id, userId: (req.user as any).userId } });
      await prisma.shortVideo.update({ where: { id: p.data.id }, data: { bookmarkCount: { increment: 1 } } });
    } catch (e) {
      if (!isDuplicate(e)) throw e;
    }
    return reply.send({ saved: true });
  });

  fastify.delete('/:id/bookmark', { preHandler: [fastify.authenticate] }, async (req, reply) => {
    const p = IdParams.safeParse(req.params);
    if (!p.success) return sendValidationError(reply, p.error);
    const res = await prisma.contentBookmark.deleteMany({
      where: { shortVideoId: p.data.id, userId: (req.user as any).userId },
    });
    if (res.count > 0) {
      await prisma.shortVideo.updateMany({
        where: { id: p.data.id, bookmarkCount: { gt: 0 } },
        data: { bookmarkCount: { decrement: 1 } },
      });
    }
    return reply.send({ saved: false });
  });
}

export const shortsRoutes = (f: FastifyInstance) => registerRoutes(f);
export const schemeFeedRoutes = async (f: FastifyInstance) => {
  await registerRoutes(f, 'SCHEME');

  // POST /api/v1/schemes/check-eligibility (Public)
  f.post('/check-eligibility', async (req, reply) => {
    const parsed = EligibilityInputSchema.safeParse(req.body ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const result = await checkSchemeEligibility(f.prisma, parsed.data);
    return reply.send({ data: result });
  });

  // GET /api/v1/schemes/catalog (Public)
  f.get('/catalog', async (_req, reply) => {
    const schemes = await f.prisma.scheme.findMany({
      where: { reviewStatus: { in: ['PUBLISHED', 'SOURCE_VERIFIED', 'NEEDS_REVIEW'] } },
      select: {
        id: true,
        slug: true,
        nameHi: true,
        officialName: true,
        category: true,
        scope: true,
        stateCode: true,
        benefits: true,
        documents: true,
        applicationMode: true,
        applicationUrl: true,
      },
      orderBy: { updatedAt: 'desc' },
    });
    return reply.send({ data: schemes, total: schemes.length });
  });
};
export const newsFeedRoutes = (f: FastifyInstance) => registerRoutes(f, 'NEWS');
