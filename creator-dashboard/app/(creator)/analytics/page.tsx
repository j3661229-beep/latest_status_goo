'use client';

import { useQuery, useQueries } from '@tanstack/react-query';
import {
  BarChart, Bar, PieChart, Pie, Cell, Legend,
  XAxis, YAxis, Tooltip, ResponsiveContainer,
} from 'recharts';
import { Download, Eye, Upload, CheckCircle, Clock } from 'lucide-react';
import { creatorApi } from '@/lib/api';
import { downloadCsv, templateName } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';

const STATUS_SLICES = [
  { status: 'APPROVED', name: 'Live', color: '#10B981' },
  { status: 'PENDING', name: 'Pending', color: '#F59E0B' },
  { status: 'REJECTED', name: 'Rejected', color: '#EF4444' },
  { status: 'DRAFT', name: 'Draft', color: '#94A3B8' },
] as const;

const TEMPLATE_LIMIT = 50; // backend max page size for /creator/templates

function StatTile({ label, value, icon: Icon, color = 'text-blue-600', bg = 'bg-blue-50' }: any) {
  return (
    <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
      <div className={`w-8 h-8 rounded-lg ${bg} flex items-center justify-center mb-3`}>
        <Icon size={16} className={color} />
      </div>
      <div className="text-2xl font-bold text-slate-900 tabular-nums">{value}</div>
      <div className="text-xs font-medium text-slate-500 mt-0.5">{label}</div>
    </div>
  );
}

