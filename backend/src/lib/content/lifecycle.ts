// src/lib/content/lifecycle.ts
// Single source of truth for the ShortVideo editorial lifecycle.
// Pure functions only — no DB access — so the rules are trivially testable.
import type { ContentStatus } from '@prisma/client';

export const TRANSITIONS: Record<ContentStatus, ContentStatus[]> = {
  DRAFT: ['SOURCE_VERIFIED', 'NEEDS_REVIEW', 'REJECTED', 'FAILED'], // NEEDS_REVIEW: card-only items skip the video stages
  SOURCE_VERIFIED: ['SCRIPT_READY', 'NEEDS_REVIEW', 'REJECTED', 'FAILED', 'DRAFT'],
  SCRIPT_READY: ['GENERATING', 'REJECTED', 'DRAFT'],
  GENERATING: ['GENERATED', 'FAILED', 'SCRIPT_READY'],
  GENERATED: ['NEEDS_REVIEW', 'FAILED', 'GENERATING'],
  NEEDS_REVIEW: ['APPROVED', 'REJECTED', 'SCRIPT_READY', 'GENERATING'],
  APPROVED: ['PUBLISHED', 'NEEDS_REVIEW', 'REJECTED'],
  PUBLISHED: ['UNPUBLISHED', 'EXPIRED', 'CORRECTION_REQUIRED'],
  FAILED: ['SCRIPT_READY', 'DRAFT', 'REJECTED'], // retry paths
  REJECTED: ['DRAFT'],
  EXPIRED: ['NEEDS_REVIEW', 'UNPUBLISHED'],
  CORRECTION_REQUIRED: ['NEEDS_REVIEW', 'UNPUBLISHED', 'GENERATING'],
  UNPUBLISHED: ['NEEDS_REVIEW', 'DRAFT'],
};

export function canTransition(from: ContentStatus, to: ContentStatus): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export class InvalidTransitionError extends Error {
  constructor(public from: ContentStatus, public to: ContentStatus) {
    super(`Cannot move content from ${from} to ${to}`);
  }
}

export function assertTransition(from: ContentStatus, to: ContentStatus): void {
  if (!canTransition(from, to)) throw new InvalidTransitionError(from, to);
}

/** Only these states are ever visible in the public feed. */
export const PUBLIC_STATUS: ContentStatus = 'PUBLISHED';

export type ContentFormat = 'CARD_ONLY' | 'CARD_WITH_VIDEO';
export type VideoState = 'NOT_REQUESTED' | 'QUEUED' | 'GENERATING' | 'READY' | 'FAILED';

export interface PublishCandidate {
  kind: 'SCHEME' | 'NEWS';
  title: string;
  /** Absent = legacy record: the old strict rules (video + thumbnail + claims) apply. */
  format?: ContentFormat;
  description?: string | null;
  videoKey?: string | null;
  thumbnailKey?: string | null;
  attribution?: string | null;
  claims?: unknown;
  warnings?: unknown;
  scheme?: { applicationUrl?: string | null; sourceUrls: string[]; lastVerifiedAt?: Date | null } | null;
  newsStory?: { canonicalUrl: string; publisher: string; publishedAt: Date } | null;
}

/**
 * Hard blockers that stop approval/publication of the CARD. Automated checks never replace
 * factual review — they only refuse content that is structurally unsafe to show.
 * A card never needs a video: a missing/failed video must not stop an otherwise good card.
 */
export function publishBlockers(c: PublishCandidate): string[] {
  const problems: string[] = [];
  if (!c.title?.trim()) problems.push('Missing title');
  if (!c.attribution?.trim()) problems.push('Missing source attribution text');
  if (c.format === undefined) {
    // Legacy strict rules.
    if (!c.videoKey) problems.push('Missing rendered video');
    if (!c.thumbnailKey) problems.push('Missing thumbnail');
    if (!Array.isArray(c.claims) || c.claims.length === 0) problems.push('No source-referenced claims recorded');
  } else if (!c.description?.trim()) {
    problems.push('Missing card summary');
  }
  if (c.kind === 'SCHEME') {
    if (!c.scheme) problems.push('Scheme record missing');
    else {
      if (c.scheme.sourceUrls.length === 0) problems.push('Scheme has no official source URLs');
      if (!c.scheme.lastVerifiedAt) problems.push('Scheme has not been verified');
    }
  } else {
    if (!c.newsStory) problems.push('News story record missing');
    else if (!c.newsStory.canonicalUrl || !c.newsStory.publisher) problems.push('News story missing publisher or URL');
  }
  return problems;
}

export interface VideoCandidate extends PublishCandidate {
  videoState?: VideoState;
}

/** Reasons a finished video cannot be approved for public playback. */
export function videoApprovalBlockers(c: VideoCandidate): string[] {
  const problems: string[] = [];
  if (c.format !== 'CARD_WITH_VIDEO') problems.push('Item is not set to Card + Video');
  if (c.videoState !== 'READY') problems.push('Video is not ready');
  if (!c.videoKey) problems.push('Missing rendered video');
  if (!c.thumbnailKey) problems.push('Missing thumbnail');
  if (!Array.isArray(c.claims) || c.claims.length === 0) problems.push('No source-referenced claims recorded');
  return problems;
}

/** Reasons an admin may not request a video for this item (eligibility + valid source). */
export function videoRequestBlockers(c: VideoCandidate): string[] {
  const problems: string[] = [];
  if (c.format !== 'CARD_WITH_VIDEO') problems.push('Set the format to Card + Video first');
  if (c.kind === 'SCHEME') {
    if (!c.scheme) problems.push('Scheme record missing');
    else {
      if (c.scheme.sourceUrls.length === 0) problems.push('Scheme has no official source URLs');
      if (!c.scheme.lastVerifiedAt) problems.push('Scheme has not been verified');
    }
  } else if (!c.newsStory) problems.push('News story record missing');
  else if (!c.newsStory.canonicalUrl) problems.push('News story has no source URL');
  return problems;
}

/** The single rule for public video playback. */
export function isVideoPublic(v: {
  format: ContentFormat; videoState: VideoState; videoApprovedAt?: Date | null; videoKey?: string | null;
}): boolean {
  return v.format === 'CARD_WITH_VIDEO' && v.videoState === 'READY' && !!v.videoApprovedAt && !!v.videoKey;
}
