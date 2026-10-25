import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  try {
    const jobs = await prisma.contentJob.findMany({
      where: {
        shortVideoId: { in: ['cmvh2xdzs001l9x39dgut0td6', 'cmvh2u4rg00179x39ezr6sr5o'] },
      },
      orderBy: { queuedAt: 'desc' },
    });
    console.log(`Found ${jobs.length} jobs:`);
    for (const j of jobs) {
      console.log(`- Job [${j.id}] video: ${j.shortVideoId} | stage: ${j.type} | state: ${j.state} | failure: "${j.failureReason}"`);
    }

    const count = await prisma.contentJob.count({
      where: { startedAt: { gte: new Date(Date.now() - 86_400_000) } },
    });
    console.log(`Jobs started in last 24h: ${count}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(console.error);
