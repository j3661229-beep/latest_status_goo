// lib/auth.ts — token storage, JWT decoding and single-flight refresh for Creator Studio.
// NOTE: tokens live in localStorage (readable by any XSS). Moving to httpOnly cookies needs
// coordinated backend + frontend changes and is intentionally out of scope here.
import axios from 'axios';
import { jwtDecode } from 'jwt-decode';

export const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000/api/v1';

const ACCESS_KEY = 'creator_access_token';
const REFRESH_KEY = 'creator_refresh_token';

/** Roles accepted by POST /auth/creator/login (Google creator login only allows CREATOR). */
export const ALLOWED_ROLES = ['CREATOR', 'SUPER_ADMIN'];

export interface SessionUser {
  userId: string;
  role: string;
  exp: number;
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

export function decodeJwt(token: string): Record<string, any> | null {
  try {
    return jwtDecode<Record<string, any>>(token);
  } catch {
    return null;
  }
}

export function isTokenExpired(token: string, skewSec = 30): boolean {
  const payload = decodeJwt(token);
  if (!payload || typeof payload.exp !== 'number') return true;
  return payload.exp * 1000 <= Date.now() + skewSec * 1000;
}

export function getSessionUser(token: string | null = getAccessToken()): SessionUser | null {
  if (!token) return null;
  const p = decodeJwt(token);
  if (!p) return null;
  return { userId: p.userId ?? p.sub, role: p.role, exp: p.exp };
}

let refreshPromise: Promise<string> | null = null;

/** Single-flight refresh: concurrent callers share one in-flight request. Resolves with the new access token. */
export function refreshTokens(): Promise<string> {
  if (refreshPromise) return refreshPromise;
  const refreshToken = getRefreshToken();
  if (!refreshToken) return Promise.reject(new Error('No refresh token'));

  refreshPromise = axios
    .post(`${BASE_URL}/auth/refresh`, { refreshToken }, { timeout: 15_000 })
    .then((r) => {
      const { accessToken, refreshToken: next } = r.data ?? {};
      if (!accessToken) throw new Error('Invalid refresh response');
      setTokens(accessToken, next);
      return accessToken as string;
    })
    .finally(() => {
      refreshPromise = null;
    });
  return refreshPromise;
}

export function redirectToLogin() {
  if (!isBrowser()) return;
  if (!window.location.pathname.startsWith('/login')) window.location.href = '/login';
}

/** Best-effort server-side revoke, then clear local tokens. */
export async function logout() {
  const refreshToken = getRefreshToken();
  if (refreshToken) {
    try {
      await axios.post(`${BASE_URL}/auth/logout`, { refreshToken }, { timeout: 5000 });
    } catch {
      /* ignore: tokens are cleared locally regardless */
    }
  }
  clearTokens();
}
