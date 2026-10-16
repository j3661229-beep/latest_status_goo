// src/lib/content/autopublish.ts
// Optional hands-off publishing, run from the maintenance tick. OFF by default (an admin turns it on
// in Schedule settings; turning it off is the "pause all" switch). It applies exactly the same hard
// gates a human publish does (publishBlockers + news freshness + expiry) and is stricter in two ways:
// any editorial warning, any report, or any generator uncertainty note keeps the item in the review
// queue. Everything it does is attributed to actor `system` in ContentReview and AuditLog.
import type { PrismaClient } from '@prisma/client';
import { canTransition, publishBlockers } from './lifecycle';
import type { ContentSettings } from './settings';
import { contentWarnings, newsFreshnessBlocker, WarningThresholds } from './warnings';
import { SYSTEM_ACTOR } from './freshness';

const DAY = 86_400_000;

export interface AutoPublishReport { published: number; held: { id: string; reasons: string[] }[]; capped: boolean }

export async function autoPublish(prisma: PrismaClient, s: ContentSettings, now: Date): Promise<AutoPublishReport> {
  const report: AutoPublishReport = { published: 0, held: [], capped: false };
  if (!s.autoPublishEnabled || s.autoPublishMaxPerDay <= 0) return report;
  if (!canTransition('NEEDS_REVIEW', 'APPROVED') || !canTransition('APPROVED', 'PUBLISHED')) return report;

  const alreadyToday = await prisma.contentReview.count({
    where: { actorId: SYSTEM_ACTOR, action: 'auto_publish', createdAt: { gte: new Date(now.getTime() - DAY) } },
  });
  let budget = s.autoPublishMaxPerDay - alreadyToday;
  if (budget <= 0) return { ...report, capped: true };

  const t: WarningThresholds = {
    schemeVerifyMaxAgeDays: s.schemeVerifyMaxAgeDays,
    newsStaleHours: s.newsStaleHours,
    developingFreshHours: s.developingFreshHours,
  };
  const candidates = await prisma.shortVideo.findMany({
    where: {
      status: 'NEEDS_REVIEW',
      reportCount: 0,
      ...(s.autoPublishSchemes ? {} : { kind: 'NEWS' as const }),
    },
    include: { scheme: true, newsStory: true },
    orderBy: { createdAt: 'asc' },
    take: 50,
  });

  for (const v of candidates) {
    if (budget <= 0) { report.capped = true; break; }
    const reasons = publishBlockers(v as any);
    if (v.expiresAt && v.expiresAt <= now) reasons.push('Content has already expired');
    if (v.kind === 'NEWS' && v.newsStory) {
      const f = newsFreshnessBlocker(v.newsStory, t, 6, now);
      if (f) reasons.push(f);
    }
    reasons.push(...contentWarnings(v as any, t, now));
    if (reasons.length) { report.held.push({ id: v.id, reasons }); continue; }

    // Optimistic guard: only if nobody (admin or another tick) moved it meanwhile.
    const res = await prisma.shortVideo.updateMany({
      where: { id: v.id, status: 'NEEDS_REVIEW', reportCount: 0 },
      data: { status: 'PUBLISHED', approvedById: SYSTEM_ACTOR, publishedById: SYSTEM_ACTOR, publishedAt: now, scheduledAt: null },
    });
    if (res.count === 0) continue;
    await prisma.contentReview.create({
      data: {
        shortVideoId: v.id, actorId: SYSTEM_ACTOR, action: 'auto_publish',
        reason: 'All automated publish gates passed; no warnings, no reports',
        before: { status: 'NEEDS_REVIEW' }, after: { status: 'PUBLISHED' },
      },
    });
    await prisma.auditLog.create({
      data: { adminId: SYSTEM_ACTOR, action: 'content.auto_publish', entityType: 'ShortVideo', entityId: v.id, before: { status: 'NEEDS_REVIEW' }, after: { status: 'PUBLISHED' } },
    }).catch(() => undefined);
    report.published++; budget--;
  }
  return report;
}
