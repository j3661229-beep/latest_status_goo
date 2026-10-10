'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { GoogleOAuthProvider } from '@react-oauth/google';
import { useState } from 'react';
import { Toaster } from '../components/Toaster';
import { GOOGLE_CLIENT_ID, GOOGLE_ENABLED } from '../lib/google';

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,
        gcTime: 5 * 60 * 1000,
        retry: 1,
        refetchOnWindowFocus: false,
      },
    },
  }));

  const content = (
    <QueryClientProvider client={queryClient}>
      {children}
      <Toaster />
    </QueryClientProvider>
  );

  // Without a configured client id the Google button is hidden entirely (see login page),
  // so don't mount the provider with a placeholder id.
  return GOOGLE_ENABLED ? (
    <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>{content}</GoogleOAuthProvider>
  ) : (
    content
  );
}
