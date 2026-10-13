# Status Go — Full System State & Architectural Audit
> **Token Optimization Notice for Claude Code**: This document contains the complete, authoritative map of the entire repository and infrastructure. **Do NOT run broad recursive searches (`find`, `grep`, `ls -R`) or read whole directories.** Refer to this document for file paths, endpoints, schemas, and credentials.

---

## 1. Project Overview & Tech Stack

| Component | Technology | Directory | Port / URL | State / Target |
| :--- | :--- | :--- | :--- | :--- |
| **Backend API** | Fastify 4 + TypeScript + Prisma 5 + Redis | `/backend` | Live: `https://statusgo-api-412085285504.asia-south1.run.app`<br>Local: `3000` | Google Cloud Run (`asia-south1`), Revision `00006-hz6` |
| **Database** | PostgreSQL 15 (Supabase) + PgBouncer | Cloud Supabase | `aws-1-ap-northeast-2.pooler.supabase.com:6543` | Clean reset, single `SUPER_ADMIN` |
| **Cache & Queues**| Redis (Upstash / Redis Cloud) | Cloud | `complex-hour-spring-91864.db.redis.io:13873` | Active & connected |
| **Admin Dashboard**| Next.js 15 (App Router) + React 18 + Tailwind | `/admin-dashboard` | Local: `http://localhost:3001` | Live Cloud Run API connected, Mobile-responsive |
| **Creator Studio**| Next.js 15 (App Router) + React 18 + Tailwind | `/creator-dashboard` | Local: `http://localhost:3002` | Live Cloud Run API connected, Mobile-responsive |
| **Mobile App** | Flutter 3.x + Dart + Riverpod + Dio | `/mobile` | Android Emulator / Play Store | Points to Cloud Run `/api/v1`, JDK 17 configured |
| **Marketing Web** | Vanilla HTML5 + CSS3 + JS | `/website` | Live: Netlify (`statusgo.in`) | Pushed to GitHub `main`, zero dummy metrics |

---

## 2. Live Credentials & Infrastructure Config

### 2.1 Admin Credentials
- **Role**: `SUPER_ADMIN`
- **Email**: `admin@statusgo.in`
- **Password**: `StatusGo@Admin2026!`
- **User ID**: `cmv5ggm180000131srdfgu4s8`
- **Plan**: `ANNUAL` (Active)
- *Valid for Admin Dashboard (`:3001`), Creator Studio (`:3002`), and Backend REST API.*

### 2.2 Live Backend Endpoints
- **Base URL**: `https://statusgo-api-412085285504.asia-south1.run.app/api/v1`
- **Health Check**: `GET /health` -> `{"status":"ok","db":"ok","redis":"ok","version":"1.0.0"}`
- **Admin Login**: `POST /auth/admin/login` -> `{ email, password }`
- **Creator Login**: `POST /auth/creator/login` -> `{ email, password }`
- **Categories**: `GET`, `POST`, `PUT`, `DELETE /admin/categories`

---

## 3. Monorepo Directory Map

```
/latest_status_goo
├── admin-dashboard/            # Next.js 15 admin application (Port 3001)
│   ├── app/(dashboard)/        # Admin dashboard pages (analytics, categories, templates, etc.)
│   ├── components/             # Sidebar, Header, Modals, QueryError
│   ├── lib/                    # api.ts (Axios), auth.ts (JWT & session), toast.ts, utils.ts
│   └── .env.local              # Points to Cloud Run /api/v1
├── backend/                    # Fastify API microservice
│   ├── prisma/schema.prisma    # 13 PostgreSQL tables
│   ├── src/
│   │   ├── app.ts              # Fastify instance, CORS, helmet, plugins, routes
│   │   ├── server.ts           # Process listener, graceful shutdown
│   │   ├── config/env.ts       # Zod-validated environment config
│   │   ├── modules/            # admin, auth, creator, festivals, search, subscriptions, templates, upload, user
│   │   └── lib/                # cache (Redis), notification (OneSignal), storage (Cloudinary/GCS)
│   └── Dockerfile              # Production multi-stage Alpine build
├── creator-dashboard/          # Next.js 15 creator studio (Port 3002)
│   ├── app/(creator)/          # dashboard, upload, templates, analytics, profile
│   ├── components/             # CreatorSidebar, TemplateEditor, canvas overlay
│   ├── lib/                    # api.ts, auth.ts, cloudinary.ts, utils.ts
│   └── .env.local              # Points to Cloud Run /api/v1
├── mobile/                     # Flutter mobile client
│   ├── lib/
│   │   ├── core/               # api (Dio), auth (Hive session), constants (AppConstants), router
│   │   └── features/           # auth, home, search, templates, user, settings, premium, legal
│   └── android/gradle.properties # org.gradle.java.home=C:\Program Files\Java\jdk-17
├── website/                    # Static landing website (Netlify)
│   ├── index.html, privacy.html, terms.html, refund.html, contact.html, about.html
│   └── css/style.css, js/main.js
├── netlify.toml                # Netlify deployment root redirecting to /website
└── package.json                # Turborepo root workspaces
```

