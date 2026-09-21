// src/lib/storage/r2.service.ts
// DEPRECATED: Cloudflare R2 storage has been replaced by Google Cloud Storage.
// This file is kept to avoid import errors but all new uploads go through src/lib/gcs.ts

export class R2Service {
  /** @deprecated Use uploadToGCS from lib/gcs.ts instead */
  isAvailable() { return false; }
}

export const r2Service = new R2Service();
