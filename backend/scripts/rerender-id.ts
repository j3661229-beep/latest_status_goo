import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
import { gcsContentStorage } from '../src/lib/content/assets';
import { runRenderStage } from '../src/lib/content/pipeline';
import { contentConfig } from '../src/lib/content/config';

async function main() {
  const videoId = process.argv[2] || 'cmvgyzdnb000263e5e97fydmt';
  const cfg = contentConfig();
  console.log(`Re-rendering short: ${videoId}`);

  const v = await prisma.shortVideo.findUnique({ where: { id: videoId } });
  if (!v) throw new Error('Video not found: ' + videoId);

  // Reset status to GENERATING so runRenderStage can proceed
  await prisma.shortVideo.update({
    where: { id: videoId },
    data: { status: 'GENERATING' },
  });

  // Clean any active job for render
  await prisma.contentJob.deleteMany({
    where: { shortVideoId: videoId },
  });

  const storage = gcsContentStorage;

  const tts = { narrate: async () => { throw new Error('not needed'); } };

  console.log('Running render stage...');
  const res = await runRenderStage(
    { prisma, storage, tts, cfg },
    videoId
  );

  console.log('Render stage complete:', res);
  const updated = await prisma.shortVideo.findUnique({
    where: { id: videoId },
    select: { id: true, status: true, videoKey: true, thumbnailKey: true, durationSec: true },
  });
  console.log('Updated video record:', updated);
  console.log(`Video URL: ${process.env.GCS_CDN_BASE_URL}/${updated?.videoKey}`);
  console.log(`Thumb URL: ${process.env.GCS_CDN_BASE_URL}/${updated?.thumbnailKey}`);
}

main()
  .catch((e) => {
    console.error('FAILED:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
