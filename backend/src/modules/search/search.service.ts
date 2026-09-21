// src/modules/search/search.service.ts
import { PrismaClient } from '@prisma/client';
import type { Redis } from 'ioredis';
import { CacheService } from '../../lib/cache/cache.service';
import { CK, TTL } from '../../lib/cache/keys';

export class SearchService {
  private cache: CacheService;

  constructor(private prisma: PrismaClient, redis: Redis) {
    this.cache = new CacheService(redis);
  }

  async search(query: string, lang?: string, type?: string, page = 1) {
    const normalizedQ = query.trim().toLowerCase();
    if (!normalizedQ || normalizedQ.length < 2) return { data: [], total: 0 };

    // Strictly validate type to prevent SQL injection via interpolation
    const ALLOWED_TYPES = ['IMAGE', 'VIDEO'] as const;
    type AllowedType = typeof ALLOWED_TYPES[number];
    const safeType: AllowedType | undefined = ALLOWED_TYPES.includes(type as AllowedType)
      ? (type as AllowedType)
      : undefined;

    const cacheKey = CK.search(normalizedQ, lang ?? 'all', safeType ?? 'all');
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const limit = 30;
    const skip = (page - 1) * limit;

    // Full-text + trigram search (§LLD-03)
    // Use separate parameterized branches for type to avoid string interpolation into SQL
    let results: any[];
    if (safeType === 'IMAGE') {
      results = await this.prisma.$queryRaw`
        SELECT t.*, c.slug as "categorySlug", c."nameHi" as "categoryNameHi",
          ts_rank(
            to_tsvector('simple',
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' ||
              coalesce(t."nameEn",'') || ' ' || coalesce(t."quoteHi",'') || ' ' ||
              coalesce(t."quoteMr",'') || ' ' || coalesce(t."quoteEn",'') || ' ' ||
              array_to_string(t.tags, ' ')
            ),
            plainto_tsquery('simple', ${normalizedQ})
          ) AS rank,
          similarity(
            coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' || coalesce(t."nameEn",''),
            ${normalizedQ}
          ) AS trgm_score
        FROM "Template" t
        JOIN "Category" c ON c.id = t."categoryId"
        WHERE t.status = 'APPROVED' AND t.type = 'IMAGE'
          AND (
            to_tsvector('simple',
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' ||
              coalesce(t."nameEn",'') || ' ' || coalesce(t."quoteHi",'') || ' ' ||
              coalesce(t."quoteMr",'') || ' ' || coalesce(t."quoteEn",'') || ' ' ||
              array_to_string(t.tags, ' ')
            ) @@ plainto_tsquery('simple', ${normalizedQ})
            OR similarity(
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' || coalesce(t."nameEn",''),
              ${normalizedQ}
            ) > 0.15
          )
        ORDER BY rank DESC, trgm_score DESC, t."useCount" DESC
        LIMIT ${limit} OFFSET ${skip}
      `;
    } else if (safeType === 'VIDEO') {
      results = await this.prisma.$queryRaw`
        SELECT t.*, c.slug as "categorySlug", c."nameHi" as "categoryNameHi",
          ts_rank(
            to_tsvector('simple',
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' ||
              coalesce(t."nameEn",'') || ' ' || coalesce(t."quoteHi",'') || ' ' ||
              coalesce(t."quoteMr",'') || ' ' || coalesce(t."quoteEn",'') || ' ' ||
              array_to_string(t.tags, ' ')
            ),
            plainto_tsquery('simple', ${normalizedQ})
          ) AS rank,
          similarity(
            coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' || coalesce(t."nameEn",''),
            ${normalizedQ}
          ) AS trgm_score
        FROM "Template" t
        JOIN "Category" c ON c.id = t."categoryId"
        WHERE t.status = 'APPROVED' AND t.type = 'VIDEO'
          AND (
            to_tsvector('simple',
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' ||
              coalesce(t."nameEn",'') || ' ' || coalesce(t."quoteHi",'') || ' ' ||
              coalesce(t."quoteMr",'') || ' ' || coalesce(t."quoteEn",'') || ' ' ||
              array_to_string(t.tags, ' ')
            ) @@ plainto_tsquery('simple', ${normalizedQ})
            OR similarity(
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' || coalesce(t."nameEn",''),
              ${normalizedQ}
            ) > 0.15
          )
        ORDER BY rank DESC, trgm_score DESC, t."useCount" DESC
        LIMIT ${limit} OFFSET ${skip}
      `;
    } else {
      // No type filter — search all
      results = await this.prisma.$queryRaw`
        SELECT t.*, c.slug as "categorySlug", c."nameHi" as "categoryNameHi",
          ts_rank(
            to_tsvector('simple',
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' ||
              coalesce(t."nameEn",'') || ' ' || coalesce(t."quoteHi",'') || ' ' ||
              coalesce(t."quoteMr",'') || ' ' || coalesce(t."quoteEn",'') || ' ' ||
              array_to_string(t.tags, ' ')
            ),
            plainto_tsquery('simple', ${normalizedQ})
          ) AS rank,
          similarity(
            coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' || coalesce(t."nameEn",''),
            ${normalizedQ}
          ) AS trgm_score
        FROM "Template" t
        JOIN "Category" c ON c.id = t."categoryId"
        WHERE t.status = 'APPROVED'
          AND (
            to_tsvector('simple',
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' ||
              coalesce(t."nameEn",'') || ' ' || coalesce(t."quoteHi",'') || ' ' ||
              coalesce(t."quoteMr",'') || ' ' || coalesce(t."quoteEn",'') || ' ' ||
              array_to_string(t.tags, ' ')
            ) @@ plainto_tsquery('simple', ${normalizedQ})
            OR similarity(
              coalesce(t."nameHi",'') || ' ' || coalesce(t."nameMr",'') || ' ' || coalesce(t."nameEn",''),
              ${normalizedQ}
            ) > 0.15
          )
        ORDER BY rank DESC, trgm_score DESC, t."useCount" DESC
        LIMIT ${limit} OFFSET ${skip}
      `;
    }

    const result = { data: results, total: results.length, query, lang };
    await this.cache.set(cacheKey, result, TTL.search);

    // Log search term async
    this.prisma.analyticsEvent.create({
      data: { event: 'search', metadata: { query: normalizedQ, lang: lang ?? 'all' } },
    }).catch(() => {});

    return result;
  }

