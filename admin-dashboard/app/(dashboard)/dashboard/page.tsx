'use client';

import { useQuery } from '@tanstack/react-query';
import {
  Users, Image, Share2, Star, DollarSign,
  AlertCircle, Clock,
} from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatNumber, formatCurrency, formatRelativeTime } from '@/lib/utils';

const LANG_COLORS: Record<string, string> = {
  HINDI:   '#7C5CFC',
  MARATHI: '#FF6B9D',
  ENGLISH: '#2DD4BF',
};
const LANG_LABELS: Record<string, string> = {
  HINDI:   'Hindi',
  MARATHI: 'Marathi',
  ENGLISH: 'English',
};

function KpiCard({
  title, value, subtitle, icon: Icon,
}: {
  title: string; value: string | number; subtitle?: string;
  icon: React.ElementType;
}) {
  return (
    <div className="stat-card">
      <div className="flex items-start justify-between mb-3">
        <div className="w-10 h-10 rounded-xl flex items-center justify-center bg-primary/10 shrink-0">
          <Icon size={20} className="text-primary" />
        </div>
      </div>
      <div className="font-900 text-xl md:text-2xl text-slate-800 mb-0.5">{value}</div>
      <div className="text-sm font-700 text-slate-700">{title}</div>
      {subtitle && <div className="text-xs text-muted mt-1">{subtitle}</div>}
    </div>
  );
}

function SkeletonCard() {
  return (
    <div className="stat-card animate-pulse">
      <div className="w-10 h-10 rounded-xl bg-slate-100 mb-3" />
      <div className="h-7 w-24 bg-slate-100 rounded mb-2" />
      <div className="h-4 w-32 bg-slate-100 rounded" />
    </div>
  );
}

