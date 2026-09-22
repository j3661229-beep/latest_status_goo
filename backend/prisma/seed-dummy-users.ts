// prisma/seed-dummy-users.ts
import { PrismaClient, Language, Plan, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding Super Admin and Creator dummy credentials...\n');

  // Hashes
  const adminPasswordHash = await bcrypt.hash('Admin@12345', 10);
  const creatorPasswordHash = await bcrypt.hash('Creator@12345', 10);

  // 1. Super Admin: admin@statusgo.com
  const superAdmin1 = await prisma.user.upsert({
    where: { email: 'admin@statusgo.com' },
    update: {
      password: adminPasswordHash,
      role: UserRole.SUPER_ADMIN,
      isActive: true,
      name: 'Super Admin',
      displayName: 'Super Admin',
    },
    create: {
      email: 'admin@statusgo.com',
      name: 'Super Admin',
      displayName: 'Super Admin',
      password: adminPasswordHash,
      role: UserRole.SUPER_ADMIN,
      plan: Plan.PREMIUM,
      language: Language.HINDI,
      isActive: true,
    },
  });
  console.log('✅ Super Admin created/updated: admin@statusgo.com (Password: Admin@12345)');

  // 1b. Super Admin fallback: superadmin@statusgo.app
  await prisma.user.upsert({
    where: { email: 'superadmin@statusgo.app' },
    update: {
      password: adminPasswordHash,
      role: UserRole.SUPER_ADMIN,
      isActive: true,
      name: 'Super Admin App',
      displayName: 'Super Admin',
    },
    create: {
      email: 'superadmin@statusgo.app',
      name: 'Super Admin App',
      displayName: 'Super Admin',
      password: adminPasswordHash,
      role: UserRole.SUPER_ADMIN,
      plan: Plan.PREMIUM,
      language: Language.HINDI,
      isActive: true,
    },
  });
  console.log('✅ Super Admin created/updated: superadmin@statusgo.app (Password: Admin@12345)');

  // 2. Creator: creator@statusgo.com
  const creator1 = await prisma.user.upsert({
    where: { email: 'creator@statusgo.com' },
    update: {
      password: creatorPasswordHash,
      role: UserRole.CREATOR,
      isActive: true,
      name: 'Rahul Sharma (Creator)',
      displayName: 'Rahul S.',
    },
    create: {
      email: 'creator@statusgo.com',
      name: 'Rahul Sharma (Creator)',
      displayName: 'Rahul S.',
      password: creatorPasswordHash,
      role: UserRole.CREATOR,
      plan: Plan.FREE,
      language: Language.HINDI,
      isActive: true,
    },
  });

  await prisma.creatorProfile.upsert({
    where: { userId: creator1.id },
    update: {
      displayName: 'Rahul Sharma',
      bio: 'Professional graphic designer creating devotional and festival templates.',
      specialization: ['devotional', 'festival', 'motivational'],
      isVerified: true,
      verifiedAt: new Date(),
    },
    create: {
      userId: creator1.id,
      displayName: 'Rahul Sharma',
      bio: 'Professional graphic designer creating devotional and festival templates.',
      specialization: ['devotional', 'festival', 'motivational'],
      isVerified: true,
      verifiedAt: new Date(),
      approvedCount: 15,
      pendingCount: 2,
      totalUploads: 18,
    },
  });
  console.log('✅ Creator created/updated: creator@statusgo.com (Password: Creator@12345)');

  // 2b. Creator: creator1@statusgo.app
  const creator2 = await prisma.user.upsert({
    where: { email: 'creator1@statusgo.app' },
    update: {
      password: creatorPasswordHash,
      role: UserRole.CREATOR,
      isActive: true,
      name: 'Rahul S. App',
    },
    create: {
      email: 'creator1@statusgo.app',
      name: 'Rahul S. App',
      displayName: 'Rahul S.',
      password: creatorPasswordHash,
      role: UserRole.CREATOR,
      plan: Plan.FREE,
      language: Language.HINDI,
      isActive: true,
    },
  });

  await prisma.creatorProfile.upsert({
    where: { userId: creator2.id },
    update: {
      displayName: 'Rahul S.',
      isVerified: true,
    },
    create: {
      userId: creator2.id,
      displayName: 'Rahul S.',
      bio: 'Creator for Status Go',
      specialization: ['devotional', 'good-morning'],
      isVerified: true,
      verifiedAt: new Date(),
    },
  });
  console.log('✅ Creator created/updated: creator1@statusgo.app (Password: Creator@12345)');

  console.log('\n🎉 Finished seeding admin and creator accounts successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding accounts:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
