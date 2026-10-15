import { describe, it, expect, vi } from 'vitest';
import Fastify from 'fastify';
import { runMaintenanceTick, redisLocker, createNewsDrafts, TickDeps } from '../src/lib/content/maintenance';
import { DEFAULTS, ingestDue, loadSettings, saveSettings, SettingsPatchSchema, ContentSettings } from '../src/lib/content/settings';
import { registerMaintenanceTick, requestIngestNow, TICK_EVERY_MS } from '../src/lib/content/queue';
import { contentAdminRoutes } from '../src/modules/content-admin/content.admin.route';
import type { IngestResult } from '../src/lib/content/ingest';

const NOW = new Date('2026-10-15T12:00:00Z');
const H = 3_600_000;
const feeds = [{ name: 'PIB', url: 'https://pib.gov.in/rss', category: 'INDIA' }];
const cfgRows = (o: Record<string, string>) => Object.entries(o).map(([key, value]) => ({ key, value }));

const ingestResult = (o: Partial<IngestResult> = {}): IngestResult => ({
  created: 0, grouped: 0, duplicates: 0, rejected: 0, errors: [], createdIds: [], changed: [], reverified: 0, ...o,
});

function mkPrisma(config: Record<string, string> = {}, stories: any[] = []) {
  const created: any[] = [];
  return {
    created,
    appConfig: {
      findMany: vi.fn(async () => cfgRows(config)),
      upsert: vi.fn(async ({ where, create, update }: any) => { config[where.key] = (update ?? create).value; return {}; }),
      findUnique: vi.fn(),
    },
    newsStory: { findMany: vi.fn(async () => stories), update: vi.fn() },
    shortVideo: {
      create: vi.fn(async ({ data }: any) => { const v = { id: `v${created.length + 1}`, ...data }; created.push(v); return v; }),
      findMany: vi.fn().mockResolvedValue([]), updateMany: vi.fn().mockResolvedValue({ count: 0 }), count: vi.fn().mockResolvedValue(0),
    },
    contentReview: { create: vi.fn() },
    contentJob: { updateMany: vi.fn(), findUnique: vi.fn().mockResolvedValue(null), create: vi.fn() },
    contentReport: { count: vi.fn().mockResolvedValue(0) },
    scheme: { findMany: vi.fn().mockResolvedValue([]) },
    auditLog: { create: vi.fn() },
  } as any;
}

function deps(prisma: any, over: Partial<TickDeps> = {}) {
  const unlock = vi.fn().mockResolvedValue(undefined);
  const d: TickDeps & { unlock: any } = {
    prisma, unlock,
    lock: async () => unlock,
    startGeneration: vi.fn().mockResolvedValue('SCRIPT'),
    now: () => NOW,
    fetchText: async () => ({ text: '' }),
    ingest: vi.fn().mockResolvedValue(ingestResult()),
    ...over,
  } as any;
  return d;
}

const story = (id: string) => ({ id, originalHeadline: `ख़बर ${id}`, category: 'INDIA', language: 'HINDI', publishedAt: new Date(NOW.getTime() - H) });
const ON = { 'content.news_ingest_enabled': 'true', 'content.news_feeds': JSON.stringify(feeds) };

describe('settings', () => {
  it('defaults are the safe ones: ingestion off, no feeds', async () => {
    const s = await loadSettings(mkPrisma());
    expect(s).toMatchObject({ ingestEnabled: false, feeds: [], autoGenerate: true, newsStaleHours: 48 });
    expect(ingestDue(s, NOW)).toBe(false);
  });
  it('tolerates corrupt values without throwing (a bad config must not kill the scheduler)', async () => {
    const s = await loadSettings(mkPrisma({
      'content.news_feeds': '{not json', 'content.news_ingest_interval_minutes': 'abc', 'content.last_ingest_at': 'garbage',
    }));
    expect(s.feeds).toEqual([]);
    expect(s.ingestIntervalMinutes).toBe(DEFAULTS.ingestIntervalMinutes);
    expect(s.lastIngestAt).toBeNull();
  });
  it('ingestDue respects enabled, feeds and the interval', () => {
    const base: ContentSettings = { ...DEFAULTS, ingestEnabled: true, feeds, ingestIntervalMinutes: 60 };
    expect(ingestDue(base, NOW)).toBe(true); // never ran
    expect(ingestDue({ ...base, lastIngestAt: new Date(NOW.getTime() - 30 * 60_000) }, NOW)).toBe(false);
    expect(ingestDue({ ...base, lastIngestAt: new Date(NOW.getTime() - 61 * 60_000) }, NOW)).toBe(true);
    expect(ingestDue({ ...base, ingestEnabled: false }, NOW)).toBe(false);
    expect(ingestDue({ ...base, feeds: [] }, NOW)).toBe(false);
  });
  it('patch schema enforces sane bounds and https feeds', () => {
    expect(SettingsPatchSchema.safeParse({ ingestIntervalMinutes: 5 }).success).toBe(false);
    expect(SettingsPatchSchema.safeParse({ ingestIntervalMinutes: 60 }).success).toBe(true);
    expect(SettingsPatchSchema.safeParse({ maxNewVideosPerRun: 500 }).success).toBe(false);
    expect(SettingsPatchSchema.safeParse({ feeds: [{ name: 'X1', url: 'http://insecure.example/rss', category: 'INDIA' }] }).success).toBe(false);
    expect(SettingsPatchSchema.safeParse({}).success).toBe(false);
    expect(SettingsPatchSchema.safeParse({ unknownField: 1, ingestEnabled: true }).success).toBe(true); // unknown keys stripped
  });
  it('saveSettings writes only the provided keys, JSON for feeds', async () => {
    const cfg: Record<string, string> = {};
    await saveSettings(mkPrisma(cfg), { ingestEnabled: true, feeds }, 'admin1');
    expect(cfg).toEqual({ 'content.news_ingest_enabled': 'true', 'content.news_feeds': JSON.stringify(feeds) });
  });
});

