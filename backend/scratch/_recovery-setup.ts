// One-off recovery setup (deleted after the task). Uses only production code paths.
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { safeFetchText } from '../src/lib/content/safe-fetch';
import { contentConfig } from '../src/lib/content/config';
import { parseFeed, dedupeKey } from '../src/lib/content/ingest';
import { startGeneration, getContentQueue } from '../src/lib/content/queue';

const ACTOR = 'recovery-task-2026-10-25';
const FEED = 'https://www.newsonair.gov.in/category/national/feed/';

(async () => {
  const prisma = new PrismaClient();
  const cfg = contentConfig();

  // 1. Safety: auto-publish OFF (task requirement); pause ingest while the isolated test runs.
  const before = await prisma.appConfig.findMany({ where: { key: { in: ['content.auto_publish_enabled', 'content.auto_publish_schemes', 'content.news_ingest_enabled'] } } });
  console.log('settings before:', before.map((r) => `${r.key}=${r.value}`).join(' '));
  for (const key of ['content.auto_publish_enabled', 'content.auto_publish_schemes', 'content.news_ingest_enabled']) {
    await prisma.appConfig.upsert({ where: { key }, create: { key, value: 'false', type: 'boolean', updatedBy: ACTOR }, update: { value: 'false', updatedBy: ACTOR } });
  }

  // 2. Source: newest NewsOnAir national item, fetched through the SSRF-safe fetcher (same as ingest).
  const feed = await safeFetchText(FEED, cfg);
  const it = parseFeed(feed.text)[0];
  const u = new URL(it.link); u.hash = '';
  const canonical = u.toString();
  const existing = await prisma.newsStory.findUnique({ where: { canonicalUrl: canonical } });
  if (existing) { console.log('story already exists, aborting to avoid duplicates', existing.id); process.exit(2); }
  const now = new Date();
  const story = await prisma.newsStory.create({
    data: {
      originalHeadline: it.title.slice(0, 500), publisher: 'NewsOnAir (Akashvani)', canonicalUrl: canonical, dedupeKey: dedupeKey(it.title),
      category: 'NEWS', publishedAt: it.publishedAt ?? now, retrievedAt: now, lastVerifiedAt: now, summary: it.summary.slice(0, 4000) || null,
    },
  });
  const video = await prisma.shortVideo.create({
    data: { kind: 'NEWS', newsStoryId: story.id, title: story.originalHeadline.slice(0, 200), category: 'NEWS', language: 'HINDI' },
  });
  console.log(`story=${story.id} publishedAt=${story.publishedAt.toISOString()} url=${canonical}`);
  console.log(`video=${video.id} status=${video.status}`);

  // 3. Enqueue through the same function the admin /content/generate route calls.
  const stage = await startGeneration(prisma, video.id);
  console.log(`enqueued stage=${stage}`);
  await getContentQueue().close();
  await prisma.$disconnect();
})().catch((e) => { console.error('SETUP FAILED', e.message); process.exit(1); });
