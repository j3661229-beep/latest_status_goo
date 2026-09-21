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

// ── QUEUE: notifications ────────────────────────────────────
const notificationWorker = new Worker(
  'notifications',
  async (job) => {
    const { name, data } = job;
    console.log(`[notifications] Processing job: ${name}`);

    switch (name) {
      case 'notify_creator_approved': {
        const { creatorUserId, templateId, templateName } = data;
        const user = await prisma.user.findUnique({
          where: { id: creatorUserId },
          select: { oneSignalPlayerId: true },
        });
        if (user?.oneSignalPlayerId) {
          await OneSignalService.send({
            heading: '✅ Template Approved!',
            content: `"${templateName}" is now live in the app!`,
            playerIds: [user.oneSignalPlayerId],
            data: { screen: 'creator_templates', templateId },
          });
        }
        break;
      }

      case 'notify_creator_rejected': {
        const { creatorUserId, templateName, reason } = data;
        const user = await prisma.user.findUnique({
          where: { id: creatorUserId },
          select: { oneSignalPlayerId: true },
        });
        if (user?.oneSignalPlayerId) {
          await OneSignalService.send({
            heading: '❌ Template Needs Changes',
            content: `"${templateName}": ${reason.slice(0, 80)}`,
            playerIds: [user.oneSignalPlayerId],
            data: { screen: 'creator_templates' },
          });
        }
        break;
      }

      case 'daily_status_push': {
        // Hindi users
        await OneSignalService.send({
          heading: '🙏 आज का स्टेटस तैयार है!',
          content: 'नए devotional और motivational status देखें। अभी share करें!',
          filters: [{ field: 'tag', key: 'language', relation: '=', value: 'HINDI' }],
          data: { screen: 'home' },
        });
        // Marathi users
        await OneSignalService.send({
          heading: '🙏 आजचा स्टेटस तयार आहे!',
          content: 'नवे devotional आणि motivational status पहा. आत्ता share करा!',
          filters: [{ field: 'tag', key: 'language', relation: '=', value: 'MARATHI' }],
          data: { screen: 'home' },
        });
        break;
      }

      case 'send_premium_welcome': {
        const { userId } = data;
        const user = await prisma.user.findUnique({
          where: { id: userId },
          select: { oneSignalPlayerId: true },
        });
        if (user?.oneSignalPlayerId) {
          await OneSignalService.send({
            heading: '⭐ Premium Activated!',
            content: 'अब unlimited status enjoy करें। आपका Status Go Premium शुरू हो गया!',
            playerIds: [user.oneSignalPlayerId],
            data: { screen: 'home' },
          });
        }
        break;
      }
    }
  },
  { connection, concurrency: 5 }
);

// ── QUEUE: cache ─────────────────────────────────────────────
const cacheWorker = new Worker(
  'cache',
  async (job) => {
    if (job.name === 'invalidate_template_cache') {
      const redis = connection;
      const patterns = ['tpl:list:*', 'tpl:featured', 'tpl:trending', 'tpl:new'];
      let totalDeleted = 0;
      for (const pattern of patterns) {
        let cursor = '0';
        do {
          const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', '100');
          cursor = nextCursor;
          if (keys.length > 0) {
            await redis.del(...keys);
            totalDeleted += keys.length;
          }
        } while (cursor !== '0');
      }
      console.log(`[cache] Invalidated ${totalDeleted} template cache keys`);
    }
  },
  { connection }
);

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
notificationWorker.on('failed', (job, err) => {
  console.error(JSON.stringify({
    level: 'error',
    worker: 'notifications',
    jobId: job?.id,
    jobName: job?.name,
    error: err.message,
    attemptsMade: job?.attemptsMade,
  }));
});

cacheWorker.on('failed', (job, err) => {
  console.error(JSON.stringify({
    level: 'error',
    worker: 'cache',
    jobId: job?.id,
    error: err.message,
  }));
});

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

console.log('✅ Workers running: notifications, cache, cron');

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('[workers] SIGTERM received — shutting down gracefully');
  await Promise.allSettled([
    notificationWorker.close(),
    cacheWorker.close(),
    cronWorker.close(),
    cronQueue.close(),
  ]);
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('[workers] SIGINT received — shutting down');
  await Promise.allSettled([
    notificationWorker.close(),
    cacheWorker.close(),
    cronWorker.close(),
    cronQueue.close(),
  ]);
  await prisma.$disconnect();
  process.exit(0);
});


async function checkPlanExpiry() {
  console.log('[cron] Checking plan expiry...');

  const expired = await prisma.subscription.findMany({
    where: {
      status: 'ACTIVE',
      expiresAt: { lt: new Date() },
    },
    select: { id: true, userId: true },
  });

  for (const sub of expired) {
    await prisma.$transaction([
      prisma.subscription.update({
        where: { id: sub.id },
        data: { status: 'EXPIRED' },
      }),
      prisma.user.update({
        where: { id: sub.userId },
        data: { plan: 'FREE', planExpiresAt: null },
      }),
    ]);
    console.log(`[cron] Expired plan for user ${sub.userId}`);
  }

  console.log(`[cron] Plan expiry check done. Expired: ${expired.length}`);
}

// ── CRON: Festival Alert ──────────────────────────────────────
async function checkFestivalAlerts() {
  console.log('[cron] Checking festival alerts...');

  const twoDaysFromNow = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000);
  const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);

  const festivals = await prisma.festival.findMany({
    where: {
      isActive: true,
      date: { gte: tomorrow, lte: twoDaysFromNow },
    },
  });

  for (const festival of festivals) {
    // Hindi notification
    await OneSignalService.send({
      heading: `🎉 ${festival.nameHi} कल है!`,
      content: `Special ${festival.nameHi} status के साथ wishes share करें`,
      filters: [{ field: 'tag', key: 'language', relation: '=', value: 'HINDI' }],
      data: { screen: 'discover', query: festival.nameHi },
    });
    // Marathi notification
    await OneSignalService.send({
      heading: `🎉 ${festival.nameMr} उद्या आहे!`,
      content: `Special ${festival.nameMr} status सह wishes share करा`,
      filters: [{ field: 'tag', key: 'language', relation: '=', value: 'MARATHI' }],
      data: { screen: 'discover', query: festival.nameMr },
    });
    console.log(`[cron] Festival alert sent: ${festival.nameEn}`);
  }
}


// ── CRON helper functions are used by cronWorker above ────────

