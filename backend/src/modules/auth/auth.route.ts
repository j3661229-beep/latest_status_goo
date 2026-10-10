// src/modules/auth/auth.route.ts
import { FastifyInstance, FastifyReply } from 'fastify';
import type { ZodTypeAny } from 'zod';
import { AuthHandler } from './auth.handler';
import {
  GoogleAuthSchema, AdminLoginSchema, RefreshSchema, LogoutSchema,
  OTPSendSchema, OTPVerifySchema, DevLoginSchema,
} from './auth.schema';
import type {
  GoogleAuthBody, AdminLoginBody, RefreshBody, OTPSendBody, OTPVerifyBody, DevLoginBody,
} from './auth.schema';
import { env } from '../../config/env';

/** preHandler that validates req.body with zod and short-circuits with 400. */
function validateBody(schema: ZodTypeAny) {
  // `req: any` keeps the route's Body generic inferred from the typed handler
  return async (req: any, reply: FastifyReply) => {
    const result = schema.safeParse(req.body ?? {});
    if (!result.success) {
      return reply.status(400).send({ error: 'Invalid body', details: result.error.flatten() });
    }
    req.body = result.data;
  };
}

const refreshTokenBodySchema = {
  type: 'object',
  required: ['refreshToken'],
  properties: { refreshToken: { type: 'string', minLength: 10 } },
};

export async function authRoutes(fastify: FastifyInstance) {
  const handler = new AuthHandler(fastify.prisma, fastify.redis);

  // POST /auth/google  — mobile app login (any Google user)
  fastify.post<{ Body: GoogleAuthBody }>('/google', {
    config: { rateLimit: { max: 20, timeWindow: '1 minute' } },
    schema: {
      body: {
        type: 'object',
        required: ['idToken'],
        properties: { idToken: { type: 'string' } },
      },
    },
    preHandler: validateBody(GoogleAuthSchema),
    handler: handler.googleLogin.bind(handler),
  });

  // POST /auth/google/creator  — Creator Studio Google login (must be invited CREATOR)
  fastify.post<{ Body: GoogleAuthBody }>('/google/creator', {
    config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
    schema: {
      body: {
        type: 'object',
        required: ['idToken'],
        properties: { idToken: { type: 'string' } },
      },
    },
    preHandler: validateBody(GoogleAuthSchema),
    handler: handler.creatorGoogleLogin.bind(handler),
  });

  // POST /auth/creator/login — Creator email+password login
  fastify.post<{ Body: AdminLoginBody }>('/creator/login', {
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
    preHandler: validateBody(AdminLoginSchema),
    handler: handler.creatorLogin.bind(handler),
  });

  // POST /auth/admin/login  — Admin / Manager email+password login
  fastify.post<{ Body: AdminLoginBody }>('/admin/login', {
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
    preHandler: validateBody(AdminLoginSchema),
    handler: handler.adminLogin.bind(handler),
  });

  // POST /auth/refresh
  fastify.post<{ Body: RefreshBody }>('/refresh', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    schema: { body: refreshTokenBodySchema },
    preHandler: validateBody(RefreshSchema),
    handler: handler.refresh.bind(handler),
  });

  // POST /auth/logout
  fastify.post<{ Body: RefreshBody }>('/logout', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    schema: { body: refreshTokenBodySchema },
    preHandler: validateBody(LogoutSchema),
    handler: handler.logout.bind(handler),
  });

  // POST /auth/otp/send  (per-IP limit here; per-phone limit enforced in the handler)
  fastify.post<{ Body: OTPSendBody }>('/otp/send', {
    config: { rateLimit: { max: 5, timeWindow: '5 minutes' } },
    schema: {
      body: {
        type: 'object',
        required: ['phoneNumber'],
        properties: { phoneNumber: { type: 'string', maxLength: 20 } },
      },
    },
    preHandler: validateBody(OTPSendSchema),
    handler: handler.otpSend.bind(handler),
  });

  // POST /auth/otp/verify
  fastify.post<{ Body: OTPVerifyBody }>('/otp/verify', {
    config: { rateLimit: { max: 10, timeWindow: '5 minutes' } },
    schema: {
      body: {
        type: 'object',
        required: ['phoneNumber', 'otp'],
        properties: {
          phoneNumber: { type: 'string', maxLength: 20 },
          otp: { type: 'string', minLength: 6, maxLength: 6 }
        },
      },
    },
    preHandler: validateBody(OTPVerifySchema),
    handler: handler.otpVerify.bind(handler),
  });

  // POST /auth/dev-login — only registered when NODE_ENV=development.
  // The handler also refuses admin accounts and re-checks NODE_ENV (defence in depth).
  if (env.NODE_ENV === 'development') {
    fastify.post<{ Body: DevLoginBody }>('/dev-login', {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
      preHandler: validateBody(DevLoginSchema),
      handler: handler.devLogin.bind(handler),
    });
  }

  // POST /auth/firebase-phone — verify Firebase phone auth ID token
  fastify.post<{ Body: { idToken: string } }>('/firebase-phone', {
    config: { rateLimit: { max: 20, timeWindow: '5 minutes' } },
    schema: {
      body: {
        type: 'object',
        required: ['idToken'],
        properties: { idToken: { type: 'string', minLength: 10 } },
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
          profilePhoto: { type: 'string', maxLength: 2048 },
          state: { type: 'string', maxLength: 100 },
          region: { type: 'string', maxLength: 100 },
          language: { type: 'string', enum: ['HINDI', 'MARATHI', 'ENGLISH', 'GUJARATI', 'PUNJABI', 'TAMIL', 'TELUGU'] },
        },
      },
    },
    preHandler: [fastify.authenticate],
    handler: handler.completeProfile.bind(handler),
  });
}
