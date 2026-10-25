// Admin-controlled content format: CARD_ONLY vs CARD_WITH_VIDEO.
// Proves: no implicit video jobs, exactly one job per explicit admin request, idempotency under
// concurrency, cards survive failed/absent videos, and unapproved videos are never exposed.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import Fastify from 'fastify';
import { contentAdminRoutes } from '../src/modules/content-admin/content.admin.route';
import { requestVideoGeneration } from '../src/lib/content/video-request';
import {
  isVideoPublic, publishBlockers, videoApprovalBlockers, videoRequestBlockers,
} from '../src/lib/content/lifecycle';
import { newsCardDefaults, schemeCardDefaults } from '../src/lib/content/card-defaults';

const NOW = Date.now();
const hoursAgo = (h: number) => new Date(NOW - h * 3_600_000);

const mkNews = (over: any = {}) => ({
  id: 'v1', kind: 'NEWS', status: 'DRAFT', title: 'शीर्षक', description: 'एडमिन द्वारा जाँचा गया सारांश', attribution: 'स्रोत: PIB',
  format: 'CARD_ONLY', videoState: 'NOT_REQUESTED', videoKey: null, thumbnailKey: null, claims: null, warnings: null,
  expiresAt: null, scriptVersion: 1, videoRequestedAt: null, videoRequestedById: null, videoFailureReason: null,
  videoApprovedAt: null, videoApprovedById: null, scheme: null, newsStoryId: 'n1',
  newsStory: { canonicalUrl: 'https://pib.gov.in/a', publisher: 'PIB', publishedAt: hoursAgo(2), lastVerifiedAt: hoursAgo(1), isDeveloping: false, correctionStatus: 'NONE' },
  ...over,
});

/** Single-record stateful fake with REAL compare-and-set semantics in updateMany. */
function statefulPrisma(initial: any) {
  const state = { video: { ...initial }, jobsFailed: 0 };
  const match = (v: any, where: any) => {
    if (where.id && v.id !== where.id) return false;
    if (where.status && v.status !== where.status) return false;
    if (where.format && v.format !== where.format) return false;
    if (where.videoKey !== undefined && v.videoKey !== where.videoKey) return false;
    if (where.videoApprovedAt?.not === null && !v.videoApprovedAt) return false;
    if (where.videoState) {
      const ok = typeof where.videoState === 'string' ? v.videoState === where.videoState : where.videoState.in.includes(v.videoState);
      if (!ok) return false;
    }
    return true;
  };
  const apply = (data: any) => {
    for (const [k, val] of Object.entries<any>(data)) {
      if (val && typeof val === 'object' && 'increment' in val) state.video[k] = (state.video[k] ?? 0) + val.increment;
      else state.video[k] = val;
    }
  };
  const p: any = {
    state,
    shortVideo: {
      findUnique: vi.fn(async () => ({ ...state.video })),
      updateMany: vi.fn(async ({ where, data }: any) => {
        if (!match(state.video, where)) return { count: 0 };
        apply(data); return { count: 1 };
      }),
      update: vi.fn(async ({ data }: any) => { apply(data); return { ...state.video }; }),
    },
    contentJob: {
      count: vi.fn(async () => state.jobsFailed),
      updateMany: vi.fn(async () => ({ count: 0 })),
      findUnique: vi.fn(async () => null),
    },
    contentReview: { create: vi.fn(async () => ({})) },
    auditLog: { create: vi.fn(async () => ({})) },
    appConfig: { findUnique: vi.fn(async () => null), findMany: vi.fn(async () => []) },
    $transaction: vi.fn(async (fn: any) => fn(p)),
  };
  return p;
}

