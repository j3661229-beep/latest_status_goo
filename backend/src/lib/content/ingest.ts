// src/lib/content/ingest.ts
// News ingestion from admin-configured, allowlisted feeds (AppConfig key `content.news_feeds`:
// [{name,url,category}]). Only creates NewsStory rows — it never generates, approves or publishes.
// If feeds fail or contain nothing new, nothing is created (we never fabricate "latest news").
import crypto from 'crypto';
import { XMLParser } from 'fast-xml-parser';
import type { Prisma, PrismaClient } from '@prisma/client';
import { contentConfig, ContentConfig } from './config';
import { FetchFn, htmlToText, safeFetchText } from './safe-fetch';

export interface FeedItem { title: string; link: string; publishedAt: Date | null; summary: string }
export interface FeedConfig { name: string; url: string; category: string }

const arr = <T,>(v: T | T[] | undefined): T[] => (v === undefined ? [] : Array.isArray(v) ? v : [v]);
const text = (v: any): string => (typeof v === 'string' ? v : v?.['#text'] ?? '');

export function parseFeed(xml: string): FeedItem[] {
  const doc = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@_', processEntities: true }).parse(xml);
  const rssItems = arr(doc?.rss?.channel?.item);
  const atomItems = arr(doc?.feed?.entry);
  const out: FeedItem[] = [];
  for (const i of rssItems) {
    out.push({ title: text(i.title).trim(), link: text(i.link).trim(), publishedAt: toDate(i.pubDate ?? i['dc:date']), summary: htmlToText(text(i.description)) });
  }
  for (const e of atomItems) {
    const links = arr(e.link);
    const href = (links.find((l: any) => !l['@_rel'] || l['@_rel'] === 'alternate') ?? links[0])?.['@_href'] ?? '';
    out.push({ title: text(e.title).trim(), link: String(href).trim(), publishedAt: toDate(e.published ?? e.updated), summary: htmlToText(text(e.summary ?? e.content)) });
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
  created: number; grouped: number; duplicates: number; rejected: number; errors: string[];
  /** Ids of newly created stories (candidates for drafts). */
  createdIds: string[];
  /** Already-known stories whose headline at the source has since changed (possible correction). */
  changed: { storyId: string; headline: string }[];
  /** Already-known stories the feed still lists unchanged (counts as a fresh source check). */
  reverified: number;
}

export async function ingestNews(
  prisma: PrismaClient,
  opts: { cfg?: ContentConfig; fetchText?: FetchFn; now?: Date; feeds?: FeedConfig[]; staleHours?: number } = {},
): Promise<IngestResult> {
  const cfg = opts.cfg ?? contentConfig();
  const now = opts.now ?? new Date();
  const fetchText: FetchFn = opts.fetchText ?? ((u) => safeFetchText(u, cfg));
  const result: IngestResult = { created: 0, grouped: 0, duplicates: 0, rejected: 0, errors: [], createdIds: [], changed: [], reverified: 0 };

  let feeds = opts.feeds;
  if (!feeds) {
    const row = await prisma.appConfig.findUnique({ where: { key: 'content.news_feeds' } });
    try { feeds = row ? (JSON.parse(row.value) as FeedConfig[]) : []; } catch { feeds = []; result.errors.push('content.news_feeds is not valid JSON'); }
  }
  const dayStart = new Date(now); dayStart.setUTCHours(0, 0, 0, 0);
  let budget = cfg.maxIngestPerDay - (await prisma.newsStory.count({ where: { retrievedAt: { gte: dayStart } } }));
  const maxAgeMs = (opts.staleHours ?? 48) * 3_600_000;

  const reverifiedIds: string[] = [];
  for (const feed of feeds) {
    if (budget <= 0) break;
    let items: FeedItem[];
    try { items = parseFeed((await fetchText(feed.url)).text); }
    catch (e) { result.errors.push(`${feed.name}: ${(e as Error).message}`); continue; } // failure → no stories, no fabrication
    for (const it of items) {
      if (budget <= 0) break;
      // Validate source + publication time (default to now if feed does not include pubDate tag, e.g. PIB)
      const pubDate = it.publishedAt ?? now;
      if (pubDate.getTime() > now.getTime() + 6 * 3_600_000 || now.getTime() - pubDate.getTime() > maxAgeMs) { result.rejected++; continue; }
      let canonical: string;
      try { const u = new URL(it.link, feed.url); if (u.protocol !== 'https:') throw new Error('http'); u.hash = ''; canonical = u.toString(); } catch { result.rejected++; continue; }

      const key = dedupeKey(it.title);
      const known = await prisma.newsStory.findUnique({ where: { canonicalUrl: canonical } });
      if (known) {
        result.duplicates++;
        if (known.dedupeKey !== key) {
          // Same URL, different headline: the publisher edited it. Record it; the maintenance tick
          // takes any published video down for re-review (we never silently keep stale claims live).
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

      const sameEvent = await prisma.newsStory.findFirst({ where: { dedupeKey: key, publishedAt: { gte: new Date(pubDate.getTime() - 48 * 3_600_000) } } });
      if (sameEvent) {
        const related = Array.isArray(sameEvent.relatedSources) ? (sameEvent.relatedSources as unknown[]) : [];
        await prisma.newsStory.update({
          where: { id: sameEvent.id },
          data: { relatedSources: [...related, { publisher: feed.name, url: canonical, publishedAt: pubDate.toISOString() }] as Prisma.InputJsonValue },
        });
        result.grouped++; continue;
      }
      const created = await prisma.newsStory.create({
        data: {
          originalHeadline: it.title.slice(0, 500), publisher: feed.name, canonicalUrl: canonical, dedupeKey: key,
          category: feed.category, publishedAt: pubDate, retrievedAt: now, lastVerifiedAt: now,
          summary: it.summary.slice(0, 4000) || null,
        },
      });
      result.created++; budget--;
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
