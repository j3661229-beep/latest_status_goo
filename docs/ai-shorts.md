# AI Shorts — Sarkari Yojana & Daily News

Hindi short-video explainers for government schemes/scholarships and daily news, generated from
**cited source material**, reviewed by a human, then published to the app's **Shorts** tab.

> By default nothing is published automatically: every video passes `NEEDS_REVIEW → APPROVED → PUBLISHED`
> through an authenticated MANAGER / SUPER_ADMIN. Creators have no access.
> **Optional hands-off mode** (Admin → Yojana & News → Schedule → *Auto-publish*, off by default, see §6a) lets the
> worker publish items that pass every gate; anything with a warning, report or failed check stays in review.

## 1. Architecture

```
 admin enters scheme ──┐                      ┌── Flutter "Shorts" tab (news / yojana / saved)
 RSS feeds (allowlist) ┤                      │   GET /schemes /news /shorts  (published only)
                       ▼                      │
              safe-fetch (SSRF guard)         │
                       ▼                      │
 SCRIPT ─► NARRATION ─► RENDER ─► NEEDS_REVIEW ─► APPROVED ─► PUBLISHED ─► (EXPIRED | CORRECTION_REQUIRED | UNPUBLISHED)
 Gemini     Google TTS   ffmpeg     │  admin dashboard: preview, edit, claims-vs-sources, audit trail
 (Vertex)   (hi-IN)      + GCS      │
                                    ▼
        BullMQ worker  ── maintenance tick every 5 min: ingest (if due) · expire · reject stale · corrections · reminders
```

| Piece | Location |
|---|---|
| Schema + migration | `backend/prisma/schema.prisma`, `backend/prisma/migrations/20261015000000_ai_shorts/` |
| Lifecycle, publish gates, warnings | `backend/src/lib/content/{lifecycle,warnings}.ts` |
| Pipeline (script, TTS, render, stages) | `backend/src/lib/content/{script,tts,render,pipeline,assets,config}.ts` |
| Safe retrieval / RSS ingestion | `backend/src/lib/content/{safe-fetch,ingest}.ts` |
| Scheduling / freshness | `backend/src/lib/content/{maintenance,freshness,settings,queue}.ts`, `backend/src/workers/content.worker.ts` |
| Public API | `backend/src/modules/shorts/` |
| Admin API | `backend/src/modules/content-admin/` |
| Admin UI | `admin-dashboard/app/(dashboard)/content/page.tsx` |
| Mobile | `mobile/lib/features/shorts/` (+ route/tab in `core/router/`) |

## 2. What you must configure (nothing is pre-configured)

### Google Cloud (Application Default Credentials — no key files)
1. Enable **Vertex AI API** and **Cloud Text-to-Speech API**; billing must be on.
2. The runtime identity (Cloud Run service account / `gcloud auth application-default login` locally) needs:
   - `roles/aiplatform.user` (Gemini on Vertex)
   - `roles/storage.objectAdmin` on the content bucket (or a custom role with create/get)
   - `roles/iam.serviceAccountTokenCreator` **on itself** so it can sign V4 URLs without a key file
3. Keep the `content/` prefix **private** (no `allUsers` reader). Delivery is via 6-hour signed URLs.
   In production, if signing fails the API returns no video URL (fails closed) unless you explicitly set
   `CONTENT_ALLOW_PUBLIC_FALLBACK=true`.

### Environment variables (see `backend/.env.example` for the full annotated list)
| Variable | Purpose | Default |
|---|---|---|
| `CONTENT_PIPELINE_ENABLED` | worker runs the pipeline + maintenance tick | `false` |
| `CONTENT_SOURCE_HOSTS` | comma list of hosts (+subdomains) the pipeline may fetch. **Empty = fetch nothing.** | empty |
| `GCS_PROJECT_ID`, `GCS_BUCKET_NAME` | project / bucket (existing vars) | — |
| `CONTENT_VERTEX_LOCATION`, `CONTENT_SCRIPT_MODEL` | Gemini location / model | `asia-south1`, `gemini-2.5-flash` |
| `CONTENT_TTS_VOICE` | Hindi voice | `hi-IN-Neural2-A` |
| `FFMPEG_PATH`, `FFPROBE_PATH` | binaries (libx264 + libass) | `ffmpeg`, `ffprobe` |
| `CONTENT_FONTS_DIR`, `CONTENT_FONT_NAME` | a Devanagari font (e.g. Noto Sans Devanagari) | — |
| `CONTENT_MAX_JOBS_PER_DAY` / `_MAX_INGEST_PER_DAY` / `_MAX_CONCURRENT_RENDERS` / `_MAX_ATTEMPTS` | spend and load limits | 60 / 40 / 1 / 3 |
| `CONTENT_MAX_NARRATION_SEC` / `_MAX_OUTPUT_BYTES` / `_MAX_SOURCE_CHARS` | per-video limits | 40 / 25 MB / 20 000 |
| `CONTENT_MONTHLY_BUDGET_USD`, `CONTENT_BUDGET_ALERT_RATIO` | hard stop / warning threshold | 20 / 0.8 |
| `CONTENT_PRICE_*` | **price estimates** used for cost tracking | see `.env.example` |
| `CONTENT_ALLOW_PUBLIC_FALLBACK` | allow unsigned CDN URLs in production | unset |

