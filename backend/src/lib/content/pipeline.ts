// src/lib/content/pipeline.ts
// Shared VIDEO generation pipeline for scheme and news items. Each stage is a pure-ish function over
// injected dependencies (DB, providers, storage, exec) so it can be tested with mocks and run from
// a BullMQ worker.
//
// The pipeline only ever acts on `videoState` — never on the card's editorial `status` — and only
// after an admin explicitly requested a video (videoState QUEUED/GENERATING). A failed video sets
// videoState = FAILED and leaves the card (status, text, publication) untouched. Stages never
// publish and never approve: a READY video still needs an explicit admin approval to be playable.
//   SCRIPT    sources → validated structured script          (QUEUED → GENERATING)
//   NARRATION Hindi TTS (cached per script version)          (GENERATING)
//   RENDER    ffmpeg render + thumbnail + upload             (GENERATING → READY, awaiting approval)
import type { ContentJobType, Prisma, PrismaClient } from '@prisma/client';
import { contentConfig, ContentConfig } from './config';
import { ScriptProvider, generateValidatedScript, ScriptValidationError, SourceDoc, Script } from './script';
import { TtsProvider, narrate } from './tts';
import { renderShort, Exec, defaultExec } from './render';
import { safeFetchText, htmlToText, UnsafeUrlError, FetchFn } from './safe-fetch';
import { ContentStorage, contentObjectKey } from './assets';

export type Stage = Extract<ContentJobType, 'SCRIPT' | 'NARRATION' | 'RENDER'>;

/** Errors that retrying cannot fix (bad content, limits, unsafe URL). The worker will not retry these. */
export class PermanentError extends Error {}
export class SkippedError extends Error {}

export interface PipelineDeps {
  prisma: PrismaClient;
  scriptProvider: ScriptProvider;
  tts: TtsProvider;
  storage: ContentStorage;
  cfg?: ContentConfig;
  exec?: Exec;
  fetchText?: FetchFn;
  now?: () => Date;
  log?: (msg: string, extra?: object) => void;
}

const include = { scheme: true, newsStory: true } satisfies Prisma.ShortVideoInclude;
type Video = Prisma.ShortVideoGetPayload<{ include: typeof include }>;

/** Caption lines to burn into the video: reviewer-edited captions win over the generated scene captions. */
export function captionTexts(v: { captions: unknown; script: unknown }): string[] {
  const edited = Array.isArray(v.captions)
    ? (v.captions as { text?: unknown }[]).map((c) => (typeof c?.text === 'string' ? c.text.trim() : '')).filter(Boolean)
    : [];
  if (edited.length) return edited;
  const scenes = (v.script as Script | null)?.scenes;
  return Array.isArray(scenes) ? scenes.map((x) => x.caption) : [];
}

export const idempotencyKey = (type: Stage, id: string, version: number) => `${type}-${id}-v${version}`;

// ── Limits / budget ──────────────────────────────────────────
export async function assertWithinLimits(d: PipelineDeps): Promise<void> {
  const cfg = d.cfg ?? contentConfig();
  const now = (d.now ?? (() => new Date()))();
  const dayStart = new Date(now); dayStart.setUTCHours(0, 0, 0, 0);
  const monthStart = new Date(now); monthStart.setUTCDate(1); monthStart.setUTCHours(0, 0, 0, 0);

  const [jobsToday, monthCost] = await Promise.all([
    d.prisma.contentJob.count({ where: { startedAt: { gte: dayStart } } }),
    d.prisma.contentJob.aggregate({ _sum: { costMicroUsd: true }, where: { queuedAt: { gte: monthStart } } }),
  ]);
  if (jobsToday >= cfg.maxJobsPerDay) throw new PermanentError(`Daily generation limit reached (${cfg.maxJobsPerDay})`);
  const spent = monthCost._sum.costMicroUsd ?? 0;
  if (spent >= cfg.monthlyBudgetMicroUsd) throw new PermanentError('Monthly content budget exhausted');
  if (spent >= cfg.monthlyBudgetMicroUsd * cfg.budgetAlertRatio) {
    d.log?.('content budget alert', { spentMicroUsd: spent, budgetMicroUsd: cfg.monthlyBudgetMicroUsd });
  }
}

