path = r"d:\latest_status_goo\backend\src\modules\shorts\shorts.route.ts"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Imports
if 'state-locator' not in content:
    content = content.replace(
        "import { checkSchemeEligibility, EligibilityInputSchema } from './schemes.calculator';",
        "import { checkSchemeEligibility, EligibilityInputSchema } from './schemes.calculator';\nimport { resolveStateFromCoords, normalizeStateCode } from '../../lib/content/state-locator';"
    )

# 2. SUB_KINDS and ListQuery
old_list_query = """const ListQuery = z.object({
  kind: optionalEnum([...KINDS]),
  category: optionalString(64),
  region: optionalString(16),
});"""

new_list_query = """const SUB_KINDS = ['TOP', 'REGIONAL'] as const;

const ListQuery = z.object({
  kind: optionalEnum([...KINDS]),
  subKind: optionalEnum([...SUB_KINDS]),
  category: optionalString(64),
  region: optionalString(16),
  state: optionalString(32),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
});"""

content = content.replace(old_list_query, new_list_query)

# 3. list handler implementation
old_list_fn = """  async function list(req: any, reply: any) {
    const parsed = ListQuery.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 10, maxLimit: 30 });
    const { kind, category, region } = parsed.data;
    const effectiveKind = forcedKind ?? kind;

    const where = publicWhere({
      ...(effectiveKind && { kind: effectiveKind }),
      ...(category && { category }),
      // A state filter still includes national (region = null) items.
      ...(region && { OR: [{ region }, { region: null }] }),
    });

    const [rows, total] = await Promise.all([
      prisma.shortVideo.findMany({
        where,
        include: shortInclude,
        orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.shortVideo.count({ where }),
    ]);"""

new_list_fn = """  async function list(req: any, reply: any) {
    const parsed = ListQuery.safeParse(req.query ?? {});
    if (!parsed.success) return sendValidationError(reply, parsed.error);
    const { page, limit, skip } = parsePagination(req.query, { defaultLimit: 10, maxLimit: 30 });
    const { kind, subKind, category, region, state, lat, lng } = parsed.data;
    const effectiveKind = forcedKind ?? kind;

    const userId = (req.user as any)?.userId as string | undefined;

    // Resolve user's state / region from params, coordinates, or profile
    let resolvedState: string | null = null;
    if (state || region) {
      resolvedState = normalizeStateCode(state || region);
    } else if (lat != null && lng != null) {
      resolvedState = resolveStateFromCoords(lat, lng);
    } else if (userId) {
      const u = await prisma.user.findUnique({
        where: { id: userId },
        select: { state: true, region: true, latitude: true, longitude: true },
      });
      if (u?.state || u?.region) {
        resolvedState = normalizeStateCode(u.state || u.region);
      } else if (u?.latitude != null && u?.longitude != null) {
        resolvedState = resolveStateFromCoords(u.latitude, u.longitude);
      }
    }

    let extraWhere: Prisma.ShortVideoWhereInput = {};

    if (effectiveKind === 'NEWS') {
      if (subKind === 'TOP') {
        extraWhere = {
          kind: 'NEWS',
          ...(category && { category }),
          OR: [{ subKind: 'TOP' }, { region: null }],
        };
      } else if (subKind === 'REGIONAL') {
        if (resolvedState) {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
            OR: [
              { subKind: 'REGIONAL', region: resolvedState },
              { region: resolvedState },
            ],
          };
        } else {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
            subKind: 'REGIONAL',
          };
        }
      } else {
        if (resolvedState) {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
            OR: [{ subKind: 'TOP' }, { region: resolvedState }, { region: null }],
          };
        } else {
          extraWhere = {
            kind: 'NEWS',
            ...(category && { category }),
          };
        }
      }
    } else if (effectiveKind === 'SCHEME') {
      extraWhere = {
        kind: 'SCHEME',
        ...(category && { category }),
        ...(resolvedState ? { OR: [{ region: resolvedState }, { region: null }] } : {}),
      };
    } else {
      extraWhere = {
        ...(effectiveKind && { kind: effectiveKind }),
        ...(category && { category }),
        ...(resolvedState ? { OR: [{ region: resolvedState }, { region: null }] } : {}),
      };
    }

    const where = publicWhere(extraWhere);

    let [rows, total] = await Promise.all([
      prisma.shortVideo.findMany({
        where,
        include: shortInclude,
        orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
        skip,
        take: limit,
      }),
      prisma.shortVideo.count({ where }),
    ]);

    // If regional news specifically requested but nothing found for this specific state yet,
    // fallback to all regional news so the user gets fresh content
    if (rows.length === 0 && effectiveKind === 'NEWS' && subKind === 'REGIONAL' && resolvedState) {
      const fallbackWhere = publicWhere({
        kind: 'NEWS',
        ...(category && { category }),
        subKind: 'REGIONAL',
      });
      const [fRows, fTotal] = await Promise.all([
        prisma.shortVideo.findMany({
          where: fallbackWhere,
          include: shortInclude,
          orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
          skip,
          take: limit,
        }),
        prisma.shortVideo.count({ where: fallbackWhere }),
      ]);
      if (fRows.length > 0) {
        rows = fRows;
        total = fTotal;
      }
    }"""

content = content.replace(old_list_fn, new_list_fn)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("shorts.route.ts updated successfully")