Schedule settings (interval, on/off, feeds, stale/expiry windows, drafts per run) live in the database and are
edited in **Admin → Yojana & News → Schedule**; no redeploy needed.

### Sources — read this before adding any
There is no per-site scraper. Content enters through (a) schemes entered/verified by an admin, and
(b) feeds an admin adds to the allowlist. I checked on 2026-10-15: `myscheme.gov.in/robots.txt` allows crawling but has no documented API
or reuse licence; `pib.gov.in` returned HTTP 403 to an automated fetch; `scholarships.gov.in` has no `robots.txt`.
**Robots permission is not a reuse licence.** Confirm each source's terms (automated retrieval, summarisation,
attribution) before adding its host to `CONTENT_SOURCE_HOSTS`.

## 3. Database
The repo previously used `prisma db push` and had no `migrations/` folder. The new migration is **additive only**
(new enums/tables/indexes/foreign keys on new tables; no existing table is altered). It was verified to apply cleanly
on top of the previous schema and to match the Prisma schema exactly.
```bash
# Option A (matches the repo's previous workflow): apply the schema
npx prisma db push                       # review the plan first; this migration is purely additive
# Option B: apply the SQL file yourself
psql "$DIRECT_DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/prisma/migrations/20261015000000_ai_shorts/migration.sql
# If you adopt `prisma migrate deploy`, baseline the existing DB first:
npx prisma migrate resolve --applied 20261015000000_ai_shorts   # only AFTER one of the above
```

## 4. Run it locally
```bash
docker compose up -d                      # postgres + redis
cd backend && cp .env.example .env        # fill JWT secrets etc. (never commit .env)
npx prisma db push && npx tsx prisma/seed.ts
# toolchain check — no cloud calls, no spend (needs ffmpeg + a Devanagari font):
FFMPEG_PATH=... CONTENT_FONTS_DIR=... npx tsx scripts/content-smoke.ts   # writes content-smoke.mp4 / .jpg; inspect the Hindi text
# API (terminal 1) and worker (terminal 2)
npm run dev
CONTENT_PIPELINE_ENABLED=true CONTENT_SOURCE_HOSTS="" gcloud auth application-default login && npm run worker
# dashboard: cd ../admin-dashboard && npm run dev    (login as the seeded SUPER_ADMIN)
```

## 5. Generate and review your first video
1. **Admin → Yojana & News**. Create a scheme (API: `POST /api/v1/admin/content/schemes`) with the official name, Hindi name, benefits,
   eligibility, documents, steps, application URL and **official source URLs** — copied from the official page.
2. `POST /admin/content/schemes/:id/verify` — you attest the details match the official source (sets *last verified*).
3. `POST /admin/content/drafts` `{kind:"SCHEME", schemeId, title, category}` then `POST /admin/content/generate` `{shortVideoId}`.
4. The worker runs SCRIPT → NARRATION → RENDER (watch **Jobs**). The item lands in **Needs Review**.
5. Open it: check the warnings, each **claim vs its quoted source**, watch the video, listen to the narration; edit if needed
   (editing the script/captions discards the render and requires regeneration).
6. **Approve → Publish** (or *Schedule*). It appears in the app's Shorts tab. Use **Correct / Unpublish / Expire** any time.

News: add a permitted feed in **Schedule** (and its host to `CONTENT_SOURCE_HOSTS`), enable ingestion, or press *Run ingest now*.

## 6. Scheduled jobs in production
The API image (`backend/Dockerfile`) runs only `dist/server.js`. **Schedules and generation need an always-on worker**:
build `backend/Dockerfile.worker` (adds ffmpeg + Noto Devanagari) and run ≥1 instance continuously with
`CONTENT_PIPELINE_ENABLED=true` (Cloud Run: min-instances=1 and CPU always allocated; or a VM/GKE). A scale-to-zero service silently stops schedules.
Exactly one repeatable `content-tick` job exists (fixed job id) and a Redis lock prevents overlapping runs, so extra worker replicas are safe.
The API server never registers schedules.

