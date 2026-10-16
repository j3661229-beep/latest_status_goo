import { describe, it, expect, vi } from 'vitest';
import { autoPublish } from '../src/lib/content/autopublish';
import { DEFAULTS, ContentSettings } from '../src/lib/content/settings';

const NOW = new Date('2026-10-15T12:00:00Z');
const H = 3_600_000;
const S = (o: Partial<ContentSettings> = {}): ContentSettings => ({ ...DEFAULTS, autoPublishEnabled: true, ...o });

const video = (id: string, o: any = {}) => ({
  id, kind: 'NEWS', status: 'NEEDS_REVIEW', title: 't', videoKey: 'v', thumbnailKey: 't', attribution: 'src',
  claims: [{ text: 'a' }], warnings: [], expiresAt: null, reportCount: 0, scheme: null,
  newsStory: { canonicalUrl: 'https://x', publisher: 'P', publishedAt: new Date(NOW.getTime() - H), lastVerifiedAt: new Date(NOW.getTime() - H / 2), isDeveloping: false, correctionStatus: 'NONE' },
  ...o,
});

function mk(videos: any[], today = 0) {
  return {
    shortVideo: { findMany: vi.fn().mockResolvedValue(videos), updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    contentReview: { count: vi.fn().mockResolvedValue(today), create: vi.fn() },
    auditLog: { create: vi.fn().mockResolvedValue({}) },
  } as any;
}

describe('autoPublish', () => {
  it('does nothing when disabled', async () => {
    const p = mk([video('a')]);
    expect((await autoPublish(p, S({ autoPublishEnabled: false }), NOW)).published).toBe(0);
    expect(p.shortVideo.findMany).not.toHaveBeenCalled();
  });

  it('publishes a clean item and audits it as system', async () => {
    const p = mk([video('a')]);
    const r = await autoPublish(p, S(), NOW);
    expect(r.published).toBe(1);
    expect(p.shortVideo.updateMany.mock.calls[0][0].data).toMatchObject({ status: 'PUBLISHED', publishedById: 'system' });
    expect(p.contentReview.create.mock.calls[0][0].data).toMatchObject({ actorId: 'system', action: 'auto_publish' });
  });

  it('holds items with blockers or warnings', async () => {
    const p = mk([
      video('nothumb', { thumbnailKey: null }),
      video('uncertain', { warnings: ['unsure about date'] }),
      video('stale', { newsStory: { canonicalUrl: 'https://x', publisher: 'P', publishedAt: new Date(NOW.getTime() - 100 * H), lastVerifiedAt: NOW, isDeveloping: false, correctionStatus: 'NONE' } }),
      video('developing', { newsStory: { canonicalUrl: 'https://x', publisher: 'P', publishedAt: NOW, lastVerifiedAt: NOW, isDeveloping: true, correctionStatus: 'NONE' } }),
    ]);
    const r = await autoPublish(p, S(), NOW);
    expect(r.published).toBe(0);
    expect(r.held.map((h) => h.id)).toEqual(['nothumb', 'uncertain', 'stale', 'developing']);
    expect(p.shortVideo.updateMany).not.toHaveBeenCalled();
  });

  it('respects the rolling daily cap', async () => {
    const p = mk([video('a'), video('b'), video('c')], 8);
    const r = await autoPublish(p, S({ autoPublishMaxPerDay: 10 }), NOW);
    expect(r.published).toBe(2);
    expect(r.capped).toBe(true);
    expect((await autoPublish(mk([video('a')], 10), S(), NOW)).capped).toBe(true);
  });

  it('skips schemes unless enabled, and skips items another actor already moved', async () => {
    const p = mk([]);
    await autoPublish(p, S(), NOW);
    expect(p.shortVideo.findMany.mock.calls[0][0].where.kind).toBe('NEWS');
    await autoPublish(p, S({ autoPublishSchemes: true }), NOW);
    expect(p.shortVideo.findMany.mock.calls[1][0].where.kind).toBeUndefined();

    const raced = mk([video('a')]);
    raced.shortVideo.updateMany.mockResolvedValue({ count: 0 });
    expect((await autoPublish(raced, S(), NOW)).published).toBe(0);
    expect(raced.contentReview.create).not.toHaveBeenCalled();
  });
});

describe('settings round trip', () => {
  it('auto-publish defaults to off and validates the cap', async () => {
    const { SettingsPatchSchema } = await import('../src/lib/content/settings');
    expect(DEFAULTS.autoPublishEnabled).toBe(false);
    expect(DEFAULTS.autoPublishSchemes).toBe(false);
    expect(SettingsPatchSchema.safeParse({ autoPublishMaxPerDay: 101 }).success).toBe(false);
    expect(SettingsPatchSchema.safeParse({ autoPublishEnabled: true, autoPublishMaxPerDay: 5 }).success).toBe(true);
  });
});