describe('lifecycle rules', () => {
  it('a card needs title, summary, attribution and source — but never a video, thumbnail or claims', () => {
    expect(publishBlockers(mkNews() as any)).toEqual([]);
    expect(publishBlockers(mkNews({ format: 'CARD_WITH_VIDEO' }) as any)).toEqual([]); // video absent ≠ card blocked
    expect(publishBlockers(mkNews({ description: ' ' }) as any)).toContain('Missing card summary');
    expect(publishBlockers(mkNews({ attribution: null }) as any)).toContain('Missing source attribution text');
    expect(publishBlockers(mkNews({ newsStory: null }) as any)).toContain('News story record missing');
  });
  it('legacy records without a format keep the old strict rules', () => {
    const legacy = { kind: 'NEWS', title: 'T', attribution: 'a', newsStory: mkNews().newsStory } as any;
    expect(publishBlockers(legacy)).toEqual(expect.arrayContaining(['Missing rendered video', 'Missing thumbnail']));
  });
  it('a video is public only when CARD_WITH_VIDEO + READY + approved + uploaded', () => {
    const ok = { format: 'CARD_WITH_VIDEO', videoState: 'READY', videoApprovedAt: new Date(), videoKey: 'k' } as const;
    expect(isVideoPublic(ok)).toBe(true);
    expect(isVideoPublic({ ...ok, format: 'CARD_ONLY' })).toBe(false);
    expect(isVideoPublic({ ...ok, videoState: 'FAILED' })).toBe(false);
    expect(isVideoPublic({ ...ok, videoState: 'GENERATING' })).toBe(false);
    expect(isVideoPublic({ ...ok, videoApprovedAt: null })).toBe(false);
    expect(isVideoPublic({ ...ok, videoKey: null })).toBe(false);
  });
  it('video approval needs a ready, uploaded video with a thumbnail and claims', () => {
    const ready = mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'READY', videoKey: 'v', thumbnailKey: 't', claims: [{ text: 'x' }] }) as any;
    expect(videoApprovalBlockers(ready)).toEqual([]);
    expect(videoApprovalBlockers({ ...ready, videoState: 'GENERATING' })).toContain('Video is not ready');
    expect(videoApprovalBlockers({ ...ready, claims: [] })).toContain('No source-referenced claims recorded');
  });
  it('a request needs the Card+Video format and a valid source', () => {
    expect(videoRequestBlockers(mkNews() as any)).toContain('Set the format to Card + Video first');
    expect(videoRequestBlockers(mkNews({ format: 'CARD_WITH_VIDEO' }) as any)).toEqual([]);
    expect(videoRequestBlockers(mkNews({ format: 'CARD_WITH_VIDEO', newsStory: null }) as any)).toContain('News story record missing');
    const scheme = (s: any) => mkNews({ format: 'CARD_WITH_VIDEO', kind: 'SCHEME', newsStory: null, scheme: s }) as any;
    expect(videoRequestBlockers(scheme({ sourceUrls: [], lastVerifiedAt: new Date() }))).toContain('Scheme has no official source URLs');
    expect(videoRequestBlockers(scheme({ sourceUrls: ['https://x.gov.in'], lastVerifiedAt: null }))).toContain('Scheme has not been verified');
  });
  it('card defaults come verbatim from the stored source', () => {
    expect(newsCardDefaults({ publisher: 'PIB', summary: '  एक   दो ' })).toEqual({ description: 'एक दो', attribution: 'स्रोत: PIB' });
    expect(newsCardDefaults({ publisher: 'PIB', summary: null }).description).toBeNull();
    expect(schemeCardDefaults({ department: null, officialName: 'PM Kisan', benefits: ['लाभ 1', 'लाभ 2'] }))
      .toEqual({ description: 'लाभ 1 लाभ 2', attribution: 'स्रोत: PM Kisan' });
  });
});

