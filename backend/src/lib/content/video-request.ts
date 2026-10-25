// src/lib/content/video-request.ts
// The ONLY code path that may start video generation. It is called exclusively from authenticated
// admin routes — ingestion, cron ticks, drafting and publishing never import it.
//
// Idempotency: the request wins an atomic compare-and-set (NOT_REQUESTED | FAILED → QUEUED) in the DB.
// Only the winner enqueues; every concurrent/repeated request observes the new state and returns it
// without touching the queue. The BullMQ job id is deterministic as a second line of defence.
import type { Prisma, PrismaClient, VideoState } from '@prisma/client';
import { videoRequestBlockers } from './lifecycle';

export type VideoRequestResult =
  | { ok: true; state: VideoState; queued: boolean; duplicate: boolean; stage?: string | null }
  | { ok: false; code: 404 | 409 | 422 | 503; message: string; problems?: string[] };

export interface VideoRequestDeps {
  prisma: PrismaClient;
  /** Queues the first pending stage (defaults to BullMQ in the route). */
  start: (videoId: string) => Promise<string | null>;
  maxManualRetries?: number;
}

const include = { scheme: true, newsStory: true } satisfies Prisma.ShortVideoInclude;
const DEAD: string[] = ['REJECTED', 'EXPIRED'];

export async function requestVideoGeneration(
  d: VideoRequestDeps, videoId: string, actorId: string,
): Promise<VideoRequestResult> {
  const v = await d.prisma.shortVideo.findUnique({ where: { id: videoId }, include });
  if (!v) return { ok: false, code: 404, message: 'Content not found' };

  // Already requested / running: idempotent no-op.
  if (v.videoState === 'QUEUED' || v.videoState === 'GENERATING') {
    return { ok: true, state: v.videoState, queued: false, duplicate: true };
  }
  if (v.videoState === 'READY') {
    return { ok: false, code: 409, message: 'A video already exists. Discard it first to generate a new one.' };
  }
  if (DEAD.includes(v.status)) return { ok: false, code: 409, message: `Cannot generate a video for content in status ${v.status}` };

  const problems = videoRequestBlockers(v as never);
  if (problems.length) return { ok: false, code: 422, message: 'This item is not eligible for video generation', problems };

  const retrying = v.videoState === 'FAILED';
  if (retrying) {
    const limit = d.maxManualRetries ?? 5;
    const failed = await d.prisma.contentJob.count({ where: { shortVideoId: v.id, state: 'FAILED' } });
    if (failed >= limit) {
      return { ok: false, code: 422, message: `Retry limit reached (${limit} failed jobs) — edit the content or switch it to Card only` };
    }
  }

  // Compare-and-set: exactly one concurrent request can move the item to QUEUED.
  const won = await d.prisma.shortVideo.updateMany({
    where: { id: v.id, format: 'CARD_WITH_VIDEO', videoState: { in: ['NOT_REQUESTED', 'FAILED'] } },
    data: {
      videoState: 'QUEUED', videoRequestedAt: new Date(), videoRequestedById: actorId,
      videoFailureReason: null, videoApprovedAt: null, videoApprovedById: null,
    },
  });
  if (won.count === 0) {
    const cur = await d.prisma.shortVideo.findUnique({ where: { id: v.id }, select: { videoState: true } });
    return { ok: true, state: cur?.videoState ?? 'QUEUED', queued: false, duplicate: true };
  }

  // Failed/cancelled job rows from earlier attempts must not block this run (beginJob skips CANCELLED).
  await d.prisma.contentJob.updateMany({
    where: { shortVideoId: v.id, state: { in: ['FAILED', 'CANCELLED'] } },
    data: { state: 'QUEUED', attempts: 0, failureReason: null, startedAt: null, finishedAt: null },
  });

  try {
    const stage = await d.start(v.id);
    return { ok: true, state: 'QUEUED', queued: true, duplicate: false, stage };
  } catch {
    // Queue unavailable: restore the previous state so the admin can simply click again.
    await d.prisma.shortVideo.updateMany({
      where: { id: v.id, videoState: 'QUEUED' },
      data: { videoState: v.videoState, videoRequestedAt: v.videoRequestedAt, videoRequestedById: v.videoRequestedById, videoFailureReason: v.videoFailureReason },
    });
    return { ok: false, code: 503, message: 'Generation queue unavailable — nothing was started. Please try again.' };
  }
}
