# Status Go — Codebase Audit Findings & Action Roadmap
> **Token Optimization Notice for Claude Code**: All known issues, audit findings, and task steps are cataloged below with **exact file paths and line numbers**. When prompted to fix an issue, proceed directly to the file without exploring or reading other files.

---

## 1. Security & Infrastructure Findings

### 🔴 Finding 1.1: Production CORS Domain Mismatch
- **File**: `backend/src/app.ts` (Lines 77–88)
- **Issue**: The CORS allowed origins currently include:
  ```typescript
  'http://localhost:3001',
  'http://localhost:3002',
  'https://admin.statusgo.app',
  'https://creator.statusgo.app',
  ```
  The production custom domain is **`statusgo.in`**, not `.app`. Any browser request coming from `https://admin.statusgo.in`, `https://creator.statusgo.in`, or Netlify preview domains (`https://*.netlify.app`) will be blocked by CORS in production.
- **Remedy**: Update CORS origin to include `statusgo.in` subdomains or use a dynamic regex origin check:
  ```typescript
  origin: [
    'http://localhost:3001',
    'http://localhost:3002',
    /https:\/\/(.*\.)?statusgo\.in$/,
    /https:\/\/(.*\.)?netlify\.app$/,
  ]
  ```

### 🟡 Finding 1.2: Refresh Token Storage in LocalStorage (Dashboards)
- **Files**:
  - `admin-dashboard/lib/auth.ts` (Lines 9–10)
  - `creator-dashboard/lib/auth.ts` (Lines 9–10)
- **Issue**: JWT access and refresh tokens are stored in browser `localStorage`. While standard for SPAs, they are vulnerable to XSS.
- **Remedy**: Keep strictly as is for MVP since backend requires coordinated cookie refactoring, but ensure all user inputs rendered in dashboard undergo React JSX auto-escaping and avoid `dangerouslySetInnerHTML`.

### 🟢 Finding 1.3: Sensitive Log Redaction & BigInt Fallback
- **File**: `backend/src/app.ts` (Lines 31–36, 61–64)
- **Status**: PASSED. Passwords, OTPs, refresh tokens, and authorization headers are properly redacted from Pino logger outputs. BigInt serializer is active.

---

## 2. Backend & Database Layer Findings

### 🟢 Finding 2.1: Category Management Endpoints
- **File**: `backend/src/modules/admin/admin.route.ts` (Lines 749–860)
- **Status**: PASSED. Full CRUD (`GET`, `POST`, `PUT`, `DELETE /api/v1/admin/categories`) implemented, validated via Zod, equipped with auto-slug generation, audit trail logging, and Redis cache invalidation (`categories:*`). Deletion is guarded against foreign key violations.

### 🟡 Finding 2.2: Redis Cache Invalidation on Category Update
- **File**: `backend/src/app.ts` (Lines 172–189)
- **Issue**: Public `GET /api/v1/categories` currently queries PostgreSQL directly. Under high traffic, this should be cached in Redis with key `categories:all` and invalidated when admin modifies categories.

### 🟢 Finding 2.3: Database Reset & Admin Seed Script
- **File**: `backend/scripts/reset-db.ts`
- **Status**: PASSED. Cleanly drops all 13 tables using `TRUNCATE ... CASCADE` and seeds one bcrypt-hashed `SUPER_ADMIN` (`admin@statusgo.in`).

---

## 3. Admin & Creator Dashboards Findings

### 🟢 Finding 3.1: Admin Mobile Responsiveness & Navigation
- **Files**:
  - `admin-dashboard/components/Sidebar.tsx` (Lines 138–170)
  - `admin-dashboard/app/(dashboard)/categories/page.tsx`
  - `admin-dashboard/app/(dashboard)/dashboard/page.tsx`
- **Status**: PASSED. Pinned top navigation header (`h-14 bg-white/95 backdrop-blur-md`) with animated mobile drawer (`z-[60]`) and outside-click backdrop. KPI cards scale smoothly on all viewports (`grid-cols-1 sm:grid-cols-2 lg:grid-cols-3`).

### 🟢 Finding 3.2: Creator Studio Upload Wizard
- **Files**:
  - `creator-dashboard/app/(creator)/upload/page.tsx`
  - `creator-dashboard/components/CreatorSidebar.tsx`
- **Status**: PASSED. Dynamic category dropdown fetches live categories directly from `/api/v1/categories`. Responsive top bar added to `CreatorSidebar.tsx`.

---

## 4. Mobile Client (Flutter) Findings

### 🟢 Finding 4.1: Production API Base URL Configuration
- **File**: `mobile/lib/core/constants/app_constants.dart` (Lines 15–27)
- **Status**: PASSED. Both `_debugApiBaseUrl` and `_releasePlaceholderApiBaseUrl` correctly point to `https://statusgo-api-412085285504.asia-south1.run.app/api/v1`.

### 🟡 Finding 4.2: Gradle Toolchain & JDK Pinning
- **File**: `mobile/android/gradle.properties` (Line 41)
- **Issue**: Java 25 was causing Gradle build failure `java.lang.IllegalArgumentException: 25.0.3`.
- **Status**: Fixed by pinning `org.gradle.java.home=C:\\Program Files\\Java\\jdk-17`. If running builds on another machine, ensure JDK 17 is installed.

---

## 5. Prioritized Action Checklist

Use these specific task numbers when instructing Claude Code:

| Task ID | Task Description | Target File | Impact |
| :--- | :--- | :--- | :--- |
| **TASK-1** | Add `statusgo.in` regex and Netlify origins to Fastify CORS | `backend/src/app.ts:77-88` | High (Prevents production CORS failures) |
| **TASK-2** | Cache public categories response in Redis | `backend/src/app.ts:173-189` | Medium (Reduces database load) |
| **TASK-3** | Add search & pagination to Admin Users list | `admin-dashboard/app/(dashboard)/users/page.tsx` | Medium (Scalability for large user bases) |
| **TASK-4** | Add Category filter dropdown to Templates review queue | `admin-dashboard/app/(dashboard)/review-queue/page.tsx` | Medium (Improves review efficiency) |
| **TASK-5** | Run and verify Flutter build APK | `mobile/android` | High (Validates Android release readiness) |
