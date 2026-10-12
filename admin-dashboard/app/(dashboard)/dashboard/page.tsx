'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';
import {
  Users, Image, Star, DollarSign,
  AlertCircle, Clock, ArrowRight,
} from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatNumber, formatRelativeTime, formatCurrency } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';

const LANG_COLORS: Record<string, string> = {
  HINDI:   '#2563EB',
  MARATHI: '#0284C7',
  ENGLISH: '#0EA5E9',
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
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">{title}</span>
        <div className="w-8 h-8 rounded-lg flex items-center justify-center bg-blue-50 border border-blue-100/60 shrink-0 text-blue-600">
          <Icon size={16} />
        </div>
      </div>
      <div className="text-2xl font-bold text-slate-900 tracking-tight tabular-nums mb-1">{value}</div>
      {subtitle && <div className="text-xs text-slate-500 leading-normal">{subtitle}</div>}
    </div>
  );
}

function SkeletonCard() {
  return (
    <div className="stat-card animate-pulse">
      <div className="flex items-center justify-between mb-3">
        <div className="h-3.5 w-20 bg-slate-100 rounded" />
        <div className="w-8 h-8 rounded-lg bg-slate-100" />
      </div>
      <div className="h-7 w-24 bg-slate-100 rounded mb-2" />
      <div className="h-3 w-32 bg-slate-100 rounded" />
    </div>
  );
}

