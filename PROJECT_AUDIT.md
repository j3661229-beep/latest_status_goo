# Status Go — Complete Project Audit

**Date:** 13 October 2026  
**Scope:** Full monorepo (`backend`, `mobile`, `admin-dashboard`, `creator-dashboard`, `website`) plus device logcat from a OnePlus CPH2661 (Android 16 / API 36) crash session.  
**Verdict:** Feature-complete MVP with a real product surface (auth, feed, editor, payments, admin/creator). **Not production-stable.** The Home video feed currently crashes the Flutter renderer during swipe, and several backend/config issues can break sessions and payments under failure.

---

## 1. Executive summary

Status Go is a daily status-maker for Indian users: Flutter Android app, Fastify API, Next.js admin and creator consoles, static marketing site. The architecture is coherent (JWT + Redis sessions, Razorpay, Cloudinary, OneSignal, Riverpod + GoRouter).

What is blocking users **right now** is not missing features. It is a crash cascade on the Home vertical video feed, confirmed by the logcat in this session:

1. `SliverGeometry is not valid: layoutExtent exceeds paintExtent`
2. `Null check operator used on a null value`
3. `!semantics.parentDataDirty` (repeated, cascading)
4. ExoPlayer (`AndroidXMedia3/1.5.1`) release while the decoder is still full

Fix the Home feed video lifecycle **before** more product work. Then close P1 security/config gaps (Redis fallback, Razorpay placeholder secrets, package-id mismatch, committed env files). Automated tests are effectively absent across the stack.

| Severity | Count | Meaning |
|----------|------:|---------|
| P0 | 3 | Crashes users or silently breaks auth/payments in production |
| P1 | 10 | High-probability bugs or security/config holes |
| P2 | 14 | Reliability, missing tests, docs/config drift |
| P3 | 10 | Polish, warnings, unused env, README mismatches |

---

## 2. Device log crash analysis (P0)

**Device:** OnePlus CPH2661 (`OP5E93L1`), Android API 36  
**Player:** ExoPlayer / Media3 1.5.1, codec `c2.qti.avc.decoder`, **720×1088 @ 30 fps**  
**App PID:** 13911

### 2.1 What the user was doing

The decoder was actively rendering a **9:16-ish video template** while the user generated repeated `ACTION_UP` touch events and OEM `slideSceneEnd` reports. That matches the **Home vertical PageView** (`home_screen.dart`), not Discover (Discover cards are thumbs only; no `VideoPlayer`).

`ShellRoute` **destroys** the previous tab. If the user had already left Home for Discover, ExoPlayer would release *first*. In this log, **sliver errors happen while the decoder is still running**, then ExoPlayer releases. So the slivers in play are PageView’s internal `Viewport` / `SliverFillViewport`, not Discover’s `CustomScrollView`.

### 2.2 Timeline (from the pasted log)

| Order | Log | Meaning |
|-------|-----|---------|
| 1 | `c2.qti.avc.decoder 720x1088 inputFps=30 outputFps=30 renderFps=30` | Home feed video playing |
| 2 | `pipelineFull: too many frames in pipeline (6)` | UI thread not consuming frames (jank / layout exceptions) |
| 3 | `dispatchTouchView action = 1` + `slideSceneEnd unknown scene 1003` | Finger up / vertical page swipe |
| 4 | `SliverGeometry is not valid: The "layoutExtent" exceeds the "paintExtent"` | PageView sliver geometry broken mid-swipe |
| 5 | `Null check operator used on a null value` | Disposed `VideoPlayerController` still read, or framework null after invalid layout |
| 6 | `!semantics.parentDataDirty` (dozens of times) | Semantics pass after a failed layout + platform-view teardown |
| 7 | `ExoPlayerImpl: Release 2b6ffa4 [AndroidXMedia3/1.5.1]` | Player torn down (page change, visibility 0, or widget dispose) |
| 8 | `OnBackInvokedCallback is not enabled` | Manifest warning only — not the crash |

`pipelineFull` is a **symptom**: once layout assertions start, the UI thread stalls, the decoder queue fills, and OEM jank logs (`IJankManager`) fire. Codec2 `BAD_INDEX` / skipped params are Qualcomm/Oplus noise and can be ignored.

