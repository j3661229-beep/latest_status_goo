// src/lib/content/warnings.ts
// Editorial warnings shown to reviewers. Pure functions — thresholds are passed in
// (read from AppConfig by the caller) rather than hard-coded.
export interface WarningInput {
  kind: 'SCHEME' | 'NEWS';
  warnings?: unknown; // uncertainty notes produced by the script generator
  claims?: unknown;
  expiresAt?: Date | null;
  scheme?: {
    sourceUrls: string[];
    applicationUrl?: string | null;
    lastVerifiedAt?: Date | null;
    nextReviewAt?: Date | null;
    reviewStatus?: string;
  } | null;
  newsStory?: {
    publishedAt: Date;
    lastVerifiedAt?: Date | null;
    isDeveloping: boolean;
    correctionStatus: string;
  } | null;
}

export interface WarningThresholds {
  schemeVerifyMaxAgeDays: number;
  newsStaleHours: number;
  developingFreshHours: number;
}

export const DEFAULT_THRESHOLDS: WarningThresholds = {
  schemeVerifyMaxAgeDays: 90,
  newsStaleHours: 48,
  developingFreshHours: 1,
};

const HOUR = 3_600_000;
const DAY = 24 * HOUR;

export function contentWarnings(
  c: WarningInput,
  t: WarningThresholds = DEFAULT_THRESHOLDS,
  now: Date = new Date(),
): string[] {
  const out: string[] = [];
  if (Array.isArray(c.warnings)) out.push(...c.warnings.filter((w): w is string => typeof w === 'string'));
  if (!Array.isArray(c.claims) || c.claims.length === 0) out.push('No source-referenced claims');
  if (c.expiresAt && c.expiresAt <= now) out.push('Content has passed its expiry date');

  if (c.kind === 'SCHEME') {
    const s = c.scheme;
    if (!s) return [...out, 'Scheme record missing'];
    if (s.sourceUrls.length === 0) out.push('Missing official source URLs');
    if (!s.applicationUrl) out.push('Missing official application URL');
    if (!s.lastVerifiedAt) out.push('Scheme details have never been verified');
    else if (now.getTime() - s.lastVerifiedAt.getTime() > t.schemeVerifyMaxAgeDays * DAY) {
      out.push(`Scheme last verified more than ${t.schemeVerifyMaxAgeDays} days ago`);
    }
    if (s.nextReviewAt && s.nextReviewAt <= now) out.push('Scheme review is overdue');
  } else {
    const n = c.newsStory;
    if (!n) return [...out, 'News story record missing'];
    const ageH = (now.getTime() - n.publishedAt.getTime()) / HOUR;
    if (ageH > t.newsStaleHours) out.push(`Story is stale (published ${Math.floor(ageH)}h ago)`);
    if (n.isDeveloping) out.push('Developing story — fresh source check required before publishing');
    if (n.correctionStatus !== 'NONE') out.push(`Source ${n.correctionStatus.toLowerCase()} by publisher`);
    if (!n.lastVerifiedAt) out.push('Source not re-checked since retrieval');
  }
  return out;
}

/**
 * News needs a recent source re-check at publish time; developing stories need a very
 * recent one. Returns an error message, or null when the check is fresh enough.
 */
export function newsFreshnessBlocker(
  n: { lastVerifiedAt?: Date | null; isDeveloping: boolean; correctionStatus: string; publishedAt: Date },
  t: WarningThresholds = DEFAULT_THRESHOLDS,
  maxVerifyAgeHours = 6,
  now: Date = new Date(),
): string | null {
  if (n.correctionStatus === 'WITHDRAWN') return 'Source story was withdrawn';
  if ((now.getTime() - n.publishedAt.getTime()) / HOUR > t.newsStaleHours) {
    return 'Story is stale — replace it with a current one or re-verify and republish as an update';
  }
  const limit = n.isDeveloping ? t.developingFreshHours : maxVerifyAgeHours;
  if (!n.lastVerifiedAt || (now.getTime() - n.lastVerifiedAt.getTime()) / HOUR > limit) {
    return `Source must be re-checked within the last ${limit}h before publishing`;
  }
  return null;
}
