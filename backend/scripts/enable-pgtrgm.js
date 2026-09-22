// Enable pg_trgm extension and test search
const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

const exec = (sql) => p.$executeRawUnsafe(sql);
const query = (sql) => p.$queryRawUnsafe(sql);

exec('CREATE EXTENSION IF NOT EXISTS pg_trgm')
  .then(() => {
    console.log('pg_trgm extension: ENABLED');
    return query("SELECT similarity('birthday', 'birthday') as s");
  })
  .then((r) => {
    console.log('similarity() function: WORKS ->', JSON.stringify(r));
    console.log('Search API should now work correctly!');
    process.exit(0);
  })
  .catch((e) => {
    console.log('Error:', e.message);
    process.exit(0);
  });