### 2.3 Root causes in code

#### A. Dispose the ExoPlayer while `VideoPlayer` is still in the tree — **P0**

`mobile/lib/features/templates/presentation/widgets/template_video_layer.dart`

```90:101:mobile/lib/features/templates/presentation/widgets/template_video_layer.dart
  void _scheduleRelease() {
    _releaseTimer?.cancel();
    _controller?.pause();
    _releaseTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      final c = _controller;
      if (c != null) {
        setState(() => _controller = null);
        c.dispose();
      }
    });
  }
```

`setState` only **schedules** a rebuild. `c.dispose()` runs **immediately**, while `VideoPlayer(c)` is still mounted. That is a textbook Media3 crash and matches `Null check operator used on a null value` plus the semantics assertion storm.

`didUpdateWidget` has the same bug (dispose, then null, no post-frame delay). `_onVisibility` can also call `c.play()` on a controller that is being disposed.

#### B. Several ExoPlayers alive during a swipe — **P0**

`PageView.builder` in `home_screen.dart` (lines 391–433) keeps adjacent pages in the cache. Each video page mounts `TemplateVideoLayer` with `playVideo: true`. Visibility only **releases** at `visibleFraction == 0`; during a swipe the outgoing page is often still > 0. Result: 2–3 decoders, `pipelineFull`, and OEM jank.

`VideoPlayerOptions(mixWithOthers: true)` makes this worse — players are allowed to run together.

#### C. Invalid sliver geometry during the swipe — **P0**

Home wraps the vertical `PageView` in `RefreshIndicator` and applies `Transform.scale` + `Opacity` from `AnimatedBuilder` on `_pageController`:

```418:431:mobile/lib/features/home/presentation/screens/home_screen.dart
          return AnimatedBuilder(
            animation: _pageController,
            child: page,
            builder: (context, child) {
              double delta = 0;
              if (_pageController.hasClients && _pageController.position.haveDimensions) {
                delta = ((_pageController.page ?? i.toDouble()) - i).abs().clamp(0.0, 1.0);
              }
              return Opacity(
                opacity: 1 - 0.5 * delta,
                child: Transform.scale(scale: 1 - 0.06 * delta, child: child),
              );
            },
          );
```

PageView’s viewport slivers report a full-page `layoutExtent`. Scaling the child down shrinks what is painted. Combined with `BouncingScrollPhysics` and `RefreshIndicator` (which expects a different overscroll contract than a paging viewport), Flutter asserts:

`SliverGeometry is not valid: The "layoutExtent" exceeds the "paintExtent"`.

The `!semantics.parentDataDirty` failures are a **cascade** of that failed layout, amplified by the ExoPlayer platform view being disposed mid-frame.

#### D. Discover slivers — **P2, not this log**

Discover uses a pinned `SliverPersistentHeader` (`minExtent == maxExtent`) plus a giant `TemplateGrid` inside one `SliverToBoxAdapter`. That is a performance risk and *can* produce the same geometry error on pull-to-refresh, but **this log shows a live 720×1088 decoder**, which Discover never starts.

#### E. Predictive back warning — **P3**

```
OnBackInvokedCallback is not enabled for the application.
Set 'android:enableOnBackInvokedCallback="true"' in the application manifest.
```

Missing on `<application>` in `mobile/android/app/src/main/AndroidManifest.xml`. Harmless until you want Android 13+ predictive back.

### 2.4 Recommended fix (Home feed)

Do these together; any one alone will still flake:

1. **Single active player.** Keep at most one `VideoPlayerController`. Pause/dispose neighbors immediately (`playThreshold` high, release at `< 0.5`, `PageController` viewportFraction 1, consider `allowImplicitScrolling: false`).
2. **Dispose after unmount.** `setState(() => _controller = null)` then `WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose())`. Guard `_onVisibility` / `_start` with a generation token so a stale async `_start()` cannot assign a disposed controller.
3. **Stop scaling PageView children.** Remove `Transform.scale` / `Opacity` during swipe, or apply them only as a paint effect that does not change sliver geometry (e.g. a shader / fade overlay outside the viewport child).
4. **Do not wrap PageView in RefreshIndicator.** Use an explicit refresh control (header button or overscroll listener that does not fight paging slivers).
5. **Fail closed.** `FlutterError.onError` + a small error widget on the feed so one bad page does not take the session down.
6. Add `android:enableOnBackInvokedCallback="true"` on `<application>`.

