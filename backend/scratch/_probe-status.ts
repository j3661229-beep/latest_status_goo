import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
const ID = 'cmvnrjuw20005h3nqfxmjv3d0';
(async () => {
  const p = new PrismaClient();
  const v = await p.shortVideo.findUnique({
    where: { id: ID },
    select: { status: true, title: true, scriptVersion: true, durationSec: true, videoKey: true, audioKey: true, thumbnailKey: true, costMicroUsd: true, updatedAt: true, aiMeta: true },
  });
  console.log('VIDEO', JSON.stringify(v, null, 0));
  const jobs = await p.contentJob.findMany({
    where: { shortVideoId: ID },
    orderBy: { queuedAt: 'asc' },
    select: { type: true, state: true, attempts: true, failureReason: true, queuedAt: true, startedAt: true, finishedAt: true, costMicroUsd: true },
  });
  for (const j of jobs) console.log('JOB', JSON.stringify(j));
  const reviews = await p.contentReview.findMany({ where: { shortVideoId: ID }, orderBy: { createdAt: 'asc' }, select: { action: true, actorId: true, reason: true, createdAt: true } });
  for (const r of reviews) console.log('REVIEW', JSON.stringify(r));
  const settings = await p.appConfig.findMany({ where: { key: { in: ['content.auto_publish_enabled', 'content.auto_publish_schemes', 'content.news_ingest_enabled'] } }, select: { key: true, value: true } });
  console.log('SETTINGS', settings.map((s) => `${s.key}=${s.value}`).join(' '));
  console.log('LOCAL_NOW', new Date().toISOString());
  await p.$disconnect();
})().catch((e) => { console.error(e.message); process.exit(1); });
