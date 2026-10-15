import { describe, it, expect, vi, beforeEach } from 'vitest';

const getSignedUrl = vi.fn();
vi.mock('@google-cloud/storage', () => ({
  Storage: class { bucket() { return { file: () => ({ getSignedUrl }) }; } },
}));

async function load(nodeEnv: string, fallback?: string) {
  vi.resetModules();
  vi.doMock('../src/config/env', () => ({
    env: { NODE_ENV: nodeEnv, GCS_PROJECT_ID: 'p', GCS_BUCKET_NAME: 'b', GCS_CDN_BASE_URL: 'https://cdn.example/b/' },
  }));
  if (fallback === undefined) delete process.env.CONTENT_ALLOW_PUBLIC_FALLBACK; else process.env.CONTENT_ALLOW_PUBLIC_FALLBACK = fallback;
  return import('../src/lib/content/assets');
}

beforeEach(() => { getSignedUrl.mockReset(); vi.spyOn(console, 'error').mockImplementation(() => undefined); });

describe('resolveAssetUrl', () => {
  it('returns null for no key and a signed URL when signing works', async () => {
    const m = await load('production');
    expect(await m.resolveAssetUrl(null)).toBeNull();
    getSignedUrl.mockResolvedValue(['https://signed.example/x?sig=1']);
    expect(await m.resolveAssetUrl('content/video/a/v1.mp4')).toBe('https://signed.example/x?sig=1');
    expect(getSignedUrl.mock.calls[0][0]).toMatchObject({ version: 'v4', action: 'read' });
  });
  it('fails CLOSED in production when signing fails (no silent public URL)', async () => {
    const m = await load('production');
    getSignedUrl.mockRejectedValue(new Error('no signBlob permission'));
    expect(await m.resolveAssetUrl('content/video/a/v1.mp4')).toBeNull();
  });
  it('production can explicitly opt in to public delivery', async () => {
    const m = await load('production', 'true');
    getSignedUrl.mockRejectedValue(new Error('x'));
    expect(await m.resolveAssetUrl('content/video/a/v1.mp4')).toBe('https://cdn.example/b/content/video/a/v1.mp4');
  });
  it('development falls back to the CDN path for convenience', async () => {
    const m = await load('development');
    getSignedUrl.mockRejectedValue(new Error('x'));
    expect(await m.resolveAssetUrl('k')).toBe('https://cdn.example/b/k');
  });
});
