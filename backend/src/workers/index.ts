// src/workers/index.ts
// BullMQ Worker process — run separately from API server
// Start with: npm run worker

import 'dotenv/config';
import { Worker, Queue } from 'bullmq';
import IORedis from 'ioredis';
import { PrismaClient } from '@prisma/client';
import { env } from '../config/env';
import { OneSignalService } from '../lib/notification/onesignal.service';

const connection = new IORedis(env.REDIS_URL, { maxRetriesPerRequest: null });
const prisma = new PrismaClient();

console.log('🔧 Status Go BullMQ Workers starting...');

// NOTE: the former `notifications` and `cache` queues had no producers anywhere in
// the API (notifications are sent inline and caches are invalidated inline), so
// their workers were removed. Only the CRON queue below is active.

// ── CRON Worker: Processes scheduled jobs ─────────────────────
const cronQueue = new Queue('cron', { connection });

const cronWorker = new Worker(
  'cron',
  async (job) => {
    const log = (msg: string) => console.log(`[cron:${job.name}] ${msg}`);
    log(`Starting job id=${job.id}`);
    try {
      if (job.name === 'plan_expiry') {
        await checkPlanExpiry();
      } else if (job.name === 'festival_alerts') {
        await checkFestivalAlerts();
      } else {
        log(`Unknown job name: ${job.name}`);
      }
      log(`Completed successfully`);
    } catch (err: any) {
      log(`ERROR: ${err.message}`);
      throw err; // Re-throw so BullMQ marks job as failed and retries
    }
  },
  {
    connection,
    concurrency: 1, // CRON jobs run serially
  }
);

// Register repeatable jobs (idempotent — safe to call on every startup)
// jobId acts as a singleton: BullMQ will only keep one instance of each
async function registerCronJobs() {
  // Plan expiry: every hour at :00
  await cronQueue.add(
    'plan_expiry',
    {},
    {
      repeat: { pattern: '0 * * * *' }, // every hour
      jobId: 'cron:plan_expiry',         // singleton — prevents duplicates on restart
      removeOnComplete: { count: 10 },
      removeOnFail: { count: 50 },
      attempts: 3,
      backoff: { type: 'exponential', delay: 60_000 }, // retry after 1min, 2min, 4min
    }
  );

  // Festival alerts: every 6 hours at :00
  await cronQueue.add(
    'festival_alerts',
    {},
    {
      repeat: { pattern: '0 */6 * * *' }, // every 6 hours
      jobId: 'cron:festival_alerts',
      removeOnComplete: { count: 10 },
      removeOnFail: { count: 50 },
      attempts: 3,
      backoff: { type: 'exponential', delay: 120_000 }, // retry after 2min, 4min, 8min
    }
  );

  console.log('✅ BullMQ CRON jobs registered: plan_expiry (hourly), festival_alerts (every 6h)');
}

// Register CRON jobs in production; in dev, run once immediately for testing
if (env.NODE_ENV === 'production') {
  registerCronJobs().catch((err) => {
    console.error('[cron] Failed to register CRON jobs:', err.message);
    process.exit(1);
  });
} else {
  // Development: register jobs but also run plan_expiry once immediately for debugging
  registerCronJobs()
    .then(() => checkPlanExpiry())
    .catch((err) => console.warn('[cron:dev] Non-fatal startup error:', err.message));
}

// Error handlers — upgraded to structured logging
cronWorker.on('failed', (job, err) => {
  console.error(JSON.stringify({
    level: 'error',
    worker: 'cron',
    jobId: job?.id,
    jobName: job?.name,
    error: err.message,
    attemptsMade: job?.attemptsMade,
  }));
});

console.log('✅ Workers running: cron');

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('[workers] SIGTERM received — shutting down gracefully');
  await Promise.allSettled([
    cronWorker.close(),
    cronQueue.close(),
  ]);
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('[workers] SIGINT received — shutting down');
  await Promise.allSettled([
    cronWorker.close(),
    cronQueue.close(),
  ]);
  await prisma.$disconnect();
  process.exit(0);
});


