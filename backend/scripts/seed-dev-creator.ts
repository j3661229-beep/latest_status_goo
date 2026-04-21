import { PrismaClient, Language, Plan, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding dev-creator...');

  const user = await prisma.user.upsert({
    where: { email: 'creator@statusgo.local' },
    update: {},
    create: {
      email: 'creator@statusgo.local',
      name: 'Local Dev Creator',
      language: Language.HINDI,
      plan: Plan.FREE,
      role: UserRole.CREATOR,
      isActive: true,
      lastActiveAt: new Date(),
    },
  });

  console.log('Dev Creator seeded:', user.email);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
