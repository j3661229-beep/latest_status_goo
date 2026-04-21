import { Client } from 'pg';

async function testConnection(url: string) {
  const client = new Client({ connectionString: url });
  try {
    await client.connect();
    console.log(`✅ Success for: ${url.replace(/:[^:]*@/, ':***@')}`);
    await client.end();
  } catch (err: any) {
    console.error(`❌ Failed for: ${url.replace(/:[^:]*@/, ':***@')} -> ${err.message}`);
  }
}

async function run() {
  const usernameFull = "postgres.eayiqtokycuqnvcxkyoc";
  const usernameShort = "postgres";
  const passEncoded = "Jayesh%20jay%402006";
  const passRawContext = "Jayesh jay@2006";
  const host = "aws-1-ap-northeast-2.pooler.supabase.com";

  await testConnection(`postgresql://${usernameFull}:${passEncoded}@${host}:5432/postgres`);
  await testConnection(`postgresql://${usernameShort}:${passEncoded}@${host}:5432/postgres`);
  await testConnection(`postgresql://${usernameFull}:${passEncoded}@${host}:6543/postgres`);
  await testConnection(`postgresql://${usernameShort}:${passEncoded}@${host}:6543/postgres`);
}

run();
