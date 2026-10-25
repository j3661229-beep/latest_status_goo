// src/modules/shorts/shorts.serializer.ts
import type { Prisma } from '@prisma/client';
import { resolveAssetUrl } from '../../lib/content/assets';
import { isVideoPublic } from '../../lib/content/lifecycle';

export const shortInclude = {
  scheme: true,
  newsStory: true,
} satisfies Prisma.ShortVideoInclude;

export type ShortWithRelations = Prisma.ShortVideoGetPayload<{ include: typeof shortInclude }>;

const SUMMARY_MAX_CHARS = 420; // ~60 words: Inshorts-style card text

/** Card text for the feed: the admin-reviewed description, else the narration, trimmed on a word boundary. */
export function cardSummary(v: ShortWithRelations): string | null {
  const text = (v.description || (v.script as { narration?: string } | null)?.narration || '').replace(/\s+/g, ' ').trim();
  if (!text) return null;
  if (text.length <= SUMMARY_MAX_CHARS) return text;
  const cut = text.slice(0, SUMMARY_MAX_CHARS);
  return `${cut.slice(0, Math.max(cut.lastIndexOf(' '), SUMMARY_MAX_CHARS / 2))}…`;
}

/** Public-safe projection: no internal ids of reviewers, costs, AI metadata or job state. */
export async function serializeShort(v: ShortWithRelations, opts: { detail?: boolean; saved?: boolean } = {}) {
  // A video (and the frame taken from it) is public only once it is rendered, validated, uploaded AND approved.
  const videoPublic = isVideoPublic(v);
  const [videoUrl, thumbnailUrl] = videoPublic
    ? await Promise.all([resolveAssetUrl(v.videoKey), resolveAssetUrl(v.thumbnailKey)])
    : [null, null];
  const base = {
    id: v.id,
    kind: v.kind,
    title: v.title,
    hook: v.hook,
    summary: cardSummary(v),
    category: v.category,
    region: v.region,
    language: v.language,
    format: v.format,
    videoUrl,
    thumbnailUrl,
    durationSec: videoPublic ? v.durationSec : null,
    captions: v.captions,
    attribution: v.attribution,
    publishedAt: v.publishedAt,
    correctionNote: v.correctionNote,
    disclaimer:
      'AI-assisted summary of the cited sources. Not an official government announcement.',
    isSaved: opts.saved ?? false,
    news: v.newsStory
      ? {
          publisher: v.newsStory.publisher,
          originalHeadline: v.newsStory.originalHeadline,
          url: v.newsStory.canonicalUrl,
          publishedAt: v.newsStory.publishedAt,
          lastVerifiedAt: v.newsStory.lastVerifiedAt,
          isDeveloping: v.newsStory.isDeveloping,
          correctionStatus: v.newsStory.correctionStatus,
        }
      : null,
    scheme: v.scheme
      ? {
          id: v.scheme.id,
          nameHi: v.scheme.nameHi,
          officialName: v.scheme.officialName,
          department: v.scheme.department,
          scope: v.scheme.scope,
          stateCode: v.scheme.stateCode,
          applicationUrl: v.scheme.applicationUrl,
          lastVerifiedAt: v.scheme.lastVerifiedAt,
        }
      : null,
  };
  if (!opts.detail) return base;
  return {
    ...base,
    description: v.description,
    // Text alternative to the video (accessibility / low-data reading).
    narration: (v.script as { narration?: string } | null)?.narration ?? null,
    keyFacts: (v.script as { keyFacts?: string[] } | null)?.keyFacts ?? [],
    claims: v.claims,
    warnings: v.warnings,
    scheme: v.scheme && {
      ...base.scheme!,
      benefits: v.scheme.benefits,
      eligibility: v.scheme.eligibility,
      documents: v.scheme.documents,
      applicationSteps: v.scheme.applicationSteps,
      applicationMode: v.scheme.applicationMode,
      sourceUrls: v.scheme.sourceUrls,
      sourceUpdatedAt: v.scheme.sourceUpdatedAt,
    },
  };
}
