// src/lib/content/settings.ts
// Operator-tunable content settings, stored in AppConfig (`content.*`) so admins can change the
// schedule without a deploy. Everything defaults to the SAFE option: ingestion is off until an
// admin turns it on, and nothing here can publish.
import { z } from 'zod';
import type { PrismaClient } from '@prisma/client';

export interface FeedConfig { name: string; url: string; category: string }

export interface ContentSettings {
  ingestEnabled: boolean;
  ingestIntervalMinutes: number;
  autoGenerate: boolean;
  maxNewVideosPerRun: number;
  newsStaleHours: number;
  newsAutoExpireHours: number; // 0 = never auto-expire published news
  schemeVerifyMaxAgeDays: number;
  developingFreshHours: number;
  feeds: FeedConfig[];
  lastIngestAt: Date | null;
}

export const DEFAULTS: ContentSettings = {
  ingestEnabled: false,
  ingestIntervalMinutes: 180,
  autoGenerate: true,
  maxNewVideosPerRun: 5,
  newsStaleHours: 48,
  newsAutoExpireHours: 72,
  schemeVerifyMaxAgeDays: 90,
  developingFreshHours: 1,
  feeds: [],
  lastIngestAt: null,
};

const KEYS = {
  ingestEnabled: 'content.news_ingest_enabled',
  ingestIntervalMinutes: 'content.news_ingest_interval_minutes',
  autoGenerate: 'content.news_auto_generate',
  maxNewVideosPerRun: 'content.news_max_new_videos_per_run',
  newsStaleHours: 'content.news_stale_hours',
  newsAutoExpireHours: 'content.news_auto_expire_hours',
  schemeVerifyMaxAgeDays: 'content.scheme_verify_max_age_days',
  developingFreshHours: 'content.developing_fresh_hours',
  feeds: 'content.news_feeds',
} as const;
export const LAST_INGEST_KEY = 'content.last_ingest_at';

export const SettingsPatchSchema = z
  .object({
    ingestEnabled: z.boolean(),
    ingestIntervalMinutes: z.number().int().min(15).max(1440),
    autoGenerate: z.boolean(),
    maxNewVideosPerRun: z.number().int().min(0).max(20),
    newsStaleHours: z.number().int().min(1).max(720),
    newsAutoExpireHours: z.number().int().min(0).max(2160),
    schemeVerifyMaxAgeDays: z.number().int().min(7).max(730),
    developingFreshHours: z.number().int().min(1).max(24),
    feeds: z
      .array(z.object({
        name: z.string().trim().min(2).max(80),
        url: z.string().url().max(2048).refine((u) => u.startsWith('https://'), 'Feed URL must use https'),
        category: z.string().trim().min(2).max(64),
      }))
      .max(30),
  })
  .partial()
  .refine((b) => Object.keys(b).length > 0, { message: 'No settings provided' });
export type SettingsPatch = z.infer<typeof SettingsPatchSchema>;

const bool = (v: string | undefined, d: boolean) => (v === undefined ? d : v === 'true');
const int = (v: string | undefined, d: number, min: number) => {
  const n = Number(v);
  return v !== undefined && Number.isFinite(n) && n >= min ? Math.trunc(n) : d;
};

export async function loadSettings(prisma: Pick<PrismaClient, 'appConfig'>): Promise<ContentSettings> {
  const rows = await prisma.appConfig.findMany({ where: { key: { startsWith: 'content.' } } });
  const get = (k: string) => rows.find((r) => r.key === k)?.value;
  let feeds: FeedConfig[] = [];
  try {
    const parsed = JSON.parse(get(KEYS.feeds) ?? '[]');
    feeds = Array.isArray(parsed) ? parsed.filter((f) => f && typeof f.url === 'string' && typeof f.name === 'string') : [];
  } catch { /* invalid JSON → no feeds; never throw from the scheduler */ }
  const last = get(LAST_INGEST_KEY);
  return {
    ingestEnabled: bool(get(KEYS.ingestEnabled), DEFAULTS.ingestEnabled),
    ingestIntervalMinutes: int(get(KEYS.ingestIntervalMinutes), DEFAULTS.ingestIntervalMinutes, 15),
    autoGenerate: bool(get(KEYS.autoGenerate), DEFAULTS.autoGenerate),
    maxNewVideosPerRun: int(get(KEYS.maxNewVideosPerRun), DEFAULTS.maxNewVideosPerRun, 0),
    newsStaleHours: int(get(KEYS.newsStaleHours), DEFAULTS.newsStaleHours, 1),
    newsAutoExpireHours: int(get(KEYS.newsAutoExpireHours), DEFAULTS.newsAutoExpireHours, 0),
    schemeVerifyMaxAgeDays: int(get(KEYS.schemeVerifyMaxAgeDays), DEFAULTS.schemeVerifyMaxAgeDays, 1),
    developingFreshHours: int(get(KEYS.developingFreshHours), DEFAULTS.developingFreshHours, 1),
    feeds,
    lastIngestAt: last && !Number.isNaN(Date.parse(last)) ? new Date(last) : null,
  };
}

export async function saveSettings(
  prisma: Pick<PrismaClient, 'appConfig'>, patch: SettingsPatch, adminId: string,
): Promise<void> {
  for (const [field, value] of Object.entries(patch) as [keyof typeof KEYS, unknown][]) {
    const key = KEYS[field];
    const str = field === 'feeds' ? JSON.stringify(value) : String(value);
    await prisma.appConfig.upsert({
      where: { key },
      create: { key, value: str, type: field === 'feeds' ? 'json' : typeof value === 'boolean' ? 'boolean' : 'number', description: `AI shorts: ${field}`, updatedBy: adminId },
      update: { value: str, updatedBy: adminId },
    });
  }
}

export async function markIngestRun(prisma: Pick<PrismaClient, 'appConfig'>, at: Date): Promise<void> {
  await prisma.appConfig.upsert({
    where: { key: LAST_INGEST_KEY },
    create: { key: LAST_INGEST_KEY, value: at.toISOString(), type: 'string', description: 'AI shorts: last ingest run (system)' },
    update: { value: at.toISOString() },
  });
}

export function ingestDue(s: ContentSettings, now: Date): boolean {
  if (!s.ingestEnabled || s.feeds.length === 0) return false;
  if (!s.lastIngestAt) return true;
  return now.getTime() - s.lastIngestAt.getTime() >= s.ingestIntervalMinutes * 60_000;
}
