'use client';

import { useQuery } from '@tanstack/react-query';
import { DollarSign, CheckCircle, CreditCard, TrendingUp, Users } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatNumber, formatCurrency } from '@/lib/utils';

function KpiCard({ icon: Icon, title, value, sub, iconBg = 'bg-primary/10', iconColor = 'text-primary' }: any) {
  return (
    <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
      <div className="flex justify-between items-start mb-4">
        <div className={`w-10 h-10 rounded-xl ${iconBg} flex items-center justify-center`}>
          <Icon size={20} className={iconColor} />
        </div>
      </div>
      <div className="font-900 text-2xl md:text-3xl text-slate-800">{value}</div>
      <div className="text-sm font-700 text-slate-700 mt-1">{title}</div>
      {sub && <div className="text-xs text-muted mt-1">{sub}</div>}
    </div>
  );
}

export default function RevenuePage() {
  const { data: rev, isLoading: revLoading } = useQuery({
    queryKey: ['admin-revenue'],
    queryFn: adminApi.getRevenue,
  });

  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['admin-stats'],
    queryFn: adminApi.getStats,
  });

  if (revLoading || statsLoading) {
    return (
      <div className="space-y-6">
        <div className="h-8 w-48 bg-slate-200 rounded animate-pulse" />
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[1, 2, 3].map(i => <div key={i} className="h-36 rounded-2xl bg-slate-100 animate-pulse" />)}
        </div>
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
        <h1 className="text-xl md:text-2xl font-900 text-slate-800">Revenue & Subscriptions</h1>
        <p className="text-muted text-sm mt-1">Live subscription data from your database</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <KpiCard
          icon={DollarSign}
          title="Monthly Recurring Revenue (MRR)"
          value={formatCurrency(currentMRR)}
          sub={`Based on active subscriptions`}
        />
        <KpiCard
          icon={CheckCircle}
          title="Active Subscriptions"
          value={formatNumber(activeSubs)}
          sub="Currently paying users (Razorpay)"
          iconBg="bg-green-100"
          iconColor="text-green-600"
        />
        <KpiCard
          icon={Users}
          title="Premium Users Total"
          value={formatNumber(totalPremiumUsers)}
          sub={`₹${formatNumber(annualRun)} annualised run rate`}
          iconBg="bg-blue-50"
          iconColor="text-blue-600"
        />
      </div>

      {/* Summary table */}
      <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
        <div className="flex items-center gap-2 mb-5">
          <TrendingUp size={18} className="text-primary" />
          <h3 className="font-800 text-slate-800">Revenue Summary</h3>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[
            { label: 'Total Revenue (All Time)', value: formatCurrency(rev?.totalRevenue || 0) },
            { label: 'ARR (Estimated)', value: formatCurrency(annualRun) },
            { label: 'ARPU', value: arpu },
            { label: 'Conversion Rate', value: conversionRate },
          ].map(item => (
            <div key={item.label} className="bg-surface rounded-xl p-4">
              <div className="text-xs text-muted font-700 mb-1">{item.label}</div>
              <div className="text-lg font-900 text-slate-800">{item.value}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Razorpay CTA */}
      <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border relative overflow-hidden">
        <div className="absolute -right-8 -top-8 w-40 h-40 bg-blue-50 rounded-full" />
        <div className="absolute -right-4 bottom-4 w-20 h-20 bg-blue-100/50 rounded-full" />
        <div className="relative z-10 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <CreditCard size={20} className="text-blue-600" />
              <h3 className="font-800 text-slate-800">Razorpay Payment Gateway</h3>
            </div>
            <p className="text-muted text-sm">View detailed transactions, refunds, and payouts in your Razorpay dashboard.</p>
          </div>
          <a
            href="https://dashboard.razorpay.com"
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary shrink-0 text-center"
          >
            Open Razorpay →
          </a>
        </div>
      </div>
    </div>
  );
}