describe('maintenance tick', () => {
  it('does nothing when another instance holds the lock', async () => {
    const p = mkPrisma({ ...ON });
    const d = deps(p, { lock: async () => null });
    const r = await runMaintenanceTick(d);
    expect(r.skipped).toBe('locked');
    expect(d.ingest).not.toHaveBeenCalled();
    expect(p.appConfig.findMany).not.toHaveBeenCalled();
  });

  it('with ingestion disabled it still runs housekeeping but never ingests', async () => {
    const p = mkPrisma({ 'content.news_feeds': JSON.stringify(feeds) });
    const d = deps(p);
    const r = await runMaintenanceTick(d);
    expect(d.ingest).not.toHaveBeenCalled();
    expect(r.ingest).toBeUndefined();
    expect(p.shortVideo.findMany).toHaveBeenCalled(); // expiry / stale sweeps ran
    expect(d.unlock).toHaveBeenCalled();
  });

  it('when due: ingests, records the run, drafts fresh stories (capped) and queues generation', async () => {
    const config = { ...ON, 'content.news_max_new_videos_per_run': '2' };
    const p = mkPrisma(config, [story('a'), story('b')]);
    const d = deps(p, { ingest: vi.fn().mockResolvedValue(ingestResult({ created: 3 })) as any });
    const r = await runMaintenanceTick(d);
    expect(r).toMatchObject({ draftsCreated: 2, generationQueued: 2 });
    expect(p.newsStory.findMany.mock.calls[0][0]).toMatchObject({ take: 2, orderBy: { publishedAt: 'desc' } });
    expect(p.created.map((v: any) => v.newsStoryId)).toEqual(['a', 'b']);
    expect(config['content.last_ingest_at']).toBe(NOW.toISOString());
    // Drafts only: nothing is created in any state beyond DRAFT (default), and nothing is published.
    expect(p.created.every((v: any) => v.status === undefined && v.publishedAt === undefined)).toBe(true);
    const allUpdates = JSON.stringify(p.shortVideo.updateMany.mock.calls);
    expect(allUpdates).not.toContain('"PUBLISHED"');
  });

  it('autoGenerate=false still creates drafts but spends nothing', async () => {
    const p = mkPrisma({ ...ON, 'content.news_auto_generate': 'false' }, [story('a')]);
    const d = deps(p);
    const r = await runMaintenanceTick(d);
    expect(r).toMatchObject({ draftsCreated: 1, generationQueued: 0 });
    expect(d.startGeneration).not.toHaveBeenCalled();
  });

  it('is not due inside the interval, and runs again after it', async () => {
    const recent = new Date(NOW.getTime() - 30 * 60_000).toISOString();
    const d1 = deps(mkPrisma({ ...ON, 'content.last_ingest_at': recent }));
    await runMaintenanceTick(d1);
    expect(d1.ingest).not.toHaveBeenCalled();
    const old = new Date(NOW.getTime() - 4 * H).toISOString();
    const d2 = deps(mkPrisma({ ...ON, 'content.last_ingest_at': old }));
    await runMaintenanceTick(d2);
    expect(d2.ingest).toHaveBeenCalledTimes(1);
  });

  it('"run now" bypasses the interval and the enabled flag, but still needs feeds', async () => {
    const d1 = deps(mkPrisma({ 'content.news_feeds': JSON.stringify(feeds), 'content.last_ingest_at': NOW.toISOString() }));
    await runMaintenanceTick(d1, { forceIngest: true });
    expect(d1.ingest).toHaveBeenCalledTimes(1);
    const d2 = deps(mkPrisma({}));
    await runMaintenanceTick(d2, { forceIngest: true });
    expect(d2.ingest).not.toHaveBeenCalled();
  });

  it('failed feeds create no drafts and queue no generation (no fabricated news)', async () => {
    const p = mkPrisma({ ...ON }, []); // nothing fresh and undrafted
    const d = deps(p, { ingest: vi.fn().mockResolvedValue(ingestResult({ errors: ['PIB: HTTP 403'] })) as any });
    const r = await runMaintenanceTick(d);
    expect(r.ingest?.errors).toEqual(['PIB: HTTP 403']);
    expect(r).toMatchObject({ draftsCreated: 0, generationQueued: 0 });
    expect(p.shortVideo.create).not.toHaveBeenCalled();
  });

  it('one failing generation enqueue does not abort the others', async () => {
    const p = mkPrisma({ ...ON }, [story('a'), story('b')]);
    const start = vi.fn().mockRejectedValueOnce(new Error('redis down')).mockResolvedValue('SCRIPT');
    const r = await runMaintenanceTick(deps(p, { startGeneration: start }));
    expect(start).toHaveBeenCalledTimes(2);
    expect(r).toMatchObject({ draftsCreated: 2, generationQueued: 1 });
  });

  it('releases the lock even when ingestion throws', async () => {
    const d = deps(mkPrisma({ ...ON }), { ingest: vi.fn().mockRejectedValue(new Error('boom')) as any });
    await expect(runMaintenanceTick(d)).rejects.toThrow('boom');
    expect(d.unlock).toHaveBeenCalled();
  });

  it('headline changes at the source take published videos down during the same run', async () => {
    const p = mkPrisma({ ...ON });
    p.shortVideo.findMany.mockImplementation(async ({ where }: any) =>
      where?.newsStoryId === 'n1' ? [{ id: 'live', status: 'PUBLISHED' }] : []);
    p.shortVideo.updateMany.mockResolvedValue({ count: 1 });
    const d = deps(p, { ingest: vi.fn().mockResolvedValue(ingestResult({ changed: [{ storyId: 'n1', headline: 'नया' }] })) as any });
    const r = await runMaintenanceTick(d);
    expect(r.takenDown).toBe(1);
    expect(p.shortVideo.updateMany.mock.calls.some((c: any) => c[0].data.status === 'CORRECTION_REQUIRED')).toBe(true);
  });
});

