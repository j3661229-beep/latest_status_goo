import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  try {
    const schemes = await prisma.scheme.findMany({
      include: {
        _count: { select: { videos: true } },
        videos: { select: { id: true, title: true, status: true, createdAt: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    console.log(`Found ${schemes.length} schemes in DB:`);
    for (const s of schemes) {
      console.log(`- [${s.id}] slug: "${s.slug}" | nameHi: "${s.nameHi}" | status: ${s.reviewStatus} | videos: ${s._count.videos}`);
      for (const v of s.videos) {
        console.log(`    video: [${v.id}] status: ${v.status} | title: "${v.title}"`);
      }
    }

    const audit = await prisma.auditLog.findMany({
      where: {
        OR: [
          { action: { contains: 'scheme' } },
          { entityType: { in: ['Scheme', 'scheme'] } },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    console.log(`\nFound ${audit.length} scheme audit logs:`);
    for (const a of audit) {
      console.log(`- ${a.createdAt.toISOString()} | action: ${a.action} | entityId: ${a.entityId} | adminId: ${a.adminId}`);
    }

    const jobs = await prisma.contentJob.findMany({
      where: {
        shortVideoId: { in: ['cmvh2u4rg00179x39ezr6sr5o', 'cmvh1b4hj0001zk1ovpcffpxa', 'cmvgzw73i0003o9w7741c7awx'] },
      },
      orderBy: { queuedAt: 'desc' },
    });
    console.log(`\nFound ${jobs.length} jobs for failed videos:`);
    for (const j of jobs) {
      console.log(`- videoId: ${j.shortVideoId} | type: ${j.type} | state: ${j.state} | failure: "${j.failureReason}"`);
    }

    const allVideos = await prisma.shortVideo.findMany({
      select: { id: true, title: true, kind: true, status: true, schemeId: true, newsStoryId: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    console.log(`\nLast 20 ShortVideo records:`);
    for (const v of allVideos) {
      console.log(`- [${v.id}] ${v.kind} | status: ${v.status} | schemeId: ${v.schemeId ?? 'none'} | title: "${v.title}"`);
    }

    const allAudit = await prisma.auditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    console.log(`\nLast 20 audit log entries:`);
    for (const a of allAudit) {
      console.log(`- ${a.createdAt.toISOString()} | action: ${a.action} | type: ${a.entityType} | id: ${a.entityId}`);
    }
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(console.error);
