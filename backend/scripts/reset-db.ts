// scripts/reset-db.ts — Wipe all data and create ONE SUPER_ADMIN account
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@statusgo.in';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'StatusGo@Admin2026!';

async function resetDatabase() {
  console.log('🔄 Wiping all tables from database...');

  // Delete in foreign-key safe order
  await prisma.$executeRawUnsafe(`
    TRUNCATE TABLE 
      "AuditLog",
      "AnalyticsEvent",
      "NotificationLog",
      "PushCampaign",
      "ShareHistory",
      "SavedStatus",
      "Subscription",
      "Template",
      "Category",
      "Festival",
      "CreatorProfile",
      "User",
      "AppConfig"
    CASCADE;
  `);

  console.log('✅ All existing data wiped successfully.');

  // Create single SUPER_ADMIN
  console.log(`👤 Creating single SUPER_ADMIN account (${ADMIN_EMAIL})...`);
  const hash = await bcrypt.hash(ADMIN_PASSWORD, 12);

  const admin = await prisma.user.create({
    data: {
      email: ADMIN_EMAIL,
      name: 'Super Admin',
      password: hash,
      role: 'SUPER_ADMIN',
      plan: 'ANNUAL',
      language: 'HINDI',
      isActive: true,
      lastActiveAt: new Date(),
    },
  });

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🎉 DATABASE RESET COMPLETE — ONLY 1 ADMIN ACCOUNT:');
  console.log(`   Email:    ${admin.email}`);
  console.log(`   Password: ${ADMIN_PASSWORD}`);
  console.log(`   Role:     ${admin.role}`);
  console.log(`   User ID:  ${admin.id}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}

resetDatabase()
  .catch((e) => {
    console.error('❌ Error during reset:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
