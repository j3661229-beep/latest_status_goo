# Status Go — Remediation Report

Branch `feat/ai-shorts` (HEAD `63b526a`), date 2026-10-16. Nothing was committed, pushed, merged or deployed.

> **`STATUS_GO_AUDIT_REPORT.md` does not exist in this repository** (searched the whole tree; only `PROJECT_AUDIT.md`
> exists). I therefore could not verify the report's own claims. Instead I independently verified every topic named in the
> remediation brief, plus `PROJECT_AUDIT.md`. If you have the original audit file, send it and I will reconcile line by line.

## 1. Findings

| # | Finding | Status | Evidence |
|---|---|---|---|
| 1 | Firebase package mismatch | **Confirmed, open (needs decision)** | `applicationId`/`namespace`/Kotlin dir/Play URL = `com.statusgo.status_go`; `google-services.json` = `com.statusgoo.enpoi` (Firebase project `status-goo-app`). The file also has **no Android OAuth client (type 1) / no SHA-1**, so Google Sign-In fails even with a matching package. `mobile/tool/check_release_ready.sh` fails on this. |
| 2 | Prisma migration history incomplete | **Confirmed → FIXED** | Only `20261015000000_ai_shorts` existed; CI used `db push`. Baseline added (see §4). |
| 3 | Test isolation (maintenance test) | **Confirmed → FIXED** | `@prisma/client` auto-loads `backend/.env` on import; real `CONTENT_SOURCE_HOSTS` leaked into the test. Pinned in `vitest.config.ts` + `vi.stubEnv` in the test. 191/192 → **192/192** pass. |
| 4 | ESLint not configured | **Confirmed → FIXED** | No `.eslintrc*` anywhere (`next lint` would prompt interactively). Committed configs added; all three lint commands exit 0 with `CI=true`. |
| 5 | Release placeholders | **Confirmed, open (owner data)** | `app_constants.dart` lines 52–62 (see §6). `check_release_ready.sh` fails on them. Not invented. |
| 6 | Tracked env files | **Checked — acceptable** | Only `.env.example` and `*/.env.production` are tracked. The two `.env.production` files contain only `NEXT_PUBLIC_*` values (API URL, public Google client id, `SHOW_DEMO_LOGIN=false`). `backend/.env` is git-ignored and not tracked. |
| 7 | PostgreSQL extensions | **Confirmed → FIXED in migration** | `pg_trgm` (used by search `similarity()`) was created only by `docker/init.sql`. Now in the baseline migration. `unaccent` is created by `init.sql` but **not used by any code**, so it was not added; dev DB also lacks it. |
| 8 | Worker health | **Confirmed, open** | Redis reachable (PING ok) but no `content:worker:heartbeat` key → no worker running. Dev DB has a video stuck in `SOURCE_VERIFIED` with a SCRIPT job left `RUNNING` by my failed run (see §5). |
| 9 | Git working tree | Dirty (expected) | 18 modified + new files, all uncommitted; two generated `tsbuildinfo` files were reverted. |
| 10 | "FFmpeg unavailable / no MP4" claim | **Stale (partly) / still no end-to-end proof** | FFmpeg was indeed missing at the start; I installed ffmpeg 9.0.2 (libx264 + libass) and a Devanagari font under `D:\tools`, and the toolchain smoke render now passes (1080×1920, 23.5 s, h264+aac, Hindi renders). **But no real generation has succeeded**: the latest real attempt failed at the first Vertex AI call (permission). No generated MP4 exists and no `videoKey` in the DB. |
| 11 | Camera permission (`PROJECT_AUDIT` M-M1) | Requires device evidence | Manifest has no `CAMERA`; image-picker camera uses the system capture intent which does not need it. Not changed. |

## 2. Files changed

| File | Reason |
|---|---|
| `backend/vitest.config.ts`, `backend/test/maintenance.test.ts` | Stop developer `.env` leaking into tests. |
| `backend/.eslintrc.json`, `backend/package.json`, `package-lock.json` | Backend ESLint (TypeScript) config; declared `eslint` and `@typescript-eslint/*` (already installed transitively, versions unchanged) so `npm ci` is explicit. |
| `admin-dashboard/.eslintrc.json`, `creator-dashboard/.eslintrc.json` | `next/core-web-vitals`; `react/no-unescaped-entities` off (stylistic only; React renders those characters correctly). 6 and 5 a11y/`<img>` warnings remain. |
| `backend/prisma/migrations/20260101000000_baseline/migration.sql`, `migration_lock.toml` | Baseline for fresh databases + `pg_trgm`. |
| `.github/workflows/ci.yml` | `migrate deploy` instead of `db push`; schema-drift check (`migrate diff --exit-code`); lint steps; new creator-dashboard job. |
| `backend/src/lib/content/render.ts` | Bug: `-shortest` cut the video at the narration end, so the **source-attribution end card never played**; and ASS `Events` Format had `Name,Style` swapped so captions used libass's tiny default style. |
| `backend/src/lib/content/safe-fetch.ts` | Bug: pinned DNS `lookup` ignored `{all:true}` (Node ≥ 20) → **every real fetch failed** with "Invalid IP address". Pinning/SSRF checks unchanged. |
| `backend/src/lib/content/autopublish.ts`, `settings.ts`, `maintenance.ts`, `test/autopublish.test.ts`, admin `content/page.tsx` | Opt-in auto-publish (**OFF by default; not enabled**), earlier this session. |
| `queue.ts`, `content.worker.ts`, `content.admin.route.ts`, admin `lib/api.ts`, `docker-compose.yml`, `docs/ai-shorts.md` | Worker heartbeat + `/admin/content/health` + dashboard banner, local worker service, docs. |
| `mobile/.../shorts_screen.dart`, `profile_screen.dart` | Feed refresh on resume / load-more retry; profile stale-data banner with retry. |
| `backend/scratch/e2e-*.ts` | Untracked helper scripts for the first real run (no secrets). Delete or keep at your discretion. |

