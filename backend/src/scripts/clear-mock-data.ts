import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function clearMockData() {
  console.log('🧹 Clearing mock data from database...');

  try {
    // 1. Delete all templates (cascades or manual depending on schema)
    const templates = await prisma.template.deleteMany({
      where: {
        OR: [
          { creator: { email: { contains: '@statusgo.app' } } },
          { nameEn: { in: ['Jai Shri Ram', 'Ganesh Vandana', 'Hanuman Chalisa', 'Path to Success', 'Monday Motivation'] } }
        ]
      }
    });
    console.log(`✅ Deleted ${templates.count} mock templates`);

    // 2. Delete all creator profiles for mock creators
    const profiles = await prisma.creatorProfile.deleteMany({
      where: {
        user: { email: { contains: '@statusgo.app' } }
      }
    });
    console.log(`✅ Deleted ${profiles.count} mock creator profiles`);

    // 3. Delete mock users (keep admins for now unless requested)
    const users = await prisma.user.deleteMany({
      where: {
        AND: [
          { email: { contains: '@statusgo.app' } },
          { role: { in: ['USER', 'CREATOR'] } }
        ]
      }
    });
    console.log(`✅ Deleted ${users.count} mock users (User/Creator role)`);

    // 4. Optionally clear audit logs or analytics
    await prisma.auditLog.deleteMany({});
    await prisma.analyticsEvent.deleteMany({});
    console.log(`✅ Cleared audit logs and analytics`);

    console.log('✨ Database is now cleaned of mock entries.');
  } catch (error) {
    console.error('❌ Error clearing data:', error);
  } finally {
    await prisma.$disconnect();
  }
}

clearMockData();