---

## 3. Architecture

```
Flutter app (Android)     Admin Next.js :3001     Creator Next.js :3002
        │                         │                        │
        └─────────────────────────┼────────────────────────┘
                                  ▼
                    Fastify 4  /api/v1  (Node 20)
                                  │
          ┌──────────┬────────────┼──────────┬──────────┐
          ▼          ▼            ▼          ▼          ▼
     PostgreSQL    Redis      Cloudinary   Razorpay   OneSignal
     (Supabase)   (Upstash)     / GCS
```

| Layer | Path | Stack |
|-------|------|--------|
| API | `backend/` | Fastify 4, Prisma 5, Redis, BullMQ, Zod |
| Admin | `admin-dashboard/` | Next.js 15, TanStack Query, Axios, Recharts |
| Creator | `creator-dashboard/` | Next.js 15, Google OAuth, overlay editor |
| Mobile | `mobile/` | Flutter 3.3+, Riverpod, GoRouter, Hive, `video_player` |
| Marketing | `website/` | Static HTML, Netlify + Firebase Hosting |
| Local infra | `docker-compose.yml` | Postgres 16 + Redis 7 |

**16 Prisma models:** User, CreatorProfile, Category, Template, SavedStatus, ShareHistory, Subscription, Festival, NotificationLog, PushCampaign, AnalyticsEvent, AppConfig, AuditLog.

**Mobile routes:** splash → intro → login → profile-setup → shell (`/home`, `/discover`, `/saved`, `/profile`) plus `/template/:id`, premium, search, legal, settings.

**API prefix:** `/api/v1` — auth, templates, search, user, subscribe, festivals, creator, admin, upload, health, categories, config.

Workers (`npm run worker`): `plan_expiry` (hourly), `festival_alerts` (6h), `renewal_reminder` (daily 09:00 IST). No BullMQ batch for template counters despite a schema comment claiming 30s batches.

---

## 4. Findings register

### P0 — fix before more feature work

| ID | Area | Issue | Where |
|----|------|--------|--------|
| **M-V1** | Mobile | Dispose `VideoPlayerController` while `VideoPlayer` is still mounted (`setState` then `dispose` on the same turn) | `template_video_layer.dart` 90–101, 123–130 |
| **M-V2** | Mobile | Multiple ExoPlayers during vertical swipe; `mixWithOthers: true`; release only at `visibleFraction == 0` | `home_screen.dart` 391–433, `template_video_layer.dart` 64–67, 104–119 |
| **B-R1** | Backend | If Redis is down, API falls back to **in-process `MemoryRedis`**. Refresh tokens, OTP, rate limits, and webhook idempotency become instance-local. Restarts and multi-instance deploys desync sessions; duplicate webhooks can activate premium twice. | `backend/src/plugins/redis.plugin.ts` |

### P1 — high

| ID | Area | Issue | Where |
|----|------|--------|--------|
| **M-V3** | Mobile | `RefreshIndicator` + `Transform.scale` on vertical `PageView` → `layoutExtent > paintExtent` | `home_screen.dart` 386–431 |
| **M-V4** | Mobile | Async `_start()` vs URL change / unmount race (`_starting` can assign a stale controller) | `template_video_layer.dart` 40–87, 123–130 |
| **M-G1** | Mobile | `google-services.json` package `com.statusgoo.enpoi` ≠ Gradle `applicationId` `com.statusgo.status_go`. Google Sign-In / Firebase phone can fail or bind the wrong app. | `mobile/android/app/google-services.json`, `build.gradle.kts` 42 |
| **M-G2** | Mobile | Firebase API key and OAuth clients committed in `google-services.json` | same |
| **B-P1** | Backend | `RAZORPAY_KEY_SECRET` / webhook secret **default to `'placeholder'`** — server can boot in production with broken payment crypto | `backend/src/config/env.ts` 46–48 |
| **B-P2** | Backend | Webhook Redis `set` failure is treated as success (`.catch(() => 'OK')`) → duplicate subscription activation | `backend/src/modules/subscriptions/sub.route.ts` |
| **B-A1** | Backend | Extra hardcoded Firebase/Android Google client ID in allowed audiences | `backend/src/lib/auth/google.service.ts` |
| **D-E1** | Dashboards | `admin-dashboard/.env.production` and `creator-dashboard/.env.production` are **tracked** (prod Cloud Run URL + Google client id) | those files; `.gitignore` does not ignore `.env.production` |
| **B-S1** | Backend | `scripts/reset-db.ts` default admin password `StatusGo@Admin2026!` if env unset | `backend/scripts/reset-db.ts` |
| **M-M1** | Mobile | Camera used in profile setup / edit profile; **no `CAMERA` permission** in the manifest | `profile_setup_screen.dart`, `AndroidManifest.xml` |

