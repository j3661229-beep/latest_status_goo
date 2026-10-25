import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  captionTexts, runScriptStage, runNarrationStage, runRenderStage, runStage, recordFailure, assertWithinLimits,
  PermanentError, SkippedError, PipelineDeps, sanitizeFailure,
} from '../src/lib/content/pipeline';
import { contentConfig } from '../src/lib/content/config';
import { RenderError } from '../src/lib/content/render';
import { ScriptProvider } from '../src/lib/content/script';

const URL1 = 'https://pmkisan.gov.in/about';
const SRC_LINE = 'पात्र किसान परिवारों को प्रति वर्ष 6,000 रुपये की सहायता दी जाती है';
const goodScript = () => ({
  title: 'पीएम किसान योजना', hook: 'किसानों के लिए सालाना सहायता',
  narration: 'पीएम किसान योजना में पात्र किसान परिवारों को प्रति वर्ष 6000 रुपये की सहायता दी जाती है। पात्रता की जाँच आधिकारिक वेबसाइट पर करें।',
  scenes: [{ text: 'योजना', caption: 'पीएम किसान', visual: 'HEADLINE_CARD' }, { text: 'लाभ', caption: 'प्रति वर्ष 6000 रुपये', visual: 'KEY_FACT' }],
  keyFacts: ['6000 रुपये'], claims: [{ text: 'सालाना सहायता', sourceUrl: URL1, sourceQuote: SRC_LINE }],
  category: 'FARMER', description: 'योजना का सरल सारांश।', attributionText: 'स्रोत: pmkisan.gov.in',
  thumbnailText: 'पीएम किसान', warnings: [], estimatedDurationSec: 26,
});

/** Tiny in-memory Prisma stand-in covering exactly what the pipeline touches. */
function fakePrisma(initial: any) {
  const videos = new Map<string, any>([[initial.id, { ...initial }]]);
  const jobs = new Map<string, any>();
  let jobSeq = 0;
  const apply = (v: any, data: any) => {
    for (const [k, val] of Object.entries<any>(data)) {
      if (val && typeof val === 'object' && 'increment' in val) v[k] = (v[k] ?? 0) + val.increment;
      else v[k] = val;
    }
  };
  const p: any = {
    shortVideo: {
      findUnique: vi.fn(async ({ where }: any) => (videos.has(where.id) ? { ...videos.get(where.id) } : null)),
      updateMany: vi.fn(async ({ where, data }: any) => {
        const v = videos.get(where.id);
        if (!v || (where.status && v.status !== where.status)) return { count: 0 };
        if (where.format && v.format !== where.format) return { count: 0 };
        if (where.scriptVersion !== undefined && v.scriptVersion !== where.scriptVersion) return { count: 0 };
        if (where.videoState) {
          const ok = typeof where.videoState === 'string' ? v.videoState === where.videoState : where.videoState.in.includes(v.videoState);
          if (!ok) return { count: 0 };
        }
        apply(v, data); return { count: 1 };
      }),
      update: vi.fn(async ({ where, data }: any) => { apply(videos.get(where.id), data); return videos.get(where.id); }),
    },
    contentJob: {
      findUnique: vi.fn(async ({ where }: any) => {
        if (where.idempotencyKey) return jobs.get(where.idempotencyKey) ?? null;
        return [...jobs.values()].find((j) => j.id === where.id) ?? null;
      }),
      upsert: vi.fn(async ({ where, create, update }: any) => {
        const ex = jobs.get(where.idempotencyKey);
        if (ex) { apply(ex, update); return ex; }
        const j = { id: `j${++jobSeq}`, costMicroUsd: 0, ...create }; jobs.set(where.idempotencyKey, j); return j;
      }),
      update: vi.fn(async ({ where, data }: any) => { const j = [...jobs.values()].find((x) => x.id === where.id)!; apply(j, data); return j; }),
      updateMany: vi.fn(async ({ where, data }: any) => {
        const j = jobs.get(where.idempotencyKey); if (!j) return { count: 0 }; apply(j, data); return { count: 1 };
      }),
      count: vi.fn(async () => [...jobs.values()].filter((j) => j.startedAt).length),
      aggregate: vi.fn(async () => ({ _sum: { costMicroUsd: [...jobs.values()].reduce((a, j) => a + (j.costMicroUsd ?? 0), 0) } })),
    },
  };
  return { prisma: p, videos, jobs };
}

