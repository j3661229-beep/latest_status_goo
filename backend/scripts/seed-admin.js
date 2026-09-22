const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const hash = '.Hv3wpYOYLDF2K.CtJ2AroXpTZMSQSm.aII/GVxVIVqCFm';
prisma.user.upsert({
  where: { email: 'admin@statusgo.app' },
  update: { password: hash, role: 'SUPER_ADMIN', isActive: true, name: 'Super Admin' },
  create: { email: 'admin@statusgo.app', name: 'Super Admin', password: hash, role: 'SUPER_ADMIN', plan: 'FREE', language: 'HINDI', isActive: true, lastActiveAt: new Date() }
}).then(u => {
  console.log('Admin ready:', u.id, u.email, u.role);
  return prisma['']();
}).catch(e => { console.error(e.message); process.exit(1); });