  async getSuggestions(prefix: string): Promise<string[]> {
    if (!prefix || prefix.length < 2) return [];

    const cacheKey = CK.suggestions(prefix);
    const cached = await this.cache.get<string[]>(cacheKey);
    if (cached) return cached;

    const results: any[] = await this.prisma.$queryRaw`
      SELECT DISTINCT COALESCE(t."nameHi", t."nameEn") as suggestion,
        similarity(
          COALESCE(t."nameHi", t."nameEn", ''),
          ${prefix}
        ) as score
      FROM "Template" t
      WHERE t.status = 'APPROVED'
        AND similarity(
          COALESCE(t."nameHi", t."nameEn", ''),
          ${prefix}
        ) > 0.1
      ORDER BY score DESC
      LIMIT 8
    `;

    const suggestions = results.map(r => r.suggestion).filter(Boolean);
    await this.cache.set(cacheKey, suggestions, TTL.suggestions);
    return suggestions;
  }

  async getTrendingTerms(): Promise<string[]> {
    const cached = await this.cache.get<string[]>(CK.trendingTerms);
    if (cached) return cached;

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const results: any[] = await this.prisma.$queryRaw`
      SELECT metadata->>'query' as term, COUNT(*) as count
      FROM "AnalyticsEvent"
      WHERE event = 'search'
        AND "createdAt" > ${sevenDaysAgo}
        AND metadata->>'query' IS NOT NULL
      GROUP BY metadata->>'query'
      ORDER BY count DESC
      LIMIT 20
    `;

    const terms = results.map(r => r.term).filter(Boolean);
    await this.cache.set(CK.trendingTerms, terms, TTL.trendingTerms);
    return terms;
  }
}
