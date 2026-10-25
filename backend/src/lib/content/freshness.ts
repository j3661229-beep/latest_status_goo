// src/lib/content/freshness.ts
// Scheduled freshness / correction / expiry housekeeping. All functions are idempotent and use
// optimistic status guards (updateMany ... where status = X), so concurrent runs or a concurrent admin
// action can never double-apply or overwrite each other. The only direction these ever move content is
// AWAY from public visibility — nothing here approves or publishes.
import type { ContentStatus, Prisma, PrismaClient } from '@prisma/client';
import { canTransition } from './lifecycle';
import type { ContentSettings } from './settings';
import { FetchError, FetchFn, UnsafeUrlError } from './safe-fetch';

export const SYSTEM_ACTOR = 'system';
const HOUR = 3_600_000;
const DAY = 24 * HOUR;

type Db = PrismaClient;

/** Atomically move one item and leave an audit trail. Returns false if it changed under us. */
async function systemMove(
  db: Db, id: string, from: ContentStatus, to: ContentStatus, action: string, reason: string,
  data: Prisma.ShortVideoUpdateInput = {},
): Promise<boolean> {
  if (!canTransition(from, to)) return false;
  const res = await db.shortVideo.updateMany({ where: { id, status: from }, data: { status: to, ...(data as object) } });
  if (res.count === 0) return false;
  await db.contentReview.create({
    data: { shortVideoId: id, actorId: SYSTEM_ACTOR, action, reason, before: { status: from }, after: { status: to } },
  });
  return true;
}

/** Published content past its expiry, and published news older than the auto-expire window → EXPIRED. */
export async function expirePublished(db: Db, s: ContentSettings, now: Date): Promise<number> {
  const due = await db.shortVideo.findMany({
    where: {
      status: 'PUBLISHED',
      OR: [
        { expiresAt: { lte: now } },
        ...(s.newsAutoExpireHours > 0
          ? [{ kind: 'NEWS' as const, newsStory: { publishedAt: { lt: new Date(now.getTime() - s.newsAutoExpireHours * HOUR) } } }]
          : []),
      ],
    },
    select: { id: true, kind: true, expiresAt: true },
    take: 200,
  });
  let n = 0;
  for (const v of due) {
    const byDate = v.expiresAt && v.expiresAt <= now;
    const ok = await systemMove(db, v.id, 'PUBLISHED', 'EXPIRED', 'auto_expire',
      byDate ? 'Reached its expiry date' : `News older than ${s.newsAutoExpireHours}h is no longer shown as current`);
    if (ok) n++;
  }
  return n;
}

const UNPUBLISHED_PIPELINE: ContentStatus[] = ['DRAFT', 'SOURCE_VERIFIED', 'SCRIPT_READY', 'NEEDS_REVIEW', 'APPROVED', 'FAILED'];

/**
 * News that went stale before anyone published it is rejected (and its queued jobs cancelled) so
 * old stories never reach the feed and don't waste generation spend. Items mid-generation are left
 * alone; they are caught on the next run once they settle.
 */
export async function rejectStaleUnpublishedNews(db: Db, s: ContentSettings, now: Date): Promise<number> {
  const stale = await db.shortVideo.findMany({
    where: {
      kind: 'NEWS',
      status: { in: UNPUBLISHED_PIPELINE },
      newsStory: { publishedAt: { lt: new Date(now.getTime() - s.newsStaleHours * HOUR) } },
    },
    select: { id: true, status: true },
    take: 200,
  });
  let n = 0;
  for (const v of stale) {
    if (await systemMove(db, v.id, v.status, 'REJECTED', 'auto_reject_stale', `Story became stale (>${s.newsStaleHours}h) before publication`)) {
      n++;
      await db.contentJob.updateMany({
        where: { shortVideoId: v.id, state: 'QUEUED' },
        data: { state: 'CANCELLED', finishedAt: now, failureReason: 'Story became stale' },
      });
    }
  }
  return n;
}

/**
 * A publisher changed the headline of a story we already ingested: treat as a possible correction.
 * Published videos are taken down for re-review; approved-but-unpublished ones go back to review.
 */
export async function handleChangedStories(
  db: Db, changed: { storyId: string; headline: string }[],
): Promise<{ takenDown: number; sentBack: number }> {
  let takenDown = 0, sentBack = 0;
  for (const c of changed) {
    const note = `स्रोत ने हेडलाइन बदली: “${c.headline.slice(0, 200)}” — तथ्यों की दोबारा जाँच करें`;
    const videos = await db.shortVideo.findMany({
      where: { newsStoryId: c.storyId, status: { in: ['PUBLISHED', 'APPROVED'] } },
      select: { id: true, status: true },
    });
    for (const v of videos) {
      if (v.status === 'PUBLISHED') {
        if (await systemMove(db, v.id, 'PUBLISHED', 'CORRECTION_REQUIRED', 'source_changed', note, { correctionNote: note, videoApprovedAt: null, videoApprovedById: null })) takenDown++;
      } else if (await systemMove(db, v.id, 'APPROVED', 'NEEDS_REVIEW', 'source_changed', note)) {
        sentBack++;
      }
    }
    if (videos.length) await db.newsStory.update({ where: { id: c.storyId }, data: { correctionStatus: 'CORRECTED' } });
  }
  return { takenDown, sentBack };
}

