// src/modules/auth/auth.route.ts
import { FastifyInstance } from 'fastify';
import { AuthHandler } from './auth.handler';
import { GoogleAuthSchema, AdminLoginSchema, RefreshSchema, LogoutSchema, OTPSendSchema, OTPVerifySchema } from './auth.schema';

export async function authRoutes(fastify: FastifyInstance) {
  const handler = new AuthHandler(fastify.prisma, fastify.redis);

  // POST /auth/google  — mobile app login (any Google user)
  fastify.post('/google', {
    schema: {
      body: {
        type: 'object',
        required: ['idToken'],
        properties: { idToken: { type: 'string' } },
      },
    },
    preHandler: async (req, reply) => {
      const result = GoogleAuthSchema.safeParse(req.body);
      if (!result.success) reply.status(400).send({ error: 'Invalid body' });
    },
    handler: handler.googleLogin.bind(handler),
  });

  // POST /auth/google/creator  — Creator Studio Google login (must be invited CREATOR)
  fastify.post('/google/creator', {
    schema: {
      body: {
        type: 'object',
        required: ['idToken'],
        properties: { idToken: { type: 'string' } },
      },
    },
    preHandler: async (req, reply) => {
      const result = GoogleAuthSchema.safeParse(req.body);
      if (!result.success) reply.status(400).send({ error: 'Invalid body' });
    },
    handler: handler.creatorGoogleLogin.bind(handler),
  });

  // POST /auth/admin/login  — Admin / Manager email+password login
  fastify.post('/admin/login', {
    schema: {
      body: {
        type: 'object',
        required: ['email', 'password'],
        properties: {
          email: { type: 'string', format: 'email' },
          password: { type: 'string', minLength: 6 },
        },
      },
    },
    preHandler: async (req, reply) => {
      const result = AdminLoginSchema.safeParse(req.body);
      if (!result.success) reply.status(400).send({ error: 'Invalid body', details: result.error.flatten() });
    },
    handler: handler.adminLogin.bind(handler),
  });

  // POST /auth/refresh
  fastify.post('/refresh', {
    preHandler: async (req, reply) => {
      const result = RefreshSchema.safeParse(req.body);
      if (!result.success) reply.status(400).send({ error: 'Invalid body' });
    },
    handler: handler.refresh.bind(handler),
  });

  // POST /auth/logout
  fastify.post('/logout', {
    preHandler: async (req, reply) => {
      const result = LogoutSchema.safeParse(req.body);
      if (!result.success) reply.status(400).send({ error: 'Invalid body' });
    },
    handler: handler.logout.bind(handler),
  });

  // POST /auth/otp/send
  fastify.post('/otp/send', {
    schema: {
      body: {
        type: 'object',
        required: ['phoneNumber'],
        properties: { phoneNumber: { type: 'string' } },
      },
    },
    preHandler: async (req, reply) => {
      const result = OTPSendSchema.safeParse(req.body);
      if (!result.success) reply.status(400).send({ error: 'Invalid body', details: result.error.flatten() });
    },
    handler: handler.otpSend.bind(handler),
  });

  // POST /auth/otp/verify
  fastify.post('/otp/verify', {
    schema: {
      body: {
        type: 'object',
        required: ['phoneNumber', 'otp'],
        properties: { 
          phoneNumber: { type: 'string' },
          otp: { type: 'string', minLength: 6, maxLength: 6 }
        },
      },
    },
    preHandler: async (req, reply) => {
      const result = OTPVerifySchema.safeParse(req.body);
      if (!result.success) reply.status(400).send({ error: 'Invalid body', details: result.error.flatten() });
    },
    handler: handler.otpVerify.bind(handler),
  });

  // POST /auth/dev-login (dev only)
  fastify.post('/dev-login', {
    handler: handler.devLogin.bind(handler),
  });
}
