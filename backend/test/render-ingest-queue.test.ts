import { describe, it, expect, vi } from 'vitest';
import { buildCaptions, buildAss, buildFfmpegArgs } from '../src/lib/content/render';
import { prepareNarration } from '../src/lib/content/tts';
import { parseFeed, dedupeKey, ingestNews } from '../src/lib/content/ingest';
import { enqueueStage, startGeneration } from '../src/lib/content/queue';
import { contentConfig, costs } from '../src/lib/content/config';

describe('render helpers', () => {
  it('captions cover the whole narration without gaps or overlaps', () => {
    const c = buildCaptions(['पहला भाग', 'दूसरा लंबा भाग यहाँ', 'तीसरा'], 24);
    expect(c[0].start).toBe(0);
    expect(c[c.length - 1].end).toBeCloseTo(24, 1);
    for (let i = 1; i < c.length; i++) expect(c[i].start).toBeCloseTo(c[i - 1].end, 1);
    expect(buildCaptions([], 10)).toEqual([]);
  });
  it('ASS has title, captions, brand, and a source end card; strips override braces', () => {
    const ass = buildAss({ title: 'शीर्षक', brand: 'स्टेटस गो', durationSec: 20, captions: [{ start: 0, end: 5, text: '{\\b1}हैक' }], endCardLines: ['स्रोत: PIB', 'AI-सहायता प्राप्त सारांश'] }, { fontName: 'Noto Sans Devanagari' });
    expect(ass).toContain('Style: Cap,Noto Sans Devanagari');
    expect(ass).toMatch(/Dialogue: 0,0:00:16\.50,0:00:20\.00,End,.*स्रोत: PIB\\NAI/);
    expect(ass).not.toContain('{\\b1}');
  });
  it('ffmpeg args: H.264 + AAC, 1080x1920, faststart, no shell string', () => {
    const a = buildFfmpegArgs({ audio: 'a.mp3', ass: 'C:\\t\\c.ass', out: 'o.mp4', durationSec: 28.5, fontsDir: '/fonts' });
    expect(a).toEqual(expect.arrayContaining(['libx264', 'aac', '+faststart']));
    expect(a.join(' ')).toContain('s=1080x1920');
    expect(a[a.indexOf('-vf') + 1]).toContain("fontsdir='/fonts'");
    expect(a[a.indexOf('-vf') + 1]).toContain('C\\:/t/c.ass'); // drive colon escaped for the filter graph
  });
  it('ffmpeg args (animated): generates filter_complex with moving gradient, audio visualizer, progress bar', () => {
    const a = buildFfmpegArgs({ audio: 'a.mp3', ass: 'C:\\t\\c.ass', out: 'o.mp4', durationSec: 28.5, fontsDir: '/fonts', animated: true });
    expect(a).toEqual(expect.arrayContaining(['libx264', 'aac', '+faststart']));
    expect(a.join(' ')).toContain('gradients=s=1080x1920');
    expect(a.join(' ')).toContain('showfreqs=s=800x140');
    expect(a.join(' ')).toContain('drawbox');
    expect(a).toContain('-filter_complex');
  });
  it('ffmpeg args (animated with avatar): renders photorealistic studio anchor broadcast with news card and audio visualizer', () => {
    const a = buildFfmpegArgs({
      audio: 'a.mp3',
      ass: 'C:\\t\\c.ass',
      out: 'o.mp4',
      durationSec: 28.5,
      fontsDir: '/fonts',
      animated: true,
      avatarVideo: 'avatar.mp4',
    });
    expect(a).toEqual(expect.arrayContaining(['libx264', 'aac', '+faststart', '-i', 'avatar.mp4']));
    expect(a.join(' ')).toContain('scale=1080:1920');
    expect(a.join(' ')).toContain('showfreqs=s=880x90');
    expect(a.join(' ')).toContain('drawbox');
    expect(a).toContain('-filter_complex');
  });
  it('ASS generates rich animated scene cards and badges when scenes provided', () => {
    const ass = buildAss({
      title: 'मुख्य शीर्षक',
      brand: 'स्टेटस गो',
      durationSec: 20,
      captions: [{ start: 0, end: 10, text: 'पहला दृश्य विवरण' }],
      scenes: [{ visual: 'KEY_FACT', text: '50000 रुपये की सहायता', caption: 'पहला दृश्य विवरण' }],
      kind: 'SCHEME',
      category: 'शिक्षा',
      endCardLines: ['स्रोत: आधिकारिक पोर्टल', 'AI-सहायता प्राप्त सारांश'],
    }, { fontName: 'Noto Sans Devanagari' });
    expect(ass).toContain('Style: Badge');
    expect(ass).toContain('Style: Highlight');
    expect(ass).toContain('वित्तीय सहायता व लाभ');
    expect(ass).toContain('50000 रुपये की सहायता');
  });
  it('TTS prep expands symbols without changing numbers', () => {
    expect(prepareNarration('₹6,000 की सहायता, 50% छूट, PM KYC')).toBe('6,000 रुपये की सहायता, 50 प्रतिशत छूट, पी एम के वाई सी');
  });
  it('cost estimates come from configurable pricing', () => {
    const cfg = contentConfig({ CONTENT_PRICE_TTS_PER_MCHAR: '32' } as any);
    expect(costs.tts(cfg, 1_000_000)).toBe(32_000_000);
    expect(costs.tts(contentConfig({} as any), 1_000_000)).toBe(16_000_000);
  });
});

