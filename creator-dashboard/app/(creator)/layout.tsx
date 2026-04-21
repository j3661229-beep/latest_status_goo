'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { CreatorSidebar } from '../../components/CreatorSidebar';

export default function CreatorLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('creator_access_token');
    if (!token) {
      router.replace('/login');
    } else {
      setReady(true);
    }
  }, [pathname]);

  if (!ready) {
    return (
      <div className="min-h-screen bg-surface flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="flex min-h-screen">
      <CreatorSidebar />
      <main className="flex-1 lg:ml-60 p-4 md:p-6 lg:p-8 min-h-screen bg-surface pt-16 lg:pt-8">
        {children}
      </main>
    </div>
  );
}