### P2 — medium

| ID | Area | Issue |
|----|------|--------|
| **T-1** | All | Almost no automated tests. Backend: `jest --passWithNoTests` and zero spec files. Mobile: 5 widget tests on design-system chips. Dashboards: no `test` script. No CI (`.github/` missing). |
| **B-M1** | Backend | No Prisma `migrations/` in repo — `db:migrate` has nothing to replay; schema drift on deploy. |
| **M-D1** | Mobile | Discover: entire masonry grid in one `SliverToBoxAdapter` — layout cost grows with every page of templates; nested horizontal lists + `FadeSlideIn` can still trip sliver/semantics bugs. |
| **M-A1** | Mobile | Release API URL and Razorpay **test** key shipped as defaults (`app_constants.dart`). |
| **M-V5** | Mobile | Home share/download captures `RepaintBoundary` while video is playing — wrong frame / platform-view capture issues. |
| **D-A1** | Dashboards | JWT in `localStorage`; no Next.js `middleware.ts`; UI guards only. (API must remain the real gate.) |
| **D-A2** | Dashboards | Demo passwords in login pages when `NEXT_PUBLIC_SHOW_DEMO_LOGIN=true`. |
| **B-A2** | Backend | `creator/login` accepts `SUPER_ADMIN` — admin password works on the creator surface. |
| **B-U1** | Backend | Global multipart 10 MB vs upload route 50 MB — confusing 413s. |
| **S-1** | Search | `/suggestions` and `/trending` only have the global 200/min limit. |
| **M-L1** | Mobile | Support/legal placeholders still `TODO(owner)` — Play / Razorpay compliance risk. |
| **W-1** | Website | Waitlist form writes **localStorage only** — never hits the API. |
| **B-H1** | Backend | SIGTERM exits without closing Fastify/Prisma/Redis. |
| **B-H2** | Backend | `SENTRY_DSN_API` is in env but never wired. |

### P3 — low

| ID | Area | Issue |
|----|------|--------|
| **M-B1** | Mobile | `enableOnBackInvokedCallback` missing (matches the log warning). |
| **M-U1** | Mobile | `showVideoBadge: true` on Home is a no-op because `playVideo` is also true. |
| **B-H3** | Backend | Public `/health` returns `NODE_ENV` and DB/Redis status. |
| **B-T1** | Backend | Template `view`/`use` increment without checking the template exists. |
| **R-1** | Docs | README claims shadcn/ui, TanStack Table, 4-step wizard, Railway/Vercel — code is custom CSS, 3-step upload, Cloud Run. |
| **R-2** | Docs | Root `.env.example` `NEXTAUTH_*` unused. |
| **C-1** | Creator | Edit mode scans only 50 DRAFT/REJECTED templates. |
| **B-C1** | Backend | Widespread `any`; stale Prisma comment about 30s BullMQ counter flush. |

---

## 5. Security snapshot

**Done well**

- Helmet, CORS allowlist, global rate limit, JWT 15m + rotating hashed refresh, bcrypt for staff, Razorpay HMAC with `timingSafeEqual`, upload magic-byte checks, parameterized search SQL, admin RBAC on role/plan changes, log redaction, account-delete anonymization.

**Not done well**