// ── Job bookkeeping ──────────────────────────────────────────
/** Returns the job row to run, or null when this exact work is already done/in progress/cancelled. */
async function beginJob(d: PipelineDeps, type: Stage, v: Video) {
  const cfg = d.cfg ?? contentConfig();
  const key = idempotencyKey(type, v.id, v.scriptVersion);
  const existing = await d.prisma.contentJob.findUnique({ where: { idempotencyKey: key } });
  if (existing?.state === 'SUCCEEDED' || existing?.state === 'CANCELLED') return null;
  if (existing?.state === 'RUNNING' && existing.startedAt && Date.now() - existing.startedAt.getTime() < cfg.jobTimeoutMs * 2) return null;
  await assertWithinLimits(d);
  const now = (d.now ?? (() => new Date()))();
  return d.prisma.contentJob.upsert({
    where: { idempotencyKey: key },
    create: { type, shortVideoId: v.id, idempotencyKey: key, state: 'RUNNING', attempts: 1, maxAttempts: cfg.maxAttempts, startedAt: now },
    update: { state: 'RUNNING', attempts: { increment: 1 }, startedAt: now, failureReason: null, finishedAt: null },
  });
}

async function finishJob(d: PipelineDeps, jobId: string, data: { costMicroUsd: number }) {
  await d.prisma.contentJob.update({
    where: { id: jobId },
    data: { state: 'SUCCEEDED', finishedAt: (d.now ?? (() => new Date()))(), costMicroUsd: data.costMicroUsd },
  });
}

/** Admin-facing failure text: never leaks URLs, paths, keys or provider internals. */
export function sanitizeFailure(err: Error): string {
  if (!(err instanceof PermanentError)) return 'Video generation failed because of a temporary service problem. Please try again.';
  const msg = err.message
    .replace(/https?:\/\/\S+/gi, '[link]')
    .replace(/[A-Za-z]:\\\S+|\/(?:[\w.-]+\/)+[\w.-]+/g, '[path]')
    .replace(/\s+/g, ' ')
    .trim();
  return msg.slice(0, 200) || 'Video generation failed.';
}

/** Called by the worker on a failed attempt. `final` = no more retries → the VIDEO becomes FAILED (the card is untouched). */
export async function recordFailure(d: PipelineDeps, type: Stage, videoId: string, err: Error, final: boolean) {
  const v = await d.prisma.shortVideo.findUnique({ where: { id: videoId }, select: { scriptVersion: true } });
  if (!v) return;
  const key = idempotencyKey(type, videoId, v.scriptVersion);
  await d.prisma.contentJob.updateMany({
    where: { idempotencyKey: key, state: { not: 'CANCELLED' } },
    data: { state: 'FAILED', failureReason: err.message.slice(0, 1000), finishedAt: (d.now ?? (() => new Date()))() },
  });
  if (final) {
    await d.prisma.shortVideo.updateMany({
      where: { id: videoId, videoState: { in: ['QUEUED', 'GENERATING'] } },
      data: { videoState: 'FAILED', videoFailureReason: sanitizeFailure(err) },
    });
  }
}

async function isCancelled(d: PipelineDeps, jobId: string) {
  return (await d.prisma.contentJob.findUnique({ where: { id: jobId }, select: { state: true } }))?.state === 'CANCELLED';
}

async function load(d: PipelineDeps, id: string): Promise<Video> {
  const v = await d.prisma.shortVideo.findUnique({ where: { id }, include });
  if (!v) throw new PermanentError('Content not found');
  return v;
}

/**
 * Gate for every stage: the work must have been explicitly requested by an admin and not since
 * cancelled/reset. This is what guarantees nothing renders for CARD_ONLY or un-requested items.
 */
function assertRequested(v: Pick<Video, 'format' | 'videoState'>) {
  if (v.format !== 'CARD_WITH_VIDEO' || (v.videoState !== 'QUEUED' && v.videoState !== 'GENERATING')) {
    throw new SkippedError(`Video not requested (format ${v.format}, state ${v.videoState})`);
  }
}

/** QUEUED → GENERATING when the first stage starts (no-op if already generating). */
async function markGenerating(d: PipelineDeps, id: string) {
  await d.prisma.shortVideo.updateMany({ where: { id, videoState: 'QUEUED' }, data: { videoState: 'GENERATING' } });
}

