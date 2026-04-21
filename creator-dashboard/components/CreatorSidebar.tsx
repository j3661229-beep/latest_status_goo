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
      <div className="px-5 py-5 border-b border-surface-border">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-primary to-secondary flex items-center justify-center shrink-0">
            <Sparkles size={16} className="text-white" />
          </div>
          <div>
            <div className="font-900 text-slate-800 text-sm">Status Go</div>
            <div className="text-[10px] text-muted font-700 uppercase tracking-widest">Creator Studio</div>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        {navItems.map(({ href, label, icon: Icon }) => {
          const isActive = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link key={href} href={href}
              onClick={() => setMobileOpen(false)}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-700 transition-all duration-150 ${
                isActive ? 'bg-primary text-white' : 'text-muted-foreground hover:bg-surface hover:text-slate-800'
              }`}>
              <Icon size={17} />
              <span className="flex-1">{label}</span>
              {isActive && <ChevronRight size={14} className="opacity-50" />}
            </Link>
          );
        })}
      </nav>

      {/* Creator profile footer */}
      <div className="px-3 py-4 border-t border-surface-border">
        <div className="flex items-center gap-3 px-3 py-3 rounded-xl bg-surface">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary to-secondary flex items-center justify-center text-white text-xs font-800 shrink-0">
            {initial}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-slate-800 text-sm font-800 truncate flex items-center gap-1">
              {displayName}
              {isVerified && <BadgeCheck size={13} className="text-success shrink-0" />}
            </div>
            <div className="text-muted text-[11px]">
              {isVerified ? '✅ Verified Creator' : 'Creator'}
            </div>
          </div>
          <button
            className="text-muted hover:text-danger transition-colors shrink-0"
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
        className="lg:hidden fixed top-4 left-4 z-[60] w-10 h-10 rounded-xl bg-white border border-surface-border shadow-card flex items-center justify-center text-slate-700"
        onClick={() => setMobileOpen(!mobileOpen)}
        aria-label="Toggle menu"
      >
        {mobileOpen ? <X size={20} /> : <Menu size={20} />}
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-black/40 z-[55] backdrop-blur-sm"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`w-60 min-h-screen bg-white flex flex-col fixed left-0 top-0 bottom-0 z-[58] border-r border-surface-border shadow-card transition-transform duration-300 lg:translate-x-0 ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        }`}
      >
        <NavContent />
      </aside>
    </>
  );
}
