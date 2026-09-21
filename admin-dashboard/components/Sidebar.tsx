'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  LayoutDashboard, ClipboardList, Image, Users, User,
  CalendarDays, Bell, BarChart2, DollarSign, Settings, FileText,
  Sparkles, LogOut, ChevronRight, Menu, X, Pin,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { adminApi } from '../lib/api';

interface NavItem {
  href: string;
  label: string;
  icon: any;
  badge?: boolean;
}

const navItems: NavItem[] = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/review-queue', label: 'Review Queue', icon: ClipboardList, badge: true },
  { href: '/coordinator', label: 'Coordinator Picks', icon: Pin },
  { href: '/templates', label: 'Templates', icon: Image },
  { href: '/creators', label: 'Creators', icon: Users },
  { href: '/users', label: 'Users', icon: User },
  { href: '/festivals', label: 'Festivals', icon: CalendarDays },
  { href: '/campaigns', label: 'Push Campaigns', icon: Bell },
  { href: '/analytics', label: 'Analytics', icon: BarChart2 },
  { href: '/revenue', label: 'Revenue', icon: DollarSign },
  { href: '/config', label: 'App Config', icon: Settings },
  { href: '/audit-log', label: 'Audit Log', icon: FileText },
];

export function Sidebar() {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  // Fetch live pending count for badge
  const { data: stats } = useQuery({
    queryKey: ['admin-stats'],
    queryFn: adminApi.getStats,
    staleTime: 2 * 60 * 1000,
  });
  const pendingCount = stats?.templates?.pending ?? 0;

  const NavContent = () => (
    <>
      {/* Logo */}
      <div className="px-6 py-5 border-b border-slate-200 bg-white">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center shrink-0 shadow-sm shadow-blue-500/20">
            <Sparkles className="text-white" size={20} />
          </div>
          <div>
            <div className="font-extrabold text-slate-900 text-base leading-tight tracking-tight">Status Go</div>
            <div className="text-[10px] text-blue-600 font-extrabold uppercase tracking-wider bg-blue-50 px-1.5 py-0.5 rounded border border-blue-100 inline-block mt-0.5">Admin Panel</div>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto bg-white">
        {navItems.map(({ href, label, icon: Icon, badge }) => {
          const isActive = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link
              key={href}
              href={href}
              onClick={() => setMobileOpen(false)}
              className={cn('sidebar-nav-item', isActive && 'active')}
            >
              <Icon size={18} className={isActive ? 'text-blue-600' : 'text-slate-500 group-hover:text-blue-600'} />
              <span className="flex-1">{label}</span>
              {badge && pendingCount > 0 && (
                <span className="bg-rose-500 text-white text-[10px] font-extrabold px-1.5 py-0.5 rounded-full min-w-[18px] text-center shadow-xs animate-pulse">
                  {pendingCount > 99 ? '99+' : pendingCount}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {/* Admin profile */}
      <div className="px-3 py-4 border-t border-slate-200 bg-white">
        <div className="flex items-center gap-3 px-3 py-2.5 rounded-xl bg-slate-50 border border-slate-200/80">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-600 to-sky-500 flex items-center justify-center text-white text-xs font-black shrink-0 shadow-xs">
            A
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-slate-900 text-sm font-bold truncate">Super Admin</div>
            <div className="text-slate-400 text-[11px] font-medium truncate">SUPER_ADMIN</div>
          </div>
          <button
            className="text-slate-400 hover:text-rose-600 transition-colors p-1.5 rounded-lg hover:bg-white"
            aria-label="Sign out"
            onClick={() => { localStorage.removeItem('admin_access_token'); window.location.reload(); }}
          >
            <LogOut size={15} />
          </button>
        </div>
      </div>
    </>
  );

  return (
    <>
      {/* Mobile hamburger button */}
      <button
        className="lg:hidden fixed top-4 left-4 z-[60] w-10 h-10 rounded-xl bg-white border border-slate-200 flex items-center justify-center text-slate-700 shadow-md"
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

      {/* Sidebar — desktop fixed, mobile slide-over */}
      <aside
        className={cn(
          'w-64 min-h-screen bg-white flex flex-col fixed left-0 top-0 bottom-0 z-[58] border-r border-slate-200 transition-transform duration-300 shadow-xs',
          'lg:translate-x-0',
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        )}
      >
        <NavContent />
      </aside>
    </>
  );
}
