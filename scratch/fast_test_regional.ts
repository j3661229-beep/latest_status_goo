import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { ingestNews } from '../backend/src/lib/content/ingest';

const testFeeds = [
  { name: 'Google News (Hindi Top)', url: 'https://news.google.com/rss?hl=hi&gl=IN&ceid=IN:hi', category: 'TOP_NEWS', region: null, isRegional: false },
  { name: 'उत्तर प्रदेश (UP Regional)', url: 'https://news.google.com/rss/search?q=Uttar+Pradesh&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'UP', isRegional: true },
  { name: 'महाराष्ट्र (MH Regional)', url: 'https://news.google.com/rss/search?q=Maharashtra&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'MH', isRegional: true },
  { name: 'बिहार (BR Regional)', url: 'https://news.google.com/rss/search?q=Bihar&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'BR', isRegional: true },
  { name: 'मध्य प्रदेश (MP Regional)', url: 'https://news.google.com/rss/search?q=Madhya+Pradesh&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'MP', isRegional: true },
  { name: 'राजस्थान (RJ Regional)', url: 'https://news.google.com/rss/search?q=Rajasthan&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'RJ', isRegional: true },
];

async function main() {
  const prisma = new PrismaClient();
  try {
    console.log('Starting fast regional news ingestion...');
    const result = await ingestNews(prisma, {
      feeds: testFeeds,
      maxIngest: 50,
      staleHours: 168,
    });
    console.log('Result:', JSON.stringify(result, null, 2));

    const publishedShorts = await prisma.shortVideo.count({
      where: { kind: 'NEWS', status: 'PUBLISHED' }
    });
    const topNewsCount = await prisma.shortVideo.count({
      where: { kind: 'NEWS', status: 'PUBLISHED', subKind: 'TOP' }
    });
    const regionalNewsCount = await prisma.shortVideo.count({
      where: { kind: 'NEWS', status: 'PUBLISHED', subKind: 'REGIONAL' }
    });

    console.log(`\nDirectly Published News Shorts: ${publishedShorts}`);
    console.log(` - Top News: ${topNewsCount}`);
    console.log(` - Regional News: ${regionalNewsCount}`);

    const cards = await prisma.shortVideo.findMany({
      where: { kind: 'NEWS', status: 'PUBLISHED', subKind: 'REGIONAL' },
      take: 4,
      orderBy: { publishedAt: 'desc' },
      select: { id: true, title: true, region: true, subKind: true, attribution: true }
    });
    console.log('\nRegional Cards Sample:\n', cards);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(console.error);
