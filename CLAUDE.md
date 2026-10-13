# CLAUDE.md — Claude Code Token-Saver Directives

## ⚠️ STRICT TOKEN BUDGET DIRECTIVES (DO NOT VIOLATE)
This repository is operating under strict API credit limits. Adhere to these rules:

1. **NEVER run recursive file scans**:
   - DO NOT run `find`, `grep -r`, `glob`, or directory sweeps over `node_modules`, `.next`, `.git`, `mobile/android`, `mobile/build`, or `.dart_tool`.
   - DO NOT run `tree` or list entire directory trees.
2. **CONSULT AUDIT FILES FIRST**:
   - System state, URLs, credentials, and architecture are in `AUDIT_SYSTEM_STATE.md`.
   - Known issues, audit findings, and line references are in `AUDIT_CODEBASE_FINDINGS.md`.
   - Never inspect code to deduce architecture—it is already documented in these two files.
3. **TARGETED FILE READS ONLY**:
   - Only view files explicitly relevant to the user's specific request.
   - Use line ranges when reading files rather than loading entire files.
4. **ULTRA-CONCISE RESPONSES**:
   - Provide minimal conversational text.
   - Jump straight to code diffs or concise bullet points.
   - Never summarize files unless explicitly asked.

---

## Repository Quick-Lookup

- **Backend**: `backend/` (Fastify 4, Prisma, TypeScript)
- **Admin Dashboard**: `admin-dashboard/` (Next.js 15, Port 3001)
- **Creator Dashboard**: `creator-dashboard/` (Next.js 15, Port 3002)
- **Mobile**: `mobile/` (Flutter 3.x, Dart)
- **Marketing Site**: `website/` (Static HTML/CSS)

## Live URLs & Config
- **Cloud Run API**: `https://statusgo-api-412085285504.asia-south1.run.app/api/v1`
- **Database**: Supabase PostgreSQL with PgBouncer
- **Admin Account**: `admin@statusgo.in` / `StatusGo@Admin2026!`
