// Mirrors POST /admin/content/:id/retry (same DB updates + startGeneration) for the isolated test item.
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { startGeneration, getContentQueue } from '../src/lib/content/queue';

const ID = process.argv[2];
const ACTOR = 'recovery-task-2026-10-25';
(async () => {
  const prisma = new PrismaClient();
  const v = await prisma.shortVideo.findUnique({ where: { id: ID }, select: { status: true, scriptVersion: true } });
  if (!v) throw new Error('video not found');
  console.log(`before: status=${v.status} scriptVersion=${v.scriptVersion}`);
  const jobs = await prisma.contentJob.findMany({ where: { shortVideoId: ID }, select: { type: true, state: true, attempts: true, failureReason: true } });
  for (const j of jobs) console.log(`  job ${j.type} ${j.state} attempts=${j.attempts} ${j.failureReason ?? ''}`);
  if (v.status !== 'FAILED') { console.log('not FAILED; nothing to retry'); process.exit(2); }
  await prisma.$transaction([
    prisma.shortVideo.update({ where: { id: ID }, data: { status: 'SCRIPT_READY' } }),
    prisma.contentReview.create({ data: { shortVideoId: ID, actorId: ACTOR, action: 'retry', before: { status: 'FAILED' }, after: { status: 'SCRIPT_READY' } } }),
    prisma.contentJob.updateMany({ where: { shortVideoId: ID, state: 'FAILED' }, data: { state: 'QUEUED', attempts: 0, failureReason: null, startedAt: null, finishedAt: null } }),
  ]);
  const stage = await startGeneration(prisma, ID);
  console.log(`re-enqueued stage=${stage}`);
  await getContentQueue().close();
  await prisma.$disconnect();
  process.exit(0);
})().catch((e) => { console.error('RETRY FAILED', e.message); process.exit(1); });