describe('requestVideoGeneration (the only enqueue path)', () => {
  let start: ReturnType<typeof vi.fn>;
  beforeEach(() => { start = vi.fn(async () => 'SCRIPT'); });

  it('refuses a CARD_ONLY item and enqueues nothing', async () => {
    const prisma = statefulPrisma(mkNews());
    const r = await requestVideoGeneration({ prisma, start }, 'v1', 'admin1');
    expect(r).toMatchObject({ ok: false, code: 422 });
    expect(start).not.toHaveBeenCalled();
    expect(prisma.state.video.videoState).toBe('NOT_REQUESTED');
  });

  it('an explicit request enqueues exactly one job and records who asked', async () => {
    const prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO' }));
    const r = await requestVideoGeneration({ prisma, start }, 'v1', 'admin1');
    expect(r).toMatchObject({ ok: true, queued: true, state: 'QUEUED', duplicate: false });
    expect(start).toHaveBeenCalledTimes(1);
    expect(prisma.state.video).toMatchObject({ videoState: 'QUEUED', videoRequestedById: 'admin1' });
    expect(prisma.state.video.status).toBe('DRAFT'); // the card lifecycle is untouched
  });

  it('repeated clicks do not create another job', async () => {
    const prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO' }));
    await requestVideoGeneration({ prisma, start }, 'v1', 'admin1');
    const again = await requestVideoGeneration({ prisma, start }, 'v1', 'admin1');
    expect(again).toMatchObject({ ok: true, queued: false, duplicate: true });
    expect(start).toHaveBeenCalledTimes(1);
  });

  it('concurrent requests (double-click, two admins) still enqueue exactly once', async () => {
    const prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO' }));
    const results = await Promise.all(Array.from({ length: 8 }, (_, i) => requestVideoGeneration({ prisma, start }, 'v1', `admin${i}`)));
    expect(start).toHaveBeenCalledTimes(1);
    expect(results.filter((r) => r.ok && r.queued)).toHaveLength(1);
    expect(results.every((r) => r.ok)).toBe(true);
  });

  it('is a no-op while generating, and refuses when a video already exists', async () => {
    const generating = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'GENERATING' }));
    expect(await requestVideoGeneration({ prisma: generating, start }, 'v1', 'a')).toMatchObject({ ok: true, duplicate: true, queued: false });
    const ready = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'READY' }));
    expect(await requestVideoGeneration({ prisma: ready, start }, 'v1', 'a')).toMatchObject({ ok: false, code: 409 });
    expect(start).not.toHaveBeenCalled();
  });

  it('refuses rejected/expired content and ineligible sources', async () => {
    for (const status of ['REJECTED', 'EXPIRED']) {
      const p = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', status }));
      expect(await requestVideoGeneration({ prisma: p, start }, 'v1', 'a')).toMatchObject({ ok: false, code: 409 });
    }
    const noSource = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', newsStory: null }));
    expect(await requestVideoGeneration({ prisma: noSource, start }, 'v1', 'a')).toMatchObject({ ok: false, code: 422 });
    expect(start).not.toHaveBeenCalled();
  });

  it('a queue outage rolls the state back so the admin can simply click again', async () => {
    const prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO' }));
    const down = vi.fn().mockRejectedValueOnce(new Error('redis down')).mockResolvedValue('SCRIPT');
    const r1 = await requestVideoGeneration({ prisma, start: down }, 'v1', 'a');
    expect(r1).toMatchObject({ ok: false, code: 503 });
    expect(prisma.state.video.videoState).toBe('NOT_REQUESTED');
    const r2 = await requestVideoGeneration({ prisma, start: down }, 'v1', 'a');
    expect(r2).toMatchObject({ ok: true, queued: true });
  });

  it('retries a FAILED video (re-arming old job rows) until the retry limit', async () => {
    const prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'FAILED', videoFailureReason: 'x' }));
    const r = await requestVideoGeneration({ prisma, start }, 'v1', 'a');
    expect(r).toMatchObject({ ok: true, queued: true });
    expect(prisma.state.video.videoFailureReason).toBeNull();
    expect(prisma.contentJob.updateMany.mock.calls[0][0].data).toMatchObject({ state: 'QUEUED', attempts: 0 });

    const limited = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'FAILED' }));
    limited.state.jobsFailed = 5;
    expect(await requestVideoGeneration({ prisma: limited, start, maxManualRetries: 5 }, 'v1', 'a')).toMatchObject({ ok: false, code: 422 });
  });
});

