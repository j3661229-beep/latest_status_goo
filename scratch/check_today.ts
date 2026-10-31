import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);
  const countToday = await prisma.newsStory.count({ where: { retrievedAt: { gte: dayStart } } });
  console.log(`News stories retrieved today: ${countToday}`);
  await prisma.$disconnect();
}
main();
