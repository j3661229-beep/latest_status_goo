# Status Go (स्टेटस गो)

> A full-stack daily status maker app for Indian users (age 30–60).  
> Share personalized WhatsApp Status, festival wishes, and motivational quotes with your name and photo overlaid on beautiful templates.

[![Backend](https://img.shields.io/badge/Backend-Fastify%204%20%2B%20Node%2020-black?logo=fastify)](./backend)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2016%20%2B%20Prisma-blue?logo=postgresql)](./backend/prisma)
[![Cache](https://img.shields.io/badge/Cache-Redis%207%20%2B%20BullMQ-red?logo=redis)](./backend)
[![Admin](https://img.shields.io/badge/Admin%20Dashboard-Next.js%2015-black?logo=next.js)](./admin-dashboard)
[![Creator](https://img.shields.io/badge/Creator%20Dashboard-Next.js%2015-black?logo=next.js)](./creator-dashboard)
[![Mobile](https://img.shields.io/badge/Mobile-Flutter%203%20%2B%20Riverpod-blue?logo=flutter)](./mobile)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     CLIENTS (3 types)                   │
│  Flutter App (Android) │ Admin Dashboard │ Creator Hub  │
└───────────────┬─────────────────┬────────────────┬──────┘
                │                 │                │
                ▼                 ▼                ▼
        ┌────────────────────────────────────────────┐
        │   Fastify 4 API  ·  Node.js 20 LTS         │
        │   JWT Auth · Rate Limit · Zod Validation   │
        └──────────────────────┬─────────────────────┘
                               │
        ┌──────────┬───────────┼───────────┬──────────┐
        ▼          ▼           ▼           ▼          ▼
   PostgreSQL    Redis 7   Cloudflare   Cloudflare  OneSignal
   (Supabase)  (Upstash)     R2 CDN      Stream      Push
```

---

## Repository Structure

```
status-go/
├── backend/              # Fastify API + BullMQ workers
├── admin-dashboard/      # Main Admin (Next.js 15) — review/analytics
├── creator-dashboard/    # Creator Portal (Next.js 15) — upload/manage
├── mobile/               # Flutter Android app
├── .env.example          # All environment variables documented
└── turbo.json            # Turborepo task pipeline
```

---

## Quick Start (Local Development)

### Prerequisites

- **Node.js 20+** — [nodejs.org](https://nodejs.org)
- **Flutter 3.x** (optional, for mobile) — [flutter.dev](https://flutter.dev)
- A free **Supabase** account — [supabase.com](https://supabase.com)
- A free **Upstash** account — [upstash.com](https://upstash.com)

### 1. Clone & Install

```bash
git clone https://github.com/yourname/status-go.git
cd status-go
npm install          # installs all workspace dependencies
```

### 2. Create Cloud Databases (5 minutes, both free)

**PostgreSQL — Supabase**
1. [supabase.com](https://supabase.com) → **New Project** (region: South Asia)
2. Settings → Database → **Connection Pooling** section
3. Copy the **Transaction** URI → paste as `DATABASE_URL`
4. Copy the **Session (Direct)** URI → paste as `DIRECT_DATABASE_URL`

**Redis — Upstash**
1. [console.upstash.com](https://console.upstash.com) → **Create Database** (region: Mumbai)
2. Copy the `rediss://...` connection URL → paste as `REDIS_URL`

### 3. Environment Setup

```bash
cp .env.example .env           # Root
cp backend/.env.example backend/.env   # Backend
# Fill in DATABASE_URL, DIRECT_DATABASE_URL, REDIS_URL, JWT_SECRET, GOOGLE_CLIENT_ID
# Everything else (R2, OneSignal, Sentry) is optional — leave blank to skip gracefully
```

**Generate JWT secrets:**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
# Run twice — once for JWT_SECRET, once for JWT_REFRESH_SECRET
```

### 4. Database Setup

```bash
cd backend
npm run db:generate  # Generate Prisma client
npm run db:migrate   # Push schema to Supabase
npm run db:seed      # Seed categories, templates, users, festivals
npm run studio       # (Optional) Explore data at localhost:5555
```

### 5. Run All Services

```bash
# From root — runs backend + both dashboards simultaneously
npm run dev

# Or run individually:
# cd backend           && npm run dev    → API at http://localhost:3000
# cd admin-dashboard   && npm run dev    → Admin at http://localhost:3001
# cd creator-dashboard && npm run dev    → Creator at http://localhost:3002
```

### 6. Flutter App (Optional)

```bash
cd mobile
flutter pub get
flutter run            # needs Android device/emulator connected
# Android emulator → API at http://10.0.2.2:3000/api/v1
```

---

## Service URLs (Local)

| Service | URL | Notes |
|---|---|---|
| **Fastify API** | http://localhost:3000 | — |
| **API Health** | http://localhost:3000/api/v1/health | DB + Redis status |
| **Admin Dashboard** | http://localhost:3001 | Google OAuth (MANAGER/SUPER_ADMIN role) |
| **Creator Dashboard** | http://localhost:3002 | Google OAuth (CREATOR role) |
| **Prisma Studio** | http://localhost:5555 | `npm run studio` in /backend |

---

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| **API** | Fastify 4 + TypeScript | 65k req/s, JSON schema validation, Pino logging |
| **ORM** | Prisma 5 | Type-safe, auto-migrations, PostgreSQL FTS support |
| **Database** | PostgreSQL 16 | GIN indexes, trigram FTS, pg_trgm for Hindi search |
| **Cache** | Redis 7 + Upstash | 4-layer cache, BullMQ queues, sliding window rate limit |
| **Queue** | BullMQ | CRON jobs, retries, priorities — notification + analytics |
| **Auth** | Google OAuth + JWT | HS256 access (15min) + rotating refresh (30d) |
| **CDN** | Cloudflare R2 + Images | Zero egress, auto-webp, global delivery |
| **Video** | Cloudflare Stream | HLS transcoding, adaptive bitrate, signed URLs |
| **Push** | OneSignal | Segment targeting, A/B testing, free 10k subscribers |
| **Payments** | Razorpay | Best Indian gateway — UPI, cards, netbanking |
| **Admin UI** | Next.js 15 + shadcn/ui | Server components, Recharts, TanStack Table |
| **Mobile** | Flutter 3 + Riverpod | Cross-platform, compile-time safe state, GoRouter |

---

## Key Features

### For Users (Flutter App)
- 🙏 Browse Hindi + Marathi image & video status templates
- 📸 Overlay your **name + face photo** on any template (canvas rendering)
- 🎙 Voice search in Hindi/Marathi/English
- 🎉 Festival calendar with 2-day advance push notifications
- 📲 1-tap share to WhatsApp Status, Facebook, Instagram
- ⭐ Premium plan via Razorpay (₹99/month or ₹799/year)
- 🔥 Day streak gamification

### For Admins (Admin Dashboard)
- 📋 Template review queue with approve/reject workflow
- 📊 Real-time analytics: DAU/MAU, retention, revenue, share breakdown
- 🔔 Push campaign composer with OneSignal segment targeting
- 👥 User + Creator management
- 🎉 Festival calendar management

### For Creators (Creator Dashboard)
- 📤 4-step upload wizard with live phone preview
- 🖼 Interactive overlay zone configurator (drag-drop name/photo zones)
- 📊 Per-template analytics (uses, shares)
- 📋 Clear guidelines + rejection reason feedback

---

## Environment Variables

See [`.env.example`](./.env.example) for all required variables with descriptions.

| Variable | Required For | Get From |
|---|---|---|
| `DATABASE_URL` | Backend | Supabase project settings |
| `REDIS_URL` | Backend | Upstash console |
| `JWT_SECRET` | Backend | `openssl rand -hex 32` |
| `GOOGLE_CLIENT_ID` | Backend + Dashboards | Google Cloud Console |
| `RAZORPAY_KEY_ID` | Backend + Flutter | Razorpay Dashboard |
| `ONESIGNAL_APP_ID` | Backend + Flutter | OneSignal Dashboard |
| `CF_R2_*` | Backend (file uploads) | Cloudflare Dashboard |

---

## Database Schema

13 tables: `User`, `CreatorProfile`, `Category`, `Template`, `SavedStatus`, `ShareHistory`, `Subscription`, `Festival`, `NotificationLog`, `PushCampaign`, `AnalyticsEvent`, `AppConfig`, `AuditLog`

Run `npm run studio` in `/backend` to explore visually.

---

## Deployment

| Component | Platform | Command |
|---|---|---|
| **Backend + Worker** | Railway | Connect GitHub repo → deploy automatically |
| **Admin Dashboard** | Vercel | `vercel --prod` in `/admin-dashboard` |
| **Creator Dashboard** | Vercel | `vercel --prod` in `/creator-dashboard` |
| **Database** | Supabase | Create project → copy connection strings |
| **Redis** | Upstash | Create database → copy Redis URL |
| **Flutter** | Play Store | `flutter build appbundle --release` → upload |

---

## Roadmap

| Phase | Timeline | Focus |
|---|---|---|
| **Phase 1 — MVP** | Weeks 1–10 | Auth + Home + Image Canvas + Review Pipeline |
| **Phase 2 — Monetization** | Weeks 11–20 | Razorpay + Video + Voice Search + Streaks |
| **Phase 3 — Scale** | Weeks 21–32 | Gujarati/Punjabi + Birthday reminders + Referrals |

---

## License

MIT © 2025 Status Go Team
