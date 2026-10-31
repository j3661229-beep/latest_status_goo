import re

path = r"d:\latest_status_goo\backend\src\modules\content-admin\content.admin.route.ts"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Imports
if 'import { extractYoutubeId }' not in content:
    content = content.replace(
        "import { resolveAssetUrl } from '../../lib/content/assets';",
        "import { resolveAssetUrl } from '../../lib/content/assets';\nimport { extractYoutubeId } from '../../lib/content/youtube';\nimport { ingestFeeds } from '../../lib/content/ingest';"
    )

# 2. EditBody: add youtubeUrl
if 'youtubeUrl: z.string().trim().url().nullable().optional()' not in content:
    content = content.replace(
        "expiresAt: z.string().datetime().nullable(),",
        "expiresAt: z.string().datetime().nullable(),\n    youtubeUrl: z.string().trim().url().nullable().optional(),"
    )

# 3. SchemeBody: add youtubeUrl
target_scheme_body = "expiresAt: z.string().datetime().nullable().optional(),"
replacement_scheme_body = "expiresAt: z.string().datetime().nullable().optional(),\n  youtubeUrl: z.string().trim().url().nullable().optional(),"
# Notice SchemeBody has expiresAt: z.string().datetime().nullable().optional()
idx = content.find(target_scheme_body)
if idx != -1:
    content = content[:idx] + replacement_scheme_body + content[idx + len(target_scheme_body):]

# 4. Scheme create: compute youtubeId
old_scheme_create = """      const scheme = await prisma.scheme.create({
        data: {
          ...d,
          sourceUpdatedAt: d.sourceUpdatedAt ? new Date(d.sourceUpdatedAt) : null,
          nextReviewAt: d.nextReviewAt ? new Date(d.nextReviewAt) : null,
          expiresAt: d.expiresAt ? new Date(d.expiresAt) : null,
          lastCheckedAt: new Date(),
        },
      });"""

new_scheme_create = """      const youtubeId = d.youtubeUrl ? extractYoutubeId(d.youtubeUrl) : null;
      const scheme = await prisma.scheme.create({
        data: {
          ...d,
          youtubeId,
          sourceUpdatedAt: d.sourceUpdatedAt ? new Date(d.sourceUpdatedAt) : null,
          nextReviewAt: d.nextReviewAt ? new Date(d.nextReviewAt) : null,
          expiresAt: d.expiresAt ? new Date(d.expiresAt) : null,
          lastCheckedAt: new Date(),
        },
      });"""
content = content.replace(old_scheme_create, new_scheme_create)

# 5. Scheme update: compute youtubeId and sync to shortVideos
old_scheme_update = """    const updated = await prisma.scheme.update({
      where: { id: p.data.id },
      data: {
        ...d,
        sourceUpdatedAt: d.sourceUpdatedAt !== undefined ? (d.sourceUpdatedAt ? new Date(d.sourceUpdatedAt) : null) : undefined,
        nextReviewAt: d.nextReviewAt !== undefined ? (d.nextReviewAt ? new Date(d.nextReviewAt) : null) : undefined,
        expiresAt: d.expiresAt !== undefined ? (d.expiresAt ? new Date(d.expiresAt) : null) : undefined,
      },
    });"""

new_scheme_update = """    const youtubeId = d.youtubeUrl !== undefined ? (d.youtubeUrl ? extractYoutubeId(d.youtubeUrl) : null) : undefined;
    const updated = await prisma.scheme.update({
      where: { id: p.data.id },
      data: {
        ...d,
        ...(youtubeId !== undefined && { youtubeId }),
        sourceUpdatedAt: d.sourceUpdatedAt !== undefined ? (d.sourceUpdatedAt ? new Date(d.sourceUpdatedAt) : null) : undefined,
        nextReviewAt: d.nextReviewAt !== undefined ? (d.nextReviewAt ? new Date(d.nextReviewAt) : null) : undefined,
        expiresAt: d.expiresAt !== undefined ? (d.expiresAt ? new Date(d.expiresAt) : null) : undefined,
      },
    });
    if (youtubeId !== undefined) {
      await prisma.shortVideo.updateMany({
        where: { schemeId: p.data.id },
        data: {
          youtubeUrl: d.youtubeUrl || null,
          youtubeId,
          format: youtubeId ? 'CARD_WITH_VIDEO' : 'CARD_ONLY',
        },
      });
    }"""
content = content.replace(old_scheme_update, new_scheme_update)

# 6. Scheme draft: format and youtube info
old_scheme_draft = """    const video = await prisma.shortVideo.create({
      data: {
        kind: 'SCHEME',
        schemeId: scheme.id,
        title,
        category: scheme.category,
        region: scheme.stateCode ?? null,
        language: scheme.language,
        status: 'DRAFT',
        format: 'CARD_ONLY',
        ...schemeCardDefaults(scheme),
      },
    });"""

new_scheme_draft = """    const format = scheme.youtubeId ? 'CARD_WITH_VIDEO' : 'CARD_ONLY';
    const video = await prisma.shortVideo.create({
      data: {
        kind: 'SCHEME',
        schemeId: scheme.id,
        title,
        category: scheme.category,
        region: scheme.stateCode ?? null,
        language: scheme.language,
        status: 'DRAFT',
        format,
        youtubeUrl: scheme.youtubeUrl,
        youtubeId: scheme.youtubeId,
        ...schemeCardDefaults(scheme),
      },
    });"""
content = content.replace(old_scheme_draft, new_scheme_draft)

# 7. Add ingest-now route before end of registerRoutes
if '/content/ingest-now' not in content:
    end_pattern = "  fastify.post('/content/jobs/:id/cancel'"
    ingest_route = """  fastify.post('/content/ingest-now', guard, async (req, reply) => {
    const settings = await loadSettings(prisma);
    const result = await ingestFeeds({ prisma, settings });
    await audit(req, 'content.ingest_now', 'news', undefined, result);
    return reply.send({ ok: true, result });
  });

  fastify.post('/content/jobs/:id/cancel'"""
    content = content.replace(end_pattern, ingest_route)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("content.admin.route.ts updated successfully")