describe('admin routes', () => {
  let prisma: any;
  let start: ReturnType<typeof vi.fn>;
  let role = 'MANAGER';

  async function build() {
    const app = Fastify();
    app.decorate('prisma', prisma);
    app.decorate('requireRole', (roles: string[]) => async (req: any, reply: any) => {
      if (!req.headers.authorization) return reply.status(401).send({ message: 'no' });
      if (!roles.includes(role)) return reply.status(403).send({ message: 'forbidden' });
      req.user = { userId: 'admin1', role };
    });
    await app.register(contentAdminRoutes, { prefix: '/admin', startGeneration: start as any });
    return app;
  }
  const h = { authorization: 'Bearer x' };
  const call = (app: any, method: string, url: string, payload: any = {}) =>
    app.inject({ method, url: `/admin${url}`, headers: h, payload });

  beforeEach(() => {
    role = 'MANAGER';
    start = vi.fn(async () => 'SCRIPT');
    prisma = statefulPrisma(mkNews());
  });

  it('only authenticated MANAGER/SUPER_ADMIN can request a video', async () => {
    prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO' }));
    const app = await build();
    expect((await app.inject({ method: 'POST', url: '/admin/content/v1/video/generate' })).statusCode).toBe(401);
    role = 'CREATOR';
    expect((await call(app, 'POST', '/content/v1/video/generate')).statusCode).toBe(403);
    expect(start).not.toHaveBeenCalled();
  });

  it('changing the format never starts a job; the default is CARD_ONLY', async () => {
    const app = await build();
    expect(prisma.state.video.format).toBe('CARD_ONLY');
    const r = await call(app, 'PATCH', '/content/v1/format', { format: 'CARD_WITH_VIDEO' });
    expect(r.statusCode).toBe(200);
    expect(prisma.state.video).toMatchObject({ format: 'CARD_WITH_VIDEO', videoState: 'NOT_REQUESTED' });
    expect(start).not.toHaveBeenCalled();
  });

  it('switching back to CARD_ONLY hides an approved video; it is blocked while generating', async () => {
    prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'READY', videoApprovedAt: new Date(), videoKey: 'v' }));
    const app = await build();
    expect((await call(app, 'PATCH', '/content/v1/format', { format: 'CARD_ONLY' })).statusCode).toBe(200);
    expect(prisma.state.video.videoApprovedAt).toBeNull();

    prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'GENERATING' }));
    const app2 = await build();
    expect((await call(app2, 'PATCH', '/content/v1/format', { format: 'CARD_ONLY' })).statusCode).toBe(409);
  });

  it('Publish as News Card publishes a CARD_ONLY item with zero video jobs', async () => {
    const app = await build();
    const r = await call(app, 'POST', '/content/v1/publish-card');
    expect(r.statusCode).toBe(200);
    expect(prisma.state.video).toMatchObject({ status: 'PUBLISHED', approvedById: 'admin1', publishedById: 'admin1' });
    expect(start).not.toHaveBeenCalled();
    expect(prisma.contentJob.updateMany).not.toHaveBeenCalled();
    expect(prisma.contentReview.create.mock.calls[0][0].data.action).toBe('publish_card');
  });

  it('a Card+Video item publishes as a card without any video', async () => {
    prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO' }));
    const app = await build();
    expect((await call(app, 'POST', '/content/v1/publish-card')).statusCode).toBe(200);
    expect(prisma.state.video.status).toBe('PUBLISHED');
    expect(prisma.state.video.videoState).toBe('NOT_REQUESTED');
    expect(start).not.toHaveBeenCalled();
  });

  it('a failed video does not stop (or unpublish) the card', async () => {
    prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'FAILED', videoFailureReason: 'Video generation failed.' }));
    const app = await build();
    expect((await call(app, 'POST', '/content/v1/publish-card')).statusCode).toBe(200);
    expect(prisma.state.video.status).toBe('PUBLISHED');
  });

  it('publish-card refuses an incomplete card (no summary) and stale news', async () => {
    prisma = statefulPrisma(mkNews({ description: null }));
    const app = await build();
    const r = await call(app, 'POST', '/content/v1/publish-card');
    expect(r.statusCode).toBe(422);
    expect(r.json().problems).toContain('Missing card summary');
    expect(prisma.state.video.status).toBe('DRAFT');

    prisma = statefulPrisma(mkNews({ newsStory: { ...mkNews().newsStory, publishedAt: hoursAgo(100) } }));
    const app2 = await build();
    expect((await call(app2, 'POST', '/content/v1/publish-card')).statusCode).toBe(422);
  });

  it('ordinary review → approve → publish never enqueues a video either', async () => {
    const app = await build();
    expect((await call(app, 'POST', '/content/v1/request-review')).statusCode).toBe(200);
    expect((await call(app, 'POST', '/content/v1/approve')).statusCode).toBe(200);
    expect((await call(app, 'POST', '/content/v1/publish')).statusCode).toBe(200);
    expect(prisma.state.video.status).toBe('PUBLISHED');
    expect(start).not.toHaveBeenCalled();
  });

  it('Generate Video: first click queues (202), the repeat is an idempotent 200', async () => {
    prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO' }));
    const app = await build();
    const a = await call(app, 'POST', '/content/v1/video/generate');
    const b = await call(app, 'POST', '/content/v1/video/generate');
    expect(a.statusCode).toBe(202);
    expect(a.json()).toMatchObject({ queued: true, videoState: 'QUEUED' });
    expect(b.statusCode).toBe(200);
    expect(b.json()).toMatchObject({ queued: false, duplicate: true });
    expect(start).toHaveBeenCalledTimes(1);
  });

  it('Generate Video on a CARD_ONLY item is refused with the reason', async () => {
    const app = await build();
    const r = await call(app, 'POST', '/content/v1/video/generate');
    expect(r.statusCode).toBe(422);
    expect(r.json().problems).toContain('Set the format to Card + Video first');
    expect(start).not.toHaveBeenCalled();
  });

  it('the legacy /content/generate alias goes through the same guarded path', async () => {
    const app = await build();
    expect((await call(app, 'POST', '/content/generate', { shortVideoId: 'v1' })).statusCode).toBe(422);
    expect(start).not.toHaveBeenCalled();
  });

  it('video approval: refused until READY, then makes it public-ready; repeats are idempotent', async () => {
    prisma = statefulPrisma(mkNews({ format: 'CARD_WITH_VIDEO', videoState: 'GENERATING' }));
    const app = await build();
    expect((await call(app, 'POST', '/content/v1/video/approve')).statusCode).toBe(422);
    expect(prisma.state.video.videoApprovedAt).toBeNull();

    Object.assign(prisma.state.video, { videoState: 'READY', videoKey: 'v.mp4', thumbnailKey: 't.jpg', claims: [{ text: 'c', sourceUrl: 'https://x.gov.in' }] });
    const ok = await call(app, 'POST', '/content/v1/video/approve');
    expect(ok.statusCode).toBe(200);
    expect(prisma.state.video.videoApprovedAt).toBeInstanceOf(Date);
    expect(isVideoPublic(prisma.state.video)).toBe(true);
    const again = await call(app, 'POST', '/content/v1/video/approve');
    expect(again.json().unchanged).toBe(true);
  });

  it('unapprove pulls only the video from the feed; discard resets it for a new request', async () => {
    prisma = statefulPrisma(mkNews({
      status: 'PUBLISHED', format: 'CARD_WITH_VIDEO', videoState: 'READY', videoKey: 'v', thumbnailKey: 't', videoApprovedAt: new Date(),
    }));
    const app = await build();
    await call(app, 'POST', '/content/v1/video/unapprove');
    expect(prisma.state.video).toMatchObject({ status: 'PUBLISHED', videoApprovedAt: null, videoState: 'READY' });
    expect(isVideoPublic(prisma.state.video)).toBe(false);

    await call(app, 'POST', '/content/v1/video/discard');
    expect(prisma.state.video).toMatchObject({ status: 'PUBLISHED', videoState: 'NOT_REQUESTED', videoKey: null, thumbnailKey: null });
  });
});
