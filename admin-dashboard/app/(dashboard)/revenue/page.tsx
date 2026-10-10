'use client';

import { useQuery } from '@tanstack/react-query';
import { DollarSign, CheckCircle, CreditCard, TrendingUp, Users } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatNumber, formatCurrency } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';

function KpiCard({ icon: Icon, title, value, sub, iconBg = 'bg-primary/10', iconColor = 'text-primary' }: any) {
  return (
    <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm">
      <div className="flex justify-between items-start mb-3">
        <div className={`w-9 h-9 rounded-lg ${iconBg} flex items-center justify-center`}>
          <Icon size={18} className={iconColor} />
        </div>
      </div>
      <div className="font-bold text-2xl text-slate-900 tabular-nums tracking-tight">{value}</div>
      <div className="text-xs font-semibold text-slate-600 uppercase tracking-wider mt-1">{title}</div>
      {sub && <div className="text-xs text-slate-400 mt-0.5">{sub}</div>}
    </div>
  );
}

export default function RevenuePage() {
  // NOTE: all amounts from /admin/revenue (mrr, arr, totalRevenue) are in paise.
  const { data: rev, isLoading: revLoading, isError: revIsError, error: revError, refetch: refetchRev } = useQuery({
    queryKey: ['admin-revenue'],
    queryFn: adminApi.getRevenue,
  });

  const { data: stats, isLoading: statsLoading, isError: statsIsError, error: statsError, refetch: refetchStats } = useQuery({
    queryKey: ['admin-stats'],
    queryFn: adminApi.getStats,
  });

  if (revLoading || statsLoading) {
    return (
      <div className="space-y-6">
        <div className="h-7 w-48 bg-slate-200 rounded animate-pulse" />
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[1, 2, 3].map(i => <div key={i} className="h-32 rounded-xl bg-slate-100 animate-pulse border border-slate-200" />)}
        </div>
      </div>
    );
  }

  if (revIsError || statsIsError) {
    return (
      <div className="space-y-6">
        <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900">Revenue & Subscriptions</h1>
        <QueryError
          error={revError ?? statsError}
          onRetry={() => { if (revIsError) refetchRev(); if (statsIsError) refetchStats(); }}
        />
      </div>
    );
  }

  const currentMRR = rev?.mrr || 0;
  const annualRun = rev?.arr || 0;
  const activeSubs = rev?.activeSubs || 0;
  const totalPremiumUsers = (rev?.premiumUsers || 0) + (rev?.annualUsers || 0);

  const totalUsers = stats?.users?.total || 0;
  const conversionRate = totalUsers > 0 ? ((totalPremiumUsers / totalUsers) * 100).toFixed(1) + '%' : '0%';
  const arpu = activeSubs > 0 ? formatCurrency(currentMRR / activeSubs) + '/mo' : '₹0/mo';

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900">Revenue & Subscriptions</h1>
        <p className="text-slate-500 text-xs mt-1">Live subscription metrics and payment telemetry from your database</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <KpiCard
          icon={DollarSign}
          title="Monthly Recurring Revenue (MRR)"
          value={formatCurrency(currentMRR)}
          sub="Based on active subscriptions"
        />
        <KpiCard
          icon={CheckCircle}
          title="Active Subscriptions"
          value={formatNumber(activeSubs)}
          sub="Currently paying users (Razorpay)"
          iconBg="bg-emerald-50"
          iconColor="text-emerald-600"
        />
        <KpiCard
          icon={Users}
          title="Premium Users Total"
          value={formatNumber(totalPremiumUsers)}
          sub={`${formatCurrency(annualRun)} annualised run rate`}
          iconBg="bg-blue-50"
          iconColor="text-blue-600"
        />
      </div>

      {/* Summary table */}
      <div className="bg-white rounded-xl p-5 md:p-6 border border-slate-200/80 shadow-sm">
        <div className="flex items-center gap-2 mb-4 pb-3 border-b border-slate-100">
          <TrendingUp size={16} className="text-primary" />
          <h3 className="font-bold text-slate-900 text-sm">Revenue Summary</h3>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3.5">
          {[
            { label: 'Total Revenue (All Time)', value: formatCurrency(rev?.totalRevenue || 0) },
            { label: 'ARR (Estimated)', value: formatCurrency(annualRun) },
            { label: 'ARPU', value: arpu },
            { label: 'Conversion Rate', value: conversionRate },
          ].map(item => (
            <div key={item.label} className="bg-slate-50/70 rounded-lg p-3.5 border border-slate-200/60">
              <div className="text-[11px] text-slate-500 font-semibold uppercase tracking-wider mb-1">{item.label}</div>
              <div className="text-lg font-bold text-slate-900 tabular-nums tracking-tight">{item.value}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Razorpay Gateway Card */}
      <div className="bg-gradient-to-r from-slate-900 via-slate-850 to-indigo-950 rounded-xl p-5 md:p-6 text-white border border-slate-800 shadow-sm relative overflow-hidden">
        <div className="absolute -right-8 -top-8 w-40 h-40 bg-blue-500/10 rounded-full blur-2xl pointer-events-none" />
        <div className="relative z-10 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="max-w-xl">
            <div className="flex items-center gap-2 mb-1.5">
              <CreditCard size={18} className="text-blue-400" />
              <h3 className="font-bold text-white text-base">Razorpay Payment Gateway</h3>
            </div>
            <p className="text-slate-300 text-xs leading-relaxed">
              View detailed transactions, refunds, webhooks, settlement timelines, and payouts in your official Razorpay dashboard.
            </p>
          </div>
          <a
            href="https://dashboard.razorpay.com"
            target="_blank"
            rel="noopener noreferrer"
            className="px-4 py-2 text-xs font-semibold rounded-lg bg-white text-slate-900 hover:bg-slate-100 transition-colors shadow-sm shrink-0 text-center"
          >
            Open Razorpay →
          </a>
        </div>
      </div>
    </div>
  );
}
