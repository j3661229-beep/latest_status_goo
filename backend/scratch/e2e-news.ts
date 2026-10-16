// One-shot, single-attempt first end-to-end run for a NEWS short. Never publishes (stages end at NEEDS_REVIEW).
import { PrismaClient } from '@prisma/client';
import { contentConfig } from '../src/lib/content/config';
import { safeFetchText, htmlToText } from '../src/lib/content/safe-fetch';
import { dedupeKey } from '../src/lib/content/ingest';
import { runStage, PipelineDeps, Stage } from '../src/lib/content/pipeline';
import { VertexGeminiProvider } from '../src/lib/content/script';
import { GoogleTtsProvider } from '../src/lib/content/tts';
import { gcsContentStorage } from '../src/lib/content/assets';

const URL_ = process.argv[2];
(async () => {
  const cfg = contentConfig();
  const prisma = new PrismaClient();
  // The PC clock on this machine is ~5.5h behind real time; take "now" from the source server's HTTP Date header.
  const hdr = (await fetch(URL_, { method: 'HEAD' })).headers.get('date');
  const now = hdr ? new Date(hdr) : new Date();
  console.log('trusted now (server clock):', now.toISOString(), '| PC clock:', new Date().toISOString());
  const r = await safeFetchText(URL_, cfg);
  const art = r.text.match(/<article[\s\S]*?<\/article>/i)?.[0] ?? r.text;
  const t = htmlToText(art).replace(/&#038;/g, '&');
  const m = t.match(/News On AIR \| ([A-Za-z]+ \d{1,2}, \d{4} \d{1,2}:\d{2} [AP]M)\s+(.*?)\s{1}(The |Union |Prime |Defence |Finance |Vice |Home )/);
  if (!m) throw new Error('Could not parse timestamp/headline from page');
  const stamp = m[1];
  const headline = t.slice(t.indexOf(stamp) + stamp.length).trim().split(/(?<=[a-z\)K])\s(?=The 6th)/)[0];
  const body = t.slice(t.indexOf(stamp) + stamp.length).trim();
  // Page shows IST wall-clock time.
  const dt = new Date(`${stamp.replace(/(\d+:\d+) ([AP]M)/, (_s, hm, ap) => { let [h, mi] = hm.split(':').map(Number); if (ap === 'PM' && h < 12) h += 12; if (ap === 'AM' && h === 12) h = 0; return `${String(h).padStart(2, '0')}:${String(mi).padStart(2, '0')}`; })} +05:30`.replace(/^([A-Za-z]+) (\d+), (\d{4}) /, (_s, mo, d, y) => `${mo} ${d}, ${y} `));
  if (Number.isNaN(dt.getTime())) throw new Error('bad date ' + stamp);
  console.log('headline:', headline.slice(0, 120));
  console.log('publishedAt:', dt.toISOString(), '| age hours:', ((now.getTime() - dt.getTime()) / 3.6e6).toFixed(2));

  const story = await prisma.newsStory.upsert({
    where: { canonicalUrl: r.finalUrl },
    create: { originalHeadline: headline.slice(0, 500), publisher: 'News On AIR (All India Radio)', canonicalUrl: r.finalUrl, dedupeKey: dedupeKey(headline), category: 'INDIA', publishedAt: dt, retrievedAt: now, lastVerifiedAt: now, summary: body.slice(0, 4000) },
    update: { lastVerifiedAt: now },
  });
  let video = await prisma.shortVideo.findFirst({ where: { newsStoryId: story.id } });
  video ??= await prisma.shortVideo.create({ data: { kind: 'NEWS', newsStoryId: story.id, title: story.originalHeadline.slice(0, 200), category: story.category, language: 'HINDI' } });
  console.log('story', story.id, 'video', video.id, 'status', video.status);

  const deps: PipelineDeps = { prisma, cfg, now: () => now, scriptProvider: new VertexGeminiProvider(cfg), tts: new GoogleTtsProvider(cfg), storage: gcsContentStorage, log: (m, x) => console.log('[pipeline]', m, x ?? '') };
  let stage: Stage | null = 'SCRIPT';
  while (stage) {
    console.log('--> stage', stage);
    const res: any = await runStage(deps, stage, video.id);
    console.log('    done; cost µUSD', res.costMicroUsd, 'next', res.next);
    stage = res.next ?? null;
  }
  const v = await prisma.shortVideo.findUnique({ where: { id: video.id } });
  console.log('FINAL', JSON.stringify({ id: v!.id, status: v!.status, durationSec: v!.durationSec, videoKey: v!.videoKey, thumbnailKey: v!.thumbnailKey, audioKey: v!.audioKey, costMicroUsd: v!.costMicroUsd, claims: (v!.claims as any[])?.length, warnings: v!.warnings }));
  await prisma.$disconnect();
})().catch((e) => { console.error('RUN FAILED:', e.message); process.exit(1); });
