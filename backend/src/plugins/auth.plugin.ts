// src/plugins/auth.plugin.ts
import fp from 'fastify-plugin';
import { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import fjwt from '@fastify/jwt';
import { env } from '../config/env';
import { getAuthState } from '../lib/auth/auth-state';
import { TOKEN_ISSUER } from '../lib/auth/jwt.service';

const authPlugin: FastifyPluginAsync = async (fastify) => {
  // Register JWT plugin (access tokens are signed by JWTService with JWT_SECRET / HS256)
  await fastify.register(fjwt, {
    secret: env.JWT_SECRET,
    sign: { expiresIn: '15m' },
  });

  /**
   * Verify the bearer token and load the user's current auth state.
   * Returns an error descriptor instead of sending, so callers decide the response.
   */
  async function verifyRequest(
    request: FastifyRequest,
  ): Promise<{ status: 401 | 403; message: string } | null> {
    try {
      await request.jwtVerify();
    } catch {
      return { status: 401, message: 'Invalid or expired token' };
    }

    const payload = request.user as any;
    // Only access tokens may authenticate API calls (refresh tokens carry type 'refresh').
    if (payload?.type !== 'access' || payload?.iss !== TOKEN_ISSUER || !payload?.userId) {
      return { status: 401, message: 'Invalid or expired token' };
    }

    const state = await getAuthState(fastify.prisma, fastify.redis, payload.userId);
    if (!state) return { status: 401, message: 'Invalid or expired token' };
    if (!state.isActive) return { status: 403, message: 'Account is disabled' };

    // Use the live role/plan rather than the (up to 15 min old) token claims,
    // so admin role changes and plan purchases take effect immediately.
    payload.role = state.role;
    payload.plan = state.plan;
    payload.creatorSuspended = state.creatorSuspended;
    return null;
  }

  function sendAuthError(reply: FastifyReply, err: { status: 401 | 403; message: string }) {
    return reply.status(err.status).send({
      statusCode: err.status,
      error: err.status === 401 ? 'Unauthorized' : 'Forbidden',
      message: err.message,
    });
  }

  // Decorator: authenticate (verify JWT access token + active account)
  fastify.decorate('authenticate', async (request: FastifyRequest, reply: FastifyReply) => {
    const err = await verifyRequest(request);
    if (err) return sendAuthError(reply, err);
  });

  // Decorator: optionalAuthenticate (allow guest access without 401)
  fastify.decorate('optionalAuthenticate', async (request: FastifyRequest, _reply: FastifyReply) => {
    if (!request.headers.authorization) return;
    try {
      const err = await verifyRequest(request);
      // Invalid / disabled credentials → treat as guest
      if (err) (request as any).user = undefined;
    } catch {
      (request as any).user = undefined;
    }
  });

  // Decorator: requireRole (role-based access control, using the live DB role)
  fastify.decorate('requireRole', (roles: string[]) => {
    return async (request: FastifyRequest, reply: FastifyReply) => {
      const err = await verifyRequest(request);
      if (err) return sendAuthError(reply, err);

      const { role } = request.user as { role: string };
      if (!roles.includes(role)) {
        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: `This endpoint requires one of: ${roles.join(', ')}`,
        });
      }
    };
  });
};

export default fp(authPlugin, { name: 'auth', dependencies: ['prisma', 'redis'] });
