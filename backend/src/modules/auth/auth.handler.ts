// src/modules/auth/auth.handler.ts
import { FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient, Language, Plan, UserRole } from '@prisma/client';
import { GoogleAuthService } from '../../lib/auth/google.service';
import { JWTService } from '../../lib/auth/jwt.service';
import { RefreshTokenStore } from '../../lib/auth/token.store';
import type { GoogleAuthBody, RefreshBody, AdminLoginBody } from './auth.schema';
import type { Redis } from 'ioredis';
import * as bcrypt from 'bcryptjs';

export class AuthHandler {
  constructor(
    private prisma: PrismaClient,
    private redis: Redis
  ) {}

  private get tokenStore() {
    return new RefreshTokenStore(this.redis);
  }

  // POST /auth/google (Mobile User Login)
  async googleLogin(req: FastifyRequest<{ Body: GoogleAuthBody }>, reply: FastifyReply) {
    const { idToken } = req.body;

    // 1. Verify Google token
    const googlePayload = await GoogleAuthService.verifyIdToken(idToken);

    // 2. Upsert user
    const user = await this.prisma.user.upsert({
      where: { googleId: googlePayload.sub },
      update: {
        lastActiveAt: new Date(),
        profilePhoto: googlePayload.picture,
        name: googlePayload.name,
      },
      create: {
        googleId: googlePayload.sub,
        email: googlePayload.email,
        name: googlePayload.name,
        profilePhoto: googlePayload.picture,
        language: Language.HINDI,
        plan: Plan.FREE,
        role: UserRole.USER,
        isActive: true,
        lastActiveAt: new Date(),
      },
    });

    // 3. Issue tokens
    const accessToken = await JWTService.signAccessToken({
      userId: user.id,
      role: user.role,
      plan: user.plan,
    });
    const refreshToken = await JWTService.signRefreshToken(user.id);
    await this.tokenStore.save(user.id, refreshToken);

    return reply.status(200).send({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        plan: user.plan,
        role: user.role,
        language: user.language,
        profilePhoto: user.profilePhoto,
      },
    });
  }

  // POST /auth/google/creator (Creator Studio Login)
  async creatorGoogleLogin(req: FastifyRequest<{ Body: GoogleAuthBody }>, reply: FastifyReply) {
    const { idToken } = req.body;

    const googlePayload = await GoogleAuthService.verifyIdToken(idToken);

    const user = await this.prisma.user.findUnique({
      where: { email: googlePayload.email },
    });

    if (!user || user.role !== UserRole.CREATOR) {
      return reply.status(403).send({ error: 'Access denied: You must be an invited Creator to use this studio.' });
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        googleId: googlePayload.sub,
        profilePhoto: googlePayload.picture || user.profilePhoto,
        lastActiveAt: new Date(),
      },
    });

    const accessToken = await JWTService.signAccessToken({
      userId: user.id,
      role: user.role,
      plan: user.plan,
    });
    const refreshToken = await JWTService.signRefreshToken(user.id);
    await this.tokenStore.save(user.id, refreshToken);

    return reply.status(200).send({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        profilePhoto: user.profilePhoto,
      },
    });
  }

  // POST /auth/admin/login
  async adminLogin(req: FastifyRequest<{ Body: AdminLoginBody }>, reply: FastifyReply) {
    const { email, password } = req.body;

    const user = await this.prisma.user.findUnique({ where: { email } });

    if (!user || !user.isActive || !user.password) {
      return reply.status(401).send({ error: 'Invalid email or password' });
    }

    if (user.role !== UserRole.SUPER_ADMIN && user.role !== UserRole.MANAGER) {
      return reply.status(403).send({ error: 'Access denied: Insufficient privileges.' });
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      return reply.status(401).send({ error: 'Invalid email or password' });
    }

    const accessToken = await JWTService.signAccessToken({
      userId: user.id,
      role: user.role,
      plan: user.plan,
    });
    const refreshToken = await JWTService.signRefreshToken(user.id);
    await this.tokenStore.save(user.id, refreshToken);

    return reply.status(200).send({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  }

  // POST /auth/refresh
  async refresh(req: FastifyRequest<{ Body: RefreshBody }>, reply: FastifyReply) {
    const { refreshToken } = req.body;

    const payload = await JWTService.verifyRefreshToken(refreshToken);
    if (!payload) {
      return reply.status(401).send({ error: 'Invalid refresh token' });
    }

    const valid = await this.tokenStore.validate(payload.userId, refreshToken);
    if (!valid) {
      return reply.status(401).send({ error: 'Refresh token revoked' });
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.userId },
      select: { id: true, role: true, plan: true, isActive: true },
    });

    if (!user || !user.isActive) {
      return reply.status(403).send({ error: 'Account inactive' });
    }

    // Token rotation
    const newAccessToken = await JWTService.signAccessToken({
      userId: user.id,
      role: user.role,
      plan: user.plan,
    });
    const newRefreshToken = await JWTService.signRefreshToken(user.id);
    await this.tokenStore.save(user.id, newRefreshToken);

    return reply.send({ accessToken: newAccessToken, refreshToken: newRefreshToken });
  }

  // POST /auth/dev-login (Development only)
  async devLogin(req: FastifyRequest<{ Body: { email: string } }>, reply: FastifyReply) {
    if (process.env.NODE_ENV === 'production') {
      return reply.status(403).send({ error: 'Not allowed in production' });
    }

    const { email } = req.body;
    const user = await this.prisma.user.findUnique({ where: { email } });
    
    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }

    const accessToken = await JWTService.signAccessToken({
      userId: user.id,
      role: user.role,
      plan: user.plan,
    });
    const refreshToken = await JWTService.signRefreshToken(user.id);
    await this.tokenStore.save(user.id, refreshToken);

    return reply.status(200).send({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        plan: user.plan,
        role: user.role,
      },
    });
  }

  // POST /auth/logout
  async logout(req: FastifyRequest<{ Body: RefreshBody }>, reply: FastifyReply) {
    const { refreshToken } = req.body;
    const payload = await JWTService.verifyRefreshToken(refreshToken);
    if (payload?.userId) {
      await this.tokenStore.invalidate(payload.userId);
    }
    return reply.send({ success: true });
  }
}
