// Verifies the local render toolchain WITHOUT any cloud calls or spend:
//   FFMPEG_PATH / FFPROBE_PATH, a Devanagari font in CONTENT_FONTS_DIR, libx264 + libass.
// Usage: npx tsx scripts/content-smoke.ts   → writes ./content-smoke.mp4 and ./content-smoke.jpg
import { execFileSync } from 'child_process';
import { writeFileSync } from 'fs';
import { contentConfig } from '../src/lib/content/config';
import { renderShort } from '../src/lib/content/render';

async function main() {
  const cfg = contentConfig();
  // 20 s sine-tone mp3 stands in for narration.
  const tmp = 'content-smoke-tone.mp3';
  execFileSync(cfg.ffmpegPath, ['-y', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'sine=frequency=330:duration=20', tmp]);
  const { readFileSync, rmSync } = await import('fs');
  const audio = readFileSync(tmp); rmSync(tmp);

  const r = await renderShort(audio, {
    title: 'पीएम किसान सम्मान निधि', brand: 'स्टेटस गो',
    sceneCaptions: ['पात्र किसान परिवारों को सहायता', 'आवेदन आधिकारिक वेबसाइट पर करें', 'पात्रता की जाँच ज़रूर करें'],
    endCardLines: ['स्रोत: pmkisan.gov.in', 'AI-सहायता प्राप्त सारांश'],
  }, cfg);
  writeFileSync('content-smoke.mp4', r.video);
  writeFileSync('content-smoke.jpg', r.thumbnail);
  console.log(`OK ${r.width}x${r.height} ${r.durationSec.toFixed(1)}s ${(r.video.length / 1e6).toFixed(2)}MB — open content-smoke.mp4 and check the Hindi text renders correctly (no boxes / broken conjuncts).`);
}
main().catch((e) => { console.error('SMOKE FAILED:', e.message); process.exit(1); });
