import { resolveStateFromCoords } from '../../lib/content/state-locator';
// src/modules/auth/auth.handler.ts
import { FastifyRequest, FastifyReply } from 'fastify';
import { PrismaClient, Prisma, Language, Plan, UserRole, User } from '@prisma/client';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { createHash, randomInt, timingSafeEqual } from 'crypto';
import { GoogleAuthService, GoogleAuthError } from '../../lib/auth/google.service';
import { JWTService } from '../../lib/auth/jwt.service';
import { RefreshTokenStore, TokenPair } from '../../lib/auth/token.store';
import { invalidateUserCaches } from '../../lib/auth/auth-state';
import { normalizePhone, phoneLookupVariants, localIndianNumber } from '../../lib/auth/phone';
import { httpsUrl } from '../../lib/http/validation';
import type { GoogleAuthBody, RefreshBody, AdminLoginBody, OTPSendBody, OTPVerifyBody, DevLoginBody } from './auth.schema';
import type { Redis } from 'ioredis';
import * as bcrypt from 'bcryptjs';
import { env } from '../../config/env';

// ── OTP policy ──────────────────────────────────────────────
const OTP_TTL_SECONDS = 300;          // 5 minutes
const OTP_MAX_ATTEMPTS = 5;           // wrong guesses before the OTP is burned
const OTP_SEND_WINDOW_SECONDS = 600;  // per-phone send limit window (10 min)
const OTP_SEND_MAX_PER_WINDOW = 3;    // sends per phone per window
const TEST_OTP = '123456';

/** Test OTP mode — dev only; hard-disabled in production regardless of ALLOW_TEST_OTP. */
const testOtpEnabled = () => env.NODE_ENV !== 'production' && !!env.ALLOW_TEST_OTP;

const otpKey = (phone: string) => `otp:${phone}`;
const otp2faSessionKey = (phone: string) => `otp:2fa:${phone}`;
const otpAttemptsKey = (phone: string) => `otp:attempts:${phone}`;
const otpSendCountKey = (phone: string) => `otp:sends:${phone}`;
const sha256 = (v: string) => createHash('sha256').update(v).digest('hex');