- Redis fallback turns a cache outage into an auth/payment correctness bug (**B-R1**, **B-P2**).
- Payment secrets can be placeholders in production (**B-P1**).
- Firebase/OAuth material and prod API URLs live in git (**M-G2**, **D-E1**).
- Package id mismatch will make Google auth look “randomly broken” (**M-G1**).
- Dashboards are SPAs with tokens in `localStorage` (acceptable only if XSS is tight and the API enforces every `/admin` and `/creator` call — it does, but there is no CSP in `next.config.mjs`).

`backend/env.yaml` is gitignored and was not in the tree. Do not commit it.

---

## 6. Quality, tests, and ops

| Check | Status |
|-------|--------|
| Backend unit/integration tests | None (`jest --passWithNoTests`) |
| Flutter widget/integration tests | 5 design-system tests only |
| Dashboard tests | None |
| GitHub Actions / any CI | **Missing** |
| Prisma migrations in git | **Missing** |
| Sentry | Env var only, not wired |
| Error reporting on mobile | `debugPrint` on video failure |
| Graceful shutdown | Missing |
| Deploy as documented | README says Railway/Vercel; committed env points at **Cloud Run** `asia-south1` |

Local Docker Compose is fine for Postgres/Redis. Backend Dockerfile is a reasonable multi-stage Node 20 image.

---

## 7. Feature completeness (product)

| Surface | State |
|---------|--------|
| Phone OTP + Google login + profile setup | Implemented |
| Home immersive video/image feed + share/download | Implemented — **unstable on video swipe** |
| Discover, search, saved, festival ribbon | Implemented |
| Template editor (name, photo, quote, frames) | Implemented |
| Premium / Razorpay (one-time + intro recurring) | Implemented — config-fragile |
| Push (OneSignal) | Code present; App ID default empty |
| Admin: review, users, festivals, campaigns, revenue, config | Implemented |
| Creator: 3-step upload + overlay zones | Implemented |
| Marketing site | Static “launching soon”; waitlist not persisted |

---

## 8. Recommended order of work

1. **Home video crash (M-V1, M-V2, M-V3, M-V4)** — single player, post-frame dispose, no PageView scale, no RefreshIndicator on PageView. Re-test on the OnePlus (and one mid-range) with three consecutive video swipes.
2. **Fail closed on Redis (B-R1, B-P2)** — do not boot or do not accept refresh/webhooks on `MemoryRedis`. Treat Redis `set` failure as *not* idempotent-success.
3. **Payment env (B-P1)** — refuse to start in production if Razorpay secrets are placeholders.
4. **Identity (M-G1, M-G2, D-E1)** — one `applicationId`, matching `google-services.json`, stop tracking `.env.production`, rotate the leaked Firebase key restrictions.
5. **Manifest (M-M1, M-B1)** — `CAMERA` + `enableOnBackInvokedCallback`.
6. **Safety net** — Prisma migrations in repo, CI (lint + `flutter analyze` + backend build), Sentry, a few tests around auth refresh, webhook verify, and `TemplateVideoLayer` lifecycle.

---

## 9. File index (highest signal)

| File | Why it matters |
|------|----------------|
| `mobile/lib/features/templates/presentation/widgets/template_video_layer.dart` | ExoPlayer lifecycle — crash source |
| `mobile/lib/features/home/presentation/screens/home_screen.dart` | Vertical feed + RefreshIndicator + scale |
| `mobile/lib/features/home/presentation/screens/discover_screen.dart` | Pinned sliver header + grid |
| `mobile/lib/core/router/app_router.dart` | Auth guards, shell, template route |
| `mobile/android/app/src/main/AndroidManifest.xml` | Permissions, back callback |
| `mobile/lib/core/constants/app_constants.dart` | API / Razorpay / legal TODOs |
| `backend/src/app.ts` | Plugins, CORS, errors |
| `backend/src/config/env.ts` | Secret defaults |
| `backend/src/plugins/redis.plugin.ts` | MemoryRedis fallback |
| `backend/src/modules/subscriptions/sub.route.ts` | Razorpay + webhook |
| `backend/prisma/schema.prisma` | Data model |
| `admin-dashboard/.env.production` | Committed prod URL |
| `creator-dashboard/.env.production` | Committed prod URL + Google client |

---

*This audit is a snapshot of the tree as of 13 October 2026 plus the device logcat pasted in the same session. It does not re-test payments or Google Sign-In live.*

