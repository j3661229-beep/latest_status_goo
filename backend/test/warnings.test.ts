import { describe, it, expect } from 'vitest';
import { contentWarnings, newsFreshnessBlocker } from '../src/lib/content/warnings';

const now = new Date('2026-10-15T12:00:00Z');
const ago = (h: number) => new Date(now.getTime() - h * 3_600_000);

describe('contentWarnings', () => {
  it('flags missing sources, unverified scheme and no claims', () => {
    const w = contentWarnings({ kind: 'SCHEME', claims: [], scheme: { sourceUrls: [], applicationUrl: null, lastVerifiedAt: null } }, undefined, now);
    expect(w).toEqual(expect.arrayContaining([
      'No source-referenced claims', 'Missing official source URLs',
      'Missing official application URL', 'Scheme details have never been verified',
    ]));
  });
  it('flags schemes verified long ago and overdue reviews', () => {
    const w = contentWarnings({
      kind: 'SCHEME', claims: [1],
      scheme: { sourceUrls: ['https://a'], applicationUrl: 'https://a', lastVerifiedAt: ago(24 * 200), nextReviewAt: ago(1) },
    }, undefined, now);
    expect(w.join()).toMatch(/more than 90 days/);
    expect(w).toContain('Scheme review is overdue');
  });
  it('flags stale / developing / corrected news', () => {
    const w = contentWarnings({
      kind: 'NEWS', claims: [1],
      newsStory: { publishedAt: ago(60), lastVerifiedAt: null, isDeveloping: true, correctionStatus: 'CORRECTED' },
    }, undefined, now);
    expect(w.join()).toMatch(/stale/);
    expect(w.join()).toMatch(/Developing story/);
    expect(w.join()).toMatch(/corrected/);
  });
  it('includes generator uncertainty notes', () => {
    const w = contentWarnings({ kind: 'NEWS', claims: [1], warnings: ['Figures disputed'], newsStory: { publishedAt: ago(1), lastVerifiedAt: ago(0), isDeveloping: false, correctionStatus: 'NONE' } }, undefined, now);
    expect(w).toContain('Figures disputed');
  });
});

describe('newsFreshnessBlocker', () => {
  const base = { isDeveloping: false, correctionStatus: 'NONE', publishedAt: ago(3), lastVerifiedAt: ago(1) };
  it('passes a fresh story', () => expect(newsFreshnessBlocker(base, undefined, 6, now)).toBeNull());
  it('blocks old verification, stale stories, withdrawn sources', () => {
    expect(newsFreshnessBlocker({ ...base, lastVerifiedAt: ago(7) }, undefined, 6, now)).toMatch(/re-checked/);
    expect(newsFreshnessBlocker({ ...base, publishedAt: ago(72) }, undefined, 6, now)).toMatch(/stale/i);
    expect(newsFreshnessBlocker({ ...base, correctionStatus: 'WITHDRAWN' }, undefined, 6, now)).toMatch(/withdrawn/);
    expect(newsFreshnessBlocker({ ...base, lastVerifiedAt: null }, undefined, 6, now)).toMatch(/re-checked/);
  });
  it('uses the tight window for developing stories', () => {
    expect(newsFreshnessBlocker({ ...base, isDeveloping: true, lastVerifiedAt: ago(2) }, undefined, 6, now)).toMatch(/1h/);
  });
});
