'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { GoogleLogin } from '@react-oauth/google';
import { Sparkles, AlertCircle, Shield } from 'lucide-react';
import { authApi } from '@/lib/api';

export default function CreatorLoginPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSuccess = async (credentialResponse: any) => {
    const idToken = credentialResponse.credential;
    if (!idToken) {
      setError('Google did not return a valid credential. Please try again.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const data = await authApi.creatorGoogleLogin(idToken);
      localStorage.setItem('creator_access_token', data.accessToken);
      router.replace('/dashboard');
    } catch (err: any) {
      const msg = err?.response?.data?.error || err?.message || 'Sign-in failed.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-950 to-indigo-950 flex items-center justify-center p-4">
      {/* Glow blobs */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -left-40 w-96 h-96 bg-primary/25 rounded-full blur-3xl" />
        <div className="absolute -bottom-20 -right-20 w-80 h-80 bg-secondary/20 rounded-full blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-indigo-600/10 rounded-full blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 shadow-2xl">
          {/* Brand */}
          <div className="flex flex-col items-center mb-8">
            <div className="w-16 h-16 rounded-3xl bg-gradient-to-br from-primary to-secondary flex items-center justify-center mb-4 shadow-2xl shadow-primary/40">
              <Sparkles size={28} className="text-white" />
            </div>
            <h1 className="text-3xl font-black text-white tracking-tight">Status Go</h1>
            <p className="text-slate-400 text-sm mt-1 font-semibold">Creator Studio</p>
          </div>

          {/* Badge */}
          <div className="flex items-center justify-center mb-6">
            <div className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-full px-4 py-2">
              <Shield size={13} className="text-primary" />
              <span className="text-slate-300 text-xs font-semibold">Invite-Only Creator Access</span>
            </div>
          </div>

          {/* Description */}
          <div className="text-center mb-6">
            <p className="text-slate-300 text-sm leading-relaxed">
              Sign in with the Google account that was{' '}
              <span className="text-primary font-bold">invited by a Status Go Admin</span>.
            </p>
            <p className="text-slate-500 text-xs mt-2">
              Only approved creators can access this studio.
            </p>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 bg-red-500/10 border border-red-500/30 text-red-400 rounded-2xl px-4 py-3 mb-5 text-sm">
              <AlertCircle size={16} className="shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          {/* Google Login Button */}
          <div className={`flex justify-center ${loading ? 'opacity-60 pointer-events-none' : ''}`}>
            {loading ? (
              <div className="flex items-center gap-3 bg-white text-slate-700 font-bold py-3 px-6 rounded-2xl text-sm w-full justify-center">
                <div className="w-5 h-5 border-2 border-slate-300 border-t-slate-700 rounded-full animate-spin" />
                Signing in…
              </div>
            ) : (
              <div className="w-full">
                <GoogleLogin
                  onSuccess={handleSuccess}
                  onError={() => {
                    setError('Google sign-in was cancelled or failed. Please try again.');
                  }}
                  size="large"
                  shape="rectangular"
                  width="400"
                  text="continue_with"
                  theme="filled_blue"
                />
              </div>
            )}
          </div>

          {/* Dev Login (Local Only) */}
          {process.env.NODE_ENV !== 'production' && (
             <div className="mt-4 flex justify-center">
               <button
                 onClick={async () => {
                   try {
                     setLoading(true);
                     const res = await fetch('http://localhost:3000/api/v1/auth/dev-login', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ email: 'creator@statusgo.local' })
                     });
                     if (!res.ok) throw new Error('Dev login failed');
                     const data = await res.json();
                     localStorage.setItem('creator_access_token', data.accessToken);
                     router.replace('/dashboard');
                   } catch (err: any) {
                     setError(err.message || 'Dev login failed');
                     setLoading(false);
                   }
                 }}
                 className="text-white/50 text-xs hover:text-white underline"
               >
                 [Dev: Login as Test Creator]
               </button>
             </div>
          )}

          {/* Divider */}
          <div className="flex items-center gap-3 my-6">
            <div className="flex-1 h-px bg-white/10" />
            <span className="text-slate-600 text-xs font-semibold">HOW IT WORKS</span>
            <div className="flex-1 h-px bg-white/10" />
          </div>

          {/* Steps */}
          <div className="space-y-3">
            {[
              { step: '1', label: 'Admin adds your Gmail to the Creators list', icon: '👤' },
              { step: '2', label: 'You sign in here with that Gmail account', icon: '🔐' },
              { step: '3', label: 'Upload, manage, and earn from your templates', icon: '🚀' },
            ].map(({ step, label, icon }) => (
              <div key={step} className="flex items-center gap-3 bg-white/3 rounded-xl px-3 py-2.5">
                <span className="text-lg">{icon}</span>
                <p className="text-slate-400 text-xs leading-snug">{label}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <p className="text-center text-slate-600 text-xs mt-4">
          Not a creator yet?{' '}
          <span className="text-slate-400 hover:text-slate-300 cursor-pointer transition-colors">
            Contact support@statusgo.app
          </span>
        </p>
      </div>
    </div>
  );
}
