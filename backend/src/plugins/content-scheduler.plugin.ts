// src/plugins/content-scheduler.plugin.ts
// Automatic, in-process maintenance tick scheduler for Fastify.
// Guarantees that news ingestion and freshness checks run automatically on schedule
// even when the standalone BullMQ worker process is not running.
// Uses redisLocker to ensure that if BullMQ worker IS running, runs never overlap.
import fp from 'fastify-plugin';
import { FastifyPluginAsync } from 'fastify';
import { contentConfig } from '../lib/content/config';
import { redisLocker, runMaintenanceTick } from '../lib/content/maintenance';
import { HEARTBEAT_KEY, startGeneration } from '../lib/content/queue';

const contentSchedulerPlugin: FastifyPluginAsync = async (fastify) => {
  const cfg = contentConfig();
  const locker = fastify.redis ? redisLocker(fastify.redis) : async () => async () => {};

  async function triggerTick(reason = 'interval') {
    try {
      const report = await runMaintenanceTick({
        prisma: fastify.prisma,
        cfg,
        lock: locker,
        startGeneration: (id) => startGeneration(fastify.prisma, id),
        log: (m, x) => fastify.log.debug({ extra: x }, `[content-tick:${reason}] ${m}`),
      });

      if (!report.skipped && fastify.redis) {
        await fastify.redis.set(HEARTBEAT_KEY, JSON.stringify({ at: new Date().toISOString(), report }), 'EX', 3600).catch(() => undefined);
      }
    } catch (err: any) {
      fastify.log.warn({ err: err.message }, `[content-tick:${reason}] error`);
    }
  }

  // Run initial tick 10 seconds after server boot
  const initialTimer = setTimeout(() => {
    triggerTick('startup');
  }, 10_000);
  initialTimer.unref();

  // Periodic tick every 3 minutes
  const intervalTimer = setInterval(() => {
    triggerTick('interval');
  }, 3 * 60_000);
  intervalTimer.unref();

  // In-process BullMQ pipeline worker (processes SCRIPT -> NARRATION -> RENDER)
  let contentWorker: { close: () => Promise<void> } | null = null;
  if (process.env.CONTENT_PIPELINE_ENABLED === 'true' && process.env.REDIS_URL) {
    try {
      const { startContentWorker } = await import('../workers/content.worker');
      contentWorker = startContentWorker(fastify.prisma, process.env.REDIS_URL);
      fastify.log.info('🚀 AI content pipeline worker started in-process');
    } catch (err: any) {
      fastify.log.warn({ err: err.message }, 'Could not start in-process content worker');
    }
  }

  fastify.addHook('onClose', async () => {
    clearTimeout(initialTimer);
    clearInterval(intervalTimer);
    if (contentWorker) {
      await contentWorker.close().catch(() => undefined);
    }
  });
};

export default fp(contentSchedulerPlugin, {
  name: 'contentSchedulerPlugin',
  dependencies: ['prisma'],
});
