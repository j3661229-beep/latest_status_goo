'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { Sidebar } from '../../components/Sidebar';
import {
  getAccessToken, getRefreshToken, decodeJwt, isTokenExpired, hasAllowedRole,
  refreshTokens, clearTokens,
} from '../../lib/auth';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const deny = () => {
      clearTokens();
      if (!cancelled) {
        setReady(false);
        router.replace('/login');
      }
    };

    (async () => {
      let token = getAccessToken();
      if (!token) return deny();

      if (isTokenExpired(token)) {
        if (!getRefreshToken()) return deny();
        try {
          token = await refreshTokens();
        } catch {
          return deny();
        }
      }

      const payload = decodeJwt<{ role?: string }>(token);
      if (!payload || !hasAllowedRole(payload.role)) return deny();

      if (!cancelled) setReady(true);
    })();

    return () => { cancelled = true; };
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
      <Sidebar />
      <main className="flex-1 lg:ml-60 p-4 md:p-6 lg:p-8 min-h-screen bg-slate-50/50 pt-16 lg:pt-8 max-w-[1600px]">
        {children}
      </main>
    </div>
  );
}
