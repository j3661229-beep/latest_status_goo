// src/lib/gcs.ts
// Google Cloud Storage upload helper
// All credentials loaded from environment variables — no hardcoded keys.
import { Storage } from '@google-cloud/storage';
import { env } from '../config/env';
import { Readable } from 'stream';
import path from 'path';
import crypto from 'crypto';

let _storage: Storage | null = null;

function getStorage(): Storage {
  if (_storage) return _storage;

  // In production, GCS_SA_KEY_JSON is a base64-encoded service account JSON string.
  // In development without creds, Storage will use Application Default Credentials (ADC).
  if (env.GCS_SA_KEY_JSON) {
    try {
      const keyJson = JSON.parse(
        Buffer.from(env.GCS_SA_KEY_JSON, 'base64').toString('utf-8')
      );
      _storage = new Storage({ credentials: keyJson, projectId: env.GCS_PROJECT_ID });
    } catch {
      // Malformed key — fall through to ADC
      _storage = new Storage({ projectId: env.GCS_PROJECT_ID });
    }
  } else {
    // Development: use ADC or anonymous (will fail on actual write without creds)
    _storage = new Storage({ projectId: env.GCS_PROJECT_ID });
  }

  return _storage;
}

export interface UploadResult {
  url: string;
  filename: string;
  bucket: string;
}

/**
 * Upload a buffer or readable stream to Google Cloud Storage.
 * @param fileData - Buffer or Readable stream of the file
 * @param originalName - Original filename (used to derive extension)
 * @param folder - GCS folder prefix (e.g. 'profiles', 'templates/images')
 * @param contentType - MIME type
 * @returns Public GCS URL
 */
export async function uploadToGCS(
  fileData: Buffer | Readable,
  originalName: string,
  folder: string,
  contentType: string
): Promise<UploadResult> {
  const storage = getStorage();
  const bucket = storage.bucket(env.GCS_BUCKET_NAME!);

  const ext = path.extname(originalName) || '';
  const filename = `${folder}/${Date.now()}_${crypto.randomBytes(8).toString('hex')}${ext}`;

  const file = bucket.file(filename);

  await new Promise<void>((resolve, reject) => {
    const stream = file.createWriteStream({
      metadata: { contentType },
      resumable: false,
      public: true, // Files are publicly readable (CDN-served)
    });

    stream.on('error', reject);
    stream.on('finish', resolve);

    if (fileData instanceof Buffer) {
      stream.end(fileData);
    } else if ('pipe' in fileData) {
      (fileData as Readable).pipe(stream);
    } else {
      stream.end(fileData);
    }
  });

  const url = `${env.GCS_CDN_BASE_URL}/${filename}`;
  return { url, filename, bucket: env.GCS_BUCKET_NAME! };
}

/**
 * Delete a file from GCS by its filename (path within bucket).
 */
export async function deleteFromGCS(filename: string): Promise<void> {
  try {
    const storage = getStorage();
    await storage.bucket(env.GCS_BUCKET_NAME!).file(filename).delete();
  } catch {
    // Ignore delete errors (file may not exist)
  }
}