const baseVideo = (over: any = {}) => ({
  id: 'v1', kind: 'SCHEME', status: 'DRAFT', format: 'CARD_WITH_VIDEO', videoState: 'QUEUED', category: 'FARMER', scriptVersion: 1, script: null, audioKey: null, videoKey: null,
  aiMeta: null, costMicroUsd: 0, newsStory: null, newsStoryId: null, schemeId: 's1',
  scheme: {
    officialName: 'PM Kisan', nameHi: 'पीएम किसान', department: 'कृषि विभाग', benefits: [SRC_LINE], eligibility: [], documents: [], applicationSteps: [],
    applicationUrl: 'https://pmkisan.gov.in/apply', sourceUrls: [URL1], lastVerifiedAt: new Date(),
  },
  ...over,
});

let storageStore: Map<string, Buffer>;
let deps: PipelineDeps & { scriptProvider: any; tts: any; storage: any };
let db: ReturnType<typeof fakePrisma>;

function setup(video: any, over: Partial<PipelineDeps> = {}) {
  db = fakePrisma(video);
  storageStore = new Map();
  const scriptProvider: ScriptProvider & { generate: any } = {
    name: 'mock', generate: vi.fn().mockResolvedValue({ raw: goodScript(), inputTokens: 1500, outputTokens: 600, model: 'm' }),
  };
  deps = {
    prisma: db.prisma, cfg: contentConfig({} as any), scriptProvider,
    tts: { name: 'mock-tts', synthesize: vi.fn().mockResolvedValue({ audio: Buffer.alloc(2000, 1), voice: 'hi-IN-X' }) },
    storage: {
      put: vi.fn(async (k: string, b: Buffer) => { storageStore.set(k, b); }),
      get: vi.fn(async (k: string) => { const b = storageStore.get(k); if (!b) throw new Error('missing'); return b; }),
    },
    exec: vi.fn(async (file: string, args: string[]) => {
      const { writeFile } = await import('fs/promises');
      if (file.includes('ffprobe')) {
        if (args.includes('stream=width,height')) return { stdout: '1080,1920\n', stderr: '' };
        return { stdout: args[args.length - 1].endsWith('.mp3') ? '25.0\n' : '28.5\n', stderr: '' };
      }
      await writeFile(args[args.length - 1], Buffer.alloc(5000, 7));
      return { stdout: '', stderr: '' };
    }),
    fetchText: vi.fn().mockRejectedValue(new Error('no network in tests')),
    ...over,
  } as any;
  return deps;
}

beforeEach(() => vi.clearAllMocks());

describe('script stage', () => {
  it('turns a verified scheme into a script with claims, attribution and cost, leaving the card status alone', async () => {
    setup(baseVideo());
    const r = await runScriptStage(deps, 'v1');
    const v = db.videos.get('v1');
    expect(v.status).toBe('DRAFT');
    expect(v.videoState).toBe('GENERATING');
    expect(v.claims).toHaveLength(1);
    expect(v.attribution).toMatch(/pmkisan/);
    expect(v.costMicroUsd).toBeGreaterThan(0);
    expect(r.next).toBe('NARRATION');
  });
  it('refuses schemes that no reviewer has verified', async () => {
    setup(baseVideo({ scheme: { ...baseVideo().scheme, lastVerifiedAt: null } }));
    await expect(runScriptStage(deps, 'v1')).rejects.toBeInstanceOf(PermanentError);
    expect(deps.scriptProvider.generate).not.toHaveBeenCalled();
  });
  it('news without retrievable source text never reaches the model', async () => {
    setup(baseVideo({
      kind: 'NEWS', scheme: null, newsStory: { canonicalUrl: 'https://pib.gov.in/x', publisher: 'PIB', publishedAt: new Date(), originalHeadline: 'H', summary: '' },
    }));
    await expect(runScriptStage(deps, 'v1')).rejects.toBeInstanceOf(PermanentError);
    expect(deps.scriptProvider.generate).not.toHaveBeenCalled();
    expect(db.videos.get('v1').status).toBe('DRAFT');
  });
  it('never touches admin-written card text', async () => {
    setup(baseVideo({ description: 'एडमिन का सारांश', attribution: 'स्रोत: PIB', hook: null }));
    await runScriptStage(deps, 'v1');
    const v = db.videos.get('v1');
    expect(v.description).toBe('एडमिन का सारांश');
    expect(v.attribution).toBe('स्रोत: PIB');
    expect(v.hook).toBeTruthy(); // only empty fields are filled
  });
  it('invalid model output becomes a permanent (non-retried) error and nothing is stored', async () => {
    setup(baseVideo());
    deps.scriptProvider.generate.mockResolvedValue({ raw: { title: 'x' }, inputTokens: 10, outputTokens: 10, model: 'm' });
    await expect(runScriptStage(deps, 'v1')).rejects.toBeInstanceOf(PermanentError);
    expect(db.videos.get('v1').script).toBeNull();
  });
  it('is idempotent: a second run of the same stage is skipped, no second model call', async () => {
    setup(baseVideo());
    await runScriptStage(deps, 'v1');
    await expect(runScriptStage(deps, 'v1')).rejects.toBeInstanceOf(SkippedError);
    expect(deps.scriptProvider.generate).toHaveBeenCalledTimes(1);
  });
});

