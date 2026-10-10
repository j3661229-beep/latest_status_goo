// src/lib/http/validation.ts
// Shared request-validation helpers (pagination clamping, zod → 400 responses).
import { z, ZodError } from 'zod';
import type { FastifyReply } from 'fastify';

/** Treat '' / null query values as "not provided" (dashboards send `?status=`). */
export const emptyToUndefined = (v: unknown) => (v === '' || v === null ? undefined : v);

/** Optional enum query param where '' means "no filter". */
export const optionalEnum = <const T extends [string, ...string[]]>(values: T) =>
  z.preprocess(emptyToUndefined, z.enum(values).optional());

/** Optional 'true' / 'false' query param where '' means "no filter". */
export const optionalBoolString = z.preprocess(
  emptyToUndefined,
  z.enum(['true', 'false']).transform((v) => v === 'true').optional(),
);

/** Optional trimmed string query param where '' means "no filter". */
export const optionalString = (max = 200) =>
  z.preprocess(
    (v) => (typeof v === 'string' ? v.trim() || undefined : emptyToUndefined(v)),
    z.string().max(max).optional(),
  );

/** Parse an integer query value; returns `fallback` for missing/NaN input. */
export function toInt(value: unknown, fallback: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && value.trim() !== '') {
    const n = parseInt(value, 10);
    if (Number.isFinite(n)) return n;
  }
  return fallback;
}

/** Clamp a numeric query value into [min, max] with a default for invalid input. */
export function clampInt(value: unknown, fallback: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, toInt(value, fallback)));
}

/**
 * Normalise page/limit query params: page >= 1, 1 <= limit <= maxLimit.
 * NaN / negative / missing values fall back to defaults instead of reaching Prisma.
 */
export function parsePagination(
  query: unknown,
  opts: { defaultLimit?: number; maxLimit?: number } = {},
): { page: number; limit: number; skip: number } {
  const q = (query ?? {}) as Record<string, unknown>;
  const defaultLimit = opts.defaultLimit ?? 20;
  const maxLimit = opts.maxLimit ?? 100;
  const page = clampInt(q.page, 1, 1, 100_000);
  const limit = clampInt(q.limit, defaultLimit, 1, maxLimit);
  return { page, limit, skip: (page - 1) * limit };
}

/** Send a uniform 400 for a zod validation failure. */
export function sendValidationError(reply: FastifyReply, error: ZodError, message = 'Invalid request') {
  return reply.status(400).send({
    statusCode: 400,
    error: message,
    details: error.flatten(),
  });
}

/** Valid date string (ISO or anything Date.parse understands). */
export const dateString = z
  .string()
  .refine((s) => !Number.isNaN(Date.parse(s)), { message: 'Invalid date' });

/** https:// URL (used for user-supplied image URLs). */
export const httpsUrl = z
  .string()
  .max(2048)
  .url()
  .refine((s) => s.startsWith('https://'), { message: 'URL must use https' });