export default function DashboardPage() {
  const { data: stats, isLoading } = useQuery({
    queryKey: ['admin-stats'],
    queryFn: adminApi.getStats,
    staleTime: 2 * 60 * 1000,
    refetchInterval: 5 * 60 * 1000,
  });

  if (isLoading || !stats) {
    return (
      <div className="space-y-6 md:space-y-8">
        <div>
          <div className="h-8 w-40 bg-slate-200 rounded animate-pulse mb-2" />
          <div className="h-4 w-64 bg-slate-100 rounded animate-pulse" />
        </div>
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
          {Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />)}
        </div>
      </div>
    );
  }

  const s = stats;

  // Safe access with fallbacks
  const totalLangUsers = (s.languageDist || []).reduce((sum: number, l: any) => sum + (l.count || 0), 0);
  const langDist = (s.languageDist || []).map((l: any) => ({
    language: LANG_LABELS[l.language] || l.language,
    value: totalLangUsers > 0 ? Math.round(((l.count || 0) / totalLangUsers) * 100) : 0,
    color: LANG_COLORS[l.language] || '#94a3b8',
    count: l.count || 0,
  }));

  return (
    <div className="space-y-6 md:space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-xl md:text-2xl font-900 text-slate-800">Dashboard</h1>
        <p className="text-muted text-sm mt-1">Welcome back — here's what's happening with Status Go today</p>
      </div>

      {/* Review Queue Alert */}
      {(s?.templates?.pending || 0) > 0 && (
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-primary to-secondary p-4 md:p-5">
          <div className="relative z-10 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <AlertCircle size={18} className="text-white" />
                <span className="text-white font-800 text-sm md:text-base">
                  {(s?.templates?.pending || 0)} templates waiting for review
                </span>
              </div>
              <p className="text-white/70 text-xs md:text-sm">Needs your attention — approve or reject from Review Queue</p>
            </div>
            <a href="/review-queue" className="bg-white text-primary font-800 text-sm px-4 py-2.5 rounded-xl hover:bg-white/90 transition-colors whitespace-nowrap self-start sm:self-auto">
              Review Now →
            </a>
          </div>
          <div className="absolute -right-8 -top-8 w-32 h-32 rounded-full bg-white/10" />
          <div className="absolute -right-4 top-8 w-16 h-16 rounded-full bg-white/10" />
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
        <KpiCard
          title="Total Users"
          value={formatNumber(s?.users?.total || 0)}
          icon={Users}
          subtitle={`+${s?.users?.new24h || 0} today · +${formatNumber(s?.users?.new7d || 0)} this week`}
        />
        <KpiCard
          title="Approved Templates"
          value={s?.templates?.approved || 0}
          icon={Image}
          subtitle={`${s?.templates?.images || 0} images · ${s?.templates?.videos || 0} videos`}
        />
        <KpiCard
          title="Pending Review"
          value={s?.templates?.pending || 0}
          icon={Clock}
          subtitle="Awaiting admin approval"
        />
        <KpiCard
          title="Premium Users"
          value={formatNumber(s?.users?.premium || 0)}
          icon={Star}
          subtitle={`${(s?.users?.total || 0) > 0 ? Math.round((s?.users?.premium || 0) / (s?.users?.total || 1) * 100) : 0}% conversion rate`}
        />
        <KpiCard
          title="Active Subscriptions"
          value={formatNumber(s?.revenue?.activeSubscriptions || 0)}
          icon={DollarSign}
          subtitle="Razorpay active plans"
        />
        <KpiCard
          title="Verified Creators"
          value={`${s?.creators?.verified || 0}/${s?.creators?.total || 0}`}
          icon={Users}
          subtitle={`${(s?.creators?.total || 0) - (s?.creators?.verified || 0)} awaiting verification`}
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 md:gap-6">
        {/* Top Templates */}
        <div className="lg:col-span-2 bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
          <h3 className="font-800 text-slate-800 mb-4">🔥 Top Templates by Usage</h3>
          {s.topTemplates && s.topTemplates.length > 0 ? (
            <div className="space-y-3">
              {s.topTemplates.map((t: any, i: number) => (
                <div key={t.id} className="flex items-center gap-3">
                  <div className="w-7 h-7 rounded-lg bg-primary/10 flex items-center justify-center text-primary text-xs font-900 shrink-0">
                    {i + 1}
                  </div>
                  <div
                    className="w-8 h-10 rounded-lg shrink-0"
                    style={{ background: t.gradient || 'linear-gradient(135deg, #7C5CFC, #FF6B9D)' }}
                  />
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-700 text-slate-800 truncate">{t.nameEn || t.nameHi || 'Untitled'}</div>
                    <div className="text-xs text-muted">{t.category?.nameEn || t.type}</div>
                  </div>
                  <div className="text-xs font-800 text-primary whitespace-nowrap">
                    {formatNumber(t.useCount || 0)} uses
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-12 text-muted">
              <Image size={32} className="opacity-30 mb-2" />
              <p className="text-sm">No approved templates yet</p>
            </div>
          )}
        </div>

        {/* Language Distribution — LIVE from DB */}
        <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
          <h3 className="font-800 text-slate-800 mb-1">Language Distribution</h3>
          <p className="text-muted text-xs mb-5">
            {totalLangUsers > 0 ? `${formatNumber(totalLangUsers)} users — live from database` : 'No user data yet'}
          </p>
          {langDist.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-8 text-muted text-sm">
              No language data yet
            </div>
          ) : (
            <div className="space-y-3.5">
              {langDist.map((item) => (
                <div key={item.language}>
                  <div className="flex justify-between text-sm mb-1.5">
                    <span className="font-700 text-slate-700">{item.language}</span>
                    <span className="text-muted font-600">{item.value}% <span className="text-slate-400">({item.count})</span></span>
                  </div>
                  <div className="h-2 bg-surface rounded-full overflow-hidden">
                    <div
                      className="h-2 rounded-full transition-all duration-700"
                      style={{ width: `${item.value}%`, backgroundColor: item.color }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Bottom Row: Recent Users + Top Creators */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
        {/* New Users */}
        <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-800 text-slate-800">👤 Recent Users</h3>
            <a href="/users" className="text-primary text-xs font-700 hover:underline">See all →</a>
          </div>
          {s.recentUsers && s.recentUsers.length > 0 ? (
            <div className="space-y-3">
              {s.recentUsers.map((u: any) => (
                <div key={u.id} className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-gradient-brand flex items-center justify-center text-white text-sm font-800 shrink-0">
                    {u.name?.[0]?.toUpperCase() || 'U'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-700 text-slate-800 truncate">{u.name}</div>
                    <div className="text-xs text-muted">{u.language} · {u.plan}</div>
                  </div>
                  <div className="text-xs text-muted whitespace-nowrap">{formatRelativeTime(u.createdAt)}</div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-sm text-muted text-center py-8">No users yet</div>
          )}
        </div>

        {/* Top Creators */}
        <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-800 text-slate-800">🎨 Top Creators</h3>
            <a href="/creators" className="text-primary text-xs font-700 hover:underline">See all →</a>
          </div>
          {s.topCreators && s.topCreators.length > 0 ? (
            <div className="space-y-3">
              {s.topCreators.map((c: any) => (
                <div key={c.id} className="flex items-center gap-3">
                  <div className="w-9 h-9 rounded-full bg-secondary/20 flex items-center justify-center text-secondary text-sm font-800 shrink-0">
                    {c.user?.name?.[0]?.toUpperCase() || 'C'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-700 text-slate-800 flex items-center gap-1 truncate">
                      {c.user?.name}
                      {c.isVerified && <span className="text-success text-xs">✅</span>}
                    </div>
                    <div className="text-xs text-muted">{c.approvedCount} approved · {c.totalUploads} uploads</div>
                  </div>
                  <div className={`text-sm font-900 ${c.approvalRate >= 85 ? 'text-success' : c.approvalRate >= 70 ? 'text-amber-600' : 'text-danger'}`}>
                    {c.approvalRate?.toFixed(0)}%
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-sm text-muted text-center py-8">No creators yet</div>
          )}
        </div>
      </div>
    </div>
  );
}
