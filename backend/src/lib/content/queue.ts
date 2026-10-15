// src/lib/content/queue.ts
// BullMQ producer for pipeline stages. Job ids are deterministic (stage-video-version), so
// double-clicks, retries and duplicate requests collapse into a single queued job.
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import type { PrismaClient } from '@prisma/client';
import { contentConfig } from './config';
import type { Stage } from './pipeline';
import { idempotencyKey } from './pipeline';

export const CONTENT_QUEUE = 'content-pipeline';

let queue: Queue | null = null;
export function getContentQueue(): Queue {
  if (!queue) {
    const connection = new IORedis(process.env.REDIS_URL!, { maxRetriesPerRequest: null });
    queue = new Queue(CONTENT_QUEUE, { connection });
  }
  return queue;
}

export async function enqueueStage(stage: Stage, videoId: string, scriptVersion: number, q: Pick<Queue, 'add' | 'getJob'> = getContentQueue()) {
  const cfg = contentConfig();
  const jobId = idempotencyKey(stage, videoId, scriptVersion);
  // BullMQ silently ignores add() when a finished job with the same id is still retained;
  // clear finished ones so retries work, but never touch queued/active jobs (that is the dedupe).
  const old = await q.getJob(jobId);
  if (old) {
    const st = await old.getState();
    if (st === 'failed' || st === 'completed') await old.remove();
  }
  await q.add(stage, { videoId }, {
    jobId,
    attempts: cfg.maxAttempts,
    backoff: { type: 'exponential', delay: 30_000 },
    removeOnComplete: { count: 200 },
    removeOnFail: { count: 500 },
  });
}

/** Pick the first stage that still has work to do for this item and queue it. */
export async function startGeneration(prisma: PrismaClient, videoId: string, q?: Pick<Queue, 'add' | 'getJob'>) {
  const v = await prisma.shortVideo.findUnique({
    where: { id: videoId },
    select: { status: true, script: true, audioKey: true, scriptVersion: true },
  });
  if (!v) return null;
  const stage: Stage = !v.script ? 'SCRIPT' : v.status === 'GENERATING' && v.audioKey ? 'RENDER' : 'NARRATION';
  await enqueueStage(stage, videoId, v.scriptVersion, q);
  return stage;
}

// ── Maintenance (scheduled tick + manual ingest) ─────────────
export const MAINTENANCE_QUEUE = 'content-maintenance';
export const TICK_EVERY_MS = 5 * 60_000;

let maintenanceQueue: Queue | null = null;
export function getMaintenanceQueue(): Queue {
  if (!maintenanceQueue) {
    const connection = new IORedis(process.env.REDIS_URL!, { maxRetriesPerRequest: null });
    maintenanceQueue = new Queue(MAINTENANCE_QUEUE, { connection });
  }
  return maintenanceQueue;
}

/**
 * Register the single repeatable tick. Called only by the worker process at startup. The fixed
 * repeat jobId makes this idempotent: starting N workers still yields exactly one schedule.
 */
export async function registerMaintenanceTick(q: Pick<Queue, 'add'> = getMaintenanceQueue()) {
  await q.add('tick', {}, {
    repeat: { every: TICK_EVERY_MS },
    jobId: 'content-tick',
    removeOnComplete: { count: 20 },
    removeOnFail: { count: 100 },
    attempts: 1, // the next tick is the retry
  });
}

/** Ask the worker to ingest immediately. A pending request absorbs duplicates (same jobId). */
export async function requestIngestNow(q: Pick<Queue, 'add'> = getMaintenanceQueue()) {
  await q.add('ingest-now', {}, { jobId: 'content-ingest-now', removeOnComplete: true, removeOnFail: true, attempts: 1 });
}