describe('createNewsDrafts', () => {
  it('only picks fresh, undrafted, uncorrected stories', async () => {
    const p = mkPrisma({}, []);
    await createNewsDrafts(p, { ...DEFAULTS, maxNewVideosPerRun: 5, newsStaleHours: 48 }, NOW);
    const w = p.newsStory.findMany.mock.calls[0][0].where;
    expect(w.videos).toEqual({ none: {} });
    expect(w.correctionStatus).toBe('NONE');
    expect(w.publishedAt.gte).toEqual(new Date(NOW.getTime() - 48 * H));
  });
  it('maxNewVideosPerRun=0 creates nothing', async () => {
    const p = mkPrisma({}, [story('a')]);
    expect(await createNewsDrafts(p, { ...DEFAULTS, maxNewVideosPerRun: 0 }, NOW)).toEqual([]);
    expect(p.newsStory.findMany).not.toHaveBeenCalled();
  });
});

describe('redisLocker', () => {
  function fakeRedis() {
    const m = new Map<string, string>();
    return {
      m,
      set: vi.fn(async (k: string, v: string, _ex: string, _t: number, nx: string) => (nx === 'NX' && m.has(k) ? null : (m.set(k, v), 'OK'))),
      get: vi.fn(async (k: string) => m.get(k) ?? null),
      del: vi.fn(async (k: string) => m.delete(k)),
    };
  }
  it('only one holder at a time; unlock releases; a stale unlock cannot free someone else\'s lock', async () => {
    const r = fakeRedis();
    const lock = redisLocker(r);
    const a = await lock();
    expect(a).not.toBeNull();
    expect(await lock()).toBeNull();
    await a!();
    const b = await lock();
    expect(b).not.toBeNull();
    await a!(); // old holder unlocking late must not delete b's lock
    expect(r.m.size).toBe(1);
    await b!();
    expect(r.m.size).toBe(0);
  });
});

describe('scheduler registration', () => {
  it('registers ONE repeatable tick with a fixed id (idempotent across worker restarts/instances)', async () => {
    const q = { add: vi.fn().mockResolvedValue({}) };
    await registerMaintenanceTick(q as any);
    await registerMaintenanceTick(q as any);
    for (const c of q.add.mock.calls) {
      expect(c[0]).toBe('tick');
      expect(c[2]).toMatchObject({ jobId: 'content-tick', repeat: { every: TICK_EVERY_MS }, attempts: 1 });
    }
  });
  it('manual ingest uses a fixed job id so repeated clicks collapse into one', async () => {
    const q = { add: vi.fn().mockResolvedValue({}) };
    await requestIngestNow(q as any);
    expect(q.add.mock.calls[0][2].jobId).toBe('content-ingest-now');
  });
});