---

## 10. Remediation status (updated 15 Oct 2026)

Legend: **Fixed** = changed + covered by an automated test · **Already fixed** = found fixed in the working tree · **Open** = not done (reason given).

| ID | Status | Notes |
|----|--------|-------|
| M-V1, M-V2, M-V3, M-V4 | Already fixed | Single-player, post-frame dispose, no `RefreshIndicator`/`Transform.scale` on the pager (uncommitted work on `chore/flutter-upgrade`). New Shorts feed follows the same rules and has lifecycle tests. **Still needs a real-device swipe test.** |
| M-B1 | Already fixed | `enableOnBackInvokedCallback` is set. |
| B-R1 | **Fixed** | In production the API refuses to boot without Redis and never silently falls back to per-instance memory (`REDIS_ALLOW_MEMORY_FALLBACK=true` is an explicit single-instance escape hatch). `CacheService` now degrades to uncached instead of 500-ing on a Redis blip. `test/hardening.test.ts`. |
| B-P2 | **Fixed** | Webhook idempotency failure now returns 503 (Razorpay retries) instead of processing the event. |
| B-P1 | **Fixed** (partly) | Placeholder Razorpay secrets can no longer validate payment signatures (the HMAC key would be public); in production, payment-creating POSTs return 503 until real credentials are set. The server still boots (webhook already refused placeholders). |
| B-H1 | **Fixed** | Graceful shutdown closes Fastify → Prisma/Redis, with a hard 8 s timeout. |
| B-H3 | **Fixed** | `/health` no longer returns `NODE_ENV`. |
| S-1 | **Fixed** | Rate limits on `/search/suggestions` (60/min) and `/search/trending` (30/min). |
| B-S1 | **Fixed** | `reset-db.ts` requires `ADMIN_PASSWORD` (≥12 chars) and no longer prints it. |
| T-1 (backend) | **Fixed** | 195 backend tests incl. real-Postgres end-to-end. |
| T-1 (mobile) | **Fixed** | 361 tests incl. a layout stress test of **every screen** (4 phone sizes, max accessibility text, light/dark, API data/empty/failing, keyboard open on forms). |
| CI | **Fixed** | `.github/workflows/ci.yml` (backend + real Postgres, admin build, Flutter analyze/test); `release-readiness.yml` for tags. |
| B-M1 | Fixed (partly) | Migration folder now exists with one additive migration (AI Shorts). Earlier tables are still created by `db push`; baseline before adopting `migrate deploy`. |
| — (found by new tests) | **Fixed** | `SessionStore` singleton was disposed by its Riverpod provider on scope teardown. · Intro screen overflowed on small phones / large text. · Discover pinned header had invalid sliver geometry (`layoutExtent > paintExtent`). · Notifications provider modified another provider during init (assertion in debug). · Suvichar banner row overflowed on 320 px. · Profile-setup form overflowed on a small phone with the keyboard open. |
| M-M1 | Not a bug | The merged manifest has no `CAMERA` permission and `image_picker` uses the system camera intent, which needs none. Declaring it would force a runtime prompt. |
| M-G1 | **Open — needs you** | `google-services.json` is for `com.statusgoo.enpoi`; `applicationId` is `com.statusgo.status_go`. Download the matching file from the Firebase console. `mobile/tool/check_release_ready.sh` fails until fixed. |
| M-L1 | **Open — needs you** | Support phone/WhatsApp, company name/address, grievance officer, policy URLs are `TODO(owner)` placeholders. Same script fails until filled. |
| M-A1 | **Open** | Release builds default to a Razorpay **test** key; pass `--dart-define=RAZORPAY_KEY_ID=rzp_live_…`. |
| M-G2, D-E1 | Open | Firebase key / prod URLs in git. They are client-side identifiers; restrict the Firebase API key in the console. `.env.production` is still tracked. |
| B-A2, B-A1 | Open | Creator login still accepts SUPER_ADMIN; extra hardcoded Google client id. Product decisions. |
| M-V5, M-D1 | Open | Share-while-video-playing capture and Discover grid performance need profiling on a device. |
| D-A1, D-A2, W-1, B-H2, R-1, R-2, C-1, B-C1 | Open | Not addressed in this pass. |