export default function CreatorAnalyticsPage() {
  const statsQ = useQuery({
    queryKey: ['creator-stats'],
    queryFn: () => creatorApi.getStats(),
    staleTime: 2 * 60 * 1000,
  });

  // Live templates carry real per-template useCount / shareCount totals.
  const liveQ = useQuery({
    queryKey: ['creator-templates', 'APPROVED', 'analytics'],
    queryFn: () => creatorApi.getTemplates({ status: 'APPROVED', limit: TEMPLATE_LIMIT }),
    staleTime: 2 * 60 * 1000,
  });

  // Exact per-status counts: read `total` from a 1-row page per status.
  const statusQs = useQueries({
    queries: STATUS_SLICES.map((s) => ({
      queryKey: ['creator-templates-count', s.status],
      queryFn: () => creatorApi.getTemplates({ status: s.status, limit: 1 }),
      staleTime: 2 * 60 * 1000,
    })),
  });

  const stats = statsQ.data;
  const totalAppUses = stats?.totalAppUses ?? 0;
  const approvalRate = stats?.approvalRate ?? 0;

  const statusLoading = statusQs.some((q) => q.isLoading);
  const statusError = statusQs.find((q) => q.isError)?.error;
  const statusCounts = STATUS_SLICES.map((s, i) => ({ ...s, value: statusQs[i].data?.total ?? 0 }));
  const statusData = statusCounts.filter((d) => d.value > 0);
  const totalTemplates = statusCounts.reduce((sum, d) => sum + d.value, 0);
  const pendingCount = statusCounts.find((d) => d.status === 'PENDING')?.value ?? 0;

  const liveTemplates: any[] = liveQ.data?.data ?? [];
  const liveTotal: number = liveQ.data?.total ?? liveTemplates.length;
  const perTemplate = [...liveTemplates]
    .sort((a, b) => (b.useCount ?? 0) - (a.useCount ?? 0))
    .slice(0, 10)
    .map((t) => ({ name: templateName(t).slice(0, 16), uses: t.useCount ?? 0, shares: t.shareCount ?? 0 }));
  const hasUsage = perTemplate.some((d) => d.uses > 0 || d.shares > 0);

  const handleExport = () => {
    downloadCsv(
      `my-templates-${new Date().toISOString().slice(0, 10)}.csv`,
      liveTemplates.map((t) => ({
        id: t.id,
        nameEn: t.nameEn ?? '',
        nameHi: t.nameHi ?? '',
        type: t.type,
        category: t.category?.nameEn ?? '',
        uses: t.useCount ?? 0,
        shares: t.shareCount ?? 0,
        createdAt: t.createdAt,
      })),
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900 tracking-tight">Analytics</h1>
          <p className="text-slate-500 text-sm mt-0.5">Performance metrics for your templates</p>
        </div>
        <button
          onClick={handleExport}
          disabled={liveTemplates.length === 0}
          className="btn-outline flex items-center gap-1.5 text-xs py-1.5 px-3 self-start sm:self-auto disabled:opacity-50"
          title="Download live templates with their use/share totals as CSV"
        >
          <Download size={13} /> Export CSV
        </button>
      </div>

      {statsQ.isError && <QueryError error={statsQ.error} onRetry={() => statsQ.refetch()} title="Could not load your stats" />}

      {/* KPI tiles */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatTile label="Total App Uses" value={totalAppUses.toLocaleString()} icon={Eye} />
        <StatTile label="Approval Rate" value={`${approvalRate.toFixed(1)}%`} icon={CheckCircle} color="text-emerald-700" bg="bg-emerald-50" />
        <StatTile label="Total Templates" value={statusLoading ? '—' : totalTemplates} icon={Upload} color="text-blue-600" bg="bg-blue-50" />
        <StatTile label="Pending Review" value={statusLoading ? '—' : pendingCount} icon={Clock} color="text-amber-700" bg="bg-amber-50" />
      </div>

      {/* Chart row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Per-template totals */}
        <div className="lg:col-span-2 bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
          <div className="mb-5">
            <h3 className="font-semibold text-slate-900 text-sm">Uses &amp; Shares by Template</h3>
            <p className="text-slate-400 text-xs mt-0.5">
              All-time totals for your top {perTemplate.length || 10} live templates
              {liveTotal > liveTemplates.length ? ` (from your ${liveTemplates.length} most recent of ${liveTotal})` : ''}
            </p>
          </div>
          {liveQ.isLoading ? (
            <div className="h-52 bg-slate-50 rounded-lg animate-pulse" />
          ) : liveQ.isError ? (
            <QueryError error={liveQ.error} onRetry={() => liveQ.refetch()} title="Could not load templates" />
          ) : !hasUsage ? (
            <div className="h-52 flex flex-col items-center justify-center text-slate-400 text-xs text-center">
              <p>No usage recorded yet.</p>
              <p className="text-[11px] mt-0.5">Once users personalise and share your live templates, totals will appear here.</p>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <BarChart data={perTemplate} barGap={2}>
                <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fontSize: 10, fill: '#64748b' }} interval={0} />
                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 10, fill: '#64748b' }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', boxShadow: '0 2px 8px rgba(0,0,0,0.05)', fontSize: 12 }}
                  formatter={(v: number, key: string) => [v.toLocaleString(), key === 'uses' ? 'Uses' : 'Shares']}
                />
                <Legend
                  iconType="circle"
                  iconSize={8}
                  wrapperStyle={{ fontSize: 11 }}
                  formatter={(v: string) => (v === 'uses' ? 'Uses' : 'Shares')}
                />
                <Bar dataKey="uses" fill="#2563EB" radius={[4, 4, 0, 0]} maxBarSize={22} />
                <Bar dataKey="shares" fill="#93C5FD" radius={[4, 4, 0, 0]} maxBarSize={22} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Status Pie */}
        <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
          <h3 className="font-semibold text-slate-900 text-sm mb-0.5">Template Status</h3>
          <p className="text-slate-400 text-xs mb-4">Breakdown of your uploads</p>
          {statusLoading ? (
            <div className="h-44 bg-slate-50 rounded-lg animate-pulse" />
          ) : statusError ? (
            <QueryError error={statusError} onRetry={() => statusQs.forEach((q) => q.refetch())} title="Could not load counts" />
          ) : statusData.length === 0 ? (
            <div className="h-44 flex items-center justify-center text-slate-400 text-xs">No templates yet.</div>
          ) : (
            <div className="flex flex-col items-center gap-4">
              <ResponsiveContainer width="100%" height={140}>
                <PieChart>
                  <Pie data={statusData} cx="50%" cy="50%" innerRadius={40} outerRadius={65} dataKey="value" paddingAngle={2}>
                    {statusData.map((d) => <Cell key={d.status} fill={d.color} />)}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
              <div className="space-y-2 w-full">
                {statusData.map(d => (
                  <div key={d.status} className="flex items-center gap-2">
                    <div className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: d.color }} />
                    <span className="text-xs text-slate-700 flex-1">{d.name}</span>
                    <span className="text-xs font-semibold text-slate-900 tabular-nums">{d.value}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
