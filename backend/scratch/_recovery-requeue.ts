// Re-queue the isolated test item through startGeneration (same path as /content/generate).
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import { startGeneration, getContentQueue } from '../src/lib/content/queue';

const ID = 'cmvnrjuw20005h3nqfxmjv3d0';
(async () => {
  const connection = new IORedis(process.env.REDIS_URL!, { maxRetriesPerRequest: null });
  const q = new Queue('content-pipeline', { connection });
  const failed = await q.getFailed(0, 3);
  for (const j of failed) console.log(`recent fail ${j.name} ${j.id} ${j.failedReason?.slice(0, 180)}`);
  await q.close();

  const prisma = new PrismaClient();
  const dayStart = new Date(); dayStart.setUTCHours(0, 0, 0, 0);
  const jobsToday = await prisma.contentJob.count({ where: { startedAt: { gte: dayStart } } });
  console.log(`jobsToday=${jobsToday} now=${new Date().toISOString()}`);
  const stage = await startGeneration(prisma, ID);
  console.log(`enqueued stage=${stage}`);
  await getContentQueue().close();
  await prisma.$disconnect();
  await connection.quit();
  process.exit(0);
})().catch((e) => { console.error('REENQUEUE FAILED', e.message); process.exit(1); });
