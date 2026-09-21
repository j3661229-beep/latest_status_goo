'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  LayoutDashboard, Upload, FileText, BarChart2, User,
  LogOut, Sparkles, ChevronRight, Menu, X, BadgeCheck,
} from 'lucide-react';
import { creatorApi } from '../lib/api';

const navItems = [
  { href: '/dashboard', label: 'My Studio', icon: LayoutDashboard },
  { href: '/upload', label: 'Upload Template', icon: Upload },
  { href: '/templates', label: 'My Templates', icon: FileText },
  { href: '/analytics', label: 'Analytics', icon: BarChart2 },
  { href: '/profile', label: 'Profile', icon: User },
] as const;

export function CreatorSidebar() {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  const { data: profile } = useQuery({
    queryKey: ['creator-profile'],
    queryFn: () => creatorApi.getProfile(),
    staleTime: 5 * 60 * 1000,
  });

  const displayName = profile?.displayName || profile?.user?.name || 'Creator';
  const initial = displayName[0]?.toUpperCase() ?? 'C';
  const isVerified = profile?.isVerified;

  const NavContent = () => (
    <>
      {/* Brand */}
      <div className="px-5 py-5 border-b border-slate-200 bg-white">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center shrink-0 shadow-sm shadow-blue-500/20">
            <Sparkles size={18} className="text-white" />
          </div>
          <div>
            <div className="font-extrabold text-slate-900 text-sm leading-tight tracking-tight">Status Go</div>
            <div className="text-[10px] text-blue-600 font-extrabold uppercase tracking-wider bg-blue-50 px-1.5 py-0.5 rounded border border-blue-100 inline-block mt-0.5">Creator Studio</div>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto bg-white">
        {navItems.map(({ href, label, icon: Icon }) => {
          const isActive = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link key={href} href={href}
              onClick={() => setMobileOpen(false)}
              className={`flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-sm font-semibold transition-all duration-150 ${
                isActive 
                  ? 'bg-blue-50 text-blue-600 font-bold border border-blue-200/80 shadow-xs' 
                  : 'text-slate-600 hover:bg-blue-50/60 hover:text-blue-600'
              }`}>
              <Icon size={17} className={isActive ? 'text-blue-600' : 'text-slate-500'} />
              <span className="flex-1">{label}</span>
              {isActive && <ChevronRight size={14} className="text-blue-500" />}
            </Link>
          );
        })}
      </nav>

      {/* Creator profile footer */}
      <div className="px-3 py-4 border-t border-slate-200 bg-white">
        <div className="flex items-center gap-3 px-3 py-2.5 rounded-xl bg-slate-50 border border-slate-200/80">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center text-white text-xs font-black shrink-0 shadow-xs">
            {initial}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-slate-900 text-sm font-bold truncate flex items-center gap-1">
              {displayName}
              {isVerified && <BadgeCheck size={14} className="text-emerald-500 shrink-0" />}
            </div>
            <div className="text-slate-400 text-[11px] font-medium">
              {isVerified ? '✅ Verified Creator' : 'Creator'}
            </div>
          </div>
          <button
            className="text-slate-400 hover:text-rose-600 transition-colors shrink-0 p-1 rounded-lg hover:bg-white"
            aria-label="Sign out"
            onClick={() => {
              localStorage.removeItem('creator_access_token');
              window.location.reload();
            }}
          >
            <LogOut size={14} />
          </button>
        </div>
      </div>
    </>
  );

  return (
    <>
      {/* Mobile hamburger */}
      <button
        className="lg:hidden fixed top-4 left-4 z-[60] w-10 h-10 rounded-xl bg-white border border-slate-200 shadow-md flex items-center justify-center text-slate-700"
        onClick={() => setMobileOpen(!mobileOpen)}
        aria-label="Toggle menu"
      >
        {mobileOpen ? <X size={20} /> : <Menu size={20} />}
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-slate-900/40 z-[55] backdrop-blur-xs"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`w-60 min-h-screen bg-white flex flex-col fixed left-0 top-0 bottom-0 z-[58] border-r border-slate-200 shadow-xs transition-transform duration-300 lg:translate-x-0 ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        }`}
      >
        <NavContent />
      </aside>
    </>
  );
}