// ── Firebase ID token verification (Google-managed RS256 keys) ──
const FIREBASE_JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
let firebaseJwks: ReturnType<typeof createRemoteJWKSet> | null = null;
function getFirebaseJwks() {
  if (!firebaseJwks) firebaseJwks = createRemoteJWKSet(new URL(FIREBASE_JWKS_URL));
  return firebaseJwks;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export class AuthHandler {
  constructor(
    private prisma: PrismaClient,
    private redis: Redis
  ) {}

  private get tokenStore() {
    return new RefreshTokenStore(this.redis);
  }

  private async issueTokens(user: Pick<User, 'id' | 'role' | 'plan'>): Promise<TokenPair> {
    const accessToken = await JWTService.signAccessToken({ userId: user.id, role: user.role, plan: user.plan });
    const refreshToken = await JWTService.signRefreshToken(user.id);
    await this.tokenStore.save(user.id, refreshToken);
    return { accessToken, refreshToken };
  }

  private inactive(reply: FastifyReply) {
    return reply.status(403).send({ error: 'Account is disabled. Please contact support.' });
  }

  /**
   * Find the user for a canonical phone number, tolerating legacy rows stored as
   * "98765…" / "9198765…". Legacy rows are migrated to the canonical form; new
   * users are created with it.
   */
  private async findOrCreatePhoneUser(canonical: string): Promise<User> {
    const variants = phoneLookupVariants(canonical);
    const matches = await this.prisma.user.findMany({ where: { phoneNumber: { in: variants } } });
    let user = matches.find((u) => u.phoneNumber === canonical) ?? matches[0];

    if (user) {
      const data: Prisma.UserUpdateInput = { lastActiveAt: new Date() };
      if (user.phoneNumber !== canonical && !matches.some((u) => u.phoneNumber === canonical)) {
        data.phoneNumber = canonical; // migrate legacy spelling
      }
      return this.prisma.user.update({ where: { id: user.id }, data });
    }

    try {
      user = await this.prisma.user.create({
        data: {
          phoneNumber: canonical,
          language: Language.HINDI,
          plan: Plan.FREE,
          role: UserRole.USER,
          isActive: true,
          lastActiveAt: new Date(),
        },
      });
      return user;
    } catch (err) {
      // Concurrent first login for the same number → the other request created it
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        const existing = await this.prisma.user.findUnique({ where: { phoneNumber: canonical } });
        if (existing) return existing;
      }
      throw err;
    }
  }

  private phoneLoginResponse(user: User, tokens: TokenPair) {
    return {
      ...tokens,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phoneNumber: user.phoneNumber,
        plan: user.plan,
        role: user.role,
        language: user.language,
        profilePhoto: user.profilePhoto,
        state: user.state,
        region: user.region,
      },
      onboardingRequired: !user.name || !user.onboardingCompleted,
    };
  }

  // POST /auth/firebase-phone (Mobile User — Firebase Phone Auth)
  async firebasePhoneLogin(req: FastifyRequest<{ Body: { idToken: string } }>, reply: FastifyReply) {
    const projectId = env.FIREBASE_PROJECT_ID;
    if (!projectId) {
      return reply.status(503).send({ error: 'Firebase phone auth not configured' });
    }

    const { idToken } = req.body;
    let phoneNumber: string | null = null;

    try {
      const { payload } = await jwtVerify(idToken, getFirebaseJwks(), {
        issuer: `https://securetoken.google.com/${projectId}`,
        audience: projectId,
        algorithms: ['RS256'],
      });
      if (!payload.sub) throw new Error('Missing subject');
      if (typeof payload.phone_number === 'string') {
        phoneNumber = normalizePhone(payload.phone_number);
      }
    } catch (err) {
      req.log.warn({ err: (err as Error).message }, 'Firebase ID token verification failed');
      return reply.status(401).send({ error: 'Invalid Firebase token' });
    }

    if (!phoneNumber) {
      return reply.status(401).send({ error: 'Firebase token has no phone number' });
    }

    const user = await this.findOrCreatePhoneUser(phoneNumber);
    if (!user.isActive) return this.inactive(reply);

    const tokens = await this.issueTokens(user);
    return reply.status(200).send(this.phoneLoginResponse(user, tokens));
  }

  // POST /auth/google (Mobile User Login)
  async googleLogin(req: FastifyRequest<{ Body: GoogleAuthBody }>, reply: FastifyReply) {
    const { idToken } = req.body;

    // 1. Verify Google token (also requires a verified email)
    let googlePayload;
    try {
      googlePayload = await GoogleAuthService.verifyIdToken(idToken);
    } catch (err) {
      if (err instanceof GoogleAuthError) return reply.status(401).send({ error: err.message });
      throw err;
    }

    // 2. Find by googleId, else link to an existing account with the same (verified) email, else create
    let user = await this.prisma.user.findUnique({ where: { googleId: googlePayload.sub } });

    if (user) {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          lastActiveAt: new Date(),
          // Don't clobber a name/photo the user customised in the app
          ...(!user.name && googlePayload.name ? { name: googlePayload.name } : {}),
          ...(!user.profilePhoto && googlePayload.picture ? { profilePhoto: googlePayload.picture } : {}),
        },
      });
    } else {
      const byEmail = await this.prisma.user.findUnique({ where: { email: googlePayload.email } });
      if (byEmail) {
        if (byEmail.googleId && byEmail.googleId !== googlePayload.sub) {
          return reply.status(409).send({ error: 'This email is already linked to a different Google account.' });
        }
        user = await this.prisma.user.update({
          where: { id: byEmail.id },
          data: {
            googleId: googlePayload.sub,
            lastActiveAt: new Date(),
            ...(!byEmail.name && googlePayload.name ? { name: googlePayload.name } : {}),
            ...(!byEmail.profilePhoto && googlePayload.picture ? { profilePhoto: googlePayload.picture } : {}),
          },
        });
      } else {
        try {
          user = await this.prisma.user.create({
            data: {
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
        } catch (err) {
          if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
            user = await this.prisma.user.findUnique({ where: { googleId: googlePayload.sub } });
          }
          if (!user) throw err;
        }
      }
    }

    if (!user.isActive) return this.inactive(reply);

    // 3. Issue tokens
    const tokens = await this.issueTokens(user);

    return reply.status(200).send({
      ...tokens,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        plan: user.plan,
        role: user.role,
        language: user.language,
        profilePhoto: user.profilePhoto,
      },
      onboardingRequired: false,
    });
  }

  // POST /auth/google/creator (Creator Studio Login)
  async creatorGoogleLogin(req: FastifyRequest<{ Body: GoogleAuthBody }>, reply: FastifyReply) {
    const { idToken } = req.body;

    let googlePayload;
    try {
      googlePayload = await GoogleAuthService.verifyIdToken(idToken);
    } catch (err) {
      if (err instanceof GoogleAuthError) return reply.status(401).send({ error: err.message });
      throw err;
    }

    const user = await this.prisma.user.findUnique({
      where: { email: googlePayload.email },
      include: { creatorProfile: { select: { isSuspended: true } } },
    });

    if (!user || user.role !== UserRole.CREATOR) {
      return reply.status(403).send({ error: 'Access denied: You must be an invited Creator to use this studio.' });
    }
    if (user.googleId && user.googleId !== googlePayload.sub) {
      return reply.status(409).send({ error: 'This email is already linked to a different Google account.' });
    }
    if (!user.isActive) return this.inactive(reply);
    if (user.creatorProfile?.isSuspended) {
      return reply.status(403).send({ error: 'Your creator account is suspended.' });
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        googleId: googlePayload.sub,
        profilePhoto: user.profilePhoto || googlePayload.picture,
        lastActiveAt: new Date(),
      },
    });

    const tokens = await this.issueTokens(user);

    return reply.status(200).send({
      ...tokens,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        profilePhoto: user.profilePhoto || googlePayload.picture,
      },
    });
  }

  // POST /auth/creator/login (Creator email/password login)
  async creatorLogin(req: FastifyRequest<{ Body: AdminLoginBody }>, reply: FastifyReply) {
    const { email, password } = req.body;

    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { creatorProfile: { select: { isSuspended: true } } },
    });

    if (!user || !user.password) {
      return reply.status(401).send({ error: 'Invalid email or password' });
    }

    // Check the password before revealing anything about the account's role/status
    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      return reply.status(401).send({ error: 'Invalid email or password' });
    }

    if (user.role !== UserRole.CREATOR && user.role !== UserRole.SUPER_ADMIN) {
      return reply.status(403).send({ error: 'Access denied: You must be an approved Creator to use this studio.' });
    }
    if (!user.isActive) return this.inactive(reply);
    if (user.role === UserRole.CREATOR && user.creatorProfile?.isSuspended) {
      return reply.status(403).send({ error: 'Your creator account is suspended.' });
    }

    const tokens = await this.issueTokens(user);

    return reply.status(200).send({
      ...tokens,
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

    if (!user || !user.password) {
      return reply.status(401).send({ error: 'Invalid email or password' });
    }

    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      return reply.status(401).send({ error: 'Invalid email or password' });
    }

    if (user.role !== UserRole.SUPER_ADMIN && user.role !== UserRole.MANAGER) {
      return reply.status(403).send({ error: 'Access denied: Insufficient privileges.' });
    }
    if (!user.isActive) return this.inactive(reply);

    const tokens = await this.issueTokens(user);

    return reply.status(200).send({
      ...tokens,
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

    // Atomically consume the stored token: exactly one concurrent refresh wins.
    const won = await this.tokenStore.consume(payload.userId, refreshToken);
    if (!won) {
      // A parallel request may have just rotated this same token — hand back that pair.
      for (let i = 0; i < 5; i++) {
        const pair = await this.tokenStore.getRotation(refreshToken);
        if (pair) return reply.send(pair);
        await sleep(50);
      }
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
    const pair = await this.issueTokens(user);
    await this.tokenStore.rememberRotation(refreshToken, pair);

    return reply.send(pair);
  }

  // POST /auth/dev-login (Development only — route registered only when NODE_ENV=development)
  async devLogin(req: FastifyRequest<{ Body: DevLoginBody }>, reply: FastifyReply) {
    if (env.NODE_ENV !== 'development') {
      return reply.status(403).send({ error: 'Not allowed outside development' });
    }

    const { email } = req.body;
    const user = await this.prisma.user.findUnique({ where: { email } });

    if (!user) {
      return reply.status(404).send({ error: 'User not found' });
    }
    // Never mint privileged tokens without a password
    if (user.role === UserRole.MANAGER || user.role === UserRole.SUPER_ADMIN) {
      return reply.status(403).send({ error: 'dev-login is not available for admin accounts' });
    }
    if (!user.isActive) return this.inactive(reply);

    const tokens = await this.issueTokens(user);

    return reply.status(200).send({
      ...tokens,
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
    // Only revoke when the presented token is the current one (a stale token can't log out a newer session)
    if (payload?.userId && (await this.tokenStore.validate(payload.userId, refreshToken))) {
      await this.tokenStore.invalidate(payload.userId);
    }
    return reply.send({ success: true });
  }

  // POST /auth/otp/send
  async otpSend(req: FastifyRequest<{ Body: OTPSendBody }>, reply: FastifyReply) {
    const phone = normalizePhone(req.body.phoneNumber);
    if (!phone || !phone.startsWith('+91')) {
      return reply.status(400).send({ error: 'Enter a valid 10-digit Indian mobile number' });
    }

    // Per-phone limit (in addition to the per-IP route limit)
    const sends = await this.redis.incr(otpSendCountKey(phone));
    if (sends === 1) await this.redis.expire(otpSendCountKey(phone), OTP_SEND_WINDOW_SECONDS);
    if (sends > OTP_SEND_MAX_PER_WINDOW) {
      return reply.status(429).send({
        statusCode: 429,
        error: 'Too Many Requests',
        message: 'Too many OTP requests for this number. Please try again in a few minutes.',
      });
    }

    const testMode = testOtpEnabled();
    const apiKey = env.TWO_FACTOR_API_KEY;
    if (!apiKey && !testMode) {
      req.log.error('OTP requested but TWO_FACTOR_API_KEY is not configured');
      return reply.status(503).send({ error: 'SMS service not configured' });
    }

    let devOtp: string | undefined;

    if (apiKey) {
      try {
        const rawTenDigit = localIndianNumber(phone);
        // NOTE: 2Factor's API takes the key in the path — never log this URL.
        const res = await fetch(`https://2factor.in/API/V1/${apiKey}/SMS/${rawTenDigit}/AUTOGEN/OTP1`);
        if (!res.ok) throw new Error(`2Factor responded with HTTP ${res.status}`);
        const body = (await res.json().catch(() => null)) as { Status?: string; Details?: string } | null;
        if (body?.Status !== 'Success') throw new Error(`2Factor rejected request: ${body?.Details ?? 'unknown'}`);
        
        const sessionId = body.Details;
        if (!sessionId) throw new Error('2Factor returned success without session ID Details');
        await this.redis.set(otp2faSessionKey(phone), sessionId, 'EX', OTP_TTL_SECONDS);
        await this.redis.del(otpAttemptsKey(phone));
      } catch (err) {
        req.log.warn({ err: (err as Error).message }, '2Factor SMS dispatch failed');
        if (!testMode) {
          return reply.status(502).send({ error: 'Failed to send OTP SMS. Please check mobile number and try again.' });
        }
      }
    }

    // When test mode is active (development only): generate local fallback OTP
    if (testMode) {
      devOtp = String(randomInt(0, 1_000_000)).padStart(6, '0');
      await this.redis.set(otpKey(phone), sha256(devOtp), 'EX', OTP_TTL_SECONDS);
    }

    return reply.status(200).send({
      success: true,
      message: `OTP sent to ${phone}`,
      expiresIn: OTP_TTL_SECONDS,
      ...(testMode && {
        otp: devOtp,
        devNote: `Test OTP mode enabled (ALLOW_TEST_OTP) — ${TEST_OTP} is also accepted`,
      }),
    });
  }

  // POST /auth/otp/verify
  async otpVerify(req: FastifyRequest<{ Body: OTPVerifyBody }>, reply: FastifyReply) {
    const { otp } = req.body;
    const phone = normalizePhone(req.body.phoneNumber);
    if (!phone || !phone.startsWith('+91')) {
      return reply.status(400).send({ error: 'Enter a valid 10-digit Indian mobile number' });
    }

    const testMode = testOtpEnabled();
    const acceptedTestOtp = testMode && (otp === TEST_OTP || otp === '000000');
    let verified = acceptedTestOtp;

    if (!verified) {
      const apiKey = env.TWO_FACTOR_API_KEY;
      const sessionId = await this.redis.get(otp2faSessionKey(phone));

      if (sessionId && apiKey) {
        try {
          const verifyRes = await fetch(`https://2factor.in/API/V1/${apiKey}/SMS/VERIFY/${sessionId}/${otp.trim()}`);
          const verifyBody = (await verifyRes.json().catch(() => null)) as { Status?: string; Details?: string } | null;
          if (verifyBody?.Status === 'Success' && (verifyBody.Details === 'OTP Matched' || verifyBody.Details?.toLowerCase().includes('match'))) {
            verified = true;
            await this.redis.del(otp2faSessionKey(phone));
          } else {
            req.log.warn({ phone, details: verifyBody?.Details }, '2Factor OTP mismatch');
          }
        } catch (err) {
          req.log.error({ err: (err as Error).message }, '2Factor verify request failed');
        }
      }

      // Check local Redis fallback (for testMode or local generation)
      if (!verified) {
        const storedHash = await this.redis.get(otpKey(phone));
        if (storedHash) {
          const attempts = await this.redis.incr(otpAttemptsKey(phone));
          if (attempts === 1) await this.redis.expire(otpAttemptsKey(phone), OTP_TTL_SECONDS);
          if (attempts > OTP_MAX_ATTEMPTS) {
            await this.redis.del(otpKey(phone), otpAttemptsKey(phone));
            return reply.status(429).send({
              statusCode: 429,
              error: 'Too Many Requests',
              message: 'Too many incorrect attempts. Please request a new OTP.',
            });
          }

          const matches = timingSafeEqual(Buffer.from(storedHash, 'hex'), Buffer.from(sha256(otp), 'hex'));
          if (matches) {
            verified = true;
            await this.redis.del(otpKey(phone), otpAttemptsKey(phone));
          }
        }
      }

      if (!verified) {
        return reply.status(400).send({ error: 'Invalid or expired OTP' });
      }
    }

    // OTP is single-use: clean up all OTP keys for this phone
    await this.redis.del(otpKey(phone), otp2faSessionKey(phone), otpAttemptsKey(phone));

    const user = await this.findOrCreatePhoneUser(phone);
    if (!user.isActive) return this.inactive(reply);

    const tokens = await this.issueTokens(user);
    return reply.status(200).send(this.phoneLoginResponse(user, tokens));
  }

  // POST /auth/complete-profile — saves name, photo URL, state, region, language, location (lat/lng/city/district)
  async completeProfile(req: FastifyRequest, reply: FastifyReply) {
    const userId = (req.user as any)?.userId ?? (req.user as any)?.sub;
    if (!userId) return reply.status(401).send({ error: 'Unauthorized' });

    const { name, profilePhoto, state, region, language, city, district, latitude, longitude } = req.body as any;

    if (!name || name.trim().length < 2) {
      return reply.status(400).send({ error: 'Name must be at least 2 characters' });
    }
    if (profilePhoto && !httpsUrl.safeParse(profilePhoto).success) {
      return reply.status(400).send({ error: 'profilePhoto must be an https URL' });
    }

    const lat = typeof latitude === 'number' ? latitude : parseFloat(latitude);
    const lng = typeof longitude === 'number' ? longitude : parseFloat(longitude);
    const hasCoords = !isNaN(lat) && !isNaN(lng);

    let effectiveState = state ? String(state).trim() : undefined;
    let effectiveRegion = region ? String(region).trim() : undefined;

    // Auto-detect state and region code from coordinates if not explicitly provided
    if (hasCoords) {
      const loc = resolveStateFromCoords(lat, lng);
      if (loc) {
        if (!effectiveState) effectiveState = loc.nameEn;
        if (!effectiveRegion) effectiveRegion = loc.code;
      }
    }

    const validLanguages = ['HINDI', 'MARATHI', 'ENGLISH', 'GUJARATI', 'PUNJABI', 'TAMIL', 'TELUGU'];
    const chosenLanguage = language && validLanguages.includes(String(language).toUpperCase())
      ? String(language).toUpperCase()
      : undefined;

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        name: name.trim(),
        displayName: name.trim(),
        ...(profilePhoto ? { profilePhoto, customPhotoUrl: profilePhoto } : {}),
        ...(effectiveState ? { state: effectiveState } : {}),
        ...(effectiveRegion ? { region: effectiveRegion } : {}),
        ...(city ? { city: String(city).trim() } : {}),
        ...(district ? { district: String(district).trim() } : {}),
        ...(hasCoords ? { latitude: lat, longitude: lng } : {}),
        ...(chosenLanguage ? { language: chosenLanguage as Language } : {}),
        onboardingCompleted: true,
        lastActiveAt: new Date(),
      },
      select: {
        id: true, name: true, email: true, phoneNumber: true,
        plan: true, role: true, language: true, profilePhoto: true,
        state: true, region: true, city: true, district: true,
        latitude: true, longitude: true, onboardingCompleted: true,
      },
    });

    await invalidateUserCaches(this.redis, userId);
    return reply.send({ user: updated, success: true });
  }
}
