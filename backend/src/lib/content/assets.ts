// src/lib/content/assets.ts
// Generated media is stored privately; clients receive short-lived signed URLs.
// Falls back to the configured CDN base only when signing is unavailable (local dev).
import { Storage } from '@google-cloud/storage';
import { env } from '../../config/env';

const SIGNED_URL_TTL_MS = 6 * 60 * 60 * 1000;
let storage: Storage | null = null;

export function contentObjectKey(kind: 'video' | 'thumb' | 'audio', id: string, version: number, ext: string) {
  return `content/${kind}/${id}/v${version}.${ext}`;
}

export async function resolveAssetUrl(key?: string | null): Promise<string | null> {
  if (!key) return null;
  try {
    storage ??= new Storage({ projectId: env.GCS_PROJECT_ID });
    const [url] = await storage.bucket(env.GCS_BUCKET_NAME).file(key).getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: Date.now() + SIGNED_URL_TTL_MS,
    });
    return url;
  } catch (e) {
    // Signing needs credentials with signBlob permission. Outside production we fall back to the CDN
    // path for convenience. In production, fail CLOSED (no URL) unless an operator explicitly accepts
    // public delivery — a silent fallback would expose private generated assets if the bucket is public.
    const allowPublic = env.NODE_ENV !== 'production' || process.env.CONTENT_ALLOW_PUBLIC_FALLBACK === 'true';
    if (!allowPublic) {
      console.error(`[content] could not sign URL for ${key}: ${(e as Error).message}`);
      return null;
    }
    return `${env.GCS_CDN_BASE_URL.replace(/\/$/, '')}/${key}`;
  }
}

/** Private object storage used by the pipeline (no public ACLs; delivery is via signed URLs). */
export interface ContentStorage {
  put(key: string, data: Buffer, contentType: string): Promise<void>;
  get(key: string): Promise<Buffer>;
}

export const gcsContentStorage: ContentStorage = {
  async put(key, data, contentType) {
    storage ??= new Storage({ projectId: env.GCS_PROJECT_ID });
    await storage.bucket(env.GCS_BUCKET_NAME).file(key).save(data, {
      resumable: false,
      contentType,
      metadata: { cacheControl: 'private, max-age=3600' },
    });
  },
  async get(key) {
    storage ??= new Storage({ projectId: env.GCS_PROJECT_ID });
    const [buf] = await storage.bucket(env.GCS_BUCKET_NAME).file(key).download();
    return buf;
  },
};