describe('narration stage', () => {
  const scripted = () => baseVideo({ videoState: 'GENERATING', script: goodScript() });
  it('synthesises and stores audio privately', async () => {
    setup(scripted());
    const r = await runNarrationStage(deps, 'v1');
    const v = db.videos.get('v1');
    expect(v.videoState).toBe('GENERATING');
    expect(v.audioKey).toBe('content/audio/v1/v1.mp3');
    expect(v.aiMeta.tts).toMatchObject({ provider: 'mock-tts', voice: 'hi-IN-X', scriptVersion: 1 });
    expect(r.cached).toBe(false);
  });
  it('does not regenerate audio for the same script version (cache)', async () => {
    setup(scripted());
    await runNarrationStage(deps, 'v1');
    const r = await runNarrationStage(deps, 'v1');
    expect(r.cached).toBe(true);
    expect(deps.tts.synthesize).toHaveBeenCalledTimes(1);
  });
  it('fails when TTS returns no/too-small audio (missing audio)', async () => {
    setup(scripted());
    deps.tts.synthesize.mockResolvedValue({ audio: Buffer.alloc(10), voice: 'x' });
    await expect(runNarrationStage(deps, 'v1')).rejects.toThrow(/audio missing/);
    expect(db.videos.get('v1').audioKey).toBeNull();
  });
  it('propagates storage upload failures (retryable) without advancing state', async () => {
    setup(scripted());
    deps.storage.put.mockRejectedValue(new Error('GCS 503'));
    await expect(runNarrationStage(deps, 'v1')).rejects.toThrow('GCS 503');
    expect(db.videos.get('v1').audioKey).toBeNull();
  });
});