// ── Stage 1: sources + script ────────────────────────────────
export async function collectSources(d: PipelineDeps, v: Video): Promise<SourceDoc[]> {
  const cfg = d.cfg ?? contentConfig();
  const fetchText: FetchFn = d.fetchText ?? ((u) => safeFetchText(u, cfg));
  const docs: SourceDoc[] = [];

  if (v.kind === 'SCHEME') {
    const s = v.scheme;
    if (!s) throw new PermanentError('Scheme record missing');
    if (!s.lastVerifiedAt) throw new PermanentError('Scheme must be verified by a reviewer before generation');
    if (s.sourceUrls.length === 0) throw new PermanentError('Scheme has no official source URLs');
    // Human-entered, reviewer-verified fields are a first-class source.
    docs.push({
      url: s.sourceUrls[0], publisher: s.department ?? undefined,
      text: [
        `योजना: ${s.nameHi} (${s.officialName})`, s.department && `विभाग: ${s.department}`,
        ...s.benefits.map((b) => `लाभ: ${b}`), ...s.eligibility.map((e) => `पात्रता: ${e}`),
        ...s.documents.map((x) => `दस्तावेज़: ${x}`), ...s.applicationSteps.map((x, i) => `आवेदन चरण ${i + 1}: ${x}`),
        s.applicationUrl && `आधिकारिक आवेदन वेबसाइट: ${s.applicationUrl}`,
      ].filter(Boolean).join('\n'),
    });
    for (const url of s.sourceUrls.slice(1, 4)) {
      try { docs.push({ url, text: htmlToText((await fetchText(url)).text) }); }
      catch (e) { d.log?.('source fetch skipped', { url, reason: (e as Error).message }); }
    }
  } else {
    const n = v.newsStory;
    if (!n) throw new PermanentError('News story record missing');
    let text = n.summary ?? '';
    try {
      const f = await fetchText(n.canonicalUrl);
      const t = htmlToText(f.text);
      if (t.length > text.length) text = t;
    } catch (e) {
      if (e instanceof UnsafeUrlError && !text) throw new PermanentError(`Source not retrievable and no stored excerpt: ${e.message}`);
      d.log?.('article fetch failed, using stored excerpt', { reason: (e as Error).message });
    }
    if (!text || text.length < 80) throw new PermanentError('Not enough verified source text to summarise (will not use model knowledge)');
    docs.push({ url: n.canonicalUrl, publisher: n.publisher, publishedAt: n.publishedAt.toISOString(), text: `${n.originalHeadline}\n${text}` });
  }
  return docs;
}

export async function runScriptStage(d: PipelineDeps, videoId: string) {
  const cfg = d.cfg ?? contentConfig();
  const v = await load(d, videoId);
  assertRequested(v);
  const job = await beginJob(d, 'SCRIPT', v);
  if (!job) throw new SkippedError('Script stage already done or running');
  await markGenerating(d, videoId);
  try {
    const sources = await collectSources(d, v);
    if (await isCancelled(d, job.id)) throw new SkippedError('Cancelled');

    const known = v.scheme ? [v.scheme.applicationUrl].filter(Boolean) as string[] : [];
    const r = await generateValidatedScript(d.scriptProvider, {
      kind: v.kind, language: 'HINDI', category: v.category, targetSeconds: 28, sources,
    }, cfg, known);

    const cur = await load(d, videoId);
    assertRequested(cur);
    // The card's text is admin-owned: the generated script only fills card fields that are still empty.
    await d.prisma.shortVideo.update({ where: { id: videoId }, data: {
      ...(!cur.hook?.trim() && { hook: r.script.hook }),
      ...(!cur.description?.trim() && { description: r.script.description }),
      ...(!cur.attribution?.trim() && { attribution: r.script.attributionText }),
      script: r.script as unknown as Prisma.InputJsonValue,
      captions: r.script.scenes.map((sc, i) => ({ i, text: sc.caption })) as unknown as Prisma.InputJsonValue,
      claims: r.script.claims as unknown as Prisma.InputJsonValue,
      warnings: r.script.warnings as unknown as Prisma.InputJsonValue,
      aiMeta: { ...(typeof cur.aiMeta === 'object' && cur.aiMeta ? cur.aiMeta as object : {}), script: { provider: r.provider, model: r.model, sourceUrls: sources.map((s) => s.url) } },
      costMicroUsd: { increment: r.costMicroUsd },
      // Regenerating an existing script invalidates old media and starts a new version.
      ...(cur.script ? { scriptVersion: { increment: 1 }, videoKey: null, audioKey: null, thumbnailKey: null } : {}),
    } });
    await finishJob(d, job.id, { costMicroUsd: r.costMicroUsd });
    return { next: 'NARRATION' as Stage, costMicroUsd: r.costMicroUsd };
  } catch (e) {
    if (e instanceof ScriptValidationError || e instanceof UnsafeUrlError) throw new PermanentError((e as Error).message);
    throw e;
  }
}