export default function DashboardPage() {
  const { data: stats, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['admin-stats'],
    queryFn: adminApi.getStats,
    staleTime: 2 * 60 * 1000,
    refetchInterval: 5 * 60 * 1000,
  });

  // MRR comes from /admin/revenue (paise) — /admin/stats only has subscription counts.
  const { data: rev } = useQuery({
    queryKey: ['admin-revenue'],
    queryFn: adminApi.getRevenue,
    staleTime: 5 * 60 * 1000,
  });

  if (isError && !stats) {
    return (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Overview</h1>
        <QueryError error={error} onRetry={() => refetch()} title="Failed to load dashboard stats" />
      </div>
    );
  }

  if (isLoading || !stats) {
    return (
      <div className="space-y-6">
        <div>
          <div className="h-7 w-36 bg-slate-200 rounded animate-pulse mb-2" />
          <div className="h-4 w-60 bg-slate-100 rounded animate-pulse" />
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 6 }).map((_, i) => <SkeletonCard key={i} />)}
        </div>
      </div>
    );
  }

  const s = stats;

  const totalLangUsers = (s.languageDist || []).reduce((sum: number, l: any) => sum + (l.count || 0), 0);
  const langDist = (s.languageDist || []).map((l: any) => ({
    language: LANG_LABELS[l.language] || l.language,
    value: totalLangUsers > 0 ? Math.round(((l.count || 0) / totalLangUsers) * 100) : 0,
    color: LANG_COLORS[l.language] || '#94a3b8',
    count: l.count || 0,
  }));

  const pendingCount = s?.templates?.pending || 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Overview</h1>
        <p className="text-slate-500 text-sm mt-0.5">Key metrics and recent system activity for Status Go</p>
      </div>

      {/* Review Queue Alert */}
      {pendingCount > 0 && (
        <div className="rounded-xl bg-amber-50/90 border border-amber-200/80 p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-sm">
          <div className="flex items-start sm:items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-amber-100 text-amber-700 flex items-center justify-center shrink-0">
              <AlertCircle size={18} />
            </div>
            <div>
              <div className="text-amber-900 font-semibold text-sm">
                {pendingCount} {pendingCount === 1 ? 'template' : 'templates'} pending review
              </div>
              <p className="text-amber-700 text-xs mt-0.5">Creators have submitted new status posters awaiting approval</p>
            </div>
          </div>
          <Link
            href="/review-queue"
            className="btn-primary bg-amber-600 hover:bg-amber-700 text-xs px-3.5 py-2 whitespace-nowrap self-start sm:self-auto"
          >
            Review Queue <ArrowRight size={14} className="ml-1" />
          </Link>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
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
          value={pendingCount}
          icon={Clock}
          subtitle="Awaiting administrative sign-off"
        />
        <KpiCard
          title="Premium Members"
          value={formatNumber(s?.users?.premium || 0)}
          icon={Star}
          subtitle={`${(s?.users?.total || 0) > 0 ? Math.round((s?.users?.premium || 0) / (s?.users?.total || 1) * 100) : 0}% active conversion`}
        />
        <KpiCard
          title="Active Subscriptions"
          value={formatNumber(s?.revenue?.activeSubscriptions || 0)}
          icon={DollarSign}
          subtitle={rev ? `MRR ${formatCurrency(rev.mrr || 0)} · ARR ${formatCurrency(rev.arr || 0)}` : 'Razorpay active plans'}
        />
        <KpiCard
          title="Verified Creators"
          value={`${s?.creators?.verified || 0} / ${s?.creators?.total || 0}`}
          icon={Users}
          subtitle={`${(s?.creators?.total || 0) - (s?.creators?.verified || 0)} awaiting verification`}
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Top Templates */}
        <div className="lg:col-span-2 bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-slate-900">Top Templates by Usage</h3>
            <Link href="/templates" className="text-blue-600 text-xs font-medium hover:underline inline-flex items-center gap-1">
              View all <ArrowRight size={12} />
            </Link>
          </div>
          {s.topTemplates && s.topTemplates.length > 0 ? (
            <div className="divide-y divide-slate-100">
              {s.topTemplates.map((t: any, i: number) => (
                <div key={t.id} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                  <span className="w-5 text-center text-xs font-semibold text-slate-400">
                    {i + 1}
                  </span>
                  <div
                    className="w-8 h-10 rounded-md shrink-0 border border-slate-200/60 bg-cover bg-center"
                    style={{
                      backgroundImage: t.imageThumbUrl || t.imageUrl ? `url(${t.imageThumbUrl || t.imageUrl})` : undefined,
                      background: !t.imageThumbUrl && !t.imageUrl ? (t.gradient || 'linear-gradient(135deg, #2563EB, #0EA5E9)') : undefined,
                    }}
                  />
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-slate-800 truncate">{t.nameEn || t.nameHi || 'Untitled Template'}</div>
                    <div className="text-xs text-slate-400">{t.category?.nameEn || t.type}</div>
                  </div>
                  <div className="text-xs font-semibold text-slate-700 tabular-nums">
                    {formatNumber(t.useCount || 0)} uses
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-10 text-slate-400">
              <Image size={28} className="opacity-40 mb-2" />
              <p className="text-xs">No template usage recorded yet</p>
            </div>
          )}
        </div>

        {/* Language Distribution */}
        <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm">
          <h3 className="text-sm font-semibold text-slate-900 mb-0.5">Language Distribution</h3>
          <p className="text-slate-400 text-xs mb-4">
            {totalLangUsers > 0 ? `${formatNumber(totalLangUsers)} registered users` : 'No language data'}
          </p>
          {langDist.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-8 text-slate-400 text-xs">
              No language data yet
            </div>
          ) : (
            <div className="space-y-3">
              {langDist.map((item) => (
                <div key={item.language}>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="font-medium text-slate-700">{item.language}</span>
                    <span className="text-slate-500 font-medium">{item.value}% <span className="text-slate-400">({item.count})</span></span>
                  </div>
                  <div className="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full transition-all duration-500"
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
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {/* New Users */}
        <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-slate-900">Recent Users</h3>
            <Link href="/users" className="text-blue-600 text-xs font-medium hover:underline inline-flex items-center gap-1">
              All users <ArrowRight size={12} />
            </Link>
          </div>
          {s.recentUsers && s.recentUsers.length > 0 ? (
            <div className="divide-y divide-slate-100">
              {s.recentUsers.map((u: any) => (
                <div key={u.id} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                  <div className="w-8 h-8 rounded-full bg-blue-50 border border-blue-100 text-blue-700 flex items-center justify-center text-xs font-semibold shrink-0">
                    {u.name?.[0]?.toUpperCase() || 'U'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-slate-800 truncate">{u.name}</div>
                    <div className="text-xs text-slate-400">{u.language} · {u.plan}</div>
                  </div>
                  <div className="text-xs text-slate-400 tabular-nums">{formatRelativeTime(u.createdAt)}</div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-xs text-slate-400 text-center py-6">No users found</div>
          )}
        </div>

        {/* Top Creators */}
        <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-slate-900">Top Creators</h3>
            <Link href="/creators" className="text-blue-600 text-xs font-medium hover:underline inline-flex items-center gap-1">
              All creators <ArrowRight size={12} />
            </Link>
          </div>
          {s.topCreators && s.topCreators.length > 0 ? (
            <div className="divide-y divide-slate-100">
              {s.topCreators.map((c: any) => (
                <div key={c.id} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                  <div className="w-8 h-8 rounded-full bg-slate-100 text-slate-700 flex items-center justify-center text-xs font-semibold shrink-0">
                    {c.user?.name?.[0]?.toUpperCase() || 'C'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-slate-800 flex items-center gap-1 truncate">
                      {c.user?.name}
                      {c.isVerified && <span className="text-emerald-600 text-xs font-bold">✓</span>}
                    </div>
                    <div className="text-xs text-slate-400">{c.approvedCount} approved · {c.totalUploads} uploads</div>
                  </div>
                  <div className="text-xs font-semibold text-slate-700 tabular-nums">
                    {c.approvalRate?.toFixed(0)}% approval
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-xs text-slate-400 text-center py-6">No creators found</div>
          )}
        </div>
      </div>
    </div>
  );
}
