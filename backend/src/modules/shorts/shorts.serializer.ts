// src/modules/shorts/shorts.serializer.ts
import type { Prisma } from '@prisma/client';
import { resolveAssetUrl } from '../../lib/content/assets';
import { isVideoPublic } from '../../lib/content/lifecycle';
import { getYoutubeThumbnailUrl } from '../../lib/content/youtube';

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

/** Public-safe projection: includes YouTube video metadata for Yojna / video content. */
export async function serializeShort(v: ShortWithRelations, opts: { detail?: boolean; saved?: boolean } = {}) {
  const youtubeUrl = v.youtubeUrl || v.scheme?.youtubeUrl || null;
  const youtubeId = v.youtubeId || v.scheme?.youtubeId || null;
  const hasYoutube = !!youtubeId;

  // If a YouTube video is attached, video is public through YouTube!
  let videoUrl: string | null = null;
  let thumbnailUrl: string | null = null;

  if (hasYoutube) {
    thumbnailUrl = getYoutubeThumbnailUrl(youtubeId!);
  } else if (v.thumbnailKey) {
    thumbnailUrl = v.thumbnailKey.startsWith('http') ? v.thumbnailKey : await resolveAssetUrl(v.thumbnailKey);
  } else if (v.newsStory?.imageUrl) {
    thumbnailUrl = v.newsStory.imageUrl;
  }

  if (!hasYoutube) {
    const videoPublic = isVideoPublic(v);
    if (videoPublic) {
      const [vUrl, tUrl] = await Promise.all([resolveAssetUrl(v.videoKey), resolveAssetUrl(v.thumbnailKey)]);
      videoUrl = vUrl;
      if (!thumbnailUrl) thumbnailUrl = tUrl;
    }
  }

  const base = {
    id: v.id,
    kind: v.kind,
    subKind: v.subKind || (v.region ? 'REGIONAL' : 'TOP'),
    title: v.title,
    hook: v.hook,
    summary: cardSummary(v),
    category: v.category,
    region: v.region,
    language: v.language,
    format: hasYoutube ? 'CARD_WITH_VIDEO' : v.format,
    videoUrl,
    thumbnailUrl,
    youtubeUrl,
    youtubeId,
    hasYoutube,
    durationSec: v.durationSec,
    captions: v.captions,
    attribution: v.attribution,
    publishedAt: v.publishedAt,
    correctionNote: v.correctionNote,
    disclaimer: 'विश्वसनीय स्रोतों से संकलित जानकारी।',
    isSaved: opts.saved ?? false,
    news: v.newsStory
      ? {
          publisher: v.newsStory.publisher,
          originalHeadline: v.newsStory.originalHeadline,
          url: v.newsStory.canonicalUrl,
          imageUrl: v.newsStory.imageUrl,
          isRegional: v.newsStory.isRegional,
          region: v.newsStory.region,
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
          youtubeUrl: v.scheme.youtubeUrl,
          youtubeId: v.scheme.youtubeId,
          lastVerifiedAt: v.scheme.lastVerifiedAt,
        }
      : null,
  };

  if (!opts.detail) return base;
  return {
    ...base,
    description: v.description,
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
