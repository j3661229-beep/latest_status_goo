// End-to-end test against a REAL Postgres (schema from prisma/schema.prisma already applied).
// Skipped unless INTEGRATION_DATABASE_URL is set, so `npm test` stays hermetic.
//   INTEGRATION_DATABASE_URL=postgresql://user@127.0.0.1:5432/scratch npx vitest run test/integration
// WARNING: this test DELETES all rows from the content tables. Point it at a scratch database only.
// External providers (Gemini, TTS, ffmpeg, GCS) are faked — it verifies our logic and our SQL.
import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import Fastify, { FastifyInstance } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { writeFile } from 'fs/promises';
import { shortsRoutes, schemeFeedRoutes, newsFeedRoutes } from '../../src/modules/shorts/shorts.route';
import { contentAdminRoutes } from '../../src/modules/content-admin/content.admin.route';
import { runStage, recordFailure, PipelineDeps } from '../../src/lib/content/pipeline';
import { contentConfig } from '../../src/lib/content/config';
import { runMaintenanceTick } from '../../src/lib/content/maintenance';
import { saveSettings } from '../../src/lib/content/settings';
import { expirePublished, checkPublishedSources } from '../../src/lib/content/freshness';
import { FetchError } from '../../src/lib/content/safe-fetch';
import { loadSettings } from '../../src/lib/content/settings';

const URL_DB = process.env.INTEGRATION_DATABASE_URL;
const run = URL_DB ? describe : describe.skip;

const SRC_URL = 'https://pmkisan.gov.in/about';
const BENEFIT = 'प्रति वर्ष 6,000 रुपये की सहायता';
const goodScript = () => ({
  title: 'पीएम किसान सम्मान निधि', hook: 'किसानों के लिए सालाना सहायता',
  narration: 'पीएम किसान योजना में पात्र किसान परिवारों को प्रति वर्ष 6000 रुपये की सहायता दी जाती है। पात्रता की जाँच आधिकारिक वेबसाइट पर करें।',
  scenes: [{ text: 'योजना', caption: 'पीएम किसान', visual: 'HEADLINE_CARD' }, { text: 'लाभ', caption: 'प्रति वर्ष 6000 रुपये', visual: 'KEY_FACT' }],
  keyFacts: ['प्रति वर्ष 6000 रुपये'],
  claims: [{ text: 'सालाना सहायता', sourceUrl: SRC_URL, sourceQuote: BENEFIT }],
  category: 'FARMER', description: 'योजना का सरल सारांश।', attributionText: 'स्रोत: pmkisan.gov.in',
  thumbnailText: 'पीएम किसान', warnings: [], estimatedDurationSec: 26,
});

