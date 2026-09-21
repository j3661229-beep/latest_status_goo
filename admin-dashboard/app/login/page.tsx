'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Sparkles, Eye, EyeOff, LogIn, AlertCircle, Shield } from 'lucide-react';
import { authApi } from '@/lib/api';

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
      localStorage.setItem('admin_access_token', data.accessToken);
      router.replace('/dashboard');
    } catch (err: any) {
      setError(err?.response?.data?.error || 'Login failed. Please check your credentials.');
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
        {/* Card */}
        <div className="bg-white border border-slate-200/80 rounded-3xl p-8 shadow-xl shadow-slate-200/50">
          {/* Brand */}
          <div className="flex flex-col items-center mb-7">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center mb-3.5 shadow-lg shadow-blue-500/25">
              <Sparkles size={26} className="text-white" />
            </div>
            <h1 className="text-2xl font-black text-slate-900 tracking-tight">Status Go</h1>
            <p className="text-slate-500 text-sm mt-0.5 font-medium">Admin &amp; Manager Portal</p>
          </div>

          {/* Security Badge */}
          <div className="flex items-center justify-center gap-2 mb-6">
            <div className="flex items-center gap-2 bg-blue-50/80 border border-blue-100 rounded-full px-4 py-1">
              <Shield size={13} className="text-blue-600" />
              <span className="text-blue-700 text-xs font-bold">Secure Admin Access</span>
            </div>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 bg-rose-50 border border-rose-200 text-rose-700 rounded-2xl px-4 py-3 mb-5 text-sm font-medium">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-rose-600" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-4">
            {/* Email */}
            <div>
              <label className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2 block">
                Email Address
              </label>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="superadmin@statusgo.app"
                required
                autoComplete="email"
                className="w-full bg-slate-50/50 border border-slate-300 text-slate-900 placeholder-slate-400 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-blue-600 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all font-medium"
              />
            </div>

            {/* Password */}
            <div>
              <label className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-2 block">
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
                  className="w-full bg-slate-50/50 border border-slate-300 text-slate-900 placeholder-slate-400 rounded-xl px-4 py-3 pr-12 text-sm focus:outline-none focus:border-blue-600 focus:bg-white focus:ring-3 focus:ring-blue-100 transition-all font-medium"
                />
                <button
                  type="button"
                  onClick={() => setShowPw(!showPw)}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
                  aria-label={showPw ? 'Hide password' : 'Show password'}
                >
                  {showPw ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-extrabold py-3.5 rounded-xl transition-all shadow-md shadow-blue-500/20 hover:shadow-lg hover:shadow-blue-500/30 flex items-center justify-center gap-2 mt-6 text-sm disabled:opacity-60 active:scale-[0.99]"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <LogIn size={18} />
                  <span>Sign In to Admin Panel</span>
                </>
              )}
            </button>
          </form>

          {/* Pre-configured admin note */}
          <div className="mt-6 pt-5 border-t border-slate-100 text-center">
            <p className="text-xs text-slate-500">
              Dev default: <span className="font-semibold text-slate-700">superadmin@statusgo.app</span> / <span className="font-semibold text-slate-700">Admin@123456</span>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
