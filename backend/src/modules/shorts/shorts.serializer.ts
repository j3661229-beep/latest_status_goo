// src/modules/shorts/shorts.serializer.ts
import type { Prisma } from '@prisma/client';
import { resolveAssetUrl } from '../../lib/content/assets';

export const shortInclude = {
  scheme: true,
  newsStory: true,
} satisfies Prisma.ShortVideoInclude;

export type ShortWithRelations = Prisma.ShortVideoGetPayload<{ include: typeof shortInclude }>;

/** Public-safe projection: no internal ids of reviewers, costs, AI metadata or job state. */
export async function serializeShort(v: ShortWithRelations, opts: { detail?: boolean; saved?: boolean } = {}) {
  const [videoUrl, thumbnailUrl] = await Promise.all([resolveAssetUrl(v.videoKey), resolveAssetUrl(v.thumbnailKey)]);
  const base = {
    id: v.id,
    kind: v.kind,
    title: v.title,
    hook: v.hook,
    category: v.category,
    region: v.region,
    language: v.language,
    videoUrl,
    thumbnailUrl,
    durationSec: v.durationSec,
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
