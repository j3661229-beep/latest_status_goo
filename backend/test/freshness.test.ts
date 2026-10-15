import { describe, it, expect, vi } from 'vitest';
import {
  expirePublished, rejectStaleUnpublishedNews, handleChangedStories, checkPublishedSources,
  recordReviewReminder, collectAttention, SYSTEM_ACTOR,
} from '../src/lib/content/freshness';
import { DEFAULTS, ContentSettings } from '../src/lib/content/settings';
import { FetchError, UnsafeUrlError } from '../src/lib/content/safe-fetch';
import { parseFeed, ingestNews } from '../src/lib/content/ingest';
import { contentConfig } from '../src/lib/content/config';

const NOW = new Date('2026-10-15T12:00:00Z');
const H = 3_600_000;
const settings = (o: Partial<ContentSettings> = {}): ContentSettings => ({ ...DEFAULTS, ...o });

function db(over: any = {}) {
  return {
    shortVideo: { findMany: vi.fn().mockResolvedValue([]), updateMany: vi.fn().mockResolvedValue({ count: 1 }), count: vi.fn().mockResolvedValue(0) },
    contentReview: { create: vi.fn().mockResolvedValue({}) },
    contentJob: { updateMany: vi.fn().mockResolvedValue({ count: 0 }), findUnique: vi.fn().mockResolvedValue(null), create: vi.fn().mockResolvedValue({}) },
    newsStory: { update: vi.fn().mockResolvedValue({}) },
    scheme: { findMany: vi.fn().mockResolvedValue([]) },
    contentReport: { count: vi.fn().mockResolvedValue(0) },
    auditLog: { create: vi.fn().mockResolvedValue({}) },
    ...over,
  } as any;
}

describe('expirePublished', () => {
  it('expires items and records a system review row; guards on current status', async () => {
    const d = db();
    d.shortVideo.findMany.mockResolvedValue([{ id: 'a', kind: 'NEWS', expiresAt: new Date(NOW.getTime() - 1) }, { id: 'b', kind: 'NEWS', expiresAt: null }]);
    expect(await expirePublished(d, settings(), NOW)).toBe(2);
    expect(d.shortVideo.updateMany).toHaveBeenCalledWith({ where: { id: 'a', status: 'PUBLISHED' }, data: { status: 'EXPIRED' } });
    expect(d.contentReview.create.mock.calls[0][0].data).toMatchObject({ actorId: SYSTEM_ACTOR, action: 'auto_expire', shortVideoId: 'a' });
    expect(d.contentReview.create.mock.calls[0][0].data.reason).toMatch(/expiry/);
    expect(d.contentReview.create.mock.calls[1][0].data.reason).toMatch(/72h/);
  });
  it('queries only PUBLISHED items past expiry or past the news window', async () => {
    const d = db();
    await expirePublished(d, settings({ newsAutoExpireHours: 24 }), NOW);
    const w = d.shortVideo.findMany.mock.calls[0][0].where;
    expect(w.status).toBe('PUBLISHED');
    expect(w.OR[0]).toEqual({ expiresAt: { lte: NOW } });
    expect(w.OR[1].newsStory.publishedAt.lt).toEqual(new Date(NOW.getTime() - 24 * H));
  });
  it('news auto-expiry can be disabled (0) while date-based expiry still works', async () => {
    const d = db();
    await expirePublished(d, settings({ newsAutoExpireHours: 0 }), NOW);
    expect(d.shortVideo.findMany.mock.calls[0][0].where.OR).toHaveLength(1);
  });
  it('does nothing (no review row) when someone else moved the item first', async () => {
    const d = db();
    d.shortVideo.findMany.mockResolvedValue([{ id: 'a', kind: 'NEWS', expiresAt: null }]);
    d.shortVideo.updateMany.mockResolvedValue({ count: 0 });
    expect(await expirePublished(d, settings(), NOW)).toBe(0);
    expect(d.contentReview.create).not.toHaveBeenCalled();
  });
});

