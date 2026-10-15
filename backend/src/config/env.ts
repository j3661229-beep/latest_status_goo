// src/config/env.ts
import { z } from 'zod';

// Boolean feature flags: only the literal strings 'true' / '1' enable them.
const boolFlag = z
  .string()
  .optional()
  .transform((v) => v === 'true' || v === '1');

// TRUST_PROXY: unset/'false' → false (do not trust X-Forwarded-For),
// 'true' → trust all hops, a number → trust that many hops,
// anything else (e.g. '10.0.0.0/8,127.0.0.1') → passed to Fastify as an address list.
const trustProxy = z
  .string()
  .optional()
  .transform((v): boolean | number | string => {
    if (v === undefined || v === '' || v === 'false' || v === '0') return false;
    if (v === 'true') return true;
    if (/^\d+$/.test(v)) return parseInt(v, 10);
    return v;
  });

const envSchema = z.object({
  // App
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().default('3000'),
  APP_URL: z.string().default('http://localhost:3000'),
  // Reverse-proxy trust (affects req.ip used for rate limiting). Default: false.
  TRUST_PROXY: trustProxy,

  // Database
  DATABASE_URL: z.string(),
  DIRECT_DATABASE_URL: z.string().optional(),

  // Redis
  REDIS_URL: z.string(),
  // Production fails CLOSED when Redis is unavailable (sessions/OTP/webhook idempotency must be shared and
  // durable). Set to 'true' ONLY for a single-instance emergency; outside production the fallback is always on.
  REDIS_ALLOW_MEMORY_FALLBACK: boolFlag,

  // JWT
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),

  // Google OAuth
  GOOGLE_CLIENT_ID: z.string().optional().default('placeholder.apps.googleusercontent.com'),

  // Razorpay
  RAZORPAY_KEY_ID: z.string().optional().default('rzp_test_placeholder'),
  RAZORPAY_KEY_SECRET: z.string().optional().default('placeholder'),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional().default('placeholder'),
  // Razorpay plan_XXXX for the ₹99/month recurring plan.
  // Populated once via POST /api/v1/subscribe/intro/setup-plan (SUPER_ADMIN only).
  RZP_MONTHLY_PLAN_ID: z.string().optional(),

  // Google Cloud Storage (file uploads)
  GCP_PROJECT_NAME: z.string().optional().default('My First Project'),
  GCS_PROJECT_ID: z.string().optional().default('my-first-project-123456'),
  GCP_PROJECT_NUMBER: z.string().optional().default('123456789'),
  GCS_BUCKET_NAME: z.string().optional().default('statusgo-media'),
  GCS_CDN_BASE_URL: z.string().optional().default('https://storage.googleapis.com/statusgo-media'),
  // GCS_SA_KEY_JSON: base64-encoded service account key JSON (set in production)
  GCS_SA_KEY_JSON: z.string().optional(),

  // Firebase phone auth — ID tokens are verified against this project.
  // If unset, POST /auth/firebase-phone returns 503.
  FIREBASE_PROJECT_ID: z.string().optional(),

  // OneSignal
  ONESIGNAL_APP_ID: z.string().optional(),
  ONESIGNAL_REST_KEY: z.string().optional(),

  // Sentry
  SENTRY_DSN_API: z.string().optional(),

  // 2Factor.in SMS Gateway
  TWO_FACTOR_API_KEY: z.string().optional(),

  // Cloudinary (cloudinary://API_KEY:API_SECRET@CLOUD_NAME)
  CLOUDINARY_URL: z.string().optional(),

  // Dev/test only: accept OTP 123456 and echo the OTP in /auth/otp/send.
  // Ignored when NODE_ENV=production.
  ALLOW_TEST_OTP: boolFlag,

  // When true, creator submissions skip the moderation queue and go live immediately.
  AUTO_APPROVE_TEMPLATES: boolFlag,
});

function parseEnv() {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    const errors = result.error.flatten().fieldErrors;
    const missing = Object.entries(errors)
      .map(([k, v]) => `  ${k}: ${v?.join(', ')}`)
      .join('\n');
    throw new Error(`❌ Invalid environment variables:\n${missing}`);
  }
  return result.data;
}

export const env = parseEnv();
export type Env = typeof env;
