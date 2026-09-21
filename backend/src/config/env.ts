// src/config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  // App
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().default('3000'),
  APP_URL: z.string().default('http://localhost:3000'),

  // Database
  DATABASE_URL: z.string(),
  DIRECT_DATABASE_URL: z.string().optional(),

  // Redis
  REDIS_URL: z.string(),

  // JWT
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),

  // Google OAuth
  GOOGLE_CLIENT_ID: z.string().optional().default('placeholder.apps.googleusercontent.com'),

  // Razorpay
  RAZORPAY_KEY_ID: z.string().optional().default('rzp_test_placeholder'),
  RAZORPAY_KEY_SECRET: z.string().optional().default('placeholder'),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional().default('placeholder'),

  // Google Cloud Storage (file uploads)
  GCP_PROJECT_NAME: z.string().optional().default('My First Project'),
  GCS_PROJECT_ID: z.string().optional().default('my-first-project-123456'),
  GCP_PROJECT_NUMBER: z.string().optional().default('123456789'),
  GCS_BUCKET_NAME: z.string().optional().default('statusgo-media'),
  GCS_CDN_BASE_URL: z.string().optional().default('https://storage.googleapis.com/statusgo-media'),
  // GCS_SA_KEY_JSON: base64-encoded service account key JSON (set in production)
  GCS_SA_KEY_JSON: z.string().optional(),

  // Firebase Admin (for phone OTP verification on backend if needed)
  FIREBASE_PROJECT_ID: z.string().optional().default('your-firebase-project-id'),
  FIREBASE_SA_KEY_JSON: z.string().optional(),

  // OneSignal
  ONESIGNAL_APP_ID: z.string().optional(),
  ONESIGNAL_REST_KEY: z.string().optional(),

  // Sentry
  SENTRY_DSN_API: z.string().optional(),
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
