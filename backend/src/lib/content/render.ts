// src/lib/content/render.ts
// High-engagement animated 9:16 renderer with live AI News Anchor Avatar:
// - Live speaking AI news presenter avatar window with broadcast framing & glowing border
// - Dynamic moving radial gradient motion background (subtle rotation & rich depth)
// - Voice-reactive real-time audio visualizer (FFmpeg showfreqs equalizer synced to speech)
// - Top animated progress bar advancing 0% -> 100% over the short
// - ASS subtitle & motion graphics layer (header badge, prominent center-stage headline/fact cards, timed captions, and verified source end-card)
// - Encoded to H.264 / AAC MP4 with faststart.
import { execFile } from 'child_process';
import { promises as fs } from 'fs';
import os from 'os';
import path from 'path';
import { contentConfig, costs, ContentConfig } from './config';

export interface Caption { start: number; end: number; text: string }

export interface RenderScene {
  text: string;
  caption: string;
  visual: 'HEADLINE_CARD' | 'KEY_FACT' | 'STEPS' | 'SOURCE_CARD' | string;
}

export class RenderError extends Error {}

export type Exec = (file: string, args: string[], opts: { timeoutMs: number }) => Promise<{ stdout: string; stderr: string }>;
export const defaultExec: Exec = (file, args, { timeoutMs }) =>
  new Promise((resolve, reject) => {
    execFile(file, args, { timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024, windowsHide: true }, (err, stdout, stderr) => {
      if (err) reject(new RenderError(`${path.basename(file)} failed: ${(stderr || err.message).slice(-600)}`));
      else resolve({ stdout, stderr });
    });
  });

