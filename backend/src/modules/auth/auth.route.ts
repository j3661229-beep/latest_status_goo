// src/modules/auth/auth.route.ts
import { FastifyInstance } from 'fastify';
import { AuthHandler } from './auth.handler';
import { GoogleAuthSchema, AdminLoginSchema, RefreshSchema, LogoutSchema, OTPSendSchema, OTPVerifySchema } from './auth.schema';

export async function authRoutes(fastify: FastifyInstance) {
  const handler = new AuthHandler(fastify.prisma, fastify.redis);

  // POST /auth/google  — mobile app login (any Google user)
  fastify.post('/google', {
    config: { rateLimit: { max: 20, timeWindow: '1 minute' } },
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
    config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
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

  // POST /auth/creator/login — Creator email+password login
  fastify.post('/creator/login', {
    config: { rateLimit: { max: 15, timeWindow: '5 minutes' } },
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
    handler: handler.creatorLogin.bind(handler),
  });

  // POST /auth/admin/login  — Admin / Manager email+password login
  fastify.post('/admin/login', {
    config: { rateLimit: { max: 10, timeWindow: '5 minutes' } },
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
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
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
    config: { rateLimit: { max: 5, timeWindow: '5 minutes' } },
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
    config: { rateLimit: { max: 10, timeWindow: '5 minutes' } },
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

  // POST /auth/dev-login — NEVER available in production
  // Route is not registered at all in production; handler also has a defence-in-depth guard.
  if (process.env.NODE_ENV !== 'production') {
    fastify.post('/dev-login', {
      handler: handler.devLogin.bind(handler),
    });
  }

  // POST /auth/firebase-phone — verify Firebase phone auth ID token
  fastify.post('/firebase-phone', {
    config: { rateLimit: { max: 20, timeWindow: '5 minutes' } },
    schema: {
      body: {
        type: 'object',
        required: ['idToken'],
        properties: { idToken: { type: 'string' } },
      },
    },
    handler: handler.firebasePhoneLogin.bind(handler),
  });

  // POST /auth/complete-profile — saves name, photo, state, region after OTP onboarding
  fastify.post('/complete-profile', {
    config: { rateLimit: { max: 10, timeWindow: '5 minutes' } },
    schema: {
      body: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string', minLength: 2, maxLength: 100 },
          profilePhoto: { type: 'string' },
          state: { type: 'string' },
          region: { type: 'string' },
          language: { type: 'string', enum: ['HINDI', 'MARATHI', 'ENGLISH', 'GUJARATI', 'PUNJABI', 'TAMIL', 'TELUGU'] },
        },
      },
    },
    preHandler: [fastify.authenticate],
    handler: handler.completeProfile.bind(handler),
  });
}
