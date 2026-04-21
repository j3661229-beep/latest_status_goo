'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  LayoutDashboard, ClipboardList, Image, Users, User,
  CalendarDays, Bell, BarChart2, DollarSign, Settings, FileText,
  Sparkles, LogOut, ChevronRight, Menu, X,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { adminApi } from '../lib/api';

const navItems = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/review-queue', label: 'Review Queue', icon: ClipboardList, badge: true },
  { href: '/templates', label: 'Templates', icon: Image },
  { href: '/creators', label: 'Creators', icon: Users },
  { href: '/users', label: 'Users', icon: User },
  { href: '/festivals', label: 'Festivals', icon: CalendarDays },
  { href: '/campaigns', label: 'Push Campaigns', icon: Bell },
  { href: '/analytics', label: 'Analytics', icon: BarChart2 },
  { href: '/revenue', label: 'Revenue', icon: DollarSign },
  { href: '/config', label: 'App Config', icon: Settings },
  { href: '/audit-log', label: 'Audit Log', icon: FileText },
] as const;

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
      <div className="px-6 py-6 border-b border-sidebar-border">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-brand flex items-center justify-center shrink-0">
            <Sparkles className="text-white" size={18} />
          </div>
          <div>
            <div className="font-900 text-white text-base leading-tight">Status Go</div>
            <div className="text-[10px] text-white/40 font-600 uppercase tracking-widest">Admin Panel</div>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
        {navItems.map(({ href, label, icon: Icon, badge }) => {
          const isActive = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link
              key={href}
              href={href}
              onClick={() => setMobileOpen(false)}
              className={cn('sidebar-nav-item', isActive && 'active')}
            >
              <Icon size={18} />
              <span className="flex-1">{label}</span>
              {badge && pendingCount > 0 && (
                <span className="bg-red-500 text-white text-[10px] font-800 px-1.5 py-0.5 rounded-full min-w-[18px] text-center animate-pulse">
                  {pendingCount > 99 ? '99+' : pendingCount}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {/* Admin profile */}
      <div className="px-3 py-4 border-t border-sidebar-border">
        <div className="flex items-center gap-3 px-3 py-3 rounded-xl bg-sidebar-muted">
          <div className="w-8 h-8 rounded-full bg-gradient-brand flex items-center justify-center text-white text-sm font-800 shrink-0">
            A
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-white text-sm font-700 truncate">Super Admin</div>
            <div className="text-white/40 text-[11px] truncate">SUPER_ADMIN</div>
          </div>
          <button
            className="text-white/40 hover:text-white transition-colors"
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
        className="lg:hidden fixed top-4 left-4 z-[60] w-10 h-10 rounded-xl bg-sidebar flex items-center justify-center text-white shadow-lg"
        onClick={() => setMobileOpen(!mobileOpen)}
        aria-label="Toggle menu"
      >
        {mobileOpen ? <X size={20} /> : <Menu size={20} />}
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-black/50 z-[55] backdrop-blur-sm"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar — desktop fixed, mobile slide-over */}
      <aside
        className={cn(
          'w-64 min-h-screen bg-sidebar flex flex-col fixed left-0 top-0 bottom-0 z-[58] border-r border-sidebar-border transition-transform duration-300',
          'lg:translate-x-0',
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        )}
      >
        <NavContent />
      </aside>
    </>
  );
}
