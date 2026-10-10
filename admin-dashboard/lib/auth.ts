// lib/auth.ts — token storage, JWT decoding, single-flight refresh, logout.
// NOTE: tokens live in localStorage (XSS-readable). Moving to httpOnly cookies
// requires backend changes and is intentionally out of scope here.
import axios from 'axios';

export const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000/api/v1';

const ACCESS_KEY = 'admin_access_token';
const REFRESH_KEY = 'admin_refresh_token';

/** Roles accepted by POST /auth/admin/login (and required by /admin/* routes). */
export const ALLOWED_ROLES = ['MANAGER', 'SUPER_ADMIN'] as const;

export interface SessionUser {
  userId: string;
  role: string;
  plan?: string;
  exp?: number;
}

const isBrowser = () => typeof window !== 'undefined';

export function getAccessToken(): string | null {
  return isBrowser() ? localStorage.getItem(ACCESS_KEY) : null;
}

export function getRefreshToken(): string | null {
  return isBrowser() ? localStorage.getItem(REFRESH_KEY) : null;
}

export function setTokens(accessToken: string, refreshToken?: string | null) {
  if (!isBrowser()) return;
  localStorage.setItem(ACCESS_KEY, accessToken);
  if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
}

export function clearTokens() {
  if (!isBrowser()) return;
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

/** Decode a JWT payload without verifying it (verification happens server-side). */
export function decodeJwt<T = Record<string, any>>(token: string): T | null {
  try {
    const part = token.split('.')[1];
    if (!part) return null;
    let b64 = part.replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) b64 += '=';
    const binary = atob(b64);
    const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(bytes)) as T;
  } catch {
    return null;
  }
}

export function isTokenExpired(token: string, skewSec = 30): boolean {
  const payload = decodeJwt<{ exp?: number }>(token);
  if (!payload?.exp) return true;
  return payload.exp * 1000 <= Date.now() + skewSec * 1000;
}

export function getSessionUser(): SessionUser | null {
  const token = getAccessToken();
  if (!token) return null;
  const p = decodeJwt<any>(token);
  if (!p) return null;
  return { userId: p.userId ?? p.sub, role: p.role, plan: p.plan, exp: p.exp };
}

export function hasAllowedRole(role?: string | null): boolean {
  return !!role && (ALLOWED_ROLES as readonly string[]).includes(role);
}

// ── Single-flight refresh ──────────────────────────────────────
let refreshPromise: Promise<string> | null = null;

/**
 * Rotate tokens via POST /auth/refresh. Concurrent callers share one in-flight
 * request. Resolves with the new access token; rejects (and clears tokens) on failure.
 */
export function refreshTokens(): Promise<string> {
  if (refreshPromise) return refreshPromise;
  const refreshToken = getRefreshToken();
  if (!refreshToken) {
    clearTokens();
    return Promise.reject(new Error('No refresh token'));
  }
  refreshPromise = axios
    .post(`${API_BASE_URL}/auth/refresh`, { refreshToken })
    .then((res) => {
      const { accessToken, refreshToken: next } = res.data ?? {};
      if (!accessToken) throw new Error('Invalid refresh response');
      setTokens(accessToken, next);
      return accessToken as string;
    })
    .catch((err) => {
      clearTokens();
      throw err;
    })
    .finally(() => {
      refreshPromise = null;
    });
  return refreshPromise;
}

export function redirectToLogin() {
  if (isBrowser() && !window.location.pathname.startsWith('/login')) {
    window.location.href = '/login';
  }
}

/** Revoke the refresh token server-side (best effort), then clear local state. */
export async function logout() {
  const refreshToken = getRefreshToken();
  if (refreshToken) {
    try {
      await axios.post(`${API_BASE_URL}/auth/logout`, { refreshToken }, { timeout: 5000 });
    } catch {
      // ignore — we still clear local tokens
    }
  }
  clearTokens();
}
