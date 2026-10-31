// src/lib/content/config.ts
// Limits, pricing and provider settings for the AI shorts pipeline.
// Read from process.env on each call (not at import) so tests and ops can override.
// Pricing values are ESTIMATES used for cost tracking only. They are deliberately
// configurable: provider prices change, so update the env vars, not the code.
const num = (v: string | undefined, d: number) => {
  const n = Number(v);
  return v !== undefined && v !== '' && Number.isFinite(n) && n >= 0 ? n : d;
};

export function contentConfig(e: NodeJS.ProcessEnv = process.env) {
  return {
    // ── Providers ────────────────────────────────────────────
    gcpProject: e.GCP_PROJECT_ID ?? e.GCS_PROJECT_ID ?? '',
    vertexLocation: e.CONTENT_VERTEX_LOCATION ?? 'asia-south1',
    scriptModel: e.CONTENT_SCRIPT_MODEL ?? 'gemini-3.5-flash',
    ttsVoice: e.CONTENT_TTS_VOICE ?? 'hi-IN-Neural2-A',
    ttsLanguageCode: e.CONTENT_TTS_LANGUAGE ?? 'hi-IN',
    ffmpegPath: e.FFMPEG_PATH ?? 'ffmpeg',
    ffprobePath: e.FFPROBE_PATH ?? 'ffprobe',
    /** Directory holding a Devanagari-capable font (e.g. NotoSansDevanagari-Bold.ttf). */
    fontsDir: e.CONTENT_FONTS_DIR ?? '',
    fontName: e.CONTENT_FONT_NAME ?? 'Noto Sans Devanagari',
    tmpDir: e.CONTENT_TMP_DIR ?? '',
    avatarVideoPath: e.CONTENT_AVATAR_VIDEO_PATH ?? '',

    // ── Safety / network ─────────────────────────────────────
    /** Comma-separated hostnames (and their subdomains) the pipeline may fetch from. Empty = fetch nothing. */
    sourceHosts: (e.CONTENT_SOURCE_HOSTS ?? '')
      .split(',').map((h) => h.trim().toLowerCase()).filter(Boolean),

    // ── Limits ───────────────────────────────────────────────
    maxSourceChars: num(e.CONTENT_MAX_SOURCE_CHARS, 20_000),
    maxFetchBytes: num(e.CONTENT_MAX_FETCH_BYTES, 2_000_000),
    fetchTimeoutMs: num(e.CONTENT_FETCH_TIMEOUT_MS, 15_000),
    maxNarrationSec: num(e.CONTENT_MAX_NARRATION_SEC, 40),
    minNarrationSec: num(e.CONTENT_MIN_NARRATION_SEC, 12),
    maxOutputBytes: num(e.CONTENT_MAX_OUTPUT_BYTES, 25_000_000),
    maxJobsPerDay: num(e.CONTENT_MAX_JOBS_PER_DAY, 60),
    maxIngestPerDay: num(e.CONTENT_MAX_INGEST_PER_DAY, 200),
    maxConcurrentRenders: num(e.CONTENT_MAX_CONCURRENT_RENDERS, 1),
    maxAttempts: num(e.CONTENT_MAX_ATTEMPTS, 3),
    jobTimeoutMs: num(e.CONTENT_JOB_TIMEOUT_MS, 180_000),
    monthlyBudgetMicroUsd: num(e.CONTENT_MONTHLY_BUDGET_USD, 20) * 1_000_000,
    budgetAlertRatio: num(e.CONTENT_BUDGET_ALERT_RATIO, 0.8),

    // ── Pricing estimates (USD) ──────────────────────────────
    price: {
      textInputPerMTokUsd: num(e.CONTENT_PRICE_TEXT_IN_PER_MTOK, 0.3),
      textOutputPerMTokUsd: num(e.CONTENT_PRICE_TEXT_OUT_PER_MTOK, 2.5),
      ttsPerMCharUsd: num(e.CONTENT_PRICE_TTS_PER_MCHAR, 16),
      renderPerSecUsd: num(e.CONTENT_PRICE_RENDER_PER_SEC, 0.00002),
      storagePerGbMonthUsd: num(e.CONTENT_PRICE_STORAGE_GB_MONTH, 0.02),
    },
  };
}
export type ContentConfig = ReturnType<typeof contentConfig>;

export const usdToMicro = (usd: number) => Math.round(usd * 1_000_000);

export const costs = {
  text(cfg: ContentConfig, inTok: number, outTok: number) {
    return usdToMicro(
      (inTok / 1e6) * cfg.price.textInputPerMTokUsd + (outTok / 1e6) * cfg.price.textOutputPerMTokUsd,
    );
  },
  tts(cfg: ContentConfig, chars: number) {
    return usdToMicro((chars / 1e6) * cfg.price.ttsPerMCharUsd);
  },
  render(cfg: ContentConfig, seconds: number) {
    return usdToMicro(seconds * cfg.price.renderPerSecUsd);
  },
};
