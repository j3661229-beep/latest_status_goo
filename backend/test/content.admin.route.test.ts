import { describe, it, expect, vi, beforeEach } from 'vitest';
import Fastify from 'fastify';
import { contentAdminRoutes, CONTENT_ADMIN_ROLES } from '../src/modules/content-admin/content.admin.route';

const NOW = Date.now();
const hoursAgo = (h: number) => new Date(NOW - h * 3_600_000);

const schemeVideo = (over: any = {}) => ({
  id: 'v1', kind: 'SCHEME', status: 'NEEDS_REVIEW', title: 'T', videoKey: 'v.mp4', thumbnailKey: 't.jpg',
  attribution: 'src', claims: [{ text: 'a', sourceUrl: 'https://x.gov.in' }], warnings: [], expiresAt: null,
  scheme: { sourceUrls: ['https://x.gov.in'], applicationUrl: 'https://x.gov.in/apply', lastVerifiedAt: hoursAgo(5), nextReviewAt: null },
  newsStory: null, newsStoryId: null, ...over,
});
const newsVideo = (story: any = {}, over: any = {}) =>
  schemeVideo({
    kind: 'NEWS', status: 'APPROVED', scheme: null, newsStoryId: 'n1',
    newsStory: { canonicalUrl: 'https://p.in/a', publisher: 'PIB', publishedAt: hoursAgo(2), lastVerifiedAt: hoursAgo(1),
                 isDeveloping: false, correctionStatus: 'NONE', ...story },
    ...over,
  });

let prisma: any;
let role = 'MANAGER';

async function build() {
  const app = Fastify();
  app.decorate('prisma', prisma);
  // Mirrors the real requireRole: 401 without a token, 403 for roles outside the list.
  app.decorate('requireRole', (roles: string[]) => async (req: any, reply: any) => {
    if (!req.headers.authorization) return reply.status(401).send({ message: 'no' });
    if (!roles.includes(role)) return reply.status(403).send({ message: 'forbidden' });
    req.user = { userId: 'admin1', role };
  });
  await app.register(contentAdminRoutes, { prefix: '/admin', startGeneration: async () => 'SCRIPT' });
  return app;
}
const h = { authorization: 'Bearer x' };
const post = (app: any, url: string, payload: any = {}) => app.inject({ method: 'POST', url: `/admin${url}`, headers: h, payload });

beforeEach(() => {
  role = 'MANAGER';
  prisma = {
    shortVideo: {
      findUnique: vi.fn().mockResolvedValue(schemeVideo()),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      update: vi.fn().mockResolvedValue({}),
      findMany: vi.fn().mockResolvedValue([]),
      count: vi.fn().mockResolvedValue(0),
    },
    newsStory: { update: vi.fn().mockResolvedValue({}) },
    contentReview: { create: vi.fn().mockResolvedValue({}) },
    contentJob: { count: vi.fn().mockResolvedValue(0), updateMany: vi.fn().mockResolvedValue({ count: 2 }) },
    appConfig: { findMany: vi.fn().mockResolvedValue([]), findUnique: vi.fn().mockResolvedValue(null) },
    auditLog: { create: vi.fn().mockResolvedValue({}) },
    $transaction: vi.fn((fn: any) => fn(prisma)),
  };
});

describe('RBAC', () => {
  it('rejects unauthenticated requests', async () => {
    const app = await build();
    const r = await app.inject({ method: 'POST', url: '/admin/content/v1/approve' });
    expect(r.statusCode).toBe(401);
  });
  it.each(['USER', 'CREATOR'])('forbids %s from approving or publishing', async (r) => {
    role = r;
    const app = await build();
    expect((await post(app, '/content/v1/approve')).statusCode).toBe(403);
    expect((await post(app, '/content/v1/publish')).statusCode).toBe(403);
    expect(prisma.shortVideo.updateMany).not.toHaveBeenCalled();
  });
  it('only admin roles are allowed', () => {
    expect(CONTENT_ADMIN_ROLES).toEqual(['MANAGER', 'SUPER_ADMIN']);
  });
});