async function checkPlanExpiry() {
  console.log('[cron] Checking plan expiry...');
  const now = new Date();

  const expired = await prisma.subscription.findMany({
    where: {
      status: 'ACTIVE',
      expiresAt: { lt: now },
    },
    select: { id: true, userId: true },
  });

  let downgraded = 0;
  for (const sub of expired) {
    await prisma.subscription.update({
      where: { id: sub.id },
      data: { status: 'EXPIRED' },
    });

    // Only downgrade when the user has no other subscription still running and their
    // plan expiry (which renewals extend) has actually passed.
    const [otherActive, user] = await Promise.all([
      prisma.subscription.count({
        where: { userId: sub.userId, status: 'ACTIVE', expiresAt: { gt: now } },
      }),
      prisma.user.findUnique({ where: { id: sub.userId }, select: { plan: true, planExpiresAt: true } }),
    ]);
    const planStillValid = !!user?.planExpiresAt && user.planExpiresAt > now;

    if (otherActive === 0 && !planStillValid && user?.plan !== 'FREE') {
      await prisma.user.update({
        where: { id: sub.userId },
        data: { plan: 'FREE', planExpiresAt: null },
      });
      downgraded++;
      console.log(`[cron] Expired plan for user ${sub.userId}`);
    }

    // Drop cached profile / plan / auth state so the API sees the change immediately
    await connection
      .del(`user:${sub.userId}`, `plan:${sub.userId}`, `authstate:${sub.userId}`)
      .catch(() => 0);
  }

  console.log(`[cron] Plan expiry check done. Subscriptions expired: ${expired.length}, users downgraded: ${downgraded}`);
}

// ── CRON: Festival Alert ──────────────────────────────────────
// Runs every 6h. Each festival is announced once, when it enters its own
// notifyDaysBefore window; a Redis key per festival+date prevents repeats.
async function checkFestivalAlerts() {
  console.log('[cron] Checking festival alerts...');

  const DAY_MS = 24 * 60 * 60 * 1000;
  const now = new Date();
  const horizon = new Date(now.getTime() + 31 * DAY_MS); // notifyDaysBefore is capped at 30

  const festivals = await prisma.festival.findMany({
    where: {
      isActive: true,
      date: { gte: now, lte: horizon },
    },
  });

  for (const festival of festivals) {
    const daysUntil = Math.ceil((festival.date.getTime() - now.getTime()) / DAY_MS);
    const window = festival.notifyDaysBefore ?? 2;
    if (daysUntil > window) continue;

    // Dedupe: one alert per festival occurrence (key lives until the festival has passed)
    const dedupeKey = `festival:alerted:${festival.id}:${festival.date.toISOString().slice(0, 10)}`;
    const ttlSeconds = Math.max(60, Math.ceil((festival.date.getTime() - now.getTime()) / 1000) + 2 * 86400);
    const firstTime = await connection.set(dedupeKey, '1', 'EX', ttlSeconds, 'NX');
    if (firstTime === null) continue;

    const whenHi = daysUntil <= 1 ? 'कल है!' : `${daysUntil} दिन में है!`;
    const whenMr = daysUntil <= 1 ? 'उद्या आहे!' : `${daysUntil} दिवसांत आहे!`;

    try {
      // Hindi notification
      await OneSignalService.send({
        heading: `🎉 ${festival.nameHi} ${whenHi}`,
        content: `Special ${festival.nameHi} status के साथ wishes share करें`,
        filters: [{ field: 'tag', key: 'language', relation: '=', value: 'HINDI' }],
        data: { screen: 'discover', query: festival.nameHi },
      });
      // Marathi notification
      await OneSignalService.send({
        heading: `🎉 ${festival.nameMr} ${whenMr}`,
        content: `Special ${festival.nameMr} status सह wishes share करा`,
        filters: [{ field: 'tag', key: 'language', relation: '=', value: 'MARATHI' }],
        data: { screen: 'discover', query: festival.nameMr },
      });
      console.log(`[cron] Festival alert sent: ${festival.nameEn} (in ${daysUntil}d)`);
    } catch (err) {
      // Allow a retry on the next run if sending blew up
      await connection.del(dedupeKey).catch(() => 0);
      throw err;
    }
  }
}

// ── CRON helper functions are used by cronWorker above ────────

