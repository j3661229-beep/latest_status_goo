// src/lib/content/maintenance.ts
// The scheduled "tick": runs every few minutes from ONE BullMQ repeatable job (singleton jobId) in the
// worker process. The tick itself decides, from AppConfig, whether an ingest is due — so admins change
// the schedule from the dashboard with no redeploy and no restart. A Redis lock stops overlapping runs.
//
// Guarantees:
//   * never publishes or approves anything (generation ends at NEEDS_REVIEW)
//   * if feeds fail or contain nothing new, no stories/videos are created
//   * generation spend is bounded per run (maxNewVideosPerRun) and by the pipeline's daily/monthly limits
import type { PrismaClient } from '@prisma/client';
import { contentConfig, ContentConfig } from './config';
import { ingestNews, IngestResult } from './ingest';
import { FetchFn, safeFetchText } from './safe-fetch';
import { ContentSettings, ingestDue, loadSettings, markIngestRun } from './settings';
import {
  checkPublishedSources, collectAttention, expirePublished, handleChangedStories, recordReviewReminder,
  rejectStaleUnpublishedNews,
} from './freshness';

export type Unlock = () => Promise<void>;
export type Locker = () => Promise<Unlock | null>;

export interface TickDeps {
  prisma: PrismaClient;
  lock: Locker;
  startGeneration: (videoId: string) => Promise<unknown>;
  cfg?: ContentConfig;
  now?: () => Date;
  fetchText?: FetchFn;
  ingest?: typeof ingestNews;
  log?: (msg: string, extra?: object) => void;
}

export interface TickReport {
  skipped?: 'locked';
  expired: number;
  rejectedStale: number;
  ingest?: Pick<IngestResult, 'created' | 'grouped' | 'duplicates' | 'rejected' | 'errors' | 'reverified'> & { changed: number };
  takenDown: number;
  sentBack: number;
  draftsCreated: number;
  generationQueued: number;
  sourceChecks?: { checked: number; takenDown: number; inconclusive: number };
  reminderRecorded: boolean;
}

const empty = (): TickReport => ({ expired: 0, rejectedStale: 0, takenDown: 0, sentBack: 0, draftsCreated: 0, generationQueued: 0, reminderRecorded: false });

/** Redis SET NX EX lock. Returns an unlock function (only deletes our own token) or null if held. */
export function redisLocker(
  redis: { set: (...a: any[]) => Promise<any>; get: (k: string) => Promise<string | null>; del: (k: string) => Promise<any> },
  key = 'content:maintenance:lock', ttlSeconds = 600,
): Locker {
  return async () => {
    const token = `${process.pid}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    const ok = await redis.set(key, token, 'EX', ttlSeconds, 'NX');
    if (ok !== 'OK') return null;
    return async () => { if ((await redis.get(key)) === token) await redis.del(key); };
  };
}

/** Create DRAFT videos for fresh, not-yet-drafted stories (newest first, capped). Idempotent. */
export async function createNewsDrafts(
  prisma: PrismaClient, s: ContentSettings, now: Date,
): Promise<string[]> {
  if (s.maxNewVideosPerRun <= 0) return [];
  const stories = await prisma.newsStory.findMany({
    where: {
      videos: { none: {} },
      correctionStatus: 'NONE',
      publishedAt: { gte: new Date(now.getTime() - s.newsStaleHours * 3_600_000) },
    },
    orderBy: { publishedAt: 'desc' },
    take: s.maxNewVideosPerRun,
  });
  const ids: string[] = [];
  for (const st of stories) {
    const v = await prisma.shortVideo.create({
      data: { kind: 'NEWS', newsStoryId: st.id, title: st.originalHeadline.slice(0, 200), category: st.category, language: st.language },
    });
    ids.push(v.id);
  }
  return ids;
}

export async function runMaintenanceTick(d: TickDeps, opts: { forceIngest?: boolean } = {}): Promise<TickReport> {
  const unlock = await d.lock();
  if (!unlock) return { ...empty(), skipped: 'locked' };
  const report = empty();
  try {
    const cfg = d.cfg ?? contentConfig();
    const now = (d.now ?? (() => new Date()))();
    const s = await loadSettings(d.prisma);
    const fetchText: FetchFn = d.fetchText ?? ((u) => safeFetchText(u, cfg));

    // Housekeeping — DB only, always runs, only ever reduces public visibility.
    report.expired = await expirePublished(d.prisma, s, now);
    report.rejectedStale = await rejectStaleUnpublishedNews(d.prisma, s, now);

    // Ingestion — only when enabled+due (or an admin pressed "run now").
    const due = opts.forceIngest ? s.feeds.length > 0 : ingestDue(s, now);
    if (due) {
      const ing = await (d.ingest ?? ingestNews)(d.prisma, { cfg, now, feeds: s.feeds, staleHours: s.newsStaleHours, fetchText });
      await markIngestRun(d.prisma, now);
      report.ingest = {
        created: ing.created, grouped: ing.grouped, duplicates: ing.duplicates, rejected: ing.rejected,
        errors: ing.errors, reverified: ing.reverified, changed: ing.changed.length,
      };
      if (ing.errors.length) d.log?.('ingest errors', { errors: ing.errors });

      const fixed = await handleChangedStories(d.prisma, ing.changed);
      report.takenDown += fixed.takenDown;
      report.sentBack = fixed.sentBack;

      const drafts = await createNewsDrafts(d.prisma, s, now);
      report.draftsCreated = drafts.length;
      if (s.autoGenerate) {
        for (const id of drafts) {
          try { await d.startGeneration(id); report.generationQueued++; }
          catch (e) { d.log?.('could not queue generation', { id, reason: (e as Error).message }); }
        }
      }

      report.sourceChecks = await checkPublishedSources(d.prisma, fetchText, now);
      report.takenDown += report.sourceChecks.takenDown;
    }

    report.reminderRecorded = await recordReviewReminder(d.prisma, await collectAttention(d.prisma, s, now), now);
    return report;
  } finally {
    await unlock().catch(() => undefined);
  }
}
