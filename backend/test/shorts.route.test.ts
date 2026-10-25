import { describe, it, expect, vi, beforeEach } from 'vitest';
import Fastify from 'fastify';
import { Prisma } from '@prisma/client';

vi.mock('../src/lib/content/assets', () => ({
  resolveAssetUrl: async (k?: string | null) => (k ? `https://cdn.test/${k}` : null),
}));

import { shortsRoutes, schemeFeedRoutes } from '../src/modules/shorts/shorts.route';

const row = (over: any = {}) => ({
  id: 's1', kind: 'SCHEME', title: 'T', hook: null, category: 'FARMER', region: null, language: 'HINDI',
  videoKey: 'v.mp4', thumbnailKey: 't.jpg', durationSec: 25, captions: [], attribution: 'src',
  publishedAt: new Date('2026-10-01'), correctionNote: null, description: null, claims: [], warnings: [],
  format: 'CARD_WITH_VIDEO', videoState: 'READY', videoApprovedAt: new Date('2026-10-02'),
  costMicroUsd: 5, aiMeta: { m: 1 }, scheme: null, newsStory: null, ...over,
});

const dupErr = () => new Prisma.PrismaClientKnownRequestError('dup', { code: 'P2002', clientVersion: 'x' });

async function build(prisma: any, user: any = { userId: 'u1' }) {
  const app = Fastify();
  app.decorate('prisma', prisma);
  app.decorate('authenticate', async (req: any, reply: any) => {
    if (!req.headers.authorization) return reply.status(401).send({ message: 'no' });
    req.user = user;
  });
  app.decorate('optionalAuthenticate', async (req: any) => {
    if (req.headers.authorization) req.user = user;
  });
  await app.register(shortsRoutes, { prefix: '/shorts' });
  await app.register(schemeFeedRoutes, { prefix: '/schemes' });
  return app;
}

let prisma: any;
const auth = { authorization: 'Bearer x' };

