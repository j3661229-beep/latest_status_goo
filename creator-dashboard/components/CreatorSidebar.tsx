'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  LayoutDashboard, Upload, FileText, BarChart2, User,
  LogOut, Sparkles, Menu, X, BadgeCheck,
} from 'lucide-react';
import { creatorApi } from '../lib/api';
import { logout } from '../lib/auth';

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
  const [signingOut, setSigningOut] = useState(false);

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
      {/* Brand Logo */}
      <div className="px-5 py-4 border-b border-slate-200/80 bg-white">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-blue-600 flex items-center justify-center shrink-0 shadow-sm">
            <Sparkles size={16} className="text-white" />
          </div>
          <div>
            <div className="font-bold text-slate-900 text-sm leading-none">Status Go</div>
            <div className="text-[10px] text-blue-700 font-semibold uppercase tracking-wider bg-blue-50 px-1.5 py-0.5 rounded border border-blue-200/60 inline-block mt-1">Creator Studio</div>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-3 space-y-0.5 overflow-y-auto bg-white">
        {navItems.map(({ href, label, icon: Icon }) => {
          const isActive = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link
              key={href}
              href={href}
              onClick={() => setMobileOpen(false)}
              className={`sidebar-nav-item ${isActive ? 'active' : ''}`}
            >
              <Icon size={17} className={isActive ? 'text-blue-600' : 'text-slate-400 group-hover:text-slate-600'} />
              <span className="flex-1">{label}</span>
            </Link>
          );
        })}
      </nav>

      {/* Creator profile footer */}
      <div className="p-3 border-t border-slate-200/80 bg-white">
        <div className="flex items-center gap-2.5 px-2.5 py-2 rounded-lg bg-slate-50 border border-slate-200/60">
          <div className="w-7 h-7 rounded-md bg-blue-600 flex items-center justify-center text-white text-xs font-bold shrink-0">
            {initial}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-slate-800 text-xs font-semibold truncate flex items-center gap-1 leading-tight">
              {displayName}
              {isVerified && <BadgeCheck size={13} className="text-emerald-600 shrink-0" />}
            </div>
            <div className="text-slate-400 text-[10px] truncate leading-tight">
              {isVerified ? 'Verified Creator' : 'Creator'}
            </div>
          </div>
          <button
            className="text-slate-400 hover:text-rose-600 transition-colors p-1 rounded hover:bg-white"
            aria-label="Sign out"
            title="Sign out"
            disabled={signingOut}
            onClick={async () => {
              setSigningOut(true);
              await logout();
              window.location.href = '/login';
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
        className="lg:hidden fixed top-3 left-3 z-[60] w-9 h-9 rounded-lg bg-white border border-slate-200 shadow-sm flex items-center justify-center text-slate-700"
        onClick={() => setMobileOpen(!mobileOpen)}
        aria-label="Toggle menu"
      >
        {mobileOpen ? <X size={18} /> : <Menu size={18} />}
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-slate-900/30 z-[55] backdrop-blur-xs transition-opacity"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`w-60 min-h-screen bg-white flex flex-col fixed left-0 top-0 bottom-0 z-[58] border-r border-slate-200/80 transition-transform duration-200 lg:translate-x-0 ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        }`}
      >
        <NavContent />
      </aside>
    </>
  );
}
