'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { GoogleLogin } from '@react-oauth/google';
import { Sparkles, AlertCircle, Shield, Lock, Mail, Eye, EyeOff, LogIn } from 'lucide-react';
import { authApi } from '@/lib/api';
import { setTokens, ALLOWED_ROLES, getSessionUser, clearTokens } from '@/lib/auth';
import { getErrorMessage } from '@/lib/utils';
import { GOOGLE_ENABLED } from '@/lib/google';

// Demo credentials are only offered in local development when explicitly opted in.
const SHOW_DEMO_LOGIN =
  process.env.NODE_ENV === 'development' && process.env.NEXT_PUBLIC_SHOW_DEMO_LOGIN === 'true';
const DEMO_EMAIL = 'creator@statusgo.com';
const DEMO_PASSWORD = 'Creator@12345';

function completeLogin(data: any): string | null {
  if (!data?.accessToken) return 'Login response did not include an access token.';
  const user = getSessionUser(data.accessToken);
  if (!user || !ALLOWED_ROLES.includes(user.role)) {
    clearTokens();
    return 'This account does not have Creator Studio access.';
  }
  setTokens(data.accessToken, data.refreshToken);
  return null;
}

export default function CreatorLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await authApi.creatorLogin(email, password);
      const problem = completeLogin(data);
      if (problem) setError(problem);
      else router.replace('/dashboard');
    } catch (err: unknown) {
      setError(getErrorMessage(err, 'Login failed. Please check your credentials.'));
    } finally {
      setLoading(false);
    }
  };

  const handleFillDemo = () => {
    setEmail(DEMO_EMAIL);
    setPassword(DEMO_PASSWORD);
    setError('');
  };

  const handleGoogleSuccess = async (credentialResponse: any) => {
    const idToken = credentialResponse.credential;
    if (!idToken) {
      setError('Google did not return a valid credential. Please try again.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const data = await authApi.creatorGoogleLogin(idToken);
      const problem = completeLogin(data);
      if (problem) setError(problem);
      else router.replace('/dashboard');
    } catch (err: unknown) {
      setError(getErrorMessage(err, 'Sign-in failed.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        <div className="bg-white border border-slate-200/80 rounded-xl p-7 shadow-sm">
          {/* Brand */}
          <div className="flex flex-col items-center mb-6 text-center">
            <div className="w-10 h-10 rounded-lg bg-blue-600 flex items-center justify-center mb-3 shadow-sm">
              <Sparkles size={20} className="text-white" />
            </div>
            <h1 className="text-xl font-bold text-slate-900 tracking-tight">Status Go</h1>
            <p className="text-slate-500 text-xs mt-0.5">Creator Studio</p>
          </div>

          {/* Badge */}
          <div className="flex items-center justify-center mb-5">
            <div className="flex items-center gap-1.5 bg-blue-50 border border-blue-100 rounded-md px-2.5 py-1">
              <Shield size={12} className="text-blue-600" />
              <span className="text-blue-700 text-xs font-semibold">Creator Access Portal</span>
            </div>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-2.5 bg-rose-50 border border-rose-200 text-rose-700 rounded-lg px-3.5 py-2.5 mb-4 text-xs font-medium">
              <AlertCircle size={15} className="shrink-0 mt-0.5 text-rose-600" />
              <span>{error}</span>
            </div>
          )}

          {/* Email / Password Login Form */}
          <form onSubmit={handlePasswordLogin} className="space-y-3.5 mb-4">
            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">
                Creator Email
              </label>
              <div className="relative">
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  className="w-full bg-white border border-slate-300 text-slate-900 placeholder-slate-400 rounded-lg px-3 py-2 pl-9 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-colors"
                />
                <Mail size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              </div>
            </div>

            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">
                Password
              </label>
              <div className="relative">
                <input
                  type={showPw ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="w-full bg-white border border-slate-300 text-slate-900 placeholder-slate-400 rounded-lg px-3 py-2 pl-9 pr-9 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-colors"
                />
                <Lock size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <button
                  type="button"
                  onClick={() => setShowPw(!showPw)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                >
                  {showPw ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2.5 rounded-lg transition-colors flex items-center justify-center gap-2 text-sm disabled:opacity-60 shadow-sm"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <LogIn size={15} />
                  <span>Sign In as Creator</span>
                </>
              )}
            </button>
          </form>

          {/* Quick Demo Fill Button (dev + NEXT_PUBLIC_SHOW_DEMO_LOGIN=true only) */}
          {SHOW_DEMO_LOGIN && (
          <div className="flex justify-center mb-4">
            <button
              type="button"
              onClick={handleFillDemo}
              className="text-xs bg-slate-50 hover:bg-slate-100 text-slate-700 border border-slate-200 px-3 py-1 rounded-md font-medium transition-colors flex items-center gap-1.5"
            >
              <span>⚡</span> Fill Demo: {DEMO_EMAIL}
            </button>
          </div>
          )}

          {GOOGLE_ENABLED && (
          <>
          {/* Divider */}
          <div className="flex items-center gap-3 my-4">
            <div className="flex-1 h-px bg-slate-200" />
            <span className="text-slate-400 text-[10px] font-semibold tracking-wider">OR GOOGLE AUTH</span>
            <div className="flex-1 h-px bg-slate-200" />
          </div>

          {/* Google Login Button */}
          <div className={`flex justify-center ${loading ? 'opacity-60 pointer-events-none' : ''}`}>
            <div className="w-full">
              <GoogleLogin
                onSuccess={handleGoogleSuccess}
                onError={() => {
                  setError('Google sign-in was cancelled or failed. Please try again.');
                }}
                size="large"
                shape="rectangular"
                width="336"
                text="continue_with"
                theme="filled_blue"
              />
            </div>
          </div>
          </>
          )}

          {/* Divider */}
          <div className="flex items-center gap-3 my-5">
            <div className="flex-1 h-px bg-slate-200" />
            <span className="text-slate-400 text-[10px] font-semibold tracking-wider">HOW IT WORKS</span>
            <div className="flex-1 h-px bg-slate-200" />
          </div>

          {/* Steps */}
          <div className="space-y-2">
            {[
              { step: '1', label: 'Admin adds your Gmail to the Creators list' },
              { step: '2', label: 'You sign in here with that Gmail account' },
              { step: '3', label: 'Upload, manage, and earn from your templates' },
            ].map(({ step, label }) => (
              <div key={step} className="flex items-center gap-2.5 bg-slate-50 border border-slate-100 rounded-lg px-3 py-2">
                <span className="w-5 h-5 rounded-full bg-slate-200/80 text-slate-600 text-[11px] font-semibold flex items-center justify-center shrink-0">{step}</span>
                <p className="text-slate-600 text-xs leading-snug">{label}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Footer */}
        <p className="text-center text-slate-400 text-xs mt-4">
          Not a creator yet?{' '}
          <span className="text-blue-600 hover:text-blue-700 font-medium cursor-pointer transition-colors">
            Contact support@statusgo.app
          </span>
        </p>
      </div>
    </div>
  );
}