describe('render stage', () => {
  const narrated = () => baseVideo({ videoState: 'GENERATING', script: goodScript(), audioKey: 'content/audio/v1/v1.mp3' });
  const withAudio = () => { storageStore.set('content/audio/v1/v1.mp3', Buffer.alloc(3000, 2)); };

  it('renders, uploads video + thumbnail and becomes READY but NOT approved or published', async () => {
    setup(narrated()); withAudio();
    await runRenderStage(deps, 'v1');
    const v = db.videos.get('v1');
    expect(v.status).toBe('DRAFT');
    expect(v.videoState).toBe('READY');
    expect(v.videoApprovedAt).toBeNull();
    expect(v.videoKey).toBe('content/video/v1/v1.mp4');
    expect(v.thumbnailKey).toBe('content/thumb/v1/v1.jpg');
    expect(v.durationSec).toBeCloseTo(28.5);
    expect(v.publishedAt).toBeUndefined();
    expect(deps.storage.put).toHaveBeenCalledWith('content/video/v1/v1.mp4', expect.any(Buffer), 'video/mp4');
  });
  it('ffmpeg failure leaves no video (the card is untouched)', async () => {
    setup(narrated()); withAudio();
    const real = deps.exec as any;
    deps.exec = vi.fn(async (f: string, a: string[], o: any) => {
      if (!f.includes('ffprobe')) throw new RenderError('ffmpeg failed: boom');
      return real(f, a, o);
    }) as any;
    await expect(runRenderStage(deps, 'v1')).rejects.toThrow(/boom/);
    const v = db.videos.get('v1');
    expect(v.videoKey).toBeNull();
    expect(v.videoState).toBe('GENERATING');
    expect(v.status).toBe('DRAFT');
  });
  it('upload failure after render does not advance state', async () => {
    setup(narrated()); withAudio();
    deps.storage.put.mockRejectedValue(new Error('upload down'));
    await expect(runRenderStage(deps, 'v1')).rejects.toThrow('upload down');
    expect(db.videos.get('v1').videoState).toBe('GENERATING');
    expect(db.videos.get('v1').videoKey).toBeNull();
  });
  it('rejects wrong output dimensions', async () => {
    setup(narrated()); withAudio();
    const real = deps.exec as any;
    deps.exec = vi.fn(async (f: string, a: string[], o: any) =>
      a.includes('stream=width,height') ? { stdout: '720,1280\n', stderr: '' } : real(f, a, o)) as any;
    await expect(runRenderStage(deps, 'v1')).rejects.toThrow(/Unexpected output size/);
  });
  it('rejects narration longer than the configured maximum', async () => {
    setup(narrated()); withAudio();
    const real = deps.exec as any;
    deps.exec = vi.fn(async (f: string, a: string[], o: any) =>
      f.includes('ffprobe') && a[a.length - 1].endsWith('.mp3') ? { stdout: '90\n', stderr: '' } : real(f, a, o)) as any;
    await expect(runRenderStage(deps, 'v1')).rejects.toThrow(/over the 40s limit/);
  });
  it('fails clearly when the audio object is missing from storage', async () => {
    setup(narrated());
    await expect(runRenderStage(deps, 'v1')).rejects.toThrow('missing');
  });
  it('a render that finishes after the admin cancelled/changed the request is discarded', async () => {
    setup(narrated()); withAudio();
    const realExec = deps.exec as any;
    deps.exec = vi.fn(async (f: string, a: string[], o: any) => {
      db.videos.get('v1').videoState = 'NOT_REQUESTED'; // admin cancelled mid-render
      return realExec(f, a, o);
    }) as any;
    await expect(runRenderStage(deps, 'v1')).rejects.toBeInstanceOf(SkippedError);
    expect(db.videos.get('v1').videoKey).toBeNull();
  });
});

