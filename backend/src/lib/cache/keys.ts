// src/lib/cache/keys.ts
// All Redis cache key patterns for Status Go
// Following strict naming convention: namespace:sub-namespace:params

export const CK = {
  // ── Template lists (invalidated on any admin publish / approval) ──
  templateList: (lang: string, cat: string, type: string, page: number) =>
    `tpl:list:${lang}:${cat}:${type}:${page}`,           // TTL: 20 min (1200s)

  templateById: (id: string) =>
    `tpl:id:${id}`,                                       // TTL: 2 hr (7200s)

  featured:    'tpl:featured',                             // TTL: 1 hr (3600s)
  trending:    'tpl:trending',                             // TTL: 1 hr (3600s)
  newArrivals: 'tpl:new',                                  // TTL: 1 hr (3600s)

  festivalTpls: (festivalId: string) =>
    `tpl:festival:${festivalId}`,                         // TTL: 6 hr (21600s)

  categories:  'categories:all',                           // TTL: 1 hr (3600s)
  appConfig:   'config:all',                               // TTL: 30 min (1800s)
  festivals:   'festivals:upcoming',                       // TTL: 6 hr (21600s)

  // ── Search ────────────────────────────────────────────────────────
  search: (q: string, lang: string, type = 'all') =>
    `search:${lang}:${type}:${Buffer.from(q).toString('base64url').slice(0, 40)}`,
                                                           // TTL: 5 min (300s)
  suggestions: (prefix: string) =>
    `suggest:${prefix.slice(0, 5).toLowerCase()}`,         // TTL: 10 min (600s)

  trendingTerms: 'search:trending',                        // TTL: 1 hr (3600s)

  // ── User-specific (shorter TTL — user data changes) ───────────────
  userProfile: (uid: string) => `user:${uid}`,             // TTL: 10 min (600s)
  userPlan:    (uid: string) => `plan:${uid}`,             // TTL: 15 min (900s)
  userSaved:   (uid: string, page: number) =>
    `saved:${uid}:p${page}`,                              // TTL: 5 min (300s)

  // ── Auth ──────────────────────────────────────────────────────────
  refreshToken:  (uid: string) => `rt:${uid}`,             // TTL: 30 days
  authAttempts:  (email: string) => `auth:${email}`,       // TTL: 15 min
  rateLimit:     (ip: string)   => `rl:${ip}`,             // TTL: 1 min window

  // ── Counter batching (BullMQ flush every 30s) ─────────────────────
  counterBatch: 'counters:tpl',                            // Redis Hash

  // ── Admin stats (invalidate on data change) ───────────────────────
  adminStats: 'admin:stats',                               // TTL: 5 min (300s)
} as const;

// TTL constants (seconds)
export const TTL = {
  templateList:   1200,   // 20 min
  templateById:   7200,   // 2 hr
  featured:       3600,   // 1 hr
  trending:       3600,   // 1 hr
  newArrivals:    3600,   // 1 hr
  festivalTpls:   21600,  // 6 hr
  categories:     3600,   // 1 hr
  appConfig:      1800,   // 30 min
  festivals:      21600,  // 6 hr
  search:         300,    // 5 min
  suggestions:    600,    // 10 min
  trendingTerms:  3600,   // 1 hr
  userProfile:    600,    // 10 min
  userPlan:       900,    // 15 min
  userSaved:      300,    // 5 min
  adminStats:     300,    // 5 min
} as const;
