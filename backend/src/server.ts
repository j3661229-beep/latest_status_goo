// src/server.ts
import 'dotenv/config';
import { buildApp } from './app';
import { env } from './config/env';

const PORT = parseInt(env.PORT);
const HOST = '0.0.0.0'; // Listen on all interfaces for Docker/Railway

let app: Awaited<ReturnType<typeof buildApp>> | null = null;
let shuttingDown = false;

async function start() {
  app = await buildApp();

  try {
    await app.listen({ port: PORT, host: HOST });
    app.log.info(`🚀 Status Go API running at http://localhost:${PORT}`);
    app.log.info(`📊 Health check: http://localhost:${PORT}/api/v1/health`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

/**
 * Graceful shutdown: stop accepting connections, let in-flight requests finish, then close
 * Prisma/Redis via Fastify's onClose hooks. A hard timeout guarantees we still exit
 * (Cloud Run sends SIGKILL ~10s after SIGTERM).
 */
async function shutdown(signal: string) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`${signal} received. Shutting down gracefully...`);
  const force = setTimeout(() => {
    console.error('Graceful shutdown timed out; forcing exit');
    process.exit(1);
  }, 8000);
  force.unref();
  try {
    await app?.close();
    process.exit(0);
  } catch (err) {
    console.error('Error during shutdown', err);
    process.exit(1);
  }
}

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));

start().catch((err) => {
  // Boot failures (e.g. Redis required but unreachable in production) must exit non-zero, not hang.
  console.error('Failed to start', err);
  process.exit(1);
});
