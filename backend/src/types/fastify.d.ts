// src/types/fastify.d.ts
import { FastifyRequest } from 'fastify';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';

export interface JWTPayload {
  userId: string;
  role: string;
  plan: string;
}

declare module 'fastify' {
  interface FastifyInstance {
    prisma: PrismaClient;
    redis: Redis;
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
    requireRole: (roles: string[]) => (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }

  interface FastifyRequest {
    user: JWTPayload;
  }
}