/**
 * Re-fetch the article behind recently published news. A definitive 404/410 means the publisher
 * removed it → take the video down for review. Any other failure (timeout, 403, blocked host) is
 * inconclusive and changes nothing. A successful fetch does NOT bump lastVerifiedAt: reachability is
 * not proof the content is unchanged, so we never claim a verification we didn't do.
 */
export async function checkPublishedSources(
  db: Db, fetchText: FetchFn, now: Date, limit = 20,
): Promise<{ checked: number; takenDown: number; inconclusive: number }> {
  const rows = await db.shortVideo.findMany({
    where: { status: 'PUBLISHED', kind: 'NEWS' },
    orderBy: { publishedAt: 'desc' },
    take: limit,
    select: { id: true, newsStory: { select: { id: true, canonicalUrl: true } } },
  });
  const out = { checked: 0, takenDown: 0, inconclusive: 0 };
  for (const r of rows) {
    if (!r.newsStory) continue;
    out.checked++;
    try {
      await fetchText(r.newsStory.canonicalUrl);
    } catch (e) {
      const gone = e instanceof FetchError && (e.status === 404 || e.status === 410);
      if (!gone || e instanceof UnsafeUrlError) { out.inconclusive++; continue; }
      const note = `मूल खबर का लिंक अब उपलब्ध नहीं है (HTTP ${(e as FetchError).status}) — स्रोत की पुष्टि करें`;
      if (await systemMove(db, r.id, 'PUBLISHED', 'CORRECTION_REQUIRED', 'source_unavailable', note, { correctionNote: note, videoApprovedAt: null, videoApprovedById: null })) out.takenDown++;
    }
  }
  return out;
}

export interface Attention {
  overdueSchemes: { id: string; name: string; reason: string }[];
  needsReviewOver24h: number;
  openReports: number;
}

/** What a human should look at: overdue scheme verification, slow review queue, user reports. */
export async function collectAttention(db: Db, s: ContentSettings, now: Date): Promise<Attention> {
  const cutoff = new Date(now.getTime() - s.schemeVerifyMaxAgeDays * DAY);
  const schemes = await db.scheme.findMany({
    where: {
      videos: { some: { status: 'PUBLISHED' } },
      OR: [{ nextReviewAt: { lte: now } }, { lastVerifiedAt: null }, { lastVerifiedAt: { lt: cutoff } }],
    },
    select: { id: true, nameHi: true, lastVerifiedAt: true, nextReviewAt: true },
    take: 100,
  });
  const [needsReview, reports] = await Promise.all([
    db.shortVideo.count({ where: { status: 'NEEDS_REVIEW', updatedAt: { lt: new Date(now.getTime() - DAY) } } }),
    db.contentReport.count({ where: { status: 'OPEN' } }),
  ]);
  return {
    overdueSchemes: schemes.map((x) => ({
      id: x.id,
      name: x.nameHi,
      reason: x.nextReviewAt && x.nextReviewAt <= now ? 'Scheduled review is overdue'
        : !x.lastVerifiedAt ? 'Never verified' : `Not verified for over ${s.schemeVerifyMaxAgeDays} days`,
    })),
    needsReviewOver24h: needsReview,
    openReports: reports,
  };
}

/** Once per UTC day: record a REVIEW_REMINDER job + audit entry when anything needs attention. */
export async function recordReviewReminder(db: Db, a: Attention, now: Date): Promise<boolean> {
  if (a.overdueSchemes.length === 0 && a.needsReviewOver24h === 0 && a.openReports === 0) return false;
  const day = now.toISOString().slice(0, 10);
  const key = `REVIEW_REMINDER-${day}`;
  if (await db.contentJob.findUnique({ where: { idempotencyKey: key }, select: { id: true } })) return false;
  await db.contentJob.create({
    data: {
      type: 'REVIEW_REMINDER', state: 'SUCCEEDED', idempotencyKey: key, startedAt: now, finishedAt: now, attempts: 1,
      payload: { overdueSchemes: a.overdueSchemes.length, needsReviewOver24h: a.needsReviewOver24h, openReports: a.openReports },
    },
  });
  await db.auditLog.create({
    data: {
      adminId: SYSTEM_ACTOR, action: 'content.review_reminder', entityType: 'ContentQueue', entityId: day,
      after: { overdueSchemes: a.overdueSchemes.map((x) => x.id), needsReviewOver24h: a.needsReviewOver24h, openReports: a.openReports },
    },
  });
  return true;
}
