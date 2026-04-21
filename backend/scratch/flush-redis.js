const Redis = require('ioredis');
const redis = new Redis('redis://localhost:6379');

async function flush() {
  try {
    await redis.flushall();
    console.log('✅ Redis cleared successfully!');
  } catch (err) {
    console.error('❌ Failed to clear Redis:', err);
  } finally {
    process.exit(0);
  }
}

flush();
