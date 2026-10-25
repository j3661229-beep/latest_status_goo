import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';

const ID = 'cmvnrjuw20005h3nqfxmjv3d0';
(async () => {
  const p = new PrismaClient();
  const v = await p.shortVideo.findUnique({ where: { id: ID }, select: { status: true, script: true, audioKey: true, videoKey: true, durationSec: true, updatedAt: true } });
  const script = v?.script as { title?: string } | null;
  console.log(`status=${v?.status} hasScript=${!!script} scriptTitle=${script?.title ?? '-'} audio=${v?.audioKey ?? '-'} video=${v?.videoKey ?? '-'} dur=${v?.durationSec ?? '-'} updated=${v?.updatedAt?.toISOString()}`);
  const jobs = await p.contentJob.findMany({ where: { shortVideoId: ID }, select: { type: true, state: true, attempts: true, failureReason: true, startedAt: true, finishedAt: true } });
  for (const j of jobs) console.log(`job ${j.type} ${j.state} attempts=${j.attempts} started=${j.startedAt?.toISOString() ?? '-'} finished=${j.finishedAt?.toISOString() ?? '-'} ${j.failureReason ?? ''}`);
  await p.$disconnect();

  const connection = new IORedis(process.env.REDIS_URL!, { maxRetriesPerRequest: null });
  for (const name of ['content-pipeline', 'content-maintenance']) {
    const q = new Queue(name, { connection });
    const counts = await q.getJobCounts('waiting', 'active', 'delayed', 'failed', 'completed');
    console.log(`queue ${name}`, JSON.stringify(counts));
    const active = await q.getActive();
    for (const j of active) console.log(`  active ${j.name} id=${j.id} data=${JSON.stringify(j.data)} attemptsMade=${j.attemptsMade}`);
    await q.close();
  }
  const hb = await connection.get('content:worker:heartbeat');
  console.log('heartbeat', hb ? hb.slice(0, 400) : 'none');
  await connection.quit();
})().catch((e) => { console.error(e.message); process.exit(1); });
