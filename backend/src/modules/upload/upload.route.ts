// src/modules/upload/upload.route.ts
// GCS & Cloudinary media upload endpoints
import { FastifyInstance } from 'fastify';
import { uploadToGCS } from '../../lib/gcs';
import { CloudinaryService } from '../../lib/storage/cloudinary.service';
import { CREATOR_ROLES, requireNotSuspended } from '../../lib/auth/guards';
import { invalidateUserCaches } from '../../lib/auth/auth-state';
import { env } from '../../config/env';

const MB = 1024 * 1024;
const MAX_IMAGE_SIZE = 10 * MB;
const MAX_VIDEO_SIZE = 50 * MB;

type DetectedType = { mime: 'image/jpeg' | 'image/png' | 'image/webp' | 'video/mp4'; ext: string };

/**
 * Identify the real file type from its leading bytes (magic numbers) instead of
 * trusting the client-supplied Content-Type.
 */
function detectFileType(head: Buffer): DetectedType | null {
  if (head.length >= 3 && head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff) {
    return { mime: 'image/jpeg', ext: '.jpg' };
  }
  if (head.length >= 8 && head.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return { mime: 'image/png', ext: '.png' };
  }
  if (head.length >= 12 && head.toString('ascii', 0, 4) === 'RIFF' && head.toString('ascii', 8, 12) === 'WEBP') {
    return { mime: 'image/webp', ext: '.webp' };
  }
  // ISO BMFF: [size:4]['ftyp'][brand:4] — accept MP4 brands, reject QuickTime ('qt  ')
  if (head.length >= 12 && head.toString('ascii', 4, 8) === 'ftyp') {
    const brand = head.toString('ascii', 8, 12);
    if (brand !== 'qt  ') return { mime: 'video/mp4', ext: '.mp4' };
  }
  return null;
}

class UploadRejected extends Error {
  constructor(public statusCode: number, message: string) {
    super(message);
  }
}

/**
 * Read a multipart file stream, validating its type from the first bytes and
 * enforcing the per-type size limit while streaming (aborts early on oversize).
 */
async function readValidatedFile(
  stream: AsyncIterable<Buffer>,
  allowed: DetectedType['mime'][],
): Promise<{ buffer: Buffer; type: DetectedType }> {
  const chunks: Buffer[] = [];
  let total = 0;
  let type: DetectedType | null = null;
  let head = Buffer.alloc(0);

  for await (const chunk of stream) {
    chunks.push(chunk);
    total += chunk.length;

    if (!type) {
      head = Buffer.concat([head, chunk]).subarray(0, 16);
      if (head.length < 12 && total < 12) continue; // need more bytes to decide
      type = detectFileType(head);
      if (!type || !allowed.includes(type.mime)) {
        throw new UploadRejected(415, 'Unsupported file type');
      }
    }

    const limit = type.mime.startsWith('video/') ? MAX_VIDEO_SIZE : MAX_IMAGE_SIZE;
    if (total > limit) {
      throw new UploadRejected(413, `File too large (max ${limit / MB} MB)`);
    }
  }

  if (!type) {
    type = detectFileType(head);
    if (!type || !allowed.includes(type.mime)) throw new UploadRejected(415, 'Unsupported file type');
  }

  return { buffer: Buffer.concat(chunks), type };
}

export async function uploadRoutes(fastify: FastifyInstance) {
  // Helper to upload via GCS (if configured) with automatic Cloudinary fallback
  async function uploadMedia(
    buffer: Buffer,
    filenameHint: string,
    folder: string,
    mimetype: string
  ): Promise<{ url: string; filename: string }> {
    // 1. Try GCS if Service Account JSON credentials exist
    if (env.GCS_SA_KEY_JSON) {
      try {
        const result = await uploadToGCS(buffer, filenameHint, folder, mimetype);
        return { url: result.url, filename: result.filename };
      } catch (err) {
        fastify.log.warn({ err }, 'GCS upload failed, falling back to Cloudinary');
      }
    }

    // 2. Fallback to Cloudinary (always available via CLOUDINARY_URL)
    const cloudinaryRes = await CloudinaryService.uploadStream(buffer, folder);
    const url = cloudinaryRes.secure_url || cloudinaryRes.url;
    return { url, filename: cloudinaryRes.public_id || filenameHint };
  }

  // POST /upload/profile-photo — authenticated user uploads their profile photo
  fastify.post('/profile-photo', {
    config: { rateLimit: { max: 10, timeWindow: '5 minutes' } },
    preHandler: [fastify.authenticate],
    handler: async (req: any, reply: any) => {
      const userId = req.user?.userId;
      if (!userId) {
        return reply.status(401).send({ error: 'Unauthorized: user ID missing from token' });
      }

      const data = await req.file({ limits: { fileSize: MAX_IMAGE_SIZE } });
      if (!data) {
        return reply.status(400).send({ error: 'No file provided' });
      }

      let file;
      try {
        file = await readValidatedFile(data.file, ['image/jpeg', 'image/png', 'image/webp']);
      } catch (err: any) {
        if (err instanceof UploadRejected) {
          data.file.resume(); // drain the rest of the rejected upload
          return reply.status(err.statusCode).send({
            error: err.statusCode === 415 ? 'Only JPEG, PNG and WebP images are allowed' : err.message,
          });
        }
        throw err; // e.g. multipart RequestFileTooLargeError → 413 via error handler
      }

      try {
        const result = await uploadMedia(file.buffer, `profile${file.type.ext}`, `profiles/${userId}`, file.type.mime);

        // Update user profile photo in DB
        await fastify.prisma.user.update({
          where: { id: userId },
          data: { profilePhoto: result.url },
        });
        await invalidateUserCaches(fastify.redis, userId);

        return reply.send({ url: result.url });
      } catch (err: any) {
        fastify.log.error(err, 'Profile photo upload failed');
        return reply.status(500).send({ error: 'Upload failed. Please try again.' });
      }
    },
  });

  // POST /upload/template — creator uploads a template image or video
  fastify.post('/template', {
    config: { rateLimit: { max: 20, timeWindow: '10 minutes' } },
    preHandler: [fastify.requireRole(CREATOR_ROLES), requireNotSuspended],
    handler: async (req: any, reply: any) => {
      const data = await req.file({ limits: { fileSize: MAX_VIDEO_SIZE } });
      if (!data) {
        return reply.status(400).send({ error: 'No file provided' });
      }

      let file;
      try {
        file = await readValidatedFile(data.file, ['image/jpeg', 'image/png', 'image/webp', 'video/mp4']);
      } catch (err: any) {
        if (err instanceof UploadRejected) {
          data.file.resume(); // drain the rest of the rejected upload
          return reply.status(err.statusCode).send({ error: err.message });
        }
        throw err;
      }

      const folder = file.type.mime.startsWith('video/') ? 'templates/videos' : 'templates/images';

      try {
        const result = await uploadMedia(file.buffer, `template${file.type.ext}`, folder, file.type.mime);
        return reply.send({ url: result.url, filename: result.filename });
      } catch (err: any) {
        fastify.log.error(err, 'Template upload failed');
        return reply.status(500).send({ error: 'Upload failed. Please try again.' });
      }
    },
  });
}
