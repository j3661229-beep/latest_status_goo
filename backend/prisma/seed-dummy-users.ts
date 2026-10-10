// prisma/seed-dummy-users.ts
import { PrismaClient, Language, Plan, UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';

const prisma = new PrismaClient();

// ── Seed safety ─────────────────────────────────────────────
// Never hard-code passwords: use SEED_*_PASSWORD from the environment, otherwise a
// random password is generated and printed once. Existing accounts keep their
// password unless the env var is set explicitly.
function assertSeedAllowed() {
  if (process.env.NODE_ENV === 'production' && process.env.FORCE_SEED !== 'true') {
    throw new Error('Refusing to seed with NODE_ENV=production (set FORCE_SEED=true to override).');
  }
}

function resolveSeedPassword(envVar: string): { password: string; fromEnv: boolean } {
  const fromEnv = process.env[envVar];
  if (fromEnv) return { password: fromEnv, fromEnv: true };
  return { password: randomBytes(12).toString('base64url'), fromEnv: false };
}


async function main() {
  console.log('🌱 Seeding Super Admin and Creator dummy credentials...\n');

  assertSeedAllowed();

  // Hashes (passwords come from env or are generated — never hard-coded)
  const adminSeed = resolveSeedPassword('SEED_ADMIN_PASSWORD');
  const creatorSeed = resolveSeedPassword('SEED_CREATOR_PASSWORD');
  const adminPasswordHash = await bcrypt.hash(adminSeed.password, 12);
  const creatorPasswordHash = await bcrypt.hash(creatorSeed.password, 12);
  // Existing accounts keep their password unless the env var is set explicitly
  const adminPwUpdate = adminSeed.fromEnv ? { password: adminPasswordHash } : {};
  const creatorPwUpdate = creatorSeed.fromEnv ? { password: creatorPasswordHash } : {};
  const describe = (seed: { password: string; fromEnv: boolean }, envVar: string) =>
    seed.fromEnv ? `(from ${envVar})` : `${seed.password} (generated; new accounts only)`;

  // 1. Super Admin: admin@statusgo.com
  const superAdmin1 = await prisma.user.upsert({
    where: { email: 'admin@statusgo.com' },
    update: {
      ...adminPwUpdate,
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
  console.log(`✅ Super Admin created/updated: admin@statusgo.com (Password: ${describe(adminSeed, 'SEED_ADMIN_PASSWORD')})`);

  // 1b. Super Admin fallback: superadmin@statusgo.app
  await prisma.user.upsert({
    where: { email: 'superadmin@statusgo.app' },
    update: {
      ...adminPwUpdate,
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
  console.log(`✅ Super Admin created/updated: superadmin@statusgo.app (Password: ${describe(adminSeed, 'SEED_ADMIN_PASSWORD')})`);

  // 1c. Super Admin fallback: admin@statusgo.app
  await prisma.user.upsert({
    where: { email: 'admin@statusgo.app' },
    update: {
      ...adminPwUpdate,
      role: UserRole.SUPER_ADMIN,
      isActive: true,
      name: 'Super Admin',
      displayName: 'Super Admin',
    },
    create: {
      email: 'admin@statusgo.app',
      name: 'Super Admin',
      displayName: 'Super Admin',
      password: adminPasswordHash,
      role: UserRole.SUPER_ADMIN,
      plan: Plan.PREMIUM,
      language: Language.HINDI,
      isActive: true,
    },
  });
  console.log(`✅ Super Admin created/updated: admin@statusgo.app (Password: ${describe(adminSeed, 'SEED_ADMIN_PASSWORD')})`);

  // 2. Creator: creator@statusgo.com
  const creator1 = await prisma.user.upsert({
    where: { email: 'creator@statusgo.com' },
    update: {
      ...creatorPwUpdate,
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
  console.log(`✅ Creator created/updated: creator@statusgo.com (Password: ${describe(creatorSeed, 'SEED_CREATOR_PASSWORD')})`);

  // 2b. Creator: creator1@statusgo.app
  const creator2 = await prisma.user.upsert({
    where: { email: 'creator1@statusgo.app' },
    update: {
      ...creatorPwUpdate,
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
  console.log(`✅ Creator created/updated: creator1@statusgo.app (Password: ${describe(creatorSeed, 'SEED_CREATOR_PASSWORD')})`);

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