beforeEach(() => {
  prisma = {
    shortVideo: {
      findMany: vi.fn().mockResolvedValue([row()]),
      findFirst: vi.fn().mockResolvedValue(row()),
      count: vi.fn().mockResolvedValue(25),
      update: vi.fn().mockResolvedValue({}),
      updateMany: vi.fn().mockResolvedValue({}),
    },
    contentBookmark: {
      findMany: vi.fn().mockResolvedValue([]),
      findUnique: vi.fn(),
      create: vi.fn().mockResolvedValue({}),
      deleteMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    contentEvent: { create: vi.fn().mockResolvedValue({}) },
    contentReport: { create: vi.fn().mockResolvedValue({}) },
  };
});

describe('feed', () => {
  it('adds a trimmed card summary from the description, falling back to the narration', async () => {
    const long = 'शब्द '.repeat(200);
    prisma.shortVideo.findMany.mockResolvedValue([
      row({ id: 'a', description: long }),
      row({ id: 'b', description: null, script: { narration: 'छोटा सारांश' } }),
      row({ id: 'c' }),
    ]);
    const app = await build(prisma);
    const res = await app.inject({ method: 'GET', url: '/shorts' });
    const [a, b, c] = res.json().data;
    expect(a.summary.length).toBeLessThanOrEqual(421);
    expect(a.summary.endsWith('…')).toBe(true);
    expect(b.summary).toBe('छोटा सारांश');
    expect(c.summary).toBeNull();
  });

  it('only queries PUBLISHED, non-expired content and paginates', async () => {
    const app = await build(prisma);
    const res = await app.inject({ url: '/shorts?page=2&limit=10&kind=NEWS&category=FARMER' });
    expect(res.statusCode).toBe(200);
    const args = prisma.shortVideo.findMany.mock.calls[0][0];
    expect(args.where.status).toBe('PUBLISHED');
    expect(JSON.stringify(args.where)).toContain('expiresAt');
    expect(args.skip).toBe(10);
    expect(args.take).toBe(10);
    expect(res.json().meta).toMatchObject({ page: 2, total: 25, hasMore: true });
  });

  it('/schemes forces kind=SCHEME even if client asks for NEWS', async () => {
    const app = await build(prisma);
    await app.inject({ url: '/schemes?kind=NEWS' });
    expect(JSON.stringify(prisma.shortVideo.findMany.mock.calls[0][0].where)).toContain('"kind":"SCHEME"');
  });

  it('rejects invalid kind with 400 and clamps limit', async () => {
    const app = await build(prisma);
    expect((await app.inject({ url: '/shorts?kind=BOGUS' })).statusCode).toBe(400);
    await app.inject({ url: '/shorts?limit=9999' });
    expect(prisma.shortVideo.findMany.mock.calls[0][0].take).toBe(30);
  });

  it('does not leak internal fields', async () => {
    const app = await build(prisma);
    const item = (await app.inject({ url: '/shorts' })).json().data[0];
    expect(item.videoUrl).toBe('https://cdn.test/v.mp4');
    expect(item.format).toBe('CARD_WITH_VIDEO');
    expect(item).not.toHaveProperty('costMicroUsd');
    expect(item).not.toHaveProperty('videoFailureReason');
    expect(item).not.toHaveProperty('videoRequestedById');
    expect(item).not.toHaveProperty('aiMeta');
    expect(item.disclaimer).toMatch(/AI-assisted/);
  });

  it.each([
    ['card-only', { format: 'CARD_ONLY', videoState: 'NOT_REQUESTED', videoApprovedAt: null }],
    ['video not approved', { videoApprovedAt: null }],
    ['video still generating', { videoState: 'GENERATING', videoApprovedAt: null }],
    ['video failed', { videoState: 'FAILED', videoApprovedAt: null }],
    ['approved video but switched back to card-only', { format: 'CARD_ONLY' }],
    ['ready+approved but no uploaded file', { videoKey: null }],
  ])('exposes NO video or video frame for %s (the card is still served)', async (_n, over) => {
    prisma.shortVideo.findMany.mockResolvedValue([row({ description: 'सारांश', ...over })]);
    const app = await build(prisma);
    const item = (await app.inject({ url: '/shorts' })).json().data[0];
    expect(item.videoUrl).toBeNull();
    expect(item.thumbnailUrl).toBeNull();
    expect(item.durationSec).toBeNull();
    expect(item.summary).toBe('सारांश');
  });

  it('detail includes a text alternative (narration, key facts) but list items do not', async () => {
    prisma.shortVideo.findFirst.mockResolvedValue(row({ script: { narration: 'पाठ', keyFacts: ['तथ्य'] } }));
    prisma.shortVideo.findMany.mockResolvedValue([]);
    prisma.contentBookmark.findUnique.mockResolvedValue(null);
    const app = await build(prisma);
    const d = (await app.inject({ url: '/shorts/s1' })).json().data;
    expect(d.narration).toBe('पाठ');
    expect(d.keyFacts).toEqual(['तथ्य']);
    prisma.shortVideo.findMany.mockResolvedValue([row({ script: { narration: 'x' } })]);
    expect((await app.inject({ url: '/shorts' })).json().data[0]).not.toHaveProperty('narration');
  });

  it('detail 404s for unpublished or missing content', async () => {
    prisma.shortVideo.findFirst.mockResolvedValue(null);
    const app = await build(prisma);
    expect((await app.inject({ url: '/shorts/nope' })).statusCode).toBe(404);
  });
});

describe('interactions', () => {
  it('require authentication', async () => {
    const app = await build(prisma);
    const r = await app.inject({ method: 'POST', url: '/shorts/s1/events', payload: { type: 'VIEW' } });
    expect(r.statusCode).toBe(401);
  });

  it('counts a first event and ignores duplicates', async () => {
    const app = await build(prisma);
    let r = await app.inject({ method: 'POST', url: '/shorts/s1/events', headers: auth, payload: { type: 'VIEW' } });
    expect(r.json()).toEqual({ counted: true });
    expect(prisma.shortVideo.update).toHaveBeenCalledTimes(1);
    prisma.contentEvent.create.mockRejectedValue(dupErr());
    r = await app.inject({ method: 'POST', url: '/shorts/s1/events', headers: auth, payload: { type: 'VIEW' } });
    expect(r.json()).toEqual({ counted: false });
    expect(prisma.shortVideo.update).toHaveBeenCalledTimes(1);
  });

  it('rejects unknown event types', async () => {
    const app = await build(prisma);
    const r = await app.inject({ method: 'POST', url: '/shorts/s1/events', headers: auth, payload: { type: 'HACK' } });
    expect(r.statusCode).toBe(400);
  });

  it('report: creates once, duplicate is a no-op', async () => {
    const app = await build(prisma);
    let r = await app.inject({ method: 'POST', url: '/shorts/s1/report', headers: auth, payload: { reason: 'OUTDATED' } });
    expect(r.statusCode).toBe(201);
    prisma.contentReport.create.mockRejectedValue(dupErr());
    r = await app.inject({ method: 'POST', url: '/shorts/s1/report', headers: auth, payload: { reason: 'OUTDATED' } });
    expect(r.json()).toMatchObject({ duplicate: true });
    expect(prisma.shortVideo.update).toHaveBeenCalledTimes(1);
  });

  it('bookmark is idempotent', async () => {
    const app = await build(prisma);
    prisma.contentBookmark.create.mockRejectedValue(dupErr());
    const r = await app.inject({ method: 'POST', url: '/shorts/s1/bookmark', headers: auth });
    expect(r.json()).toEqual({ saved: true });
    expect(prisma.shortVideo.update).not.toHaveBeenCalled();
  });
});