const RSS = (items: string) => `<?xml version="1.0"?><rss version="2.0"><channel>${items}</channel></rss>`;
const item = (title: string, link: string, pub: Date, desc = 'सारांश '.repeat(30)) =>
  `<item><title>${title}</title><link>${link}</link><pubDate>${pub.toUTCString()}</pubDate><description><![CDATA[<p>${desc}</p>]]></description></item>`;
const NOW = new Date('2026-10-15T12:00:00Z');
const hAgo = (h: number) => new Date(NOW.getTime() - h * 3_600_000);

function ingestPrisma() {
  const stories: any[] = [];
  return {
    stories,
    prisma: {
      appConfig: { findUnique: vi.fn().mockResolvedValue(null) },
      newsStory: {
        count: vi.fn(async () => stories.length),
        findUnique: vi.fn(async ({ where }: any) => stories.find((s) => s.canonicalUrl === where.canonicalUrl) ?? null),
        findFirst: vi.fn(async ({ where }: any) => stories.find((s) => s.dedupeKey === where.dedupeKey) ?? null),
        create: vi.fn(async ({ data }: any) => { const st = { id: `n${stories.length}`, relatedSources: [], ...data }; stories.push(st); return st; }),
        update: vi.fn(async ({ where, data }: any) => { Object.assign(stories.find((s) => s.id === where.id), data); }),
      },
    } as any,
  };
}
const feeds = [{ name: 'PIB', url: 'https://pib.gov.in/rss', category: 'INDIA' }];
const cfg = contentConfig({} as any);