describe('rejectStaleUnpublishedNews', () => {
  it('rejects stale unpublished news, cancels its queued jobs, never touches in-flight generation', async () => {
    const d = db();
    d.shortVideo.findMany.mockResolvedValue([{ id: 'a', status: 'NEEDS_REVIEW' }, { id: 'b', status: 'SCRIPT_READY' }]);
    expect(await rejectStaleUnpublishedNews(d, settings({ newsStaleHours: 48 }), NOW)).toBe(2);
    const w = d.shortVideo.findMany.mock.calls[0][0].where;
    expect(w.kind).toBe('NEWS');
    expect(w.status.in).not.toContain('GENERATING');
    expect(w.status.in).not.toContain('PUBLISHED');
    expect(w.newsStory.publishedAt.lt).toEqual(new Date(NOW.getTime() - 48 * H));
    expect(d.shortVideo.updateMany.mock.calls[0][0]).toEqual({ where: { id: 'a', status: 'NEEDS_REVIEW' }, data: { status: 'REJECTED' } });
    expect(d.contentJob.updateMany.mock.calls[0][0]).toMatchObject({ where: { shortVideoId: 'a', state: 'QUEUED' }, data: { state: 'CANCELLED' } });
  });
});

describe('handleChangedStories', () => {
  it('takes a published video down for re-review and flags the story corrected', async () => {
    const d = db();
    d.shortVideo.findMany.mockResolvedValue([{ id: 'p', status: 'PUBLISHED' }]);
    const r = await handleChangedStories(d, [{ storyId: 's1', headline: 'नई हेडलाइन' }]);
    expect(r).toEqual({ takenDown: 1, sentBack: 0 });
    const call = d.shortVideo.updateMany.mock.calls[0][0];
    expect(call.data.status).toBe('CORRECTION_REQUIRED');
    expect(call.data.correctionNote).toContain('नई हेडलाइन');
    expect(d.newsStory.update.mock.calls[0][0].data.correctionStatus).toBe('CORRECTED');
  });
  it('sends an approved-but-unpublished video back to NEEDS_REVIEW instead', async () => {
    const d = db();
    d.shortVideo.findMany.mockResolvedValue([{ id: 'p', status: 'APPROVED' }]);
    expect(await handleChangedStories(d, [{ storyId: 's1', headline: 'x' }])).toEqual({ takenDown: 0, sentBack: 1 });
    expect(d.shortVideo.updateMany.mock.calls[0][0].data.status).toBe('NEEDS_REVIEW');
  });
  it('leaves stories without any live video alone', async () => {
    const d = db();
    await handleChangedStories(d, [{ storyId: 's1', headline: 'x' }]);
    expect(d.shortVideo.updateMany).not.toHaveBeenCalled();
    expect(d.newsStory.update).not.toHaveBeenCalled();
  });
});

describe('checkPublishedSources', () => {
  const rows = [{ id: 'v1', newsStory: { id: 's1', canonicalUrl: 'https://pib.gov.in/a' } }];
  it('takes a video down when the publisher removed the article (404/410)', async () => {
    for (const status of [404, 410]) {
      const d = db(); d.shortVideo.findMany.mockResolvedValue(rows);
      const r = await checkPublishedSources(d, async () => { throw new FetchError(`HTTP ${status}`, status); }, NOW);
      expect(r).toEqual({ checked: 1, takenDown: 1, inconclusive: 0 });
      expect(d.shortVideo.updateMany.mock.calls[0][0].data.status).toBe('CORRECTION_REQUIRED');
    }
  });
  it('treats timeouts, 403/500s and blocked hosts as inconclusive (no takedown)', async () => {
    for (const err of [new FetchError('HTTP 500', 500), new FetchError('HTTP 403', 403), new FetchError('timeout'), new UnsafeUrlError('host not allowed'), new Error('ECONNRESET')]) {
      const d = db(); d.shortVideo.findMany.mockResolvedValue(rows);
      const r = await checkPublishedSources(d, async () => { throw err; }, NOW);
      expect(r).toEqual({ checked: 1, takenDown: 0, inconclusive: 1 });
      expect(d.shortVideo.updateMany).not.toHaveBeenCalled();
    }
  });
  it('a reachable source changes nothing and never bumps lastVerifiedAt', async () => {
    const d = db(); d.shortVideo.findMany.mockResolvedValue(rows);
    const r = await checkPublishedSources(d, async () => ({ text: '<p>ok</p>' }), NOW);
    expect(r).toEqual({ checked: 1, takenDown: 0, inconclusive: 0 });
    expect(d.newsStory.update).not.toHaveBeenCalled();
    expect(d.shortVideo.updateMany).not.toHaveBeenCalled();
  });
});

