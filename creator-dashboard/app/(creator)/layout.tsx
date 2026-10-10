'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { CreatorSidebar } from '../../components/CreatorSidebar';
import {
  ALLOWED_ROLES, clearTokens, getAccessToken, getSessionUser, isTokenExpired, refreshTokens,
} from '../../lib/auth';

/**
 * Client-side route guard. Decodes the access token (no signature check — the backend is the
 * real authority), verifies role, and refreshes an expired token before rendering anything.
 */
async function checkSession(): Promise<boolean> {
  let token = getAccessToken();
  if (!token) return false;

  const user = getSessionUser(token);
  if (!user || !ALLOWED_ROLES.includes(user.role)) return false;

  if (isTokenExpired(token)) {
    try {
      token = await refreshTokens();
    } catch {
      return false;
    }
    const refreshed = getSessionUser(token);
    if (!refreshed || !ALLOWED_ROLES.includes(refreshed.role)) return false;
  }
  return true;
}

export default function CreatorLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    checkSession().then((ok) => {
      if (cancelled) return;
      if (ok) {
        setReady(true);
      } else {
        clearTokens();
        setReady(false);
        router.replace('/login');
      }
    });
    return () => {
      cancelled = true;
    };
  }, [pathname, router]);

  if (!ready) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen bg-slate-50/50">
      <CreatorSidebar />
      <main className="flex-1 lg:ml-60 p-4 md:p-6 lg:p-8 min-h-screen bg-slate-50/50 pt-16 lg:pt-8 max-w-[1600px]">
        {children}
      </main>
    </div>
  );
}
