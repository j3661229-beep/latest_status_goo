// src/lib/content/ingest.ts
// News ingestion from trusted feeds (Google News, Amar Ujala, PIB, etc.).
// Ingests Top News & Regional News and creates PUBLISHED ShortVideo cards directly
// without requiring admin approval (as requested: news from trusted sources is published directly).
import crypto from 'crypto';
import { XMLParser } from 'fast-xml-parser';
import type { Prisma, PrismaClient } from '@prisma/client';
import { contentConfig, ContentConfig } from './config';
import { FetchFn, htmlToText, safeFetchText } from './safe-fetch';
import { DEFAULT_FEEDS, FeedConfig } from './settings';

export interface FeedItem {
  title: string;
  link: string;
  publishedAt: Date | null;
  summary: string;
  imageUrl?: string | null;
}

const arr = <T,>(v: T | T[] | undefined): T[] => (v === undefined ? [] : Array.isArray(v) ? v : [v]);
const text = (v: any): string => (typeof v === 'string' ? v : v?.['#text'] ?? '');

function extractImage(item: any, rawHtml: string): string | null {
  try {
    const enc = item?.enclosure;
    if (enc && typeof enc === 'object') {
      const url = enc['@_url'];
      const type = enc['@_type'] ?? '';
      if (url && (type.startsWith('image') || /\.(jpg|jpeg|png|webp|avif)/i.test(url))) return String(url);
    }
    const media = item?.['media:content'] || item?.['media:thumbnail'];
    if (media) {
      if (typeof media === 'object') {
        const url = media['@_url'] || media['url'];
        if (url) return String(url);
      } else if (Array.isArray(media)) {
        const u = media[0]?.['@_url'] || media[0]?.['url'];
        if (u) return String(u);
      }
    }
    if (rawHtml) {
      const imgMatch = rawHtml.match(/<img[^>]+src=["'](https?:\/\/[^"'>]+)["']/i);
      if (imgMatch && imgMatch[1]) return imgMatch[1];
    }
  } catch {
    // ignore parsing failure
  }
  return null;
}

export function parseFeed(xml: string): FeedItem[] {
  const doc = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@_', processEntities: true }).parse(xml);
  const rssItems = arr(doc?.rss?.channel?.item);
  const atomItems = arr(doc?.feed?.entry);
  const out: FeedItem[] = [];

  for (const i of rssItems) {
    const descRaw = String(i.description ?? '');
    const img = extractImage(i, descRaw);
    out.push({
      title: text(i.title).trim(),
      link: text(i.link).trim(),
      publishedAt: toDate(i.pubDate ?? i['dc:date']),
      summary: htmlToText(descRaw),
      imageUrl: img,
    });
  }

  for (const e of atomItems) {
    const links = arr(e.link);
    const href = (links.find((l: any) => !l['@_rel'] || l['@_rel'] === 'alternate') ?? links[0])?.['@_href'] ?? '';
    const contentRaw = String(e.summary ?? e.content ?? '');
    const img = extractImage(e, contentRaw);
    out.push({
      title: text(e.title).trim(),
      link: String(href).trim(),
      publishedAt: toDate(e.published ?? e.updated),
      summary: htmlToText(contentRaw),
      imageUrl: img,
    });
  }

  return out.filter((i) => i.title && i.link);
}

function toDate(v: unknown): Date | null {
  if (!v) return null;
  const d = new Date(text(v));
  return Number.isNaN(d.getTime()) ? null : d;
}

export function dedupeKey(title: string): string {
  const norm = title.normalize('NFC').toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, ' ').replace(/\s+/g, ' ').trim();
  return crypto.createHash('sha1').update(norm).digest('hex');
}

export interface IngestResult {
  created: number;
  grouped: number;
  duplicates: number;
  rejected: number;
  errors: string[];
  createdIds: string[];
  changed: { storyId: string; headline: string }[];
  reverified: number;
}