// ── Stage 2: narration ───────────────────────────────────────
export async function runNarrationStage(d: PipelineDeps, videoId: string) {
  const cfg = d.cfg ?? contentConfig();
  const v = await load(d, videoId);
  assertRequested(v);
  const script = v.script as unknown as Script | null;
  if (!script?.narration) throw new PermanentError('No script to narrate');
  const meta = (v.aiMeta ?? {}) as Record<string, any>;

  // Cache: audio is generated once per script version.
  if (v.audioKey && meta.tts?.scriptVersion === v.scriptVersion) {
    await markGenerating(d, videoId);
    return { next: 'RENDER' as Stage, costMicroUsd: 0, cached: true };
  }
  const job = await beginJob(d, 'NARRATION', v);
  if (!job) throw new SkippedError('Narration already done or running');
  await markGenerating(d, videoId);

  const r = await narrate(d.tts, script.narration, cfg);
  if (await isCancelled(d, job.id)) throw new SkippedError('Cancelled');
  const key = contentObjectKey('audio', v.id, v.scriptVersion, 'mp3');
  await d.storage.put(key, r.audio, 'audio/mpeg');

  const cur = await load(d, videoId);
  assertRequested(cur);
  await d.prisma.shortVideo.update({
    where: { id: v.id },
    data: {
      audioKey: key,
      aiMeta: { ...meta, tts: { provider: r.provider, voice: r.voice, chars: r.chars, scriptVersion: v.scriptVersion } },
      costMicroUsd: { increment: r.costMicroUsd },
    },
  });
  await finishJob(d, job.id, { costMicroUsd: r.costMicroUsd });
  return { next: 'RENDER' as Stage, costMicroUsd: r.costMicroUsd, cached: false };
}

// ── Stage 3: render + thumbnail + upload ─────────────────────
export async function runRenderStage(d: PipelineDeps, videoId: string) {
  const cfg = d.cfg ?? contentConfig();
  const v = await load(d, videoId);
  assertRequested(v);
  const script = v.script as unknown as Script | null;
  if (!script || !v.audioKey) throw new PermanentError('Script or narration audio missing');
  const job = await beginJob(d, 'RENDER', v);
  if (!job) throw new SkippedError('Render already done or running');
  await markGenerating(d, videoId);

  const audio = await d.storage.get(v.audioKey);
  const endCard = v.kind === 'SCHEME'
    ? [script.attributionText, v.scheme?.applicationUrl ? `आधिकारिक वेबसाइट: ${v.scheme.applicationUrl}` : '', 'AI-सहायता प्राप्त सारांश']
    : [script.attributionText, v.newsStory ? `${v.newsStory.publisher} · ${v.newsStory.publishedAt.toLocaleDateString('en-IN')}` : '', 'AI-सहायता प्राप्त सारांश'];
  const rendered = await renderShort(audio, {
    title: script.title,
    brand: 'स्टेटस गो',
    sceneCaptions: captionTexts(v),
    scenes: (script as any).scenes,
    category: v.category,
    kind: v.kind,
    endCardLines: endCard.filter(Boolean),
  }, cfg, d.exec ?? defaultExec);
  if (await isCancelled(d, job.id)) throw new SkippedError('Cancelled');

  const vKey = contentObjectKey('video', v.id, v.scriptVersion, 'mp4');
  const tKey = contentObjectKey('thumb', v.id, v.scriptVersion, 'jpg');
  await d.storage.put(vKey, rendered.video, 'video/mp4');
  await d.storage.put(tKey, rendered.thumbnail, 'image/jpeg');

  // Atomic: only if the video is still wanted (not cancelled / reset by an admin while rendering).
  // A fresh render is never auto-approved: an admin must preview and approve it.
  const done = await d.prisma.shortVideo.updateMany({
    where: { id: videoId, format: 'CARD_WITH_VIDEO', videoState: { in: ['QUEUED', 'GENERATING'] }, scriptVersion: v.scriptVersion },
    data: {
      videoKey: vKey, thumbnailKey: tKey, durationSec: rendered.durationSec,
      videoState: 'READY', videoFailureReason: null, videoApprovedAt: null, videoApprovedById: null,
      costMicroUsd: { increment: rendered.costMicroUsd },
    },
  });
  if (done.count === 0) throw new SkippedError('Video request was cancelled or changed during rendering');
  await finishJob(d, job.id, { costMicroUsd: rendered.costMicroUsd });
  return { next: null, costMicroUsd: rendered.costMicroUsd };
}

export async function runStage(d: PipelineDeps, stage: Stage, videoId: string) {
  switch (stage) {
    case 'SCRIPT': return runScriptStage(d, videoId);
    case 'NARRATION': return runNarrationStage(d, videoId);
    case 'RENDER': return runRenderStage(d, videoId);
  }
}