describe('cost limits and failure recording', () => {
  it('blocks work once the daily job limit is reached', async () => {
    setup(baseVideo());
    const tight = { ...deps.cfg!, maxJobsPerDay: 0 };
    await expect(runScriptStage({ ...deps, cfg: tight }, 'v1')).rejects.toThrow(/Daily generation limit/);
    expect(deps.scriptProvider.generate).not.toHaveBeenCalled();
  });
  it('blocks work when the monthly budget is exhausted and alerts near the threshold', async () => {
    setup(baseVideo());
    const log = vi.fn();
    db.jobs.set('old', { id: 'old', costMicroUsd: 19_000_000, queuedAt: new Date() });
    await assertWithinLimits({ ...deps, log });
    expect(log).toHaveBeenCalledWith('content budget alert', expect.any(Object));
    db.jobs.set('old2', { id: 'old2', costMicroUsd: 2_000_000, queuedAt: new Date() });
    await expect(assertWithinLimits(deps)).rejects.toThrow(/budget exhausted/);
  });
  it('final failure marks only the VIDEO failed, with a sanitized reason; the card status is preserved', async () => {
    setup(baseVideo({ status: 'PUBLISHED', videoState: 'GENERATING', script: goodScript(), audioKey: 'a' }));
    db.jobs.set('RENDER-v1-v1', { id: 'j9', state: 'RUNNING', startedAt: new Date() });
    await recordFailure(deps, 'RENDER', 'v1', new Error('ffmpeg exploded at /srv/x/y.mp4'), false);
    expect(db.videos.get('v1').videoState).toBe('GENERATING');
    expect(db.jobs.get('RENDER-v1-v1').failureReason).toContain('ffmpeg exploded');
    await recordFailure(deps, 'RENDER', 'v1', new Error('ffmpeg exploded at /srv/x/y.mp4'), true);
    const v = db.videos.get('v1');
    expect(v.videoState).toBe('FAILED');
    expect(v.status).toBe('PUBLISHED'); // an otherwise publishable/published card is never invalidated
    expect(v.videoFailureReason).not.toMatch(/ffmpeg|\/srv/); // unknown errors → generic message, no internals
  });
  it('sanitizeFailure strips links and paths from permanent errors', () => {
    expect(sanitizeFailure(new PermanentError('Source https://secret.example/a?token=1 failed at /var/app/x.js')))
      .toBe('Source [link] failed at [path]');
    expect(sanitizeFailure(new Error('boom'))).toMatch(/temporary service problem/);
  });
  it('stages refuse to run for CARD_ONLY or un-requested items (no implicit video work)', async () => {
    for (const over of [{ format: 'CARD_ONLY' }, { videoState: 'NOT_REQUESTED' }, { videoState: 'READY' }, { videoState: 'FAILED' }]) {
      setup(baseVideo(over));
      for (const stage of ['SCRIPT', 'NARRATION', 'RENDER'] as const) {
        await expect(runStage(deps, stage, 'v1')).rejects.toBeInstanceOf(SkippedError);
      }
      expect(deps.scriptProvider.generate).not.toHaveBeenCalled();
      expect(deps.tts.synthesize).not.toHaveBeenCalled();
      expect(db.jobs.size).toBe(0);
    }
  });
  it('a cancelled job is skipped instead of re-run', async () => {
    setup(baseVideo());
    db.jobs.set('SCRIPT-v1-v1', { id: 'jc', state: 'CANCELLED' });
    await expect(runStage(deps, 'SCRIPT', 'v1')).rejects.toBeInstanceOf(SkippedError);
  });
  it('full happy path ends at READY awaiting approval, not published or approved', async () => {
    setup(baseVideo());
    await runStage(deps, 'SCRIPT', 'v1');
    await runStage(deps, 'NARRATION', 'v1');
    await runStage(deps, 'RENDER', 'v1');
    const v = db.videos.get('v1');
    expect(v.status).toBe('DRAFT');
    expect(v.videoState).toBe('READY');
    expect(v.videoApprovedAt).toBeNull();
    expect(v.costMicroUsd).toBeGreaterThan(0);
  });
});

describe('captions drive the render', () => {
  const script = { scenes: [{ caption: 'पहला' }, { caption: 'दूसरा' }] };
  it('reviewer-edited captions win; otherwise scene captions are used', () => {
    expect(captionTexts({ captions: [{ i: 0, text: ' संपादित ' }, { text: '' }, { text: 'दूसरी' }], script })).toEqual(['संपादित', 'दूसरी']);
    expect(captionTexts({ captions: [], script })).toEqual(['पहला', 'दूसरा']);
    expect(captionTexts({ captions: null, script })).toEqual(['पहला', 'दूसरा']);
    expect(captionTexts({ captions: 'garbage', script: null })).toEqual([]);
  });
  it('the script stage seeds captions from the scenes', async () => {
    setup(baseVideo());
    await runScriptStage(deps, 'v1');
    expect(db.videos.get('v1').captions).toEqual([{ i: 0, text: 'पीएम किसान' }, { i: 1, text: 'प्रति वर्ष 6000 रुपये' }]);
  });
  it('rendering does not overwrite reviewer-edited captions', async () => {
    setup(baseVideo({ videoState: 'GENERATING', script: goodScript(), audioKey: 'content/audio/v1/v1.mp3', captions: [{ text: 'मेरा कैप्शन' }] }));
    storageStore.set('content/audio/v1/v1.mp3', Buffer.alloc(3000, 2));
    await runRenderStage(deps, 'v1');
    expect(db.videos.get('v1').captions).toEqual([{ text: 'मेरा कैप्शन' }]);
  });
});