run('end-to-end (real Postgres, faked providers)', () => {
  let prisma: PrismaClient;
  let app: FastifyInstance;
  let deps: PipelineDeps;
  const storage = new Map<string, Buffer>();
  const h = (role: string) => ({ 'x-role': role, authorization: 'Bearer test' });

  const wipe = async () => {
    for (const m of ['contentEvent', 'contentBookmark', 'contentReport', 'contentReview', 'contentJob', 'shortVideo', 'newsStory', 'scheme'] as const) {
      await (prisma as any)[m].deleteMany({});
    }
    await prisma.appConfig.deleteMany({ where: { key: { startsWith: 'content.' } } });
    await prisma.auditLog.deleteMany({ where: { adminId: { in: ['admin-it', 'system'] } } });
  };

  beforeAll(async () => {
    prisma = new PrismaClient({ datasources: { db: { url: URL_DB } } });
    await wipe();

    app = Fastify();
    app.decorate('prisma', prisma);
    app.decorate('redis', {} as any);
    // Auth stubs mimic the real decorators' contract (RBAC itself is unit-tested against the real plugin logic).
    const asUser = (req: any) => { req.user = { userId: req.headers['x-user'] ?? 'user-it', role: req.headers['x-role'] ?? 'USER' }; };
    app.decorate('authenticate', async (req: any, reply: any) => {
      if (!req.headers.authorization) return reply.status(401).send({ message: 'no' });
      asUser(req);
    });
    app.decorate('optionalAuthenticate', async (req: any) => { if (req.headers.authorization) asUser(req); });
    app.decorate('requireRole', (roles: string[]) => async (req: any, reply: any) => {
      if (!req.headers.authorization) return reply.status(401).send({ message: 'no' });
      asUser(req);
      if (!roles.includes(req.user.role)) return reply.status(403).send({ message: 'forbidden' });
      req.user.userId = 'admin-it';
    });
    await app.register(shortsRoutes, { prefix: '/api/v1/shorts' });
    await app.register(schemeFeedRoutes, { prefix: '/api/v1/schemes' });
    await app.register(newsFeedRoutes, { prefix: '/api/v1/news' });
    await app.register(contentAdminRoutes, { prefix: '/api/v1/admin', startGeneration: async () => 'SCRIPT', requestIngest: async () => {} });

    deps = {
      prisma, cfg: contentConfig({} as any),
      scriptProvider: { name: 'mock', generate: async () => ({ raw: goodScript(), inputTokens: 3000, outputTokens: 700, model: 'mock-model' }) },
      tts: { name: 'mock-tts', synthesize: async () => ({ audio: Buffer.alloc(4000, 1), voice: 'hi-IN-Mock' }) },
      storage: {
        put: async (k, b) => { storage.set(k, b); },
        get: async (k) => { const b = storage.get(k); if (!b) throw new Error(`missing ${k}`); return b; },
      },
      exec: async (file: string, args: string[]) => {
        if (file.includes('ffprobe')) {
          if (args.includes('stream=width,height')) return { stdout: '1080,1920\n', stderr: '' };
          return { stdout: args[args.length - 1].endsWith('.mp3') ? '25.0\n' : '28.5\n', stderr: '' };
        }
        await writeFile(args[args.length - 1], Buffer.alloc(6000, 7));
        return { stdout: '', stderr: '' };
      },
      fetchText: async () => { throw new Error('no network'); },
    } as PipelineDeps;
  });

  afterAll(async () => {
    await wipe();
    await prisma.$disconnect();
    await app.close();
  });

  const api = (method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE', url: string, role = 'MANAGER', payload?: any, user?: string) =>
    app.inject({ method, url: `/api/v1${url}`, headers: { ...h(role), ...(user ? { 'x-user': user } : {}) }, payload });
  const publicGet = (url: string) => app.inject({ method: 'GET', url: `/api/v1${url}` });

  let videoId = '';

  it('scheme: manual entry → verify → draft → pipeline → review → publish → public feed', async () => {
    // creators cannot do any of this
    expect((await api('POST', '/admin/content/schemes', 'CREATOR', {})).statusCode).toBe(403);

    const created = await api('POST', '/admin/content/schemes', 'MANAGER', {
      slug: 'pm-kisan-e2e', officialName: 'PM Kisan Samman Nidhi', nameHi: 'पीएम किसान सम्मान निधि', category: 'FARMER',
      department: 'कृषि विभाग', benefits: [BENEFIT], eligibility: ['पात्र किसान परिवार'], documents: ['आधार कार्ड'],
      applicationSteps: ['पोर्टल खोलें'], applicationMode: 'ONLINE', applicationUrl: 'https://pmkisan.gov.in/apply', sourceUrls: [SRC_URL],
    });
    expect(created.statusCode).toBe(201);
    const schemeId = created.json().data.id;
    expect((await api('POST', '/admin/content/schemes', 'MANAGER', { slug: 'pm-kisan-e2e', officialName: 'dup dup', nameHi: 'डुप', category: 'FARMER' })).statusCode).toBe(409);

    // Pipeline refuses an unverified scheme.
    const draft = await api('POST', '/admin/content/drafts', 'MANAGER', { kind: 'SCHEME', schemeId, title: 'पीएम किसान', category: 'FARMER' });
    expect(draft.statusCode).toBe(201);
    videoId = draft.json().data.id;
    const unverified = await runStage(deps, 'SCRIPT', videoId).catch((e) => e);
    expect(String(unverified.message)).toMatch(/verified/);
    await recordFailure(deps, 'SCRIPT', videoId, unverified, false); // what the worker's 'failed' handler does
    expect((await prisma.contentJob.findFirstOrThrow({ where: { shortVideoId: videoId } })).state).toBe('FAILED');

    expect((await api('POST', `/admin/content/schemes/${schemeId}/verify`)).statusCode).toBe(200);
    await runStage(deps, 'SCRIPT', videoId);
    await runStage(deps, 'NARRATION', videoId);
    await runStage(deps, 'RENDER', videoId);

    const v = await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } });
    expect(v.status).toBe('NEEDS_REVIEW');
    expect(v.costMicroUsd).toBeGreaterThan(0);
    expect(v.videoKey).toBe(`content/video/${videoId}/v1.mp4`);
    expect(storage.has(v.videoKey!)).toBe(true);
    expect(await prisma.contentJob.count({ where: { shortVideoId: videoId, state: 'SUCCEEDED' } })).toBe(3);

    // Not visible to the public before approval + publication.
    expect((await publicGet('/schemes')).json().data).toHaveLength(0);
    expect((await publicGet(`/shorts/${videoId}`)).statusCode).toBe(404);

    // Publishing before approval is impossible.
    expect((await api('POST', `/admin/content/${videoId}/publish`)).statusCode).toBe(409);

    // Two reviewers approve at the same moment: exactly one decision is recorded.
    const [a, b] = await Promise.all([api('POST', `/admin/content/${videoId}/approve`), api('POST', `/admin/content/${videoId}/approve`)]);
    expect([a.statusCode, b.statusCode].every((c) => c === 200 || c === 409)).toBe(true);
    expect([a.statusCode, b.statusCode]).toContain(200);
    expect(await prisma.contentReview.count({ where: { shortVideoId: videoId, action: 'approve' } })).toBe(1);

    expect((await api('POST', `/admin/content/${videoId}/publish`)).statusCode).toBe(200);
    const feed = (await publicGet('/schemes')).json();
    expect(feed.data).toHaveLength(1);
    expect(feed.data[0]).toMatchObject({ id: videoId, kind: 'SCHEME', title: 'पीएम किसान सम्मान निधि' });
    expect(feed.data[0].videoUrl).toContain(`content/video/${videoId}/v1.mp4`);
    expect(feed.data[0]).not.toHaveProperty('costMicroUsd');
    expect(feed.data[0].disclaimer).toMatch(/AI-assisted/);
    // wrong kind endpoint never leaks it
    expect((await publicGet('/news')).json().data).toHaveLength(0);

    const detail = (await publicGet(`/shorts/${videoId}`)).json();
    expect(detail.data.scheme).toMatchObject({ applicationUrl: 'https://pmkisan.gov.in/apply', eligibility: ['पात्र किसान परिवार'], documents: ['आधार कार्ड'] });
    expect(detail.data.narration).toContain('6000');
    expect(await prisma.auditLog.count({ where: { action: 'content.publish', entityId: videoId } })).toBe(1);
  });

  it('interactions hit real unique constraints: events/reports/bookmarks are idempotent per user', async () => {
    const post = (u: string, url: string, body?: any, user = 'u1') => api('POST', url, 'USER', body, user);
    expect((await post('x', `/shorts/${videoId}/events`, { type: 'VIEW' })).json()).toEqual({ counted: true });
    expect((await post('x', `/shorts/${videoId}/events`, { type: 'VIEW' })).json()).toEqual({ counted: false });
    expect((await post('x', `/shorts/${videoId}/events`, { type: 'VIEW' }, 'u2')).json()).toEqual({ counted: true });
    expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } })).viewCount).toBe(2);

    expect((await post('x', `/shorts/${videoId}/report`, { reason: 'OUTDATED', note: 'पुराना' })).statusCode).toBe(201);
    expect((await post('x', `/shorts/${videoId}/report`, { reason: 'OUTDATED' })).json()).toMatchObject({ duplicate: true });
    expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } })).reportCount).toBe(1);

    await post('x', `/shorts/${videoId}/bookmark`);
    await post('x', `/shorts/${videoId}/bookmark`);
    expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } })).bookmarkCount).toBe(1);
    const saved = (await api('GET', '/shorts/bookmarks/list', 'USER', undefined, 'u1')).json();
    expect(saved.data.map((d: any) => d.id)).toEqual([videoId]);
    expect((await api('GET', '/shorts/bookmarks/list', 'USER', undefined, 'someone-else')).json().data).toEqual([]);
    await api('DELETE', `/shorts/${videoId}/bookmark`, 'USER', undefined, 'u1');
    expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } })).bookmarkCount).toBe(0);

    // Reports show up for admins and can be resolved.
    const reports = (await api('GET', '/admin/content/reports')).json();
    expect(reports.data).toHaveLength(1);
    expect((await api('POST', `/admin/content/reports/${reports.data[0].id}/resolve`, 'MANAGER', { status: 'RESOLVED' })).statusCode).toBe(200);
  });

  it('correction takes content out of the feed immediately; edits invalidate media; unpublish works', async () => {
    const r = await api('POST', `/admin/content/${videoId}/correct`, 'MANAGER', { note: 'लाभ राशि स्रोत से मिलाकर सुधारें' });
    expect(r.statusCode, r.body).toBe(200);
    expect((await publicGet('/schemes')).json().data).toHaveLength(0);
    expect((await publicGet(`/shorts/${videoId}`)).statusCode).toBe(404);

    const edit = await api('PATCH', `/admin/content/${videoId}`, 'MANAGER', { script: { narration: 'यह सुधारी हुई कथा है, पर्याप्त लंबी है।' } });
    expect(edit.statusCode).toBe(200);
    const v = await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } });
    expect(v).toMatchObject({ status: 'SCRIPT_READY', videoKey: null, audioKey: null, scriptVersion: 2 });
    // Approval is impossible until it has been regenerated and reviewed again.
    expect((await api('POST', `/admin/content/${videoId}/approve`)).statusCode).toBe(409);

    // Regenerate from the edited script: narration cached by version, render again, back in review.
    await runStage(deps, 'NARRATION', videoId);
    await runStage(deps, 'RENDER', videoId);
    expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } })).status).toBe('NEEDS_REVIEW');
    expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } })).videoKey).toBe(`content/video/${videoId}/v2.mp4`);

    const trail = await prisma.contentReview.findMany({ where: { shortVideoId: videoId }, orderBy: { createdAt: 'asc' } });
    expect(trail.map((t) => t.action)).toEqual(expect.arrayContaining(['approve', 'publish', 'correct', 'edit']));
  });

  it('expiry: an expired item disappears from the feed immediately and the sweep records it', async () => {
    await prisma.shortVideo.update({ where: { id: videoId }, data: { status: 'PUBLISHED', publishedAt: new Date(Date.now() - 60_000), expiresAt: new Date(Date.now() + 3_600_000) } });
    expect((await publicGet('/schemes')).json().data).toHaveLength(1);
    await prisma.shortVideo.update({ where: { id: videoId }, data: { expiresAt: new Date(Date.now() - 1000) } });
    expect((await publicGet('/schemes')).json().data).toHaveLength(0); // hidden even before any sweep runs
    expect(await expirePublished(prisma, await loadSettings(prisma), new Date())).toBe(1);
    expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: videoId } })).status).toBe('EXPIRED');
    expect(await expirePublished(prisma, await loadSettings(prisma), new Date())).toBe(0); // idempotent
  });

  describe('news: scheduled ingestion → drafts → freshness', () => {
    const feeds = [{ name: 'PIB', url: 'https://pib.gov.in/rss', category: 'INDIA' }];
    const item = (title: string, link: string, ageH: number) =>
      `<item><title>${title}</title><link>${link}</link><pubDate>${new Date(Date.now() - ageH * 3_600_000).toUTCString()}</pubDate><description>${'विवरण '.repeat(30)}</description></item>`;
    const rss = (...items: string[]) => `<rss><channel>${items.join('')}</channel></rss>`;
    const tickDeps = (xml: string | (() => never), extra: any = {}) => ({
      prisma, cfg: contentConfig({} as any), lock: async () => async () => {}, startGeneration: vi.fn().mockResolvedValue('SCRIPT'),
      fetchText: async () => { if (typeof xml === 'function') xml(); return { text: xml as string }; }, ...extra,
    });

    it('does nothing until ingestion is enabled; then ingests, dedupes, drafts, and never publishes', async () => {
      await saveSettings(prisma, { feeds, maxNewVideosPerRun: 2, ingestIntervalMinutes: 15 }, 'admin-it');
      const xml = rss(item('पहली ख़बर', 'https://pib.gov.in/1', 1), item('दूसरी ख़बर', 'https://pib.gov.in/2', 2), item('तीसरी ख़बर', 'https://pib.gov.in/3', 3), item('पुरानी ख़बर', 'https://pib.gov.in/4', 400));
      const d = tickDeps(xml);

      await runMaintenanceTick(d as any);
      expect(await prisma.newsStory.count()).toBe(0); // disabled by default

      await saveSettings(prisma, { ingestEnabled: true }, 'admin-it');
      const r = await runMaintenanceTick(d as any);
      expect(r.ingest).toMatchObject({ created: 3, rejected: 1 });
      expect(r).toMatchObject({ draftsCreated: 2, generationQueued: 2 }); // capped at 2, newest first
      const videos = await prisma.shortVideo.findMany({ where: { kind: 'NEWS' }, include: { newsStory: true } });
      expect(videos.map((x) => x.newsStory!.originalHeadline).sort()).toEqual(['दूसरी ख़बर', 'पहली ख़बर']);
      expect(videos.every((x) => x.status === 'DRAFT' && x.publishedAt === null)).toBe(true);

      // Interval not elapsed → no second ingest; the undrafted third story is picked up on a later due run.
      const again = await runMaintenanceTick(d as any);
      expect(again.ingest).toBeUndefined();
      await prisma.appConfig.deleteMany({ where: { key: 'content.last_ingest_at' } });
      const third = await runMaintenanceTick(d as any);
      expect(third.ingest).toMatchObject({ created: 0, duplicates: 3, reverified: 3 });
      expect(third.draftsCreated).toBe(1);
      expect(await prisma.shortVideo.count({ where: { kind: 'NEWS' } })).toBe(3);
    });

    it('a failing feed creates nothing new', async () => {
      await prisma.appConfig.deleteMany({ where: { key: 'content.last_ingest_at' } });
      const before = await prisma.shortVideo.count();
      const r = await runMaintenanceTick(tickDeps(() => { throw new FetchError('HTTP 403', 403); }) as any);
      expect(r.ingest?.errors[0]).toMatch(/403/);
      expect(r.draftsCreated).toBe(0);
      expect(await prisma.shortVideo.count()).toBe(before);
    });

    it('stale unpublished news is auto-rejected; a changed headline pulls a published video back', async () => {
      // Make story #1's video published, and story #2's video old & unreviewed.
      const [v1, v2] = await prisma.shortVideo.findMany({ where: { kind: 'NEWS' }, include: { newsStory: true }, orderBy: { createdAt: 'asc' }, take: 2 });
      await prisma.shortVideo.update({ where: { id: v1.id }, data: { status: 'PUBLISHED', publishedAt: new Date() } });
      await prisma.newsStory.update({ where: { id: v2.newsStoryId! }, data: { publishedAt: new Date(Date.now() - 100 * 3_600_000) } });
      await prisma.shortVideo.update({ where: { id: v2.id }, data: { status: 'NEEDS_REVIEW' } });

      await prisma.appConfig.deleteMany({ where: { key: 'content.last_ingest_at' } });
      const changedXml = rss(item('संशोधित हेडलाइन', v1.newsStory!.canonicalUrl, 1));
      const r = await runMaintenanceTick(tickDeps(changedXml) as any);

      expect(r.rejectedStale).toBeGreaterThanOrEqual(1);
      expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: v2.id } })).status).toBe('REJECTED');
      expect(r.ingest?.changed).toBe(1);
      const live = await prisma.shortVideo.findUniqueOrThrow({ where: { id: v1.id } });
      expect(live.status).toBe('CORRECTION_REQUIRED');
      expect(live.correctionNote).toContain('संशोधित हेडलाइन');
      const story = await prisma.newsStory.findUniqueOrThrow({ where: { id: v1.newsStoryId! } });
      expect(story.correctionStatus).toBe('CORRECTED');
      expect(story.originalHeadline).toBe(v1.newsStory!.originalHeadline); // original is preserved
      expect((await prisma.contentReview.findMany({ where: { shortVideoId: v1.id, actorId: 'system' } })).map((x) => x.action)).toContain('source_changed');
    });

    it('a published story whose source article returns 404 is taken down; transient errors are ignored', async () => {
      const v = await prisma.shortVideo.findFirstOrThrow({ where: { kind: 'NEWS', status: 'DRAFT' } });
      await prisma.shortVideo.update({ where: { id: v.id }, data: { status: 'PUBLISHED', publishedAt: new Date() } });
      const flaky = await checkPublishedSources(prisma, async () => { throw new FetchError('HTTP 503', 503); }, new Date());
      expect(flaky.takenDown).toBe(0);
      expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: v.id } })).status).toBe('PUBLISHED');
      const gone = await checkPublishedSources(prisma, async () => { throw new FetchError('HTTP 404', 404); }, new Date());
      expect(gone.takenDown).toBeGreaterThanOrEqual(1);
      expect((await prisma.shortVideo.findUniqueOrThrow({ where: { id: v.id } })).status).toBe('CORRECTION_REQUIRED');
      expect((await publicGet('/news')).json().data.map((d: any) => d.id)).not.toContain(v.id);
    });

    it('freshness gate: stale or unverified news cannot be approved-and-published', async () => {
      const story = await prisma.newsStory.create({
        data: { originalHeadline: 'gate', publisher: 'PIB', canonicalUrl: 'https://pib.gov.in/gate', dedupeKey: 'gate', category: 'INDIA', publishedAt: new Date(Date.now() - 3_600_000), lastVerifiedAt: new Date(Date.now() - 20 * 3_600_000) },
      });
      const v = await prisma.shortVideo.create({
        data: { kind: 'NEWS', newsStoryId: story.id, title: 'gate video', category: 'INDIA', status: 'APPROVED', videoKey: 'v', thumbnailKey: 't', attribution: 'a', claims: [{ text: 'x', sourceUrl: 'https://pib.gov.in/gate' }] },
      });
      const blocked = await api('POST', `/admin/content/${v.id}/publish`);
      expect(blocked.statusCode).toBe(422);
      expect(blocked.json().problems.join()).toMatch(/re-checked/);
      expect((await api('POST', `/admin/content/${v.id}/recheck`)).statusCode).toBe(200);
      expect((await api('POST', `/admin/content/${v.id}/publish`)).statusCode).toBe(200);
      const pub = (await publicGet(`/news/${v.id}`)).json().data;
      expect(pub.news).toMatchObject({ publisher: 'PIB', url: 'https://pib.gov.in/gate' });
      expect(pub.news.publishedAt).toBeTruthy();
    });
  });
});