export async function ingestNews(
  prisma: PrismaClient,
  opts: { cfg?: ContentConfig; fetchText?: FetchFn; now?: Date; feeds?: FeedConfig[]; staleHours?: number; maxIngest?: number } = {},
): Promise<IngestResult> {
  const cfg = opts.cfg ?? contentConfig();
  const now = opts.now ?? new Date();
  const fetchText: FetchFn = opts.fetchText ?? ((u) => safeFetchText(u, cfg));
  const result: IngestResult = { created: 0, grouped: 0, duplicates: 0, rejected: 0, errors: [], createdIds: [], changed: [], reverified: 0 };

  let feeds = opts.feeds;
  if (!feeds || feeds.length === 0) {
    const row = await prisma.appConfig.findUnique({ where: { key: 'content.news_feeds' } });
    try {
      feeds = row ? (JSON.parse(row.value) as FeedConfig[]) : DEFAULT_FEEDS;
    } catch {
      feeds = DEFAULT_FEEDS;
    }
  }

  const dayStart = new Date(now);
  dayStart.setUTCHours(0, 0, 0, 0);
  const maxLimit = opts.maxIngest ?? cfg.maxIngestPerDay;
  const countToday = await prisma.newsStory.count({ where: { retrievedAt: { gte: dayStart } } });
  let budget = opts.maxIngest !== undefined ? opts.maxIngest : Math.max(0, maxLimit - countToday);
  const maxAgeMs = (opts.staleHours ?? 48) * 3_600_000;

  const reverifiedIds: string[] = [];
  for (const feed of feeds) {
    if (budget <= 0) break;
    let items: FeedItem[];
    try {
      const res = await fetchText(feed.url);
      items = parseFeed(res.text);
    } catch (e) {
      result.errors.push(`${feed.name}: ${(e as Error).message}`);
      continue;
    }

    for (const it of items) {
      if (budget <= 0) break;
      const pubDate = it.publishedAt ?? now;
      if (pubDate.getTime() > now.getTime() + 6 * 3_600_000 || now.getTime() - pubDate.getTime() > maxAgeMs) {
        result.rejected++;
        continue;
      }

      let canonical: string;
      try {
        const u = new URL(it.link, feed.url);
        if (u.protocol !== 'https:') throw new Error('http');
        u.hash = '';
        canonical = u.toString();
      } catch {
        result.rejected++;
        continue;
      }

      const key = dedupeKey(it.title);
      const known = await prisma.newsStory.findUnique({ where: { canonicalUrl: canonical } });
      if (known) {
        result.duplicates++;
        if (known.dedupeKey !== key) {
          const related = Array.isArray(known.relatedSources) ? (known.relatedSources as unknown[]) : [];
          await prisma.newsStory.update({
            where: { id: known.id },
            data: { relatedSources: [...related, { type: 'headline_change', headline: it.title.slice(0, 500), seenAt: now.toISOString() }] as Prisma.InputJsonValue },
          });
          result.changed.push({ storyId: known.id, headline: it.title });
        } else {
          reverifiedIds.push(known.id);
          result.reverified++;
        }
        continue;
      }

      const sameEvent = await prisma.newsStory.findFirst({
        where: { dedupeKey: key, publishedAt: { gte: new Date(pubDate.getTime() - 48 * 3_600_000) } },
      });
      if (sameEvent) {
        const related = Array.isArray(sameEvent.relatedSources) ? (sameEvent.relatedSources as unknown[]) : [];
        await prisma.newsStory.update({
          where: { id: sameEvent.id },
          data: { relatedSources: [...related, { publisher: feed.name, url: canonical, publishedAt: pubDate.toISOString() }] as Prisma.InputJsonValue },
        });
        result.grouped++;
        continue;
      }

      const isRegional = feed.isRegional ?? false;
      const subKind = isRegional ? 'REGIONAL' : 'TOP';
      const category = feed.category || (isRegional ? 'REGIONAL' : 'TOP_NEWS');

      const created = await prisma.newsStory.create({
        data: {
          originalHeadline: it.title.slice(0, 500),
          publisher: feed.name,
          canonicalUrl: canonical,
          dedupeKey: key,
          category,
          region: feed.region || null,
          isRegional,
          imageUrl: it.imageUrl || null,
          publishedAt: pubDate,
          retrievedAt: now,
          lastVerifiedAt: now,
          summary: it.summary.slice(0, 4000) || null,
        },
      });

      // Directly publish the news item so no admin approval is needed for news
      await prisma.shortVideo.create({
        data: {
          kind: 'NEWS',
          subKind,
          newsStoryId: created.id,
          title: it.title.slice(0, 500),
          category,
          region: feed.region || null,
          status: 'PUBLISHED',
          format: 'CARD_ONLY',
          description: it.summary.slice(0, 1000) || null,
          attribution: `स्रोत: ${feed.name}`,
          publishedAt: pubDate,
          thumbnailKey: it.imageUrl || null,
        },
      }).catch((e) => console.error('[ingest] failed to create direct ShortVideo for news:', e));

      result.created++;
      budget--;
      if (created?.id) result.createdIds.push(created.id);
    }
  }

  if (reverifiedIds.length > 0) {
    if (typeof (prisma.newsStory as any).updateMany === 'function') {
      await (prisma.newsStory as any).updateMany({
        where: { id: { in: reverifiedIds } },
        data: { lastVerifiedAt: now },
      }).catch(() => undefined);
    } else {
      for (const id of reverifiedIds) {
        await prisma.newsStory.update({ where: { id }, data: { lastVerifiedAt: now } }).catch(() => undefined);
      }
    }
  }

  return result;
}
