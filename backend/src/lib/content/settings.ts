// src/lib/content/settings.ts
// Operator-tunable content settings, stored in AppConfig (`content.*`) so admins can change the
// schedule without a deploy. Everything defaults to safe options. News from trusted sources is
// auto-published directly, while Schemes always require explicit admin approval.
import { z } from 'zod';
import type { PrismaClient } from '@prisma/client';

export interface FeedConfig {
  name: string;
  url: string;
  category: string;
  region?: string | null; // e.g. 'UP', 'MH', 'MP', 'RJ', 'BR', 'GJ', 'DL', 'PB' or null for national
  isRegional?: boolean;
}

export interface ContentSettings {
  ingestEnabled: boolean;
  ingestIntervalMinutes: number;
  autoPublishEnabled: boolean;
  autoPublishSchemes: boolean;
  autoPublishMaxPerDay: number;
  maxNewVideosPerRun: number;
  newsStaleHours: number;
  newsAutoExpireHours: number; // 0 = never auto-expire published news
  schemeVerifyMaxAgeDays: number;
  developingFreshHours: number;
  feeds: FeedConfig[];
  lastIngestAt: Date | null;
}

export const DEFAULT_FEEDS: FeedConfig[] = [
  // ── Top National News (Hindi & English Trusted Sources) ───────────────────────
  { name: 'Google News (Hindi Top)', url: 'https://news.google.com/rss?hl=hi&gl=IN&ceid=IN:hi', category: 'TOP_NEWS', region: null, isRegional: false },
  { name: 'Google News (National)', url: 'https://news.google.com/rss/headlines/section/topic/NATION?hl=hi&gl=IN&ceid=IN:hi', category: 'TOP_NEWS', region: null, isRegional: false },
  { name: 'Amar Ujala (Breaking)', url: 'https://www.amarujala.com/rss/breaking-news.xml', category: 'TOP_NEWS', region: null, isRegional: false },
  { name: 'PIB National (Govt Verified)', url: 'https://pib.gov.in/RssMain.aspx?ModId=6&LangId=2', category: 'TOP_NEWS', region: null, isRegional: false },

  // ── Regional News (State-wise trusted news feeds) ──────────────────────────────
  { name: 'उत्तर प्रदेश (UP Regional)', url: 'https://news.google.com/rss/search?q=Uttar+Pradesh&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'UP', isRegional: true },
  { name: 'महाराष्ट्र (MH Regional)', url: 'https://news.google.com/rss/search?q=Maharashtra&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'MH', isRegional: true },
  { name: 'मध्य प्रदेश (MP Regional)', url: 'https://news.google.com/rss/search?q=Madhya+Pradesh&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'MP', isRegional: true },
  { name: 'राजस्थान (RJ Regional)', url: 'https://news.google.com/rss/search?q=Rajasthan&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'RJ', isRegional: true },
  { name: 'बिहार (BR Regional)', url: 'https://news.google.com/rss/search?q=Bihar&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'BR', isRegional: true },
  { name: 'गुजरात (GJ Regional)', url: 'https://news.google.com/rss/search?q=Gujarat&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'GJ', isRegional: true },
  { name: 'दिल्ली (DL Regional)', url: 'https://news.google.com/rss/search?q=Delhi&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'DL', isRegional: true },
  { name: 'पंजाब (PB Regional)', url: 'https://news.google.com/rss/search?q=Punjab&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'PB', isRegional: true },
  { name: 'हरियाणा (HR Regional)', url: 'https://news.google.com/rss/search?q=Haryana&hl=hi&gl=IN&ceid=IN:hi', category: 'REGIONAL', region: 'HR', isRegional: true },
];

export const DEFAULTS: ContentSettings = {
  ingestEnabled: true,
  ingestIntervalMinutes: 60,
  autoPublishEnabled: true,
  autoPublishSchemes: false, // Schemes require explicit admin approval!
  autoPublishMaxPerDay: 50,
  maxNewVideosPerRun: 20,
  newsStaleHours: 48,
  newsAutoExpireHours: 72,
  schemeVerifyMaxAgeDays: 90,
  developingFreshHours: 1,
  feeds: DEFAULT_FEEDS,
  lastIngestAt: null,
};

const KEYS = {
  ingestEnabled: 'content.news_ingest_enabled',
  ingestIntervalMinutes: 'content.news_ingest_interval_minutes',
  autoPublishEnabled: 'content.auto_publish_enabled',
  autoPublishSchemes: 'content.auto_publish_schemes',
  autoPublishMaxPerDay: 'content.auto_publish_max_per_day',
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
    autoPublishEnabled: z.boolean(),
    autoPublishSchemes: z.boolean(),
    autoPublishMaxPerDay: z.number().int().min(0).max(100),
    maxNewVideosPerRun: z.number().int().min(0).max(50),
    newsStaleHours: z.number().int().min(1).max(720),
    newsAutoExpireHours: z.number().int().min(0).max(2160),
    schemeVerifyMaxAgeDays: z.number().int().min(7).max(730),
    developingFreshHours: z.number().int().min(1).max(24),
    feeds: z
      .array(z.object({
        name: z.string().trim().min(2).max(80),
        url: z.string().url().max(2048).refine((u) => u.startsWith('https://'), 'Feed URL must use https'),
        category: z.string().trim().min(2).max(64),
        region: z.string().trim().max(16).nullish(),
        isRegional: z.boolean().optional(),
      }))
      .max(50),
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
    const raw = get(KEYS.feeds);
    const parsed = raw ? JSON.parse(raw) : [];
    feeds = Array.isArray(parsed) && parsed.length > 0
      ? parsed.filter((f) => f && typeof f.url === 'string' && typeof f.name === 'string').map(f => ({
          name: f.name,
          url: f.url,
          category: f.category || (f.isRegional ? 'REGIONAL' : 'TOP_NEWS'),
          region: f.region || null,
          isRegional: !!f.isRegional,
        }))
      : DEFAULT_FEEDS;
  } catch {
    feeds = DEFAULT_FEEDS;
  }
  const last = get(LAST_INGEST_KEY);
  return {
    ingestEnabled: bool(get(KEYS.ingestEnabled), DEFAULTS.ingestEnabled),
    ingestIntervalMinutes: int(get(KEYS.ingestIntervalMinutes), DEFAULTS.ingestIntervalMinutes, 15),
    autoPublishEnabled: bool(get(KEYS.autoPublishEnabled), DEFAULTS.autoPublishEnabled),
    autoPublishSchemes: bool(get(KEYS.autoPublishSchemes), DEFAULTS.autoPublishSchemes),
    autoPublishMaxPerDay: int(get(KEYS.autoPublishMaxPerDay), DEFAULTS.autoPublishMaxPerDay, 0),
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


export function ingestDue(settings: ContentSettings, now = new Date()): boolean {
  if (!settings.ingestEnabled) return false;
  if (!settings.lastIngestAt) return true;
  const elapsedMinutes = (now.getTime() - settings.lastIngestAt.getTime()) / 60000;
  return elapsedMinutes >= settings.ingestIntervalMinutes;
}
