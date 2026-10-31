import { PrismaClient } from '@prisma/client';
import { ingestNews } from '../backend/src/lib/content/ingest';
import { loadSettings } from '../backend/src/lib/content/settings';

async function main() {
  const prisma = new PrismaClient();
  try {
    console.log('Loading settings...');
    const settings = await loadSettings(prisma);
    console.log(`Feeds configured: ${settings.feeds.length}`);
    for (const f of settings.feeds) {
      console.log(` - [${f.isRegional ? 'REGIONAL: ' + f.region : 'TOP'}] ${f.name} -> ${f.url}`);
    }

    console.log('\nRunning ingestNews...');
    const result = await ingestNews(prisma, {
      feeds: settings.feeds,
      staleHours: 72, // permit slightly older for test
    });
    console.log('Ingest Result:', JSON.stringify(result, null, 2));

    const totalNews = await prisma.newsStory.count();
    const publishedShorts = await prisma.shortVideo.count({
      where: { kind: 'NEWS', status: 'PUBLISHED' }
    });
    const topNewsCount = await prisma.shortVideo.count({
      where: { kind: 'NEWS', status: 'PUBLISHED', subKind: 'TOP' }
    });
    const regionalNewsCount = await prisma.shortVideo.count({
      where: { kind: 'NEWS', status: 'PUBLISHED', subKind: 'REGIONAL' }
    });

    console.log('\n--- VERIFICATION STATS ---');
    console.log(`Total News Stories in DB: ${totalNews}`);
    console.log(`Directly Published News Shorts: ${publishedShorts}`);
    console.log(` - Top News Cards: ${topNewsCount}`);
    console.log(` - Regional News Cards: ${regionalNewsCount}`);

    const sample = await prisma.shortVideo.findMany({
      where: { kind: 'NEWS', status: 'PUBLISHED' },
      take: 3,
      orderBy: { publishedAt: 'desc' },
      select: { id: true, title: true, subKind: true, region: true, attribution: true, status: true, format: true }
    });
    console.log('\nSample Cards:\n', sample);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(console.error);
