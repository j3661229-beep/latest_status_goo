import { describe, it, expect } from 'vitest';
import { canTransition, assertTransition, publishBlockers, TRANSITIONS } from '../src/lib/content/lifecycle';

const good = {
  kind: 'SCHEME' as const,
  title: 'पीएम किसान',
  videoKey: 'v.mp4',
  thumbnailKey: 't.jpg',
  attribution: 'स्रोत: pmkisan.gov.in',
  claims: [{ text: 'x', sourceUrl: 'https://pmkisan.gov.in' }],
  scheme: { sourceUrls: ['https://pmkisan.gov.in'], lastVerifiedAt: new Date() },
};

describe('lifecycle', () => {
  it('never allows publishing without approval', () => {
    for (const from of Object.keys(TRANSITIONS) as (keyof typeof TRANSITIONS)[]) {
      if (from !== 'APPROVED') expect(canTransition(from, 'PUBLISHED')).toBe(false);
    }
    expect(canTransition('APPROVED', 'PUBLISHED')).toBe(true);
  });
  it('generation cannot skip review', () => {
    expect(canTransition('GENERATED', 'APPROVED')).toBe(false);
    expect(canTransition('GENERATED', 'NEEDS_REVIEW')).toBe(true);
  });
  it('assertTransition throws on invalid moves', () => {
    expect(() => assertTransition('DRAFT', 'PUBLISHED')).toThrow(/Cannot move/);
  });
  it('published content can be corrected, unpublished or expired', () => {
    for (const to of ['UNPUBLISHED', 'EXPIRED', 'CORRECTION_REQUIRED'] as const) {
      expect(canTransition('PUBLISHED', to)).toBe(true);
    }
  });
});

describe('publishBlockers', () => {
  it('passes a complete scheme', () => expect(publishBlockers(good)).toEqual([]));
  it('flags missing assets, sources and verification', () => {
    const p = publishBlockers({ ...good, videoKey: null, claims: [], scheme: { sourceUrls: [], lastVerifiedAt: null } });
    expect(p).toEqual(
      expect.arrayContaining([
        'Missing rendered video',
        'No source-referenced claims recorded',
        'Scheme has no official source URLs',
        'Scheme has not been verified',
      ]),
    );
  });
  it('requires publisher and URL for news', () => {
    const p = publishBlockers({
      ...good,
      kind: 'NEWS',
      scheme: null,
      newsStory: { canonicalUrl: '', publisher: '', publishedAt: new Date() },
    });
    expect(p).toContain('News story missing publisher or URL');
  });
});
