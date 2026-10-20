import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { contentConfig } from './src/lib/content/config';
import { VertexGeminiProvider } from './src/lib/content/script';
import { GoogleTtsProvider } from './src/lib/content/tts';
import { gcsContentStorage } from './src/lib/content/assets';
import { runStage, PipelineDeps, Stage, recordFailure } from './src/lib/content/pipeline';

const prisma = new PrismaClient();

async function main() {
  const cfg = contentConfig();
  const deps: PipelineDeps = {
    prisma,
    cfg,
    scriptProvider: new VertexGeminiProvider(cfg),
    tts: new GoogleTtsProvider(cfg),
    storage: gcsContentStorage,
    log: (m, x) => console.log(`[test-pipeline] ${m}`, x ?? ''),
  };

  const id = 'cmvgyzdnb000263e5e97fydmt';

  // Clear stuck RUNNING job from previous aborted run
  await prisma.contentJob.updateMany({
    where: { shortVideoId: id, state: 'RUNNING' },
    data: { state: 'FAILED', failureReason: 'Aborted run reset' },
  });

  const video = await prisma.shortVideo.findUnique({ where: { id } });
  if (!video) return;

  console.log(`Video status: ${video.status}, hasScript: ${!!video.script}, audioKey: ${video.audioKey}`);

  let currentStage: Stage | null = !video.script ? 'SCRIPT' : !video.audioKey ? 'NARRATION' : 'RENDER';

  while (currentStage) {
    console.log(`Executing stage: ${currentStage}...`);
    try {
      const res = await runStage(deps, currentStage, id);
      console.log(`Stage ${currentStage} completed:`, res);
      currentStage = res.next;
    } catch (e: any) {
      console.error(`Stage ${currentStage} failed:`, e);
      await recordFailure(deps, currentStage, id, e, true);
      break;
    }
  }

  const finalVideo = await prisma.shortVideo.findUnique({
    where: { id },
    select: {
      id: true,
      title: true,
      status: true,
      audioKey: true,
      videoKey: true,
      thumbnailKey: true,
      durationSec: true,
      costMicroUsd: true,
    },
  });
  console.log('Final video state:');
  console.log(JSON.stringify(finalVideo, null, 2));
}

main().finally(() => prisma.$disconnect());