describe('news ingestion', () => {
  it('parses RSS and Atom', () => {
    expect(parseFeed(RSS(item('शीर्षक', 'https://a.in/1', hAgo(1))))[0]).toMatchObject({ title: 'शीर्षक', link: 'https://a.in/1' });
    const atom = `<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>T</title><link href="https://a.in/2"/><updated>${hAgo(1).toISOString()}</updated><summary>s</summary></entry></feed>`;
    expect(parseFeed(atom)[0].link).toBe('https://a.in/2');
  });
  it('creates only fresh, valid, https stories with attribution metadata', async () => {
    const { prisma, stories } = ingestPrisma();
    const xml = RSS([
      item('ताज़ा ख़बर', 'https://pib.gov.in/a', hAgo(2)),
      item('पुरानी ख़बर', 'https://pib.gov.in/b', hAgo(200)),          // stale
      item('भविष्य की ख़बर', 'https://pib.gov.in/c', new Date(NOW.getTime() + 86_400_000)), // future date
      item('असुरक्षित', 'http://pib.gov.in/d', hAgo(1)),               // not https
    ].join(''));
    const r = await ingestNews(prisma, { cfg, now: NOW, feeds, fetchText: async () => ({ text: xml }) });
    expect(r).toMatchObject({ created: 1, rejected: 3 });
    expect(stories[0]).toMatchObject({ publisher: 'PIB', canonicalUrl: 'https://pib.gov.in/a', category: 'INDIA' });
    expect(stories[0].publishedAt).toBeInstanceOf(Date);
    expect(stories[0].retrievedAt).toEqual(NOW);
  });
  it('dedupes by URL and groups the same event from another publisher', async () => {
    const { prisma, stories } = ingestPrisma();
    const f1 = RSS(item('बड़ी घोषणा!', 'https://pib.gov.in/a', hAgo(3)));
    const f2 = RSS(item('बड़ी  घोषणा', 'https://other.in/z', hAgo(2)) + item('बड़ी घोषणा!', 'https://pib.gov.in/a', hAgo(3)));
    await ingestNews(prisma, { cfg, now: NOW, feeds, fetchText: async () => ({ text: f1 }) });
    const r = await ingestNews(prisma, { cfg, now: NOW, feeds, fetchText: async () => ({ text: f2 }) });
    expect(r).toMatchObject({ created: 0, grouped: 1, duplicates: 1 });
    expect(stories).toHaveLength(1);
    expect(stories[0].relatedSources[0].url).toBe('https://other.in/z');
    expect(dedupeKey('बड़ी घोषणा!')).toBe(dedupeKey('  बड़ी   घोषणा '));
  });
  it('creates nothing and reports the error when a feed fails (no fabricated news)', async () => {
    const { prisma, stories } = ingestPrisma();
    const r = await ingestNews(prisma, { cfg, now: NOW, feeds, fetchText: async () => { throw new Error('HTTP 403'); } });
    expect(stories).toHaveLength(0);
    expect(r.created).toBe(0);
    expect(r.errors[0]).toMatch(/PIB: HTTP 403/);
  });
  it('honours the daily ingest cap', async () => {
    const { prisma, stories } = ingestPrisma();
    const xml = RSS([1, 2, 3].map((i) => item(`ख़बर ${i}`, `https://pib.gov.in/${i}`, hAgo(1))).join(''));
    await ingestNews(prisma, { cfg: { ...cfg, maxIngestPerDay: 2 }, now: NOW, feeds, fetchText: async () => ({ text: xml }) });
    expect(stories).toHaveLength(2);
  });
});

describe('queue', () => {
  const mkQueue = (existingState?: string) => {
    const remove = vi.fn();
    return {
      add: vi.fn().mockResolvedValue({}),
      getJob: vi.fn().mockResolvedValue(existingState ? { getState: async () => existingState, remove } : null),
      remove,
    };
  };
  it('uses a deterministic job id so duplicate requests collapse', async () => {
    const q = mkQueue();
    await enqueueStage('SCRIPT', 'v1', 2, q as any);
    expect(q.add.mock.calls[0][2]).toMatchObject({ jobId: 'SCRIPT-v1-v2', attempts: 3, backoff: { type: 'exponential' } });
  });
  it('clears a retained failed job so a retry is actually queued, but leaves active ones alone', async () => {
    const failed = mkQueue('failed'); await enqueueStage('RENDER', 'v1', 1, failed as any);
    expect(failed.remove).toHaveBeenCalled();
    const active = mkQueue('active'); await enqueueStage('RENDER', 'v1', 1, active as any);
    expect(active.remove).not.toHaveBeenCalled();
  });
  it('startGeneration picks the first unfinished stage', async () => {
    const q = mkQueue();
    const prisma = (v: any) => ({ shortVideo: { findUnique: async () => v } }) as any;
    expect(await startGeneration(prisma({ status: 'DRAFT', script: null, audioKey: null, scriptVersion: 1 }), 'v', q as any)).toBe('SCRIPT');
    expect(await startGeneration(prisma({ status: 'SCRIPT_READY', script: {}, audioKey: null, scriptVersion: 1 }), 'v', q as any)).toBe('NARRATION');
    expect(await startGeneration(prisma({ status: 'GENERATING', script: {}, audioKey: 'a', scriptVersion: 1 }), 'v', q as any)).toBe('RENDER');
  });
});
