// src/modules/upload/upload.route.ts
// GCS-backed file upload endpoints
import { FastifyInstance } from 'fastify';
import { uploadToGCS } from '../../lib/gcs';

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

export async function uploadRoutes(fastify: FastifyInstance) {
  // POST /upload/profile-photo — authenticated user uploads their profile photo
  fastify.post('/profile-photo', {
    config: { rateLimit: { max: 10, timeWindow: '5 minutes' } },
    preHandler: [fastify.authenticate],
    handler: async (req: any, reply: any) => {
      const data = await req.file({ limits: { fileSize: MAX_FILE_SIZE } });
      if (!data) {
        return reply.status(400).send({ error: 'No file provided' });
      }

      const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowedTypes.includes(data.mimetype)) {
        return reply.status(400).send({ error: 'Only JPEG, PNG and WebP images are allowed' });
      }

      const chunks: Buffer[] = [];
      for await (const chunk of data.file) {
        chunks.push(chunk);
      }
      const buffer = Buffer.concat(chunks);

      try {
        const result = await uploadToGCS(
          buffer,
          data.filename,
          `profiles/${req.user.sub}`,
          data.mimetype
        );

        // Update user profile photo in DB
        await fastify.prisma.user.update({
          where: { id: req.user.sub },
          data: { profilePhoto: result.url },
        });

        return reply.send({ url: result.url });
      } catch (err: any) {
        fastify.log.error(err, 'GCS upload failed');
        return reply.status(500).send({ error: 'Upload failed. Please try again.' });
      }
    },
  });

  // POST /upload/template — creator uploads a template image
  fastify.post('/template', {
    config: { rateLimit: { max: 20, timeWindow: '10 minutes' } },
    preHandler: [fastify.authenticate],
    handler: async (req: any, reply: any) => {
      const user = await fastify.prisma.user.findUnique({ where: { id: req.user.sub } });
      if (!user || !['CREATOR', 'MANAGER', 'SUPER_ADMIN'].includes(user.role)) {
        return reply.status(403).send({ error: 'Creator access required' });
      }

      const data = await req.file({ limits: { fileSize: MAX_FILE_SIZE } });
      if (!data) {
        return reply.status(400).send({ error: 'No file provided' });
      }

      const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'video/mp4'];
      if (!allowedTypes.includes(data.mimetype)) {
        return reply.status(400).send({ error: 'Unsupported file type' });
      }

      const folder = data.mimetype.startsWith('video/') ? 'templates/videos' : 'templates/images';

      const chunks: Buffer[] = [];
      for await (const chunk of data.file) {
        chunks.push(chunk);
      }
      const buffer = Buffer.concat(chunks);

      try {
        const result = await uploadToGCS(buffer, data.filename, folder, data.mimetype);
        return reply.send({ url: result.url, filename: result.filename });
      } catch (err: any) {
        fastify.log.error(err, 'GCS template upload failed');
        return reply.status(500).send({ error: 'Upload failed. Please try again.' });
      }
    },
  });
}
