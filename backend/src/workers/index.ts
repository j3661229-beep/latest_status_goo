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

// ── CRON: Plan Expiry ─────────────────────────────────────────
// Checks for expired subscriptions daily at 3:30 AM IST (22:00 UTC)
// CRON queue (kept for manual job dispatch from API)
const _planExpiryQueue = new Queue('cron', { connection });

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

// Simple CRON-like scheduling (use proper CRON scheduler in production, e.g., BullMQ's repeat)
if (env.NODE_ENV === 'production') {
  // Run plan expiry every hour
  setInterval(checkPlanExpiry, 60 * 60 * 1000);
  // Run festival alerts every 6 hours
  setInterval(checkFestivalAlerts, 6 * 60 * 60 * 1000);
}

// Error handlers
notificationWorker.on('failed', (job, err) => {
  console.error(`[notifications] Job ${job?.id} failed:`, err.message);
});
cacheWorker.on('failed', (job, err) => {
  console.error(`[cache] Job ${job?.id} failed:`, err.message);
});

console.log('✅ Workers running: notifications, cache');
console.log('✅ CRON jobs: plan_expiry, festival_alerts');

// Graceful shutdown
process.on('SIGTERM', async () => {
  await notificationWorker.close();
  await cacheWorker.close();
  await prisma.$disconnect();
  process.exit(0);
});
