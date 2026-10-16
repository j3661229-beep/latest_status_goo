import { defineConfig } from 'vitest/config';

// Dummy values so modules that import src/config/env.ts can load under test.
// Tests never talk to a real database, Redis, or cloud service.
// NOTE: @prisma/client auto-loads backend/.env when imported, and variables that already exist in
// process.env win over it. Every setting a test could read from a developer's real .env is therefore
// pinned here (empty / default) so local config can never leak into test results.
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    env: {
      NODE_ENV: 'test',
      DATABASE_URL: 'postgresql://test:test@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'x'.repeat(32),
      JWT_REFRESH_SECRET: 'y'.repeat(32),
      CONTENT_SOURCE_HOSTS: '',
      CONTENT_PIPELINE_ENABLED: 'false',
      CONTENT_FONTS_DIR: '',
      CONTENT_FONT_NAME: 'Noto Sans Devanagari',
      CONTENT_ALLOW_PUBLIC_FALLBACK: '',
      FFMPEG_PATH: 'ffmpeg',
      FFPROBE_PATH: 'ffprobe',
    },
  },
});
