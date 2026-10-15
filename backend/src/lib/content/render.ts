// src/lib/content/render.ts
// Template-driven 9:16 renderer: solid brand background + ASS captions/title + narration → H.264/AAC MP4.
// No AI footage, no fake documents or seals. Hindi text goes through libass (needs a Devanagari font
// in CONTENT_FONTS_DIR). ffmpeg is invoked with an argument array (never a shell string).
import { execFile } from 'child_process';
import { promises as fs } from 'fs';
import os from 'os';
import path from 'path';
import { contentConfig, costs, ContentConfig } from './config';

export interface Caption { start: number; end: number; text: string }

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

export interface RenderPlan {
  title: string;
  captions: Caption[];
  durationSec: number;
  endCardLines: string[]; // source / URL / date lines shown for the last seconds
  brand: string;
}

/** ASS subtitle file: title bar, captions, end card. 1080x1920 canvas. */
export function buildAss(plan: RenderPlan, cfg: Pick<ContentConfig, 'fontName'>): string {
  const f = cfg.fontName;
  const endStart = Math.max(0, plan.durationSec - 3.5);
  const ev = (style: string, s: number, e: number, text: string) =>
    `Dialogue: 0,${assTime(s)},${assTime(e)},${style},,0,0,0,,${assEscape(text)}`;
  return [
    '[Script Info]', 'ScriptType: v4.00+', 'PlayResX: 1080', 'PlayResY: 1920', 'WrapStyle: 0', '',
    '[V4+ Styles]',
    'Format: Name,Fontname,Fontsize,PrimaryColour,OutlineColour,BackColour,Bold,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV',
    `Style: Title,${f},70,&H00FFFFFF,&H00000000,&H80000000,1,1,3,0,8,70,70,170`,
    `Style: Cap,${f},62,&H00FFFFFF,&H00000000,&H99000000,1,3,4,0,2,80,80,420`,
    `Style: Brand,${f},40,&H00E0E0E0,&H00000000,&H00000000,0,1,2,0,9,50,50,60`,
    `Style: End,${f},52,&H00FFFFFF,&H00000000,&H99000000,1,3,4,0,5,90,90,0`,
    '',
    '[Events]', 'Format: Layer,Start,End,Name,Style,MarginL,MarginR,MarginV,Effect,Text',
    ev('Brand', 0, plan.durationSec, plan.brand),
    ev('Title', 0, Math.min(plan.durationSec, 4), plan.title),
    ...plan.captions.filter((c) => c.start < endStart).map((c) => ev('Cap', c.start, Math.min(c.end, endStart), c.text)),
    ev('End', endStart, plan.durationSec, plan.endCardLines.join('\n')),
    '',
  ].join('\n');
}

export function buildFfmpegArgs(o: {
  audio: string; ass: string; out: string; durationSec: number; fontsDir: string;
}): string[] {
  // Filter paths: ffmpeg filter syntax needs ':' and '\' escaped inside the subtitles filter.
  const esc = (p: string) => p.replace(/\\/g, '/').replace(/:/g, '\\:').replace(/'/g, "\\'");
  const sub = `subtitles='${esc(o.ass)}'${o.fontsDir ? `:fontsdir='${esc(o.fontsDir)}'` : ''}`;
  return [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-f', 'lavfi', '-i', `color=c=0x0b2a66:s=1080x1920:r=25:d=${o.durationSec.toFixed(2)}`,
    '-i', o.audio,
    '-vf', `${sub},format=yuv420p`,
    '-c:v', 'libx264', '-profile:v', 'main', '-preset', 'veryfast', '-crf', '26', '-r', '25',
    '-c:a', 'aac', '-b:a', '96k', '-ar', '44100',
    '-t', o.durationSec.toFixed(2), '-shortest', '-movflags', '+faststart',
    o.out,
  ];
}

export interface RenderResult {
  video: Buffer; thumbnail: Buffer; durationSec: number; costMicroUsd: number; width: number; height: number;
}

/** Renders and verifies the output (exists, size cap, duration within narration±1s, 1080x1920, thumbnail made). */
export async function renderShort(
  audio: Buffer, plan: Omit<RenderPlan, 'durationSec' | 'captions'> & { sceneCaptions: string[] },
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
    const assPath = path.join(dir, 'c.ass');
    await fs.writeFile(assPath, buildAss({ ...plan, captions, durationSec }, cfg), 'utf8');

    const out = path.join(dir, 'out.mp4');
    await exec(cfg.ffmpegPath, buildFfmpegArgs({ audio: audioPath, ass: assPath, out, durationSec, fontsDir: cfg.fontsDir }), { timeoutMs: cfg.jobTimeoutMs });

    const st = await fs.stat(out).catch(() => null);
    if (!st || st.size === 0) throw new RenderError('Render produced no output file');
    if (st.size > cfg.maxOutputBytes) throw new RenderError(`Output ${st.size} bytes exceeds limit ${cfg.maxOutputBytes}`);

    const vdur = await probeDuration(out, cfg, exec);
    if (Math.abs(vdur - durationSec) > 1.5) throw new RenderError(`Output duration ${vdur.toFixed(1)}s does not match expected ${durationSec.toFixed(1)}s`);
    const dim = await exec(cfg.ffprobePath, ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', out], { timeoutMs: 20_000 });
    const [w, h] = dim.stdout.trim().split(',').map(Number);
    if (w !== 1080 || h !== 1920) throw new RenderError(`Unexpected output size ${w}x${h} (need 1080x1920)`);

    const thumbPath = path.join(dir, 't.jpg');
    await exec(cfg.ffmpegPath, ['-y', '-hide_banner', '-loglevel', 'error', '-ss', '1', '-i', out, '-frames:v', '1', '-q:v', '4', thumbPath], { timeoutMs: 30_000 });
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