describe('admin: settings / ingest / attention endpoints', () => {
  let role = 'MANAGER';
  async function build(p: any, opts: any = {}) {
    const app = Fastify();
    app.decorate('prisma', p);
    app.decorate('requireRole', (roles: string[]) => async (req: any, reply: any) => {
      if (!req.headers.authorization) return reply.status(401).send({ message: 'no' });
      if (!roles.includes(role)) return reply.status(403).send({ message: 'forbidden' });
      req.user = { userId: 'admin1', role };
    });
    await app.register(contentAdminRoutes, { prefix: '/admin', startGeneration: async () => 'SCRIPT', ...opts });
    return app;
  }
  const h = { authorization: 'Bearer x' };
  const withAudit = (cfg: Record<string, string>) => { const p = mkPrisma(cfg); p.auditLog.create = vi.fn().mockResolvedValue({}); return p; };

  it('creators cannot read or change the schedule', async () => {
    role = 'CREATOR';
    const app = await build(withAudit({}));
    expect((await app.inject({ url: '/admin/content/settings', headers: h })).statusCode).toBe(403);
    expect((await app.inject({ method: 'PUT', url: '/admin/content/settings', headers: h, payload: { ingestEnabled: true } })).statusCode).toBe(403);
    expect((await app.inject({ method: 'POST', url: '/admin/content/ingest/run', headers: h })).statusCode).toBe(403);
    role = 'MANAGER';
  });
  it('GET reports feeds that the host allowlist would block', async () => {
    const app = await build(withAudit({ 'content.news_feeds': JSON.stringify(feeds) }));
    const body = (await app.inject({ url: '/admin/content/settings', headers: h })).json();
    expect(body.sourceHostsConfigured).toBe(false);
    expect(body.blockedFeeds).toEqual(['https://pib.gov.in/rss']);
  });
  it('PUT validates, saves and audits', async () => {
    const cfg: Record<string, string> = {};
    const p = withAudit(cfg);
    const app = await build(p);
    expect((await app.inject({ method: 'PUT', url: '/admin/content/settings', headers: h, payload: { ingestIntervalMinutes: 2 } })).statusCode).toBe(400);
    expect((await app.inject({ method: 'PUT', url: '/admin/content/settings', headers: h, payload: { feeds: [{ name: 'Bad', url: 'http://x.in/rss', category: 'INDIA' }] } })).statusCode).toBe(400);
    expect(cfg).toEqual({});
    const ok = await app.inject({ method: 'PUT', url: '/admin/content/settings', headers: h, payload: { ingestEnabled: true, ingestIntervalMinutes: 120 } });
    expect(ok.statusCode).toBe(200);
    expect(cfg).toMatchObject({ 'content.news_ingest_enabled': 'true', 'content.news_ingest_interval_minutes': '120' });
    expect(p.auditLog.create.mock.calls[0][0].data).toMatchObject({ action: 'content.settings.update', entityType: 'ContentSettings', adminId: 'admin1' });
  });
  it('ingest/run needs feeds, queues the request, and survives queue outages with a 503', async () => {
    const requestIngest = vi.fn().mockResolvedValue(undefined);
    let app = await build(withAudit({}), { requestIngest });
    expect((await app.inject({ method: 'POST', url: '/admin/content/ingest/run', headers: h })).statusCode).toBe(422);
    expect(requestIngest).not.toHaveBeenCalled();

    app = await build(withAudit({ 'content.news_feeds': JSON.stringify(feeds) }), { requestIngest });
    expect((await app.inject({ method: 'POST', url: '/admin/content/ingest/run', headers: h })).statusCode).toBe(202);
    expect(requestIngest).toHaveBeenCalledTimes(1);

    app = await build(withAudit({ 'content.news_feeds': JSON.stringify(feeds) }), { requestIngest: vi.fn().mockRejectedValue(new Error('redis')) });
    expect((await app.inject({ method: 'POST', url: '/admin/content/ingest/run', headers: h })).statusCode).toBe(503);
  });
  it('attention endpoint returns the review backlog', async () => {
    const p = withAudit({});
    p.contentReport.count.mockResolvedValue(2);
    const app = await build(p);
    const body = (await app.inject({ url: '/admin/content/attention', headers: h })).json();
    expect(body.data).toMatchObject({ openReports: 2, overdueSchemes: [], needsReviewOver24h: 0 });
  });
});
