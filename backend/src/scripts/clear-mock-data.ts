// src/scripts/clear-mock-data.ts
// Deletes seeded mock users/templates AND wipes all audit logs + analytics events.
// Usage: npx tsx src/scripts/clear-mock-data.ts --yes
// Refuses to run with NODE_ENV=production unless FORCE_CLEAR=true.
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function clearMockData() {
  if (process.env.NODE_ENV === 'production' && process.env.FORCE_CLEAR !== 'true') {
    console.error('❌ Refusing to run with NODE_ENV=production (set FORCE_CLEAR=true to override).');
    process.exitCode = 1;
    await prisma.$disconnect();
    return;
  }
  if (!process.argv.includes('--yes')) {
    console.error('❌ This permanently deletes mock data and ALL audit-log / analytics rows.');
    console.error('   Re-run with --yes to confirm.');
    process.exitCode = 1;
    await prisma.$disconnect();
    return;
  }

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
