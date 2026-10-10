// src/lib/cache/keys.ts
// All Redis cache key patterns for Status Go
// Following strict naming convention: namespace:sub-namespace:params
import { createHash } from 'crypto';

/** Stable short hash of a params object / string (keys never embed raw user input). */
export function hashKey(value: unknown): string {
  const input = typeof value === 'string' ? value : JSON.stringify(value);
  return createHash('sha256').update(input).digest('hex').slice(0, 32);
}

export interface TemplateListKeyParams {
  lang?: string;
  categoryId?: string;
  type?: string;
  isPremium?: boolean;
  page: number;
  limit: number;
}

export const CK = {
  // ── Template lists (invalidated on any admin publish / approval) ──
  // Every query param that affects the result is part of the hash.
  templateList: (p: TemplateListKeyParams) =>
    `tpl:list:${hashKey({
      lang: p.lang ?? 'ALL',
      cat: p.categoryId ?? 'ALL',
      type: p.type ?? 'ALL',
      premium: p.isPremium === undefined ? 'ALL' : String(p.isPremium),
      page: p.page,
      limit: p.limit,
    })}`,                                                  // TTL: 20 min (1200s)

  templateById: (id: string) =>
    `tpl:id:${id}`,                                       // TTL: 2 hr (7200s)

  featured:    'tpl:featured',                             // TTL: 1 hr (3600s)
  trending:    'tpl:trending',                             // TTL: 1 hr (3600s)
  newArrivals: (type: string, lang: string, page: number) =>
    `tpl:new:${type}:${lang}:${page}`,                     // TTL: 1 hr (3600s)

  appConfig:       'config:all',                           // TTL: 30 min (1800s)
  publicAppConfig: 'config:public',                        // TTL: 30 min (1800s)
  festivals:   (days: number) => `festivals:upcoming:${days}`, // TTL: 6 hr (21600s)

  // ── Search ────────────────────────────────────────────────────────
  search: (params: { q: string; lang: string; type: string; page: number; limit: number }) =>
    `search:q:${hashKey(params)}`,                         // TTL: 5 min (300s)
  suggestions: (prefix: string) =>
    `suggest:${hashKey(prefix.trim().toLowerCase())}`,     // TTL: 10 min (600s)

  trendingTerms: 'search:trending',                        // TTL: 1 hr (3600s)

  // ── User-specific (shorter TTL — user data changes) ───────────────
  userProfile: (uid: string) => `user:${uid}`,             // TTL: 10 min (600s)
  userPlan:    (uid: string) => `plan:${uid}`,             // TTL: 15 min (900s)
  userSaved:   (uid: string, page: number, limit: number) =>
    `saved:${uid}:p${page}:l${limit}`,                    // TTL: 5 min (300s)
  userSavedPattern: (uid: string) => `saved:${uid}:*`,

  // ── Auth ──────────────────────────────────────────────────────────
  refreshToken:  (uid: string) => `rt:${uid}`,             // TTL: 30 days

  // ── Admin stats (invalidate on data change) ───────────────────────
  adminStats: 'admin:stats',                               // TTL: 5 min (300s)

  // ── Home feed (personalised, region-aware) ────────────────────────
  homeFeed: (state: string, lang: string) =>
    `home:feed:${hashKey({ state, lang })}`,               // TTL: 5 min (300s)
} as const;

// TTL constants (seconds)
export const TTL = {
  templateList:   1200,   // 20 min
  templateById:   7200,   // 2 hr
  featured:       3600,   // 1 hr
  trending:       3600,   // 1 hr
  newArrivals:    3600,   // 1 hr
  appConfig:      1800,   // 30 min
  festivals:      21600,  // 6 hr
  search:         300,    // 5 min
  suggestions:    600,    // 10 min
  trendingTerms:  3600,   // 1 hr
  userProfile:    600,    // 10 min
  userPlan:       900,    // 15 min
  userSaved:      300,    // 5 min
  adminStats:     300,    // 5 min
  homeFeed:       300,    // 5 min
} as const;