export async function probeDuration(file: string, cfg: ContentConfig = contentConfig(), exec: Exec = defaultExec): Promise<number> {
  const { stdout } = await exec(cfg.ffprobePath, ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', file], { timeoutMs: 20_000 });
  const d = parseFloat(stdout.trim());
  if (!Number.isFinite(d) || d <= 0) throw new RenderError('Could not determine media duration');
  return d;
}

/** Split narration into timed captions proportional to text length (words per line capped for small screens). */
export function buildCaptions(sceneCaptions: string[], durationSec: number): Caption[] {
  const lines = sceneCaptions.map((c) => c.trim()).filter(Boolean);
  if (lines.length === 0) return [];
  const total = lines.reduce((a, l) => a + l.length, 0);
  let t = 0;
  return lines.map((text, i) => {
    const span = i === lines.length - 1 ? durationSec - t : (text.length / total) * durationSec;
    const c = { start: +t.toFixed(2), end: +(t + span).toFixed(2), text };
    t += span;
    return c;
  });
}

const assTime = (s: number) => {
  const cs = Math.round(s * 100);
  const h = Math.floor(cs / 360000), m = Math.floor((cs % 360000) / 6000), sec = Math.floor((cs % 6000) / 100);
  return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}.${String(cs % 100).padStart(2, '0')}`;
};
const assEscape = (t: string) => t.replace(/\\/g, '＼').replace(/[{}]/g, '').replace(/\r?\n/g, '\\N');

export function sceneBadge(visual?: string, kind?: 'SCHEME' | 'NEWS'): string {
  switch (visual) {
    case 'HEADLINE_CARD':
      return kind === 'SCHEME' ? '【 ⚡ नई सरकारी योजना 】' : '【 📢 मुख्य समाचार 】';
    case 'KEY_FACT':
      return kind === 'SCHEME' ? '【 💰 वित्तीय सहायता व लाभ 】' : '【 📌 मुख्य तथ्य 】';
    case 'STEPS':
      return kind === 'SCHEME' ? '【 📋 आवेदन प्रक्रिया व शर्तें 】' : '【 🔍 महत्वपूर्ण बिंदु 】';
    case 'SOURCE_CARD':
      return '【 ✅ आधिकारिक पुष्टि 】';
    default:
      return '【 📌 मुख्य जानकारी 】';
  }
}

export function wrapLines(text: string, maxChars = 24): string {
  const words = text.split(/\s+/);
  const lines: string[] = [];
  let cur = '';
  for (const w of words) {
    if (!cur) cur = w;
    else if ((cur + ' ' + w).length <= maxChars) cur += ' ' + w;
    else { lines.push(cur); cur = w; }
  }
  if (cur) lines.push(cur);
  return lines.join('\n');
}

export interface RenderPlan {
  title: string;
  captions: Caption[];
  durationSec: number;
  endCardLines: string[]; // source / URL / date lines shown for the last seconds
  brand: string;
  category?: string;
  scenes?: RenderScene[];
  kind?: 'SCHEME' | 'NEWS';
  hasAvatar?: boolean;
}

/** ASS subtitle file: title bar, captions, end card. 1080x1920 canvas. */
export function buildAss(plan: RenderPlan, cfg: Pick<ContentConfig, 'fontName'>): string {
  const f = cfg.fontName;
  const endStart = Math.max(0, plan.durationSec - 3.5);
  const ev = (style: string, s: number, e: number, text: string, prefix = '') =>
    `Dialogue: 0,${assTime(s)},${assTime(e)},${style},,0,0,0,,${prefix}${assEscape(text)}`;

  const events: string[] = [];

  // Top header brand + category tag
  const catLabel = plan.category ? (plan.kind === 'SCHEME' ? `योजना विशेष · ${plan.category}` : `ताज़ा समाचार · ${plan.category}`) : plan.brand;
  const headerPrefix = plan.hasAvatar ? '🔴 LIVE  ✦  ' : '⚡ ';
  events.push(ev('Brand', 0, plan.durationSec, `${headerPrefix}${plan.brand.toUpperCase()}  ✦  ${catLabel}`, '{\\fad(200,200)}'));

  // Scene cards or default title
  if (plan.scenes && plan.scenes.length > 0) {
    const scenes = plan.scenes;
    scenes.forEach((sc, i) => {
      const cap = plan.captions[i];
      const sStart = cap ? cap.start : (i * (endStart / scenes.length));
      const sEnd = Math.min(cap ? cap.end : ((i + 1) * (endStart / scenes.length)), endStart);
      if (sEnd > sStart) {
        const badge = sceneBadge(sc.visual, plan.kind);
        events.push(ev('Badge', sStart, sEnd, badge, '{\\fad(250,200)}'));
        events.push(ev('Highlight', sStart, sEnd, wrapLines(sc.text, 24), '{\\fad(300,200)}'));
      }
    });
  } else {
    events.push(ev('Title', 0, Math.min(plan.durationSec, 4), plan.title));
  }

  // Spoken narration subtitles
  plan.captions
    .filter((c) => c.start < endStart)
    .forEach((c) => {
      events.push(ev('Cap', c.start, Math.min(c.end, endStart), c.text, '{\\fad(150,150)}'));
    });

  // End card: official verified checkmark + sources
  const endBody = (plan.endCardLines.length > 0 && plan.endCardLines[0].startsWith('✅'))
    ? plan.endCardLines.join('\n')
    : ['✅ स्टेटस गो पर सत्यापित', ...plan.endCardLines].join('\n');
  events.push(ev('End', endStart, plan.durationSec, endBody, '{\\fad(300,150)}'));

  // Margins tailored to layout: when photorealistic studio avatar is present, scene cards sit in the lower-third news desk card (y=1190..1880)
  const badgeMarginV = plan.hasAvatar ? 1220 : 360;
  const highlightMarginV = plan.hasAvatar ? 1310 : 450;
  const capMarginV = plan.hasAvatar ? 120 : 260;
  const brandMarginV = plan.hasAvatar ? 32 : 60;
  const titleMarginV = plan.hasAvatar ? 1280 : 170;

  return [
    '[Script Info]', 'ScriptType: v4.00+', 'PlayResX: 1080', 'PlayResY: 1920', 'WrapStyle: 0', '',
    '[V4+ Styles]',
    'Format: Name,Fontname,Fontsize,PrimaryColour,OutlineColour,BackColour,Bold,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV',
    `Style: Title,${f},64,&H00FFFFFF,&H00000000,&H80000000,1,1,3,0,8,70,70,${titleMarginV}`,
    `Style: Brand,${f},38,&H0000FFFF,&H00000000,&H90000000,1,1,2,0,8,60,60,${brandMarginV}`,
    `Style: Badge,${f},44,&H0000E5FF,&H00000000,&HA0000000,1,3,4,0,8,70,70,${badgeMarginV}`,
    `Style: Highlight,${f},60,&H00FFFFFF,&H00000000,&HB0000000,1,3,5,2,8,70,70,${highlightMarginV}`,
    `Style: Cap,${f},52,&H00FFFFFF,&H00000000,&HAA000000,1,3,4,0,2,70,70,${capMarginV}`,
    `Style: End,${f},54,&H00FFFFFF,&H00000000,&HAA000000,1,3,5,2,5,80,80,0`,
    '',
    '[Events]', 'Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text',
    ...events,
    '',
  ].join('\n');
}

export interface BuildFfmpegArgsOptions {
  audio: string;
  ass: string;
  out: string;
  durationSec: number;
  fontsDir: string;
  animated?: boolean;
  avatarVideo?: string;
}

export function buildFfmpegArgs(o: BuildFfmpegArgsOptions): string[] {
  // Filter paths: ffmpeg filter syntax needs ':' and '\' escaped inside the subtitles filter.
  const esc = (p: string) => p.replace(/\\/g, '/').replace(/:/g, '\\:').replace(/'/g, "\\'");
  const sub = `subtitles='${esc(o.ass)}'${o.fontsDir ? `:fontsdir='${esc(o.fontsDir)}'` : ''}`;
  const dStr = o.durationSec.toFixed(2);
  const endStart = Math.max(0, o.durationSec - 3.5).toFixed(2);

  if (o.animated && o.avatarVideo) {
    // Photorealistic broadcast television newsroom studio with live speaking AI News Anchor:
    // 1. Full-bleed studio video (1080x1920) with live speaking anchor behind the news desk
    // 2. Top live broadcast header bar (🔴 LIVE ✦ BRAND ✦ Category)
    // 3. Top animated progress bar advancing 0% -> 100%
    // 4. Lower-third translucent dark glass news card overlaying the desk (y=1190..1880)
    // 5. Voice-reactive real-time audio visualizer (FFmpeg showfreqs equalizer synced to speech)
    // 6. Subtitles & animated highlight cards via libass
    // 7. Smooth end-card transition with studio dimming and verified checkmark
    return [
      '-y', '-hide_banner', '-loglevel', 'error',
      '-ss', '0', '-t', dStr, '-i', o.audio,
      '-ss', '0', '-t', dStr, '-i', o.avatarVideo,
      '-filter_complex',
      `[0:a]showfreqs=s=880x90:mode=bar:ascale=log:fscale=log:win_size=1024:averaging=1:colors=0x00E5FF|0x7C4DFF[wave];` +
      `[wave]colorkey=0x000000:0.1:0.1[wave_keyed];` +
      `[1:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,` +
      `drawbox=x=0:y=0:w=1080:h=95:color=0x06112c@0.92:t=fill,` +
      `drawbox=x=0:y=93:w=1080:h=3:color=0x00E5FF@0.8:t=fill,` +
      `drawbox=x=0:y=0:w='iw*(t/${dStr})':h=14:color=0x00E5FF@0.95:t=fill,` +
      `drawbox=x=40:y=1190:w=1000:h=690:color=0x06112c@0.85:enable='between(t,0,${endStart})':t=fill,` +
      `drawbox=x=40:y=1190:w=1000:h=690:color=0x00E5FF@0.6:enable='between(t,0,${endStart})':t=3,` +
      `drawbox=x=0:y=0:w=1080:h=1920:color=0x06112c@0.88:enable='gte(t,${endStart})':t=fill[bg_boxed];` +
      `[bg_boxed][wave_keyed]overlay=x=(W-w)/2:y=1570:enable='between(t,0,${endStart})'[v_wave];` +
      `[v_wave]${sub},format=yuv420p[v_out]`,
      '-map', '[v_out]', '-map', '0:a',
      '-c:v', 'libx264', '-profile:v', 'main', '-preset', 'veryfast', '-crf', '22', '-r', '25',
      '-af', 'apad', '-c:a', 'aac', '-b:a', '96k', '-ar', '44100',
      '-t', dStr, '-movflags', '+faststart',
      o.out,
    ];
  }

  if (o.animated) {
    // Animated layout without avatar:
    return [
      '-y', '-hide_banner', '-loglevel', 'error',
      '-i', o.audio,
      '-f', 'lavfi', '-i', `gradients=s=1080x1920:r=25:c0=0x06112c:c1=0x0f2b5c:c2=0x19083b:c3=0x06283b:nb_colors=4:type=radial:speed=0.015:d=${dStr}`,
      '-filter_complex',
      `[0:a]showfreqs=s=800x140:mode=bar:ascale=log:fscale=log:win_size=1024:averaging=1:colors=0x00E5FF|0x7C4DFF[wave];` +
      `[wave]colorkey=0x000000:0.1:0.1[wave_keyed];` +
      `[1:v]drawbox=x=0:y=0:w='iw*(t/${dStr})':h=14:color=0x00E5FF@0.95:t=fill[bg_prog];` +
      `[bg_prog][wave_keyed]overlay=x=(W-w)/2:y=1220[v_wave];` +
      `[v_wave]${sub},format=yuv420p[v_out]`,
      '-map', '[v_out]', '-map', '0:a',
      '-c:v', 'libx264', '-profile:v', 'main', '-preset', 'veryfast', '-crf', '24', '-r', '25',
      '-af', 'apad', '-c:a', 'aac', '-b:a', '96k', '-ar', '44100',
      '-t', dStr, '-movflags', '+faststart',
      o.out,
    ];
  }

  // Classic/fallback rendering with -vf (preserves unit test expectations)
  return [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-f', 'lavfi', '-i', `color=c=0x0b2a66:s=1080x1920:r=25:d=${dStr}`,
    '-i', o.audio,
    '-vf', `${sub},format=yuv420p`,
    '-c:v', 'libx264', '-profile:v', 'main', '-preset', 'veryfast', '-crf', '26', '-r', '25',
    '-af', 'apad', '-c:a', 'aac', '-b:a', '96k', '-ar', '44100',
    '-t', dStr, '-movflags', '+faststart',
    o.out,
  ];
}

export interface RenderResult {
  video: Buffer; thumbnail: Buffer; durationSec: number; costMicroUsd: number; width: number; height: number;
}

export type RenderShortPlan = Omit<RenderPlan, 'durationSec' | 'captions'> & {
  sceneCaptions: string[];
  animated?: boolean;
  avatarVideo?: string;
};

/** Renders and verifies the output (exists, size cap, duration within narration±1s, 1080x1920, thumbnail made). */
export async function renderShort(
  audio: Buffer, plan: RenderShortPlan,
  cfg: ContentConfig = contentConfig(), exec: Exec = defaultExec,
): Promise<RenderResult> {
  const dir = await fs.mkdtemp(path.join(cfg.tmpDir || os.tmpdir(), 'shortgen-'));
  try {
    const audioPath = path.join(dir, 'a.mp3');
    await fs.writeFile(audioPath, audio);
    const narrSec = await probeDuration(audioPath, cfg, exec);
    if (narrSec > cfg.maxNarrationSec) throw new RenderError(`Narration is ${narrSec.toFixed(1)}s, over the ${cfg.maxNarrationSec}s limit`);
    if (narrSec < cfg.minNarrationSec) throw new RenderError(`Narration is only ${narrSec.toFixed(1)}s, under the ${cfg.minNarrationSec}s minimum`);

    const durationSec = narrSec + 3.5; // + end card (source attribution) hold
    const captions = buildCaptions(plan.sceneCaptions, narrSec);
    if (captions.length === 0) throw new RenderError('No captions to render');

    // Auto-discover talking avatar video if available
    let avatarVideo = plan.avatarVideo ?? cfg.avatarVideoPath;
    if (!avatarVideo) {
      const candidates = [
        path.resolve(process.cwd(), 'assets/avatar/studio_anchor_60s.mp4'),
        path.resolve(process.cwd(), 'assets/avatar/anchor_talking_60s.mp4'),
        path.resolve(__dirname, '../../../assets/avatar/studio_anchor_60s.mp4'),
        path.resolve(__dirname, '../../assets/avatar/studio_anchor_60s.mp4'),
        path.resolve(__dirname, '../../../assets/avatar/anchor_talking_60s.mp4'),
        path.resolve(__dirname, '../../assets/avatar/anchor_talking_60s.mp4'),
      ];
      for (const cand of candidates) {
        if (await fs.stat(cand).catch(() => null)) {
          avatarVideo = cand;
          break;
        }
      }
    }

    const hasAvatar = Boolean(avatarVideo);
    const assPath = path.join(dir, 'c.ass');
    await fs.writeFile(assPath, buildAss({ ...plan, captions, durationSec, hasAvatar }, cfg), 'utf8');

    const out = path.join(dir, 'out.mp4');
    await exec(
      cfg.ffmpegPath,
      buildFfmpegArgs({
        audio: audioPath,
        ass: assPath,
        out,
        durationSec,
        fontsDir: cfg.fontsDir,
        animated: plan.animated !== false,
        avatarVideo: avatarVideo || undefined,
      }),
      { timeoutMs: cfg.jobTimeoutMs },
    );

    const st = await fs.stat(out).catch(() => null);
    if (!st || st.size === 0) throw new RenderError('Render produced no output file');
    if (st.size > cfg.maxOutputBytes) throw new RenderError(`Output ${st.size} bytes exceeds limit ${cfg.maxOutputBytes}`);

    const vdur = await probeDuration(out, cfg, exec);
    if (Math.abs(vdur - durationSec) > 1.5) throw new RenderError(`Output duration ${vdur.toFixed(1)}s does not match expected ${durationSec.toFixed(1)}s`);
    const dim = await exec(cfg.ffprobePath, ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', out], { timeoutMs: 20_000 });
    const [w, h] = dim.stdout.trim().split(',').map(Number);
    if (w !== 1080 || h !== 1920) throw new RenderError(`Unexpected output size ${w}x${h} (need 1080x1920)`);

    const thumbPath = path.join(dir, 't.jpg');
    const thumbTime = Math.min(2, Math.max(0.5, durationSec / 4)).toFixed(1);
    await exec(cfg.ffmpegPath, ['-y', '-hide_banner', '-loglevel', 'error', '-ss', thumbTime, '-i', out, '-frames:v', '1', '-q:v', '4', thumbPath], { timeoutMs: 30_000 });
    const thumbSt = await fs.stat(thumbPath).catch(() => null);
    if (!thumbSt || thumbSt.size === 0) throw new RenderError('Thumbnail generation failed');

    return {
      video: await fs.readFile(out), thumbnail: await fs.readFile(thumbPath),
      durationSec: vdur, width: w, height: h, costMicroUsd: costs.render(cfg, durationSec),
    };
  } finally {
    await fs.rm(dir, { recursive: true, force: true }).catch(() => undefined); // temp-file cleanup, success or failure
  }
}