Local-only (not in git): `backend/.env` gained `FFMPEG_PATH`, `FFPROBE_PATH`, `CONTENT_FONTS_DIR`, `CONTENT_FONT_NAME` (names only; no secrets).

## 3. Commands and real results (sanitized)

| Command | Result |
|---|---|
| `cd backend && npx vitest run` | 13 files passed, **192 passed**, 9 skipped (integration needs `INTEGRATION_DATABASE_URL`) |
| `INTEGRATION_DATABASE_URL=<scratch> npx vitest run test/integration` | **9/9 passed** (real Postgres, scratch DB only) |
| `cd backend && npx tsc --noEmit` / admin / creator | exit 0 / 0 / 0 |
| `npm run lint` (backend) | exit 0 — 0 errors, 3 warnings (unused vars) |
| `CI=true npx next lint` admin / creator | exit 0 — 0 errors, 6 / 5 warnings |
| `npx next build` admin / creator | both exit 0 |
| `flutter analyze` / `flutter test` | no issues / **361 passed** |
| `npx prisma validate` | valid |
| `npx tsx --env-file=.env scripts/content-smoke.ts` | OK 1080×1920 23.5 s; frames inspected: title, captions, brand and end card all render; Devanagari conjuncts correct. Cosmetic: Latin text in the end card appears larger (font has no Latin glyphs). |
| Secret scan of changed/new files | clean (one hit: the pre-existing local-only dev Redis password in `docker-compose.yml`) |

## 4. Database migration safety evidence

- Throwaway Postgres 18.4 cluster started on `127.0.0.1:55432` in `D:\tools`, separate from your local server on 5432. **The Supabase dev database was only read** (schema introspection); nothing was applied, reset or altered. The throwaway server was stopped afterwards.
- Baseline = schema at commit `5c976f0` via `prisma migrate diff --from-empty` (13 tables, 9 enums) + `CREATE EXTENSION IF NOT EXISTS pg_trgm`. Existing `ai_shorts` migration untouched.
- Empty DB `fresh_test`: `prisma migrate deploy` applied both migrations; `migrate status` = up to date.
- `prisma migrate diff --from-url fresh_test --to-schema-datamodel schema.prisma` → **empty (identical)**.
- Same diff against the **existing dev DB** → **empty (identical)**. Fresh and dev schemas are the same. Differences that remain are operational only: dev has **no `_prisma_migrations` table** (built with `db push`) and lacks the unused `unaccent` extension (`pg_trgm` is present there).
- Fresh DB: 21 tables + `_prisma_migrations`, 19 foreign keys, `pg_trgm` works (`similarity('kisan','kisaan') = 0.625`).
- Seed on a second empty migrated DB: 5 users, 8 categories, 14 templates, 8 config rows, 10 festivals (seed needs `SEED_ADMIN_PASSWORD` or generates one; refuses `NODE_ENV=production` without `FORCE_SEED`).
- **Not applied to dev (needs your approval):** to adopt migrations on the existing databases run, once per environment, `prisma migrate resolve --applied 20260101000000_baseline` then `--applied 20261015000000_ai_shorts`. This only records history; it executes no SQL. Do **not** `migrate deploy` the baseline on an existing database.

## 5. Real AI Shorts verification — NOT complete

Source verified: News On AIR (All India Radio) article "Over 1000 cr approved for setting up of five ITI clusters…", page time "October 16, 2026 4:50 PM" (IST = 11:20 UTC). Server clocks (Google, newsonair) read 11:42 GMT when the story was fetched, so it was ~22 minutes old. The **PC clock is ~5.5 h behind real time** (shows 11:42 labelled IST = 06:12 UTC); the runner takes "now" from the server `Date` header.

| Stage | Result |
|---|---|
| Source fetch via SSRF-guarded fetcher (allowlisted host) | OK (after the `safe-fetch.ts` fix) |
| NewsStory + draft recorded in dev DB | OK — story `cmvakkwfo0000qaeina70cdwq`, video `cmvakkxmy0002qaeija2nhlvi` |
| Script (Vertex AI Gemini) | **FAILED** — `aiplatform.endpoints.predict` denied |
| GCS bucket access | **FAILED** — `storage.buckets.get` / `storage.objects.list` denied |
| TTS | Not tested (blocked by identity; no client probe possible) |
| Render, upload, signed-URL retrieval, DB lifecycle to `NEEDS_REVIEW`, admin queue | **Not run** |

