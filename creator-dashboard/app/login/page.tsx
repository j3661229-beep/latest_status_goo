'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { GoogleLogin } from '@react-oauth/google';
import { Sparkles, AlertCircle, Shield, Lock, Mail, Eye, EyeOff, LogIn } from 'lucide-react';
import { authApi } from '@/lib/api';

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
      localStorage.setItem('creator_access_token', data.accessToken);
      router.replace('/dashboard');
    } catch (err: any) {
      const msg = err?.response?.data?.error || err?.message || 'Login failed. Please check your credentials.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleFillDemo = () => {
    setEmail('creator@statusgo.com');
    setPassword('Creator@12345');
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
          <div className="flex flex-col items-center mb-6">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center mb-3 shadow-lg shadow-blue-500/25">
              <Sparkles size={26} className="text-white" />
            </div>
            <h1 className="text-2xl font-black text-slate-900 tracking-tight">Status Go</h1>
            <p className="text-slate-500 text-sm mt-0.5 font-semibold">Creator Studio</p>
          </div>

          {/* Badge */}
          <div className="flex items-center justify-center mb-5">
            <div className="flex items-center gap-2 bg-blue-50 border border-blue-100 rounded-full px-4 py-1">
              <Shield size={13} className="text-blue-600" />
              <span className="text-blue-700 text-xs font-bold">Creator Access Portal</span>
            </div>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-3 bg-rose-50 border border-rose-200 text-rose-700 rounded-2xl px-4 py-3 mb-5 text-sm font-medium">
              <AlertCircle size={16} className="shrink-0 mt-0.5 text-rose-600" />
              <span>{error}</span>
            </div>
          )}

          {/* Email / Password Login Form */}
          <form onSubmit={handlePasswordLogin} className="space-y-3.5 mb-5">
            <div>
              <label className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5 block">
                Creator Email
              </label>
              <div className="relative">
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="creator@statusgo.com"
                  required
                  className="w-full bg-slate-50 border border-slate-300 text-slate-900 placeholder-slate-400 rounded-xl px-4 py-2.5 pl-10 text-sm focus:outline-none focus:border-blue-600 focus:bg-white focus:ring-2 focus:ring-blue-100 transition-all font-medium"
                />
                <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
              </div>
            </div>

            <div>
              <label className="text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5 block">
                Password
              </label>
              <div className="relative">
                <input
                  type={showPw ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="w-full bg-slate-50 border border-slate-300 text-slate-900 placeholder-slate-400 rounded-xl px-4 py-2.5 pl-10 pr-10 text-sm focus:outline-none focus:border-blue-600 focus:bg-white focus:ring-2 focus:ring-blue-100 transition-all font-medium"
                />
                <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                <button
                  type="button"
                  onClick={() => setShowPw(!showPw)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                >
                  {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 rounded-xl transition-all shadow-md shadow-blue-500/20 hover:shadow-lg hover:shadow-blue-500/30 flex items-center justify-center gap-2 text-sm disabled:opacity-60"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  <LogIn size={16} />
                  <span>Sign In as Creator</span>
                </>
              )}
            </button>
          </form>

          {/* Quick Demo Fill Button */}
          <div className="flex justify-center mb-5">
            <button
              type="button"
              onClick={handleFillDemo}
              className="text-xs bg-amber-50 hover:bg-amber-100 text-amber-800 border border-amber-200 px-3.5 py-1.5 rounded-full font-semibold transition-colors flex items-center gap-1.5"
            >
              <span>⚡</span> Fill Demo: creator@statusgo.com
            </button>
          </div>

          {/* Divider */}
          <div className="flex items-center gap-3 my-5">
            <div className="flex-1 h-px bg-slate-200" />
            <span className="text-slate-400 text-[10px] font-bold tracking-wider">OR GOOGLE AUTH</span>
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
                width="400"
                text="continue_with"
                theme="filled_blue"
              />
            </div>
          </div>

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
