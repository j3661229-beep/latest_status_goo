// src/app.ts
import Fastify, { FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import multipart from '@fastify/multipart';
import compress from '@fastify/compress';
import { env } from './config/env';

// Plugins
import prismaPlugin from './plugins/prisma.plugin';
import redisPlugin from './plugins/redis.plugin';
import authPlugin from './plugins/auth.plugin';

// Routes
import { authRoutes } from './modules/auth/auth.route';
import { templateRoutes } from './modules/templates/template.route';
import { searchRoutes } from './modules/search/search.route';
import { userRoutes } from './modules/user/user.route';
import { subscriptionRoutes } from './modules/subscriptions/sub.route';
import { festivalRoutes } from './modules/festivals/festival.route';
import { creatorRoutes } from './modules/creator/creator.route';
import { adminRoutes } from './modules/admin/admin.route';
import { uploadRoutes } from './modules/upload/upload.route';

// ── Per-route rate limit configurations ─────────────────────
// Applied via config.rateLimit on individual routes
const RATE_LIMITS = {
  auth:        { max: 20,  timeWindow: '1 minute'  },  // general auth
  adminLogin:  { max: 10,  timeWindow: '5 minutes' },  // admin/creator login
  otpSend:     { max: 5,   timeWindow: '5 minutes' },  // OTP send
  otpVerify:   { max: 10,  timeWindow: '5 minutes' },  // OTP verify
  refresh:     { max: 30,  timeWindow: '1 minute'  },  // token refresh
  payment:     { max: 5,   timeWindow: '1 minute'  },  // payment create/verify
  search:      { max: 60,  timeWindow: '1 minute'  },  // search
  campaign:    { max: 5,   timeWindow: '1 minute'  },  // push campaigns
} as const;

export { RATE_LIMITS };

export async function buildApp() {
  const app = Fastify({
    logger: {
      level: env.NODE_ENV === 'production' ? 'info' : 'debug',
      ...(env.NODE_ENV !== 'production' && {
        transport: {
          target: 'pino-pretty',
          options: { colorize: true, translateTime: 'SYS:standard', ignore: 'pid,hostname' },
        },
      }),
      // Redact sensitive fields from all log output
      redact: {
        paths: ['req.headers.authorization', 'body.password', 'body.refreshToken', 'body.idToken', 'body.otp'],
        censor: '[REDACTED]',
      },
    },
    trustProxy: true,
    disableRequestLogging: false,
  });

  // ── Security ─────────────────────────────────────────────
  await app.register(helmet, {
    contentSecurityPolicy: false, // APIs don't need CSP
  });

  await app.register(cors, {
    origin: [
      'http://localhost:3001',
      'http://localhost:3002',
      'https://admin.statusgo.app',
      'https://creator.statusgo.app',
      // Flutter app uses HTTP requests, not CORS
    ],
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type'],
    credentials: true,
  });

  await app.register(rateLimit, {
    global: true,
    max: 200,
    timeWindow: '1 minute',
    keyGenerator: (req: FastifyRequest) => req.ip ?? 'unknown',
    errorResponseBuilder: (_req: FastifyRequest, context: { ttl: number }) => ({
      statusCode: 429,
      error: 'Too Many Requests',
      message: `Rate limit exceeded. Retry in ${Math.round(context.ttl / 1000)}s`,
    }),
  });

  // ── Multipart (file uploads) ─────────────────────────────
  await app.register(multipart, {
    limits: {
      fieldNameSize: 100,
      fieldSize: 100,
      fields: 10,
      fileSize: 10 * 1024 * 1024,  // 10 MB
      files: 1,
    },
  });

  // ── Compression (improves response times significantly) ───
  await app.register(compress, {
    global: true,
    encodings: ['gzip', 'deflate'],
  });

  // ── Infrastructure Plugins ───────────────────────────────
  await app.register(prismaPlugin);
  await app.register(redisPlugin);
  await app.register(authPlugin);

  // ── Health Check ─────────────────────────────────────────
  app.get('/api/v1/health', async (req, reply) => {
    const start = Date.now();

    // Test DB
    let dbStatus = 'ok';
    try {
      await app.prisma.$queryRaw`SELECT 1`;
    } catch {
      dbStatus = 'error';
    }

    // Test Redis
    let redisStatus = 'ok';
    try {
      await app.redis.ping();
    } catch {
      redisStatus = 'error';
    }

    return reply.send({
      status: dbStatus === 'ok' && redisStatus === 'ok' ? 'ok' : 'degraded',
      db: dbStatus,
      redis: redisStatus,
      version: '1.0.0',
      env: env.NODE_ENV,
      latency_ms: Date.now() - start,
    });
  });

  // ── API Routes ───────────────────────────────────────────
  const V1 = '/api/v1';

  await app.register(authRoutes,          { prefix: `${V1}/auth` });
  await app.register(templateRoutes,      { prefix: `${V1}/templates` });
  await app.register(searchRoutes,        { prefix: `${V1}/search` });
  await app.register(userRoutes,          { prefix: `${V1}/user` });
  await app.register(subscriptionRoutes,  { prefix: `${V1}/subscribe` });
  await app.register(festivalRoutes,      { prefix: `${V1}/festivals` });
  await app.register(creatorRoutes,       { prefix: `${V1}/creator` });
  await app.register(adminRoutes,         { prefix: `${V1}/admin` });
  await app.register(uploadRoutes,        { prefix: `${V1}/upload` });

  // Fallback for plan list
  app.get(`${V1}/plans`, async (_req, reply) => {
    return reply.redirect(`${V1}/subscribe/plans`);
  });

  // ── Public: Categories list ──────────────────────────────
  app.get(`${V1}/categories`, async (_req, reply) => {
    const categories = await app.prisma.category.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      select: {
        id: true,
        slug: true,
        nameEn: true,
        nameHi: true,
        nameMr: true,
        emoji: true,
        gradient: true,
        templateCount: true,
      },
    });
    return reply.send({ data: categories, total: categories.length });
  });

  // ── Global Error Handler ─────────────────────────────────
  app.setErrorHandler((error, _req, reply) => {
    app.log.error(error);

    if (error.validation) {
      return reply.status(400).send({
        statusCode: 400,
        error: 'Validation Error',
        message: error.message,
        details: error.validation,
      });
    }

    const statusCode = error.statusCode ?? 500;
    return reply.status(statusCode).send({
      statusCode,
      error: error.name ?? 'Internal Server Error',
      message: env.NODE_ENV === 'production' ? 'An error occurred' : error.message,
    });
  });

  // ── 404 Handler ──────────────────────────────────────────
  app.setNotFoundHandler((_req, reply) => {
    reply.status(404).send({
      statusCode: 404,
      error: 'Not Found',
      message: 'Route not found',
    });
  });

  return app;
}
