import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { DEFAULT_FEEDS } from '../backend/src/lib/content/settings';
import { ingestNews } from '../backend/src/lib/content/ingest';

async function main() {
  const prisma = new PrismaClient();
  try {
    console.log(`Setting content.news_feeds to DEFAULT_FEEDS (${DEFAULT_FEEDS.length} feeds)...`);
    await prisma.appConfig.upsert({
      where: { key: 'content.news_feeds' },
      create: {
        key: 'content.news_feeds',
        value: JSON.stringify(DEFAULT_FEEDS),
        type: 'json',
        description: 'AI shorts news RSS feeds with regional support'
      },
      update: {
        value: JSON.stringify(DEFAULT_FEEDS)
      }
    });

    console.log('AppConfig updated! Now running ingestNews across all feeds...');
    const result = await ingestNews(prisma, {
      feeds: DEFAULT_FEEDS,
      staleHours: 168, // allow up to 7 days for initial population
      maxIngest: 100,
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

    const regionalSamples = await prisma.shortVideo.findMany({
      where: { kind: 'NEWS', status: 'PUBLISHED', subKind: 'REGIONAL' },
      take: 5,
      orderBy: { publishedAt: 'desc' },
      select: { id: true, title: true, subKind: true, region: true, attribution: true, status: true }
    });
    console.log('\nRegional Samples:\n', regionalSamples);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(console.error);
