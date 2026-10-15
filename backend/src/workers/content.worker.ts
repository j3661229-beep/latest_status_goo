// src/workers/content.worker.ts
// BullMQ worker for the AI shorts pipeline. Started from workers/index.ts (one process, one
// worker per queue — no duplicate schedulers). It never publishes: stages end at NEEDS_REVIEW.
import { Worker, UnrecoverableError } from 'bullmq';
import IORedis from 'ioredis';
import type { PrismaClient } from '@prisma/client';
import { contentConfig } from '../lib/content/config';
import { CONTENT_QUEUE, MAINTENANCE_QUEUE, enqueueStage, registerMaintenanceTick, startGeneration } from '../lib/content/queue';
import { redisLocker, runMaintenanceTick } from '../lib/content/maintenance';
import { PermanentError, SkippedError, PipelineDeps, Stage, runStage, recordFailure } from '../lib/content/pipeline';
import { VertexGeminiProvider } from '../lib/content/script';
import { GoogleTtsProvider } from '../lib/content/tts';
import { gcsContentStorage } from '../lib/content/assets';

export function startContentWorker(prisma: PrismaClient, redisUrl: string) {
  const cfg = contentConfig();
  const deps: PipelineDeps = {
    prisma, cfg,
    scriptProvider: new VertexGeminiProvider(cfg),
    tts: new GoogleTtsProvider(cfg),
    storage: gcsContentStorage,
    log: (m, x) => console.log(`[content] ${m}`, x ?? ''),
  };

  const worker = new Worker(
    CONTENT_QUEUE,
    async (job) => {
      const stage = job.name as Stage;
      const { videoId } = job.data as { videoId: string };
      try {
        const res = await runStage(deps, stage, videoId);
        if (res.next) {
          const v = await prisma.shortVideo.findUnique({ where: { id: videoId }, select: { scriptVersion: true } });
          if (v) await enqueueStage(res.next, videoId, v.scriptVersion);
        }
        return { ok: true, costMicroUsd: res.costMicroUsd };
      } catch (e) {
        if (e instanceof SkippedError) return { skipped: e.message }; // duplicate / cancelled / raced: not an error
        if (e instanceof PermanentError) throw new UnrecoverableError(e.message);
        throw e;
      }
    },
    {
      connection: new IORedis(redisUrl, { maxRetriesPerRequest: null }),
      concurrency: cfg.maxConcurrentRenders,
      limiter: { max: 10, duration: 60_000 }, // provider rate limit
      lockDuration: cfg.jobTimeoutMs + 30_000,
    },
  );

  worker.on('failed', async (job, err) => {
    if (!job) return;
    const final = err instanceof UnrecoverableError || job.attemptsMade >= (job.opts.attempts ?? 1);
    console.error(`[content:${job.name}] ${job.data?.videoId} failed (attempt ${job.attemptsMade}, final=${final}): ${err.message}`);
    try { await recordFailure(deps, job.name as Stage, job.data.videoId, err, final); }
    catch (e) { console.error('[content] could not record failure', e); }
  });

  // ── Scheduled maintenance: ONE repeatable tick; the tick reads AppConfig to decide what is due. ──
  const lockRedis = new IORedis(redisUrl, { maxRetriesPerRequest: null });
  const maintenance = new Worker(
    MAINTENANCE_QUEUE,
    async (job) => {
      const report = await runMaintenanceTick(
        {
          prisma, cfg,
          lock: redisLocker(lockRedis),
          startGeneration: (id) => startGeneration(prisma, id),
          log: deps.log,
        },
        { forceIngest: job.name === 'ingest-now' },
      );
      deps.log?.(`${job.name} done`, report);
      return report;
    },
    { connection: new IORedis(redisUrl, { maxRetriesPerRequest: null }), concurrency: 1 },
  );
  maintenance.on('failed', (job, err) => console.error(`[content-maintenance:${job?.name}] failed: ${err.message}`));
  registerMaintenanceTick().catch((e) => console.error('[content] could not register maintenance tick', e));

  return {
    close: async () => { await Promise.allSettled([worker.close(), maintenance.close(), lockRedis.quit()]); },
  };
}