---

## 4. Database Schema (13 Prisma Models)

1. **`User`**: Core user accounts (`id`, `googleId`, `email`, `phoneNumber`, `name`, `password`, `language`, `plan`, `role`, `streakCount`, `introOfferClaimedAt`).
2. **`CreatorProfile`**: Approved status creators (`id`, `userId`, `displayName`, `bio`, `isVerified`, `isSuspended`, `totalDownloads`, `approvalRate`).
3. **`Category`**: Status poster genres (`id`, `slug`, `nameEn`, `nameHi`, `nameMr`, `nameGu`, `namePa`, `emoji`, `gradient`, `sortOrder`, `isActive`).
4. **`Template`**: Daily posters & videos (`id`, `nameHi`, `nameMr`, `nameEn`, `type`, `status`, `imageUrl`, `videoUrl`, `categoryId`, `creatorId`, `isPremium`, `isFeatured`, `useCount`, `shareCount`).
5. **`SavedStatus`**: Bookmarked statuses per user.
6. **`ShareHistory`**: WhatsApp & Instagram analytics tracking.
7. **`Subscription`**: Razorpay payments & plan tracking (`plan`, `status`, `razorpayOrderId`, `amountPaid`).
8. **`Festival`**: Calendar events with automated push alert timings (`date`, `notifyDaysBefore`, `categoryId`).
9. **`NotificationLog`**: User-level in-app notification inbox.
10. **`PushCampaign`**: Mass broadcast push messages via OneSignal.
11. **`AnalyticsEvent`**: In-app behavioral telemetry.
12. **`AppConfig`**: Key-value remote runtime settings (limits, maintenance mode, versions).
13. **`AuditLog`**: Security compliance trail of all administrative actions.

---

## 5. API Routes Reference

- `/api/v1/auth`:
  - `POST /admin/login`, `POST /creator/login`, `POST /otp/send`, `POST /otp/verify`, `POST /google`, `POST /refresh`, `POST /logout`
- `/api/v1/admin`:
  - `GET /stats`, `GET /revenue`, `GET /templates`, `GET /templates/pending`, `POST /templates/:id/approve`, `POST /templates/:id/reject`, `PATCH /templates/:id`
  - `GET /categories`, `POST /categories`, `PUT /categories/:id`, `DELETE /categories/:id`
  - `GET /festivals`, `POST /festivals`, `PUT /festivals/:id`
  - `GET /creators`, `PATCH /creators/:id`, `POST /creators/invite`
  - `GET /users`, `PATCH /users/:id`
  - `GET /campaigns`, `POST /campaigns/send`, `POST /campaigns/test`
  - `GET /config`, `PUT /config`
  - `GET /audit-log`
- `/api/v1/creator`:
  - `GET /stats`, `GET /profile`, `PUT /profile`, `GET /templates`, `POST /templates/draft`, `PUT /templates/:id`, `POST /templates/:id/submit`
- `/api/v1/templates`:
  - `GET /feed`, `GET /trending`, `GET /featured`, `GET /:id`, `POST /:id/use`, `POST /:id/share`, `POST /:id/save`
- `/api/v1/festivals`:
  - `GET /upcoming`, `GET /calendar`
- `/api/v1/subscribe`:
  - `GET /plans`, `POST /create`, `POST /verify`, `POST /webhook`