describe('attention + reminders', () => {
  it('lists overdue schemes with the reason', async () => {
    const d = db();
    d.scheme.findMany.mockResolvedValue([
      { id: 's1', nameHi: 'क', lastVerifiedAt: null, nextReviewAt: null },
      { id: 's2', nameHi: 'ख', lastVerifiedAt: new Date(NOW.getTime() - 200 * 24 * H), nextReviewAt: null },
      { id: 's3', nameHi: 'ग', lastVerifiedAt: new Date(NOW.getTime() - H), nextReviewAt: new Date(NOW.getTime() - H) },
    ]);
    d.contentReport.count.mockResolvedValue(3);
    const a = await collectAttention(d, settings(), NOW);
    expect(a.overdueSchemes.map((x) => x.reason)).toEqual(['Never verified', 'Not verified for over 90 days', 'Scheduled review is overdue']);
    expect(a.openReports).toBe(3);
    expect(d.scheme.findMany.mock.calls[0][0].where.videos).toEqual({ some: { status: 'PUBLISHED' } });
  });
  it('records at most one reminder per day, and none when nothing needs attention', async () => {
    const d = db();
    expect(await recordReviewReminder(d, { overdueSchemes: [], needsReviewOver24h: 0, openReports: 0 }, NOW)).toBe(false);
    const a = { overdueSchemes: [{ id: 's1', name: 'क', reason: 'r' }], needsReviewOver24h: 0, openReports: 0 };
    expect(await recordReviewReminder(d, a, NOW)).toBe(true);
    expect(d.contentJob.create.mock.calls[0][0].data).toMatchObject({ type: 'REVIEW_REMINDER', idempotencyKey: 'REVIEW_REMINDER-2026-10-15' });
    d.contentJob.findUnique.mockResolvedValue({ id: 'exists' });
    expect(await recordReviewReminder(d, a, NOW)).toBe(false);
    expect(d.contentJob.create).toHaveBeenCalledTimes(1);
  });
});

describe('ingest: corrections and re-sightings', () => {
  const cfg = contentConfig({} as any);
  const feeds = [{ name: 'PIB', url: 'https://pib.gov.in/rss', category: 'INDIA' }];
  const rss = (title: string) => `<rss><channel><item><title>${title}</title><link>https://pib.gov.in/a</link><pubDate>${new Date(NOW.getTime() - H).toUTCString()}</pubDate><description>${'सारांश '.repeat(20)}</description></item></channel></rss>`;
  const stored = { id: 'n1', canonicalUrl: 'https://pib.gov.in/a', dedupeKey: '', relatedSources: [] as any[] };
  const mk = (known: any) => ({
    appConfig: { findUnique: vi.fn() },
    newsStory: {
      count: vi.fn().mockResolvedValue(0), findUnique: vi.fn().mockResolvedValue(known), findFirst: vi.fn().mockResolvedValue(null),
      create: vi.fn(), update: vi.fn().mockResolvedValue({}),
    },
  }) as any;

  it('a known story still listed with the same headline counts as a fresh source check', async () => {
    const { dedupeKey } = await import('../src/lib/content/ingest');
    const p = mk({ ...stored, dedupeKey: dedupeKey('पुरानी हेडलाइन') });
    const r = await ingestNews(p, { cfg, now: NOW, feeds, fetchText: async () => ({ text: rss('पुरानी हेडलाइन') }) });
    expect(r).toMatchObject({ reverified: 1, changed: [], created: 0 });
    expect(p.newsStory.update.mock.calls[0][0].data).toEqual({ lastVerifiedAt: NOW });
  });
  it('a known story whose headline changed is reported (and the change recorded, original kept)', async () => {
    const { dedupeKey } = await import('../src/lib/content/ingest');
    const p = mk({ ...stored, dedupeKey: dedupeKey('पुरानी हेडलाइन') });
    const r = await ingestNews(p, { cfg, now: NOW, feeds, fetchText: async () => ({ text: rss('बदली हुई हेडलाइन') }) });
    expect(r.changed).toEqual([{ storyId: 'n1', headline: 'बदली हुई हेडलाइन' }]);
    expect(r.reverified).toBe(0);
    const data = p.newsStory.update.mock.calls[0][0].data;
    expect(data.relatedSources[0]).toMatchObject({ type: 'headline_change', headline: 'बदली हुई हेडलाइन' });
    expect(data).not.toHaveProperty('originalHeadline');
    expect(data).not.toHaveProperty('lastVerifiedAt'); // a changed story is NOT re-verified
  });
  it('parseFeed ignores items without title or link', () => {
    expect(parseFeed('<rss><channel><item><title>x</title></item></channel></rss>')).toEqual([]);
  });
});
