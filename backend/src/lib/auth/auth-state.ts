// src/lib/auth/auth-state.ts
// Short-lived cache of the security-relevant user state (active flag, role, plan,
// creator suspension) so every authenticated request can reject banned users and
// honour role changes without waiting for the 15-minute access token to expire.
import type { PrismaClient, Prisma } from '@prisma/client';
import type { Redis } from 'ioredis';

export const AUTH_STATE_TTL = 60; // seconds

export interface AuthState {
  isActive: boolean;
  role: string;
  plan: string;
  creatorSuspended: boolean;
}

export const authStateKey = (userId: string) => `authstate:${userId}`;

export async function getAuthState(
  prisma: PrismaClient,
  redis: Redis,
  userId: string,
): Promise<AuthState | null> {
  const key = authStateKey(userId);
  try {
    const cached = await redis.get(key);
    if (cached) return JSON.parse(cached) as AuthState;
  } catch {
    // Cache miss / Redis failure → fall through to DB
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      isActive: true,
      role: true,
      plan: true,
      creatorProfile: { select: { isSuspended: true } },
    },
  });
  if (!user) return null;

  const state: AuthState = {
    isActive: user.isActive,
    role: user.role,
    plan: user.plan,
    creatorSuspended: user.creatorProfile?.isSuspended ?? false,
  };

  try {
    await redis.setex(key, AUTH_STATE_TTL, JSON.stringify(state));
  } catch {
    // ignore cache write failures
  }
  return state;
}

/** Drop every cached view of a user (profile, plan, auth state). */
export async function invalidateUserCaches(redis: Redis, userId: string): Promise<void> {
  try {
    await redis.del(authStateKey(userId), `user:${userId}`, `plan:${userId}`);
  } catch {
    // ignore
  }
}

/**
 * Fields safe to return to clients for a User row.
 * Never includes password, googleId or device push identifiers.
 */
export const safeUserSelect = {
  id: true,
  email: true,
  phoneNumber: true,
  name: true,
  displayName: true,
  profilePhoto: true,
  customPhotoUrl: true,
  language: true,
  plan: true,
  planExpiresAt: true,
  role: true,
  isActive: true,
  timezone: true,
  state: true,
  region: true,
  city: true,
  district: true,
  latitude: true,
  longitude: true,
  onboardingCompleted: true,
  businessName: true,
  businessPhone: true,
  businessAddress: true,
  businessDesignation: true,
  businessLogo: true,
  frameType: true,
  streakCount: true,
  lastStreakDate: true,
  lastActiveAt: true,
  totalShares: true,
  totalSaves: true,
  appVersion: true,
  deviceModel: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.UserSelect;

/** Compact user summary for embedding in lists (admin stats, creators, etc.). */
export const userSummarySelect = {
  id: true,
  name: true,
  email: true,
  phoneNumber: true,
  profilePhoto: true,
  role: true,
  plan: true,
  language: true,
  isActive: true,
  createdAt: true,
} satisfies Prisma.UserSelect;
