// src/lib/storage/r2.service.ts
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from '../../config/env';
import { randomUUID } from 'crypto';

const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const ALLOWED_VIDEO_TYPES = ['video/mp4'];
const MAX_IMAGE_SIZE = 5 * 1024 * 1024;  // 5MB
const MAX_VIDEO_SIZE = 50 * 1024 * 1024; // 50MB

function createR2Client(): S3Client | null {
  if (!env.CF_R2_ACCOUNT_ID || !env.CF_R2_ACCESS_KEY || !env.CF_R2_SECRET_KEY) {
    return null;
  }
  return new S3Client({
    region: 'auto',
    endpoint: `https://${env.CF_R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: env.CF_R2_ACCESS_KEY,
      secretAccessKey: env.CF_R2_SECRET_KEY,
    },
  });
}

let r2Client: S3Client | null = null;

export class R2Service {
  private static getClient(): S3Client {
    if (!r2Client) {
      r2Client = createR2Client();
    }
    if (!r2Client) {
      throw new Error('Cloudflare R2 not configured. Set CF_R2_* environment variables.');
    }
    return r2Client;
  }

  static validateImageUpload(mimeType: string, fileSize: number): void {
    if (!ALLOWED_IMAGE_TYPES.includes(mimeType)) {
      throw new Error(`Invalid image type: ${mimeType}. Allowed: ${ALLOWED_IMAGE_TYPES.join(', ')}`);
    }
    if (fileSize > MAX_IMAGE_SIZE) {
      throw new Error(`Image too large: ${(fileSize / 1024 / 1024).toFixed(1)}MB. Max: 5MB`);
    }
  }

  static validateVideoUpload(mimeType: string, fileSize: number): void {
    if (!ALLOWED_VIDEO_TYPES.includes(mimeType)) {
      throw new Error(`Invalid video type: ${mimeType}. Only MP4 allowed.`);
    }
    if (fileSize > MAX_VIDEO_SIZE) {
      throw new Error(`Video too large: ${(fileSize / 1024 / 1024).toFixed(1)}MB. Max: 50MB`);
    }
  }

  // Generate presigned PUT URL for direct client → R2 upload
  static async getPresignedUploadUrl(params: {
    filename: string;
    mimeType: string;
    fileSize: number;
    folder: 'templates' | 'user-photos' | 'thumbnails';
  }): Promise<{ uploadUrl: string; publicUrl: string; key: string }> {
    this.validateImageUpload(params.mimeType, params.fileSize);

    const ext = params.filename.split('.').pop() ?? 'jpg';
    const key = `${params.folder}/${randomUUID()}.${ext}`;

    const command = new PutObjectCommand({
      Bucket: env.CF_R2_BUCKET_NAME,
      Key: key,
      ContentType: params.mimeType,
      ContentLength: params.fileSize,
    });

    const uploadUrl = await getSignedUrl(this.getClient(), command, { expiresIn: 300 });
    const publicUrl = `${env.CF_R2_PUBLIC_URL}/${key}`;

    return { uploadUrl, publicUrl, key };
  }
}
