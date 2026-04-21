// src/plugins/auth.plugin.ts
import fp from 'fastify-plugin';
import { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import fjwt from '@fastify/jwt';
import { env } from '../config/env';

const authPlugin: FastifyPluginAsync = async (fastify) => {
  // Register JWT plugin
  await fastify.register(fjwt, {
    secret: env.JWT_SECRET,
    sign: { expiresIn: '15m' },
  });

  // Decorator: authenticate (verify JWT access token)
  fastify.decorate('authenticate', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      await request.jwtVerify();
    } catch (err) {
      reply.status(401).send({ statusCode: 401, error: 'Unauthorized', message: 'Invalid or expired token' });
    }
  });

  // Decorator: requireRole (role-based access control)
  fastify.decorate('requireRole', (roles: string[]) => {
    return async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        await request.jwtVerify();
        const { role } = request.user as { role: string };

        if (!roles.includes(role)) {
          reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: `This endpoint requires one of: ${roles.join(', ')}`,
          });
        }
      } catch (err) {
        reply.status(401).send({ statusCode: 401, error: 'Unauthorized', message: 'Invalid or expired token' });
      }
    };
  });
};

export default fp(authPlugin, { name: 'auth' });