Cause: ADC is signed in as an account (`statusgo007@gmail.com`) that has **no IAM roles** on the project; the project owner is `sarangtawde0@gmail.com`. No mocks were substituted. Current dev-DB state: video `SOURCE_VERIFIED`, one SCRIPT job still `RUNNING` (left by the failed run; the pipeline treats it as stale after 6 minutes and will re-run it). The scheme video is blocked separately: no fetchable, verifiable official scheme page (`pmkisan.gov.in` serves an incomplete TLS chain whose root Node does not trust — I did not weaken TLS; myScheme is browser-rendered; MyGov/PIB return 403).

Auto-publish: **disabled** (setting absent → default off; code path off by default). Nothing is published.

## 6. Security and release blockers

1. **Android package/Firebase mismatch + missing SHA-1** (Google Sign-In and Firebase Phone Auth cannot work on a device). Not testable until fixed.
2. **Owner placeholders** in `mobile/lib/core/constants/app_constants.dart`: `supportEmail`, `supportPhone` (`+91 00000 00000`), `supportWhatsappNumber`, `companyName`, `companyAddress`, `grievanceOfficerName`, `grievanceOfficerEmail`, `websiteUrl`, `privacyUrl`, `termsUrl`, `refundUrl` (all `TODO(owner)`). The legal screens interpolate these, so they would show "TODO" text. Release also needs `--dart-define=RAZORPAY_KEY_ID=rzp_live_…` (default is a test key).
3. **Test OTP / demo login** must be off in production (`ALLOW_TEST_OTP` is set in the local `.env`; `NEXT_PUBLIC_SHOW_DEMO_LOGIN=false` is correct in both `.env.production` files).
4. **Prefer ADC / managed identity over `GCS_SA_KEY_JSON`** (empty locally — good). `TRUST_PROXY` is not set; behind Cloud Run set it (e.g. `1`) or rate limiting keys on the proxy IP.
5. **Always-on worker** required in production; currently none running (no heartbeat).
6. `OneSignal`, `Sentry` keys empty locally — push and monitoring are not configured. Cloudflare R2/Stream keys empty (unused by shorts).
7. Production API URL exists in `.env.production` (Cloud Run); I made no production calls.
8. Public-access prevention on the GCS bucket is "inherited", not "enforced" — consider enforcing it.

## 7. Remaining manual actions

1. **Decide the Android package** (options below), register that app in Firebase project `status-goo-app` with the SHA fingerprints, download the new `google-services.json`.
   - **A (recommended): keep `com.statusgo.status_go`** — matches Gradle, Kotlin package, Play URL and iOS; no code change. Debug SHA-1 `FB:F6:15:0B:41:97:7D:CE:11:A1:5B:24:B8:F1:D6:CB:ED:10:5E:7C`, SHA-256 `90:C3:7A:FC:C0:A5:90:31:6D:9A:87:0A:DA:EC:33:5F:09:15:EC:AA:86:60:74:D3:54:71:FA:24:8C:FF:09:8E` (public fingerprints); add your **release/upload key** fingerprints too, and Play App Signing's if used.
   - **B: switch to `com.statusgoo.enpoi`** — requires changing `applicationId`, `namespace`, the Kotlin package directory and the Play URL, and is permanent once published.
   - Only choose B if `com.statusgoo.enpoi` was already published or is the intended permanent ID.
2. **Fix Google auth** for the pipeline: `gcloud auth application-default login` as the owner account, *or* grant the ADC identity `roles/aiplatform.user`, `roles/storage.objectAdmin` on the bucket, `roles/serviceusage.serviceUsageConsumer` and `roles/iam.serviceAccountTokenCreator` on itself (for signed URLs). I changed no IAM.
3. **Fix the PC clock** (auto time/zone, or `w32tm /resync` as admin).
4. Then rerun: `cd backend && npx tsx --env-file=.env scratch/e2e-news.ts <article url>`, and verify GCS upload/retrieval, DB state `NEEDS_REVIEW`, and the admin review queue.
5. Provide a scheme source (facts from the official page, or approve a host/CA decision) for the scheme video.
6. Fill the owner placeholders (§6.2). Approve running `migrate resolve --applied` on dev/prod.
7. Start an always-on worker (`docker compose --profile worker …` or Cloud Run min-instances=1).

## 8. Decision: **NO-GO**

Evidence for: builds, type checks, lint, 192 backend + 9 integration + 361 Flutter tests pass; fresh-database migration is proven identical to the schema and to dev; two real pipeline bugs fixed.
Evidence against: Android Google/Phone auth cannot work (package + SHA-1); no real AI-shorts generation has completed (Vertex/GCS permissions) — **end-to-end is not verified**; owner legal/contact placeholders are still `TODO`; no worker is running; monitoring/push not configured. Re-evaluate after §7 items 1–3 and 6.
