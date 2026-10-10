// scratch/flush-redis.js — wipe the Redis database pointed to by REDIS_URL.
// DANGEROUS: deletes every key (sessions, OTPs, caches).
// Usage: node scratch/flush-redis.js --yes
require('dotenv/config');
const Redis = require('ioredis');

async function flush() {
  if (!process.argv.includes('--yes')) {
    console.error('Refusing to run without --yes (this deletes ALL keys in REDIS_URL).');
    process.exit(1);
  }
  if (process.env.NODE_ENV === 'production') {
    console.error('Refusing to flush Redis with NODE_ENV=production.');
    process.exit(1);
  }
  const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
  try {
    await redis.flushdb();
    console.log('✅ Redis cleared successfully!');
  } catch (err) {
    console.error('❌ Failed to clear Redis:', err.message);
  } finally {
    redis.disconnect();
    process.exit(0);
  }
}

flush();