describe('approve / reject', () => {
  it('approves reviewed content, records review + audit', async () => {
    prisma.shortVideo.findUnique
      .mockResolvedValueOnce(schemeVideo())
      .mockResolvedValue(schemeVideo({ status: 'APPROVED' }));
    const app = await build();
    const r = await post(app, '/content/v1/approve');
    expect(r.statusCode).toBe(200);
    expect(prisma.contentReview.create.mock.calls[0][0].data).toMatchObject({ action: 'approve', actorId: 'admin1' });
    expect(prisma.auditLog.create).toHaveBeenCalled();
  });
  it('refuses to approve content with no sources or video (422)', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ videoKey: null, claims: [] }));
    const app = await build();
    const r = await post(app, '/content/v1/approve');
    expect(r.statusCode).toBe(422);
    expect(r.json().problems).toContain('Missing rendered video');
    expect(prisma.shortVideo.updateMany).not.toHaveBeenCalled();
  });
  it('cannot skip review: a GENERATED item cannot be approved', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'GENERATED' }));
    const app = await build();
    expect((await post(app, '/content/v1/approve')).statusCode).toBe(409);
  });
  it('reject requires a real reason', async () => {
    const app = await build();
    expect((await post(app, '/content/v1/reject', { reason: 'no' })).statusCode).toBe(400);
    expect((await post(app, '/content/v1/reject', { reason: 'Eligibility not in source' })).statusCode).toBe(200);
  });
  it('is idempotent when already in the target state', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'APPROVED' }));
    const app = await build();
    const r = await post(app, '/content/v1/approve');
    expect(r.json().unchanged).toBe(true);
    expect(prisma.shortVideo.updateMany).not.toHaveBeenCalled();
  });
  it('409s when another reviewer changed it concurrently', async () => {
    prisma.shortVideo.updateMany.mockResolvedValue({ count: 0 });
    const app = await build();
    expect((await post(app, '/content/v1/approve')).statusCode).toBe(409);
    expect(prisma.contentReview.create).not.toHaveBeenCalled();
  });
});

describe('publish', () => {
  it('only publishes APPROVED content', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'NEEDS_REVIEW' }));
    const app = await build();
    expect((await post(app, '/content/v1/publish')).statusCode).toBe(409);
  });
  it('publishes approved scheme content', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'APPROVED' }));
    const app = await build();
    expect((await post(app, '/content/v1/publish')).statusCode).toBe(200);
    const data = prisma.shortVideo.update.mock.calls[0][0].data;
    expect(data.publishedById).toBe('admin1');
  });
  it('blocks news whose source was not re-checked recently', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(newsVideo({ lastVerifiedAt: hoursAgo(10) }));
    const app = await build();
    const r = await post(app, '/content/v1/publish');
    expect(r.statusCode).toBe(422);
    expect(r.json().problems.join()).toMatch(/re-checked/);
  });
  it('requires a much fresher check for developing stories', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(newsVideo({ isDeveloping: true, lastVerifiedAt: hoursAgo(2) }));
    const app = await build();
    expect((await post(app, '/content/v1/publish')).statusCode).toBe(422);
  });
  it('blocks stale news (older than the configured window)', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(newsVideo({ publishedAt: hoursAgo(100) }));
    const app = await build();
    expect((await post(app, '/content/v1/publish')).json().problems.join()).toMatch(/stale/);
  });
  it('blocks withdrawn source stories', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(newsVideo({ correctionStatus: 'WITHDRAWN' }));
    const app = await build();
    expect((await post(app, '/content/v1/publish')).statusCode).toBe(422);
  });
  it('publishes fresh news; scheduling sets a future publishedAt', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(newsVideo());
    const app = await build();
    const when = new Date(NOW + 3_600_000).toISOString();
    const r = await post(app, '/content/v1/publish', { scheduledAt: when });
    expect(r.statusCode).toBe(200);
    expect(prisma.shortVideo.update.mock.calls[0][0].data.publishedAt.toISOString()).toBe(when);
    expect(prisma.contentReview.create.mock.calls[0][0].data.action).toBe('schedule');
  });
});

describe('correction / unpublish', () => {
  it('correct takes content down and marks the news story corrected', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(newsVideo({}, { status: 'PUBLISHED' }));
    const app = await build();
    const r = await post(app, '/content/v1/correct', { note: 'Figure was wrong in source' });
    expect(r.statusCode).toBe(200);
    expect(prisma.shortVideo.updateMany.mock.calls[0][0].data.status).toBe('CORRECTION_REQUIRED');
    expect(prisma.newsStory.update.mock.calls[0][0].data.correctionStatus).toBe('CORRECTED');
  });
  it('withdraw unpublishes and marks the story withdrawn', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(newsVideo({}, { status: 'PUBLISHED' }));
    const app = await build();
    await post(app, '/content/v1/correct', { note: 'Publisher retracted story', withdraw: true });
    expect(prisma.shortVideo.updateMany.mock.calls[0][0].data.status).toBe('UNPUBLISHED');
    expect(prisma.newsStory.update.mock.calls[0][0].data.correctionStatus).toBe('WITHDRAWN');
  });
  it('unpublish needs a reason', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'PUBLISHED' }));
    const app = await build();
    expect((await post(app, '/content/v1/unpublish', {})).statusCode).toBe(400);
    expect((await post(app, '/content/v1/unpublish', { reason: 'Scheme closed for applications' })).statusCode).toBe(200);
  });
});

