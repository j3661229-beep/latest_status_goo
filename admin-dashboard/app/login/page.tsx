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
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-950 to-slate-900 flex items-center justify-center p-4">
      {/* Glow blobs */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -left-40 w-96 h-96 bg-primary/20 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -right-40 w-96 h-96 bg-secondary/15 rounded-full blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        {/* Card */}
        <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-3xl p-8 shadow-2xl">
          {/* Brand */}
          <div className="flex flex-col items-center mb-8">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-primary to-secondary flex items-center justify-center mb-4 shadow-lg shadow-primary/30">
              <Sparkles size={26} className="text-white" />
            </div>
            <h1 className="text-2xl font-black text-white tracking-tight">Status Go</h1>
            <p className="text-slate-400 text-sm mt-1">Admin &amp; Manager Portal</p>
          </div>

          {/* Badge */}
          <div className="flex items-center justify-center gap-2 mb-6">
            <div className="flex items-center gap-2 bg-white/5 border border-white/10 rounded-full px-4 py-1.5">
              <Shield size={13} className="text-primary" />
              <span className="text-slate-300 text-xs font-semibold">Secure Admin Access</span>
            </div>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 bg-red-500/10 border border-red-500/30 text-red-400 rounded-2xl px-4 py-3 mb-5 text-sm">
              <AlertCircle size={16} className="shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-4">
            {/* Email */}
            <div>
              <label className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-2 block">
                Email Address
              </label>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="superadmin@statusgo.app"
                required
                autoComplete="email"
                className="w-full bg-white/5 border border-white/10 text-white placeholder-slate-500 rounded-2xl px-4 py-3 text-sm focus:outline-none focus:border-primary/50 focus:bg-white/10 transition-all"
              />
            </div>

            {/* Password */}
            <div>
              <label className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-2 block">
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
                  className="w-full bg-white/5 border border-white/10 text-white placeholder-slate-500 rounded-2xl px-4 py-3 pr-12 text-sm focus:outline-none focus:border-primary/50 focus:bg-white/10 transition-all"
                />
                <button
                  type="button"
                  onClick={() => setShowPw(s => !s)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white transition-colors p-1"
                >
                  {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={loading || !email || !password}
              className="w-full mt-2 flex items-center justify-center gap-3 bg-gradient-to-r from-primary to-secondary text-white font-bold py-3.5 rounded-2xl text-sm hover:opacity-90 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-primary/20"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <LogIn size={17} />
              )}
              {loading ? 'Signing in…' : 'Sign In to Admin Panel'}
            </button>
          </form>

          {/* Hint */}
          <div className="mt-6 text-center">
            <p className="text-slate-500 text-xs">
              Default credentials: <span className="text-slate-300 font-mono">admin123</span>
            </p>
            <p className="text-slate-600 text-xs mt-1">
              Only Super Admins and Managers can access this portal.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
