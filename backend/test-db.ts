// test-db.ts — quick connectivity check for the configured Postgres URLs.
// Usage: npx tsx test-db.ts
// Reads DATABASE_URL / DIRECT_DATABASE_URL from the environment (.env via dotenv).
// Never hard-code credentials here.
import 'dotenv/config';
import { Client } from 'pg';

const redact = (url: string) => url.replace(/\/\/([^:@/]+):[^@]*@/, '//$1:***@');

async function testConnection(label: string, url: string | undefined) {
  if (!url) {
    console.log(`⏭️  ${label} is not set — skipping`);
    return;
  }
  const client = new Client({ connectionString: url });
  try {
    await client.connect();
    await client.query('SELECT 1');
    console.log(`✅ ${label} OK: ${redact(url)}`);
  } catch (err: any) {
    console.error(`❌ ${label} failed: ${redact(url)} -> ${err.message}`);
  } finally {
    await client.end().catch(() => {});
  }
}

async function run() {
  await testConnection('DATABASE_URL', process.env.DATABASE_URL);
  await testConnection('DIRECT_DATABASE_URL', process.env.DIRECT_DATABASE_URL);
}

run();
