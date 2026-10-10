// scripts/seed-admin.js — create or update a SUPER_ADMIN account.
// Usage:
//   SEED_ADMIN_EMAIL=you@example.com SEED_ADMIN_PASSWORD='a-strong-password' node scripts/seed-admin.js
// Refuses to run with NODE_ENV=production unless FORCE_SEED=true.
require('dotenv/config');
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

async function main() {
  if (process.env.NODE_ENV === 'production' && process.env.FORCE_SEED !== 'true') {
    throw new Error('Refusing to seed in production (set FORCE_SEED=true to override).');
  }

  const email = process.env.SEED_ADMIN_EMAIL;
  const password = process.env.SEED_ADMIN_PASSWORD;
  if (!email || !password) {
    throw new Error('SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD must be set.');
  }
  if (password.length < 12) {
    throw new Error('SEED_ADMIN_PASSWORD must be at least 12 characters.');
  }

  const prisma = new PrismaClient();
  try {
    const hash = await bcrypt.hash(password, 12);
    const user = await prisma.user.upsert({
      where: { email },
      update: { password: hash, role: 'SUPER_ADMIN', isActive: true },
      create: {
        email,
        name: 'Super Admin',
        password: hash,
        role: 'SUPER_ADMIN',
        plan: 'FREE',
        language: 'HINDI',
        isActive: true,
        lastActiveAt: new Date(),
      },
    });
    console.log('Admin ready:', user.id, user.email, user.role);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
