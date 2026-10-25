// src/app.ts
import Fastify, { FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import multipart from '@fastify/multipart';
import compress from '@fastify/compress';
import { Prisma } from '@prisma/client';
import { env } from './config/env';
import { CK } from './lib/cache/keys';
import { CacheService } from './lib/cache/cache.service';

// Plugins
import prismaPlugin from './plugins/prisma.plugin';
import redisPlugin from './plugins/redis.plugin';
import authPlugin from './plugins/auth.plugin';
import contentSchedulerPlugin from './plugins/content-scheduler.plugin';

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
import { shortsRoutes, schemeFeedRoutes, newsFeedRoutes } from './modules/shorts/shorts.route';
import { contentAdminRoutes } from './modules/content-admin/content.admin.route';
import { dailyContentRoutes } from './modules/daily-content/daily-content.route';

// Global JSON fallback for BigInt (e.g. un-cast COUNT(*) from $queryRaw) — without
// this JSON.stringify throws "Do not know how to serialize a BigInt" → 500.
if (!(BigInt.prototype as any).toJSON) {
  (BigInt.prototype as any).toJSON = function (this: bigint) {
    const n = Number(this);
    return Number.isSafeInteger(n) ? n : this.toString();
  };
}

// AppConfig keys that are safe to expose to unauthenticated clients via GET /config
const PUBLIC_CONFIG_KEYS = [
  'app_version_android',
  'maintenance_mode',
  'daily_free_limit_images',
  'daily_free_limit_videos',
  'featured_template_count',
  'trending_template_count',
  'premium_price_monthly',
  'premium_price_annual',
];

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
    // Only trust X-Forwarded-For when explicitly configured (TRUST_PROXY), otherwise
    // clients could spoof their IP and bypass per-IP rate limits.
    trustProxy: env.TRUST_PROXY,
    disableRequestLogging: false,
  });

  // ── Security ─────────────────────────────────────────────
  await app.register(helmet, {
    contentSecurityPolicy: false, // APIs don't need CSP
  });

  // The mobile client sends Content-Type: application/json on every request, including
  // body-less POST/DELETE (e.g. /user/saved/:id). Accept an empty body instead of a 400.
  if (app.hasContentTypeParser('application/json')) {
    app.removeContentTypeParser('application/json');
  }
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (_req, body, done) => {
    const text = (body as string).trim();
    if (!text) return done(null, undefined);
    try {
      done(null, JSON.parse(text));
    } catch {
      const err = new Error('Invalid JSON body') as Error & { statusCode: number };
      err.statusCode = 400;
      done(err, undefined);
    }
  });

  await app.register(cors, {
    origin: [
      'http://localhost:3001',
      'http://localhost:3002',
      /^https:\/\/([a-z0-9-]+\.)*statusgo\.(in|app)$/,
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
  await app.register(contentSchedulerPlugin);

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
  await app.register(contentAdminRoutes,  { prefix: `${V1}/admin` });
  await app.register(uploadRoutes,        { prefix: `${V1}/upload` });
  await app.register(shortsRoutes,        { prefix: `${V1}/shorts` });
  await app.register(schemeFeedRoutes,    { prefix: `${V1}/schemes` });
  await app.register(newsFeedRoutes,      { prefix: `${V1}/news` });
  await app.register(dailyContentRoutes,  { prefix: `${V1}/daily-content` });

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

  // ── Public: non-sensitive app config (feature flags, limits, prices) ──
  app.get(`${V1}/config`, async (_req, reply) => {
    const cache = new CacheService(app.redis);
    const cached = await cache.get(CK.publicAppConfig).catch(() => null);
    if (cached) return reply.send({ data: cached });

    const rows = await app.prisma.appConfig.findMany({
      where: { key: { in: PUBLIC_CONFIG_KEYS } },
      select: { key: true, value: true, type: true },
    });
    const data: Record<string, string | number | boolean> = {};
    for (const row of rows) {
      if (row.type === 'boolean') data[row.key] = row.value === 'true';
      else if (row.type === 'number' && row.value.trim() !== '' && !Number.isNaN(Number(row.value))) data[row.key] = Number(row.value);
      else data[row.key] = row.value;
    }
    await cache.set(CK.publicAppConfig, data, 1800).catch(() => {});
    return reply.send({ data });
  });

  // ── Global Error Handler ─────────────────────────────────
  app.setErrorHandler((error, _req, reply) => {
    // Map common Prisma errors to client errors instead of generic 500s
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      const mapped: Record<string, [number, string]> = {
        P2025: [404, 'Not Found'],          // record to update/delete not found
        P2002: [409, 'Conflict'],           // unique constraint
        P2003: [400, 'Bad Request'],        // foreign key (e.g. unknown categoryId)
      };
      const hit = mapped[error.code];
      if (hit) {
        app.log.warn({ code: error.code, meta: error.meta }, 'Prisma request error');
        return reply.status(hit[0]).send({ statusCode: hit[0], error: hit[1], message: hit[1] });
      }
    }
    if (error instanceof Prisma.PrismaClientValidationError) {
      app.log.warn(error.message);
      return reply.status(400).send({ statusCode: 400, error: 'Bad Request', message: 'Invalid request parameters' });
    }

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
      // 4xx messages (e.g. "request file too large") are safe to show; hide 5xx internals in prod
      message: env.NODE_ENV === 'production' && statusCode >= 500 ? 'An error occurred' : error.message,
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
