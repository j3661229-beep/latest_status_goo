// src/lib/auth/guards.ts
// Reusable preHandlers that run after `authenticate` / `requireRole`
// (which populate request.user with the live role and creator suspension flag).
import type { FastifyReply, FastifyRequest } from 'fastify';

export const CREATOR_ROLES = ['CREATOR', 'MANAGER', 'SUPER_ADMIN'];

/** Blocks suspended creators from creator-only actions. Admin roles are never blocked. */
export async function requireNotSuspended(request: FastifyRequest, reply: FastifyReply) {
  const user = request.user as { role?: string; creatorSuspended?: boolean } | undefined;
  if (user?.role === 'CREATOR' && user.creatorSuspended) {
    return reply.status(403).send({
      statusCode: 403,
      error: 'Forbidden',
      message: 'Your creator account is suspended.',
    });
  }
}