describe('edit', () => {
  it('editing the script of an item with a finished video drops the render and its approval; the card status is untouched', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ format: 'CARD_WITH_VIDEO', videoState: 'READY', videoApprovedAt: new Date() }));
    const app = await build();
    const r = await app.inject({
      method: 'PATCH', url: '/admin/content/v1', headers: h,
      payload: { script: { narration: 'यह नई कथा है, पर्याप्त लंबी।' } },
    });
    expect(r.statusCode).toBe(200);
    expect(r.json().needsRerender).toBe(true);
    const data = prisma.shortVideo.update.mock.calls[0][0].data;
    expect(data).toMatchObject({ videoKey: null, audioKey: null, videoState: 'NOT_REQUESTED', videoApprovedAt: null });
    expect(data.status).toBeUndefined();
  });
  it('editing a card-only item never touches video state', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ format: 'CARD_ONLY', videoState: 'NOT_REQUESTED' }));
    const app = await build();
    const r = await app.inject({ method: 'PATCH', url: '/admin/content/v1', headers: h, payload: { title: 'नया शीर्षक' } });
    expect(r.statusCode).toBe(200);
    expect(r.json().needsRerender).toBe(false);
    expect(prisma.shortVideo.update.mock.calls[0][0].data).not.toHaveProperty('videoState');
  });
  it('refuses render-affecting edits while a video is generating', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ format: 'CARD_WITH_VIDEO', videoState: 'GENERATING' }));
    const app = await build();
    const r = await app.inject({ method: 'PATCH', url: '/admin/content/v1', headers: h, payload: { title: 'नया शीर्षक' } });
    expect(r.statusCode).toBe(409);
  });
  it('refuses to edit published content', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'PUBLISHED' }));
    const app = await build();
    const r = await app.inject({ method: 'PATCH', url: '/admin/content/v1', headers: h, payload: { title: 'New title' } });
    expect(r.statusCode).toBe(409);
  });
  it('rejects non-https claim sources', async () => {
    const app = await build();
    const r = await app.inject({
      method: 'PATCH', url: '/admin/content/v1', headers: h,
      payload: { claims: [{ text: 'x', sourceUrl: 'http://insecure.example' }] },
    });
    expect(r.statusCode).toBe(400);
  });
});

describe('retry', () => {
  it('retries a FAILED video: back to QUEUED and failed jobs re-armed', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ format: 'CARD_WITH_VIDEO', videoState: 'FAILED' }));
    const app = await build();
    const r = await post(app, '/content/v1/retry');
    expect(r.statusCode).toBe(202);
    expect(prisma.contentJob.updateMany.mock.calls[0][0].data).toMatchObject({ state: 'QUEUED', attempts: 0 });
  });
  it('enforces the retry limit', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ format: 'CARD_WITH_VIDEO', videoState: 'FAILED' }));
    prisma.contentJob.count.mockResolvedValue(5);
    const app = await build();
    const r = await post(app, '/content/v1/retry');
    expect(r.statusCode).toBe(422);
    expect(prisma.contentJob.updateMany).not.toHaveBeenCalled();
  });
});

describe('request-review', () => {
  it('returns corrected content to the queue only if it is structurally publishable', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'CORRECTION_REQUIRED', videoKey: null }));
    const app = await build();
    expect((await post(app, '/content/v1/request-review')).statusCode).toBe(422);
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ status: 'EXPIRED' }));
    expect((await post(app, '/content/v1/request-review')).statusCode).toBe(200);
  });
});

describe('edit merges the script instead of replacing it', () => {
  it('a narration-only edit keeps scenes and key facts', async () => {
    prisma.shortVideo.findUnique.mockResolvedValue(schemeVideo({ script: { narration: 'पुरानी', scenes: [{ caption: 'क' }], keyFacts: ['तथ्य'] } }));
    const app = await build();
    const r = await app.inject({ method: 'PATCH', url: '/admin/content/v1', headers: h, payload: { script: { narration: 'यह नई कथा है, पर्याप्त लंबी है।' } } });
    expect(r.statusCode).toBe(200);
    expect(prisma.shortVideo.update.mock.calls[0][0].data.script).toEqual({
      narration: 'यह नई कथा है, पर्याप्त लंबी है।', scenes: [{ caption: 'क' }], keyFacts: ['तथ्य'],
    });
  });
  it('captions may omit timings (they are proportional)', async () => {
    const app = await build();
    const r = await app.inject({ method: 'PATCH', url: '/admin/content/v1', headers: h, payload: { captions: [{ text: 'नया कैप्शन' }] } });
    expect(r.statusCode).toBe(200);
  });
  it('the optimistic lock uses a non-empty update (empty updateMany data matches 0 rows in Prisma)', async () => {
    const app = await build();
    await app.inject({ method: 'PATCH', url: '/admin/content/v1', headers: h, payload: { title: 'नया शीर्षक' } });
    expect(Object.keys(prisma.shortVideo.updateMany.mock.calls[0][0].data).length).toBeGreaterThan(0);
  });
});