## 6a. Hands-off mode (auto-publish)
Off by default. When enabled, each 5-minute tick publishes `NEEDS_REVIEW` items **only if** all of these hold: video, thumbnail,
attribution and source-referenced claims exist; the scheme is verified (scheme videos are auto-published only if *Also auto-publish
scheme videos* is ticked; otherwise news only); the news source was re-checked recently (1h developing / 6h otherwise), is not stale,
withdrawn or developing; the item has no editorial warnings (including generator uncertainty notes) and no user reports; and the rolling
24h cap (*Max auto-published per 24h*, default 10) isn't reached. Everything else waits for a person. Each auto-publish is recorded
as actor `system` (ContentReview `auto_publish` + AuditLog). **Pause:** untick the switch — takes effect on the next tick. **Undo:** Unpublish.
Freshness safeguards keep running (auto-expire, source re-checks, take-down on changed/withdrawn sources).
The dashboard shows a worker-health banner (`GET /admin/content/health`): worker heartbeat, failed jobs in 24h, videos stuck generating.
Local worker: `docker compose --profile worker up -d --build worker`.

## 7. API
Public (JWT; GET list/detail also work as guest): `GET /api/v1/shorts|schemes|news` (`kind`, `category`, `region`, `page`, `limit≤30`),
`GET /shorts/:id` (text alternative, sources, related), `POST /shorts/:id/events|report|bookmark`, `DELETE /shorts/:id/bookmark`, `GET /shorts/bookmarks/list`.
Admin (`MANAGER`/`SUPER_ADMIN`, prefix `/api/v1/admin/content`): `review-queue`, `status-counts`, `:id`, `PATCH :id`, `generate`, `approve`, `reject`, `publish`,
`unpublish`, `expire`, `correct`, `request-review`, `retry`, `recheck`, `jobs`, `jobs/:id/cancel`, `costs`, `reports`, `reports/:id/resolve`, `schemes`, `schemes/:id/verify`,
`drafts`, `settings` (GET/PUT), `ingest/run`, `attention`, `health`.

## 8. Safeguards in the code
- **No unsupported claims:** a script is rejected unless every claim quotes its source verbatim, every number appears in the sources, no link is invented, nothing promises a benefit, and it is Hindi. No source text → the model is never called (no general-knowledge news).
- **Gates:** publishing needs approval + video + thumbnail + attribution + claims + (scheme) verified sources / (news) a recent source re-check (1h for developing stories, 6h otherwise) and a non-stale, non-withdrawn story.
- **Concurrency/idempotency:** optimistic status guards, deterministic job ids, per-version audio cache, duplicate events/reports/bookmarks are no-ops.
- **SSRF:** https-only, host allowlist, public IPs only, connection pinned to the vetted address, redirect re-validation, size/time/type limits. No end-user input is ever fetched.
- **Freshness:** auto-reject stale unpublished news, auto-expire old news, take down on source 404/410 or changed headline, daily review reminders.
- **Audit:** every decision → `ContentReview` + `AuditLog`; system actions use actor `system`.

## 9. Cost model (estimates — verify against current provider pricing)
Assumptions per ~32 s video: ~2.7k input / ~0.8k output tokens at the configured Gemini rates, ~350 characters of narration at the configured TTS rate, ~32 s render compute.

| Item | Assumed price | ≈ per video |
|---|---|---|
| Script (text model) incl. ~30 % retry | $0.30 / $2.50 per M tokens in/out | $0.0037 |
| Hindi TTS | $16 per M chars | $0.0056 |
| Render compute | $0.00002 / s | $0.0006 |
| Storage | $0.02 / GB-month | < $0.0001 |
| **Total** | | **≈ $0.01 (~₹0.9)** |

At the default cap of 40 generated videos/day this is roughly **$12/month**, within the default `$20` budget. Delivery (egress) is *not* in the app's tracking:
if a video is ~1.5 MB (measure yours with the smoke script) and egress is ~$0.12/GB, ≈ **$0.18 per 1 000 views**. Update `CONTENT_PRICE_*` when prices change; the dashboard shows tracked cost per published video and per 1 000 views.

## 10. Tests
```bash
cd backend && npx vitest run                                   # unit/route/pipeline tests (mocked providers)
INTEGRATION_DATABASE_URL=postgresql://…/scratch npx vitest run test/integration   # real Postgres — DELETES content rows; use a scratch DB
cd mobile && flutter analyze && flutter test
cd admin-dashboard && npx tsc --noEmit && npx next build
```

## 11. Known limitations / before production
See the final report in the pull request description. Highlights: real Gemini/TTS/ffmpeg/GCS calls are untested here; Hindi glyph rendering needs the smoke check;
category values entered by admins must match the app's chips; no push notifications for reminders; headline-change detection can over-trigger; the mobile feed has no Wi-Fi-only mode.
