'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  LayoutDashboard, ClipboardList, Image, Users, User,
  CalendarDays, Bell, BarChart2, DollarSign, Settings, FileText,
  Sparkles, LogOut, Menu, X, Pin,
} from 'lucide-react';
import { cn } from '../lib/utils';
import { adminApi } from '../lib/api';
import { getSessionUser, logout } from '../lib/auth';

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

  // Current admin identity: role from the JWT, name/email from /user/me
  const router = useRouter();
  const [session, setSession] = useState<{ role?: string } | null>(null);
  useEffect(() => { setSession(getSessionUser()); }, [pathname]);
  const { data: me } = useQuery({
    queryKey: ['me'],
    queryFn: adminApi.getMe,
    staleTime: 10 * 60 * 1000,
  });
  const meUser = me?.user;
  const role: string = meUser?.role ?? session?.role ?? '';
  const displayName: string = meUser?.name || meUser?.email || (role ? role.replace('_', ' ') : 'Admin');
  const subtitle = meUser?.email && meUser?.name ? meUser.email : role;
  const initial = (displayName.trim()[0] || 'A').toUpperCase();

  const [signingOut, setSigningOut] = useState(false);
  const handleSignOut = async () => {
    setSigningOut(true);
    await logout();
    router.replace('/login');
  };

  const NavContent = () => (
    <>
      {/* Logo */}
      <div className="px-5 py-4 border-b border-slate-200/80 bg-white">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-blue-600 flex items-center justify-center shrink-0 shadow-sm">
            <Sparkles className="text-white" size={16} />
          </div>
          <div>
            <div className="font-bold text-slate-900 text-sm leading-none">Status Go</div>
            <div className="text-[10px] text-blue-700 font-semibold uppercase tracking-wider bg-blue-50 px-1.5 py-0.5 rounded border border-blue-200/60 inline-block mt-1">Admin</div>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-3 space-y-0.5 overflow-y-auto bg-white">
        {navItems.map(({ href, label, icon: Icon, badge }) => {
          const isActive = pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link
              key={href}
              href={href}
              onClick={() => setMobileOpen(false)}
              className={cn('sidebar-nav-item', isActive && 'active')}
            >
              <Icon size={17} className={isActive ? 'text-blue-600' : 'text-slate-400 group-hover:text-slate-600'} />
              <span className="flex-1">{label}</span>
              {badge && pendingCount > 0 && (
                <span className="bg-rose-50 text-rose-700 border border-rose-200 text-[11px] font-bold px-1.5 py-0.2 rounded-md min-w-[20px] text-center">
                  {pendingCount > 99 ? '99+' : pendingCount}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {/* Admin profile footer */}
      <div className="p-3 border-t border-slate-200/80 bg-white">
        <div className="flex items-center gap-2.5 px-2.5 py-2 rounded-lg bg-slate-50 border border-slate-200/60">
          <div className="w-7 h-7 rounded-md bg-blue-600 flex items-center justify-center text-white text-xs font-bold shrink-0">
            {initial}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-slate-800 text-xs font-semibold truncate leading-tight" title={displayName}>{displayName}</div>
            <div className="text-slate-400 text-[10px] truncate leading-tight" title={subtitle}>
              {subtitle}{meUser?.name && meUser?.email && role ? ` · ${role}` : ''}
            </div>
          </div>
          <button
            className="text-slate-400 hover:text-rose-600 transition-colors p-1 rounded hover:bg-white"
            aria-label="Sign out"
            title="Sign out"
            disabled={signingOut}
            onClick={handleSignOut}
          >
            <LogOut size={14} />
          </button>
        </div>
      </div>
    </>
  );

  return (
    <>
      {/* Mobile hamburger button */}
      <button
        className="lg:hidden fixed top-3 left-3 z-[60] w-9 h-9 rounded-lg bg-white border border-slate-200 flex items-center justify-center text-slate-700 shadow-sm"
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
        className={cn(
          'w-60 min-h-screen bg-white flex flex-col fixed left-0 top-0 bottom-0 z-[58] border-r border-slate-200/80 transition-transform duration-200',
          'lg:translate-x-0',
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        )}
      >
        <NavContent />
      </aside>
    </>
  );
}
