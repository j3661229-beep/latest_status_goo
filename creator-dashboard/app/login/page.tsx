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
    <div className="min-h-screen bg-gradient-to-br from-blue-50/70 via-slate-50 to-white flex items-center justify-center p-4 relative overflow-hidden">
      {/* Subtle geometric background accents */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-32 -left-32 w-96 h-96 bg-blue-100/50 rounded-full blur-3xl" />
        <div className="absolute -bottom-32 -right-32 w-96 h-96 bg-sky-100/50 rounded-full blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        <div className="bg-white border border-slate-200/80 rounded-3xl p-8 shadow-xl shadow-slate-200/50">
          {/* Brand */}
          <div className="flex flex-col items-center mb-7">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center mb-3.5 shadow-lg shadow-blue-500/25">
              <Sparkles size={26} className="text-white" />
            </div>
            <h1 className="text-2xl font-black text-slate-900 tracking-tight">Status Go</h1>
            <p className="text-slate-500 text-sm mt-0.5 font-semibold">Creator Studio</p>
          </div>

          {/* Badge */}
          <div className="flex items-center justify-center mb-5">
            <div className="flex items-center gap-2 bg-blue-50 border border-blue-100 rounded-full px-4 py-1">
              <Shield size={13} className="text-blue-600" />
              <span className="text-blue-700 text-xs font-bold">Invite-Only Creator Access</span>
            </div>
          </div>

          {/* Description */}
          <div className="text-center mb-6">
            <p className="text-slate-600 text-sm leading-relaxed font-medium">
              Sign in with the Google account that was{' '}
              <span className="text-blue-600 font-bold">invited by Status Go Admin</span>.
            </p>
            <p className="text-slate-400 text-xs mt-1">
              Only approved creators can access this studio.
            </p>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 bg-rose-50 border border-rose-200 text-rose-700 rounded-2xl px-4 py-3 mb-5 text-sm font-medium">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-rose-600" />
              <span>{error}</span>
            </div>
          )}

          {/* Google Login Button */}
          <div className={`flex justify-center ${loading ? 'opacity-60 pointer-events-none' : ''}`}>
            {loading ? (
              <div className="flex items-center gap-3 bg-slate-100 text-slate-700 font-bold py-3 px-6 rounded-xl text-sm w-full justify-center">
                <div className="w-5 h-5 border-2 border-slate-400 border-t-blue-600 rounded-full animate-spin" />
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
                 className="text-blue-600 text-xs hover:text-blue-700 font-semibold underline"
               >
                 [Dev: Quick Login as Test Creator]
               </button>
             </div>
          )}

          {/* Divider */}
          <div className="flex items-center gap-3 my-6">
            <div className="flex-1 h-px bg-slate-200" />
            <span className="text-slate-400 text-[11px] font-bold tracking-wider">HOW IT WORKS</span>
            <div className="flex-1 h-px bg-slate-200" />
          </div>

          {/* Steps */}
          <div className="space-y-2.5">
            {[
              { step: '1', label: 'Admin adds your Gmail to the Creators list', icon: '👤' },
              { step: '2', label: 'You sign in here with that Gmail account', icon: '🔐' },
              { step: '3', label: 'Upload, manage, and earn from your templates', icon: '🚀' },
            ].map(({ step, label, icon }) => (
              <div key={step} className="flex items-center gap-3 bg-slate-50 border border-slate-100 rounded-xl px-3.5 py-2.5">
                <span className="text-lg shrink-0">{icon}</span>
                <p className="text-slate-600 text-xs font-medium leading-snug">{label}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <p className="text-center text-slate-500 text-xs mt-4">
          Not a creator yet?{' '}
          <span className="text-blue-600 hover:text-blue-700 font-semibold cursor-pointer transition-colors">
            Contact support@statusgo.app
          </span>
        </p>
      </div>
    </div>
  );
}
