// src/server.ts
import 'dotenv/config';
import { buildApp } from './app';
import { env } from './config/env';

const PORT = parseInt(env.PORT);
const HOST = '0.0.0.0'; // Listen on all interfaces for Docker/Railway

async function start() {
  const app = await buildApp();

  try {
    await app.listen({ port: PORT, host: HOST });
    app.log.info(`🚀 Status Go API running at http://localhost:${PORT}`);
    app.log.info(`📊 Health check: http://localhost:${PORT}/api/v1/health`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received. Shutting down...');
  process.exit(0);
});

start();
