'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Sparkles, Eye, EyeOff, LogIn, AlertCircle, Shield } from 'lucide-react';
import { authApi } from '@/lib/api';
import { setTokens, clearTokens } from '@/lib/auth';
import { getErrorMessage } from '@/lib/utils';

// Demo credentials are only offered in local development when explicitly enabled.
const SHOW_DEMO_LOGIN =
  process.env.NODE_ENV === 'development' && process.env.NEXT_PUBLIC_SHOW_DEMO_LOGIN === 'true';
const DEMO_EMAIL = 'admin@statusgo.com';
const DEMO_PASSWORD = 'Admin@12345';

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const data = await authApi.adminLogin(email, password);
      clearTokens();
      setTokens(data.accessToken, data.refreshToken);
      router.replace('/dashboard');
    } catch (err: any) {
      setError(
        err?.response
          ? getErrorMessage(err, 'Login failed. Please check your credentials.')
          : 'Cannot reach the server. Check your connection and try again.',
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
      <div className="w-full max-w-sm">
        {/* Card */}
        <div className="bg-white border border-slate-200/80 rounded-xl p-7 shadow-sm">
          {/* Brand */}
          <div className="flex flex-col items-center mb-6 text-center">
            <div className="w-10 h-10 rounded-lg bg-blue-600 flex items-center justify-center mb-3 shadow-sm">
              <Sparkles size={20} className="text-white" />
            </div>
            <h1 className="text-xl font-bold text-slate-900 tracking-tight">Status Go</h1>
            <p className="text-slate-500 text-xs mt-0.5">Admin &amp; Manager Console</p>
          </div>

          {/* Security Badge */}
          <div className="flex items-center justify-center gap-1.5 mb-5">
            <div className="flex items-center gap-1.5 bg-blue-50 border border-blue-100 rounded-md px-2.5 py-1">
              <Shield size={12} className="text-blue-600" />
              <span className="text-blue-700 text-xs font-semibold">Secure Admin Access</span>
            </div>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-2.5 bg-rose-50 border border-rose-200 text-rose-700 rounded-lg px-3.5 py-2.5 mb-4 text-xs font-medium">
              <AlertCircle size={15} className="shrink-0 mt-0.5 text-rose-600" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-3.5">
            {/* Email */}
            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">
                Email address
              </label>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="admin@statusgo.com"
                required
                autoComplete="email"
                className="w-full bg-white border border-slate-300 text-slate-900 placeholder-slate-400 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-colors"
              />
            </div>

            {/* Password */}
            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">
                Password
              </label>
              <div className="relative">
                <input
                  type={showPw ? 'text' : 'password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  autoComplete="current-password"
                  className="w-full bg-white border border-slate-300 text-slate-900 placeholder-slate-400 rounded-lg px-3 py-2 pr-10 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 transition-colors"
                />
                <button
                  type="button"
                  onClick={() => setShowPw(!showPw)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
                  aria-label={showPw ? 'Hide password' : 'Show password'}
                >
                  {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2.5 rounded-lg transition-colors flex items-center justify-center gap-2 mt-5 text-sm disabled:opacity-60 shadow-sm"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <LogIn size={16} />
                  <span>Sign In</span>
                </>
              )}
            </button>
          </form>

          {/* Demo quick-fill — dev only, opt-in via NEXT_PUBLIC_SHOW_DEMO_LOGIN=true */}
          {SHOW_DEMO_LOGIN && (
            <div className="mt-5 pt-4 border-t border-slate-100 flex flex-col items-center gap-2">
              <p className="text-[11px] text-slate-400">Quick Fill Demo Admin Credentials (dev only):</p>
              <button
                type="button"
                onClick={() => {
                  setEmail(DEMO_EMAIL);
                  setPassword(DEMO_PASSWORD);
                  setError('');
                }}
                className="text-xs bg-slate-50 hover:bg-slate-100 text-slate-700 border border-slate-200 px-3 py-1 rounded-md font-medium transition-colors flex items-center gap-1.5"
              >
                <span>⚡</span> {DEMO_EMAIL}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
