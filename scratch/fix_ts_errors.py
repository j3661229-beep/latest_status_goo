# 1. Fix backend/src/lib/content/settings.ts -> add ingestDue
path_settings = r"d:\latest_status_goo\backend\src\lib\content\settings.ts"
with open(path_settings, "r", encoding="utf-8") as f:
    c = f.read()

if 'export function ingestDue' not in c:
    c += """

export function ingestDue(settings: ContentSettings, now = new Date()): boolean {
  if (!settings.ingestEnabled) return false;
  if (!settings.lastIngestAt) return true;
  const elapsedMinutes = (now.getTime() - settings.lastIngestAt.getTime()) / 60000;
  return elapsedMinutes >= settings.ingestIntervalMinutes;
}
"""
    with open(path_settings, "w", encoding="utf-8") as f:
        f.write(c)
    print("Fixed settings.ts")

# 2. Fix backend/src/modules/content-admin/content.admin.route.ts -> ingestNews
path_admin = r"d:\latest_status_goo\backend\src\modules\content-admin\content.admin.route.ts"
with open(path_admin, "r", encoding="utf-8") as f:
    c = f.read()

c = c.replace("import { ingestFeeds } from '../../lib/content/ingest';", "import { ingestNews } from '../../lib/content/ingest';")
c = c.replace("ingestFeeds({ prisma, settings })", "ingestNews({ prisma, settings })")
with open(path_admin, "w", encoding="utf-8") as f:
    f.write(c)
print("Fixed content.admin.route.ts")

# 3. Fix backend/src/modules/user/user.route.ts -> resolveStateFromCoords returns IndianStateLocation
path_user = r"d:\latest_status_goo\backend\src\modules\user\user.route.ts"
with open(path_user, "r", encoding="utf-8") as f:
    c = f.read()

old_user_detect = """    if ((finalState === undefined || finalState === null) && latitude != null && longitude != null) {
      const detected = resolveStateFromCoords(latitude, longitude);
      if (detected) {
        finalState = detected;
        finalRegion = finalRegion ?? detected;
      }
    }"""

new_user_detect = """    if ((finalState === undefined || finalState === null) && latitude != null && longitude != null) {
      const detected = resolveStateFromCoords(latitude, longitude);
      if (detected) {
        finalState = detected.code;
        finalRegion = finalRegion ?? detected.code;
      }
    }"""
c = c.replace(old_user_detect, new_user_detect)
with open(path_user, "w", encoding="utf-8") as f:
    f.write(c)
print("Fixed user.route.ts")

# 4. Fix backend/src/modules/shorts/shorts.route.ts -> resolveStateFromCoords, duplicate userId, and extraWhere types
path_shorts = r"d:\latest_status_goo\backend\src\modules\shorts\shorts.route.ts"
with open(path_shorts, "r", encoding="utf-8") as f:
    c = f.read()

# Fix resolveStateFromCoords:
c = c.replace("resolvedState = resolveStateFromCoords(lat, lng);", "resolvedState = resolveStateFromCoords(lat, lng)?.code ?? null;")
c = c.replace("resolvedState = resolveStateFromCoords(u.latitude, u.longitude);", "resolvedState = resolveStateFromCoords(u.latitude, u.longitude)?.code ?? null;")

# Fix line 128:
old_else = """    } else {
      extraWhere = {
        ...(effectiveKind && { kind: effectiveKind }),
        ...(category && { category }),
        ...(resolvedState ? { OR: [{ region: resolvedState }, { region: null }] } : {}),
      };
    }"""
new_else = """    } else {
      extraWhere = {
        ...(effectiveKind ? { kind: effectiveKind as any } : {}),
        ...(category ? { category } : {}),
        ...(resolvedState ? { OR: [{ region: resolvedState }, { region: null }] } : {}),
      };
    }"""
c = c.replace(old_else, new_else)

# Fix duplicate userId:
old_dup_user = """    const userId = (req.user as any)?.userId as string | undefined;
    const saved = new Set<string>();"""
new_dup_user = """    const saved = new Set<string>();"""
c = c.replace(old_dup_user, new_dup_user)

with open(path_shorts, "w", encoding="utf-8") as f:
    f.write(c)
print("Fixed shorts.route.ts")
