import { defineConfig } from 'vitest/config';

// Dummy values so modules that import src/config/env.ts can load under test.
// Tests never talk to a real database, Redis, or cloud service.
export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    env: {
      NODE_ENV: 'test',
      DATABASE_URL: 'postgresql://test:test@localhost:5432/test',
      REDIS_URL: 'redis://localhost:6379',
      JWT_SECRET: 'x'.repeat(32),
      JWT_REFRESH_SECRET: 'y'.repeat(32),
    },
  },
});
