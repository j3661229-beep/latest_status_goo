const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

async function main() {
  const statusCounts = await p.shortVideo.groupBy({ by: ['status'], _count: true });
  console.log('Video status counts:', JSON.stringify(statusCounts));

  const jobCounts = await p.contentJob.groupBy({ by: ['type', 'state'], _count: true });
  console.log('Job state counts:', JSON.stringify(jobCounts));

  const recent = await p.shortVideo.findMany({
    orderBy: { createdAt: 'desc' },
    take: 5,
    select: { id: true, status: true, title: true, kind: true, createdAt: true, durationSec: true, videoKey: true }
  });
  console.log('Recent videos:');
  for (const v of recent) {
    console.log('  ' + v.id + ' | ' + v.status + ' | ' + v.kind + ' | dur=' + v.durationSec + 's | key=' + (v.videoKey || 'null') + ' | ' + String(v.title).slice(0,60));
  }

  try {
    const feeds = await p.newsFeed.findMany();
    console.log('News feeds:', JSON.stringify(feeds));
  } catch(e) {
    console.log('No newsFeed table or error:', e.message);
  }

  await p['$disconnect']();
}

main().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
