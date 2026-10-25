import { PrismaClient } from '@prisma/client';

const p = new PrismaClient();

async function main() {
  const counts: any[] = await p.$queryRawUnsafe(
    'SELECT status, COUNT(*)::int as count FROM "content"."short_videos" GROUP BY status ORDER BY count DESC'
  );
  console.log('Video status counts:', JSON.stringify(counts));

  const jobs: any[] = await p.$queryRawUnsafe(
    'SELECT type, state, COUNT(*)::int as count FROM "content"."content_jobs" GROUP BY type, state ORDER BY type, state'
  );
  console.log('Job state counts:', JSON.stringify(jobs));

  const recent: any[] = await p.$queryRawUnsafe(
    'SELECT id, status, title, kind, created_at, duration_sec, video_key FROM "content"."short_videos" ORDER BY created_at DESC LIMIT 5'
  );
  console.log('Recent videos:');
  for (const v of recent) {
    console.log('  ' + v.id + ' | ' + v.status + ' | ' + v.kind + ' | dur=' + v.duration_sec + 's | key=' + (v.video_key || 'null') + ' | ' + String(v.title).slice(0,60));
  }

  const feeds: any[] = await p.$queryRawUnsafe(
    'SELECT id, name, url, active FROM "content"."news_feeds" ORDER BY name'
  );
  console.log('News feeds:', JSON.stringify(feeds));

  await p.$disconnect();
}

main().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
