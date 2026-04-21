'use client';

import { useQuery } from '@tanstack/react-query';
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer,
} from 'recharts';
import { adminApi } from '@/lib/api';
import { formatNumber } from '@/lib/utils';
import { TrendingUp } from 'lucide-react';

const PLATFORM_COLORS = ['#25D366', '#128C7E', '#E4405F', '#1877F2', '#7C5CFC'];

function SkeletonBox({ h = 'h-64' }: { h?: string }) {
  return <div className={`${h} rounded-2xl bg-slate-100 animate-pulse`} />;
}

export default function AnalyticsPage() {
  const { data: dauData, isLoading: dauLoading } = useQuery({
    queryKey: ['dau'],
    queryFn: () => adminApi.getDau(30),
    staleTime: 5 * 60 * 1000,
  });
  const { data: searchesData, isLoading: searchLoading } = useQuery({
    queryKey: ['searches'],
    queryFn: adminApi.getSearches,
    staleTime: 5 * 60 * 1000,
  });
  const { data: sharesData, isLoading: sharesLoading } = useQuery({
    queryKey: ['shares'],
    queryFn: adminApi.getShares,
    staleTime: 5 * 60 * 1000,
  });

  const dau: any[] = dauData?.data ?? [];
  const shares: any[] = sharesData?.data ?? [];
  const searches: any[] = searchesData?.data ?? [];

  const totalDau = dau.length > 0 ? Number(dau[dau.length - 1]?.count ?? 0) : 0;
  const totalShares = shares.reduce((s: number, r: any) => s + Number(r.count), 0);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl md:text-2xl font-900 text-slate-800">Analytics</h1>
        <p className="text-muted text-sm mt-1">User behavior, engagement, and platform insights</p>
      </div>

      {/* Summary Chips */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <div className="bg-white rounded-2xl p-4 shadow-card border border-surface-border">
          <div className="text-xs text-muted font-700 mb-1">Today's DAU</div>
          <div className="text-2xl font-900 text-primary">{formatNumber(totalDau)}</div>
        </div>
        <div className="bg-white rounded-2xl p-4 shadow-card border border-surface-border">
          <div className="text-xs text-muted font-700 mb-1">Total Shares (30d)</div>
          <div className="text-2xl font-900 text-primary">{formatNumber(totalShares)}</div>
        </div>
        <div className="col-span-2 md:col-span-1 bg-white rounded-2xl p-4 shadow-card border border-surface-border">
          <div className="text-xs text-muted font-700 mb-1">Top Search Today</div>
          <div className="text-base font-900 text-slate-800 truncate">{searches[0]?.term || '—'}</div>
        </div>
      </div>

      {/* DAU Chart */}
      <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-5">
          <div>
            <h3 className="font-800 text-slate-800">Daily Active Users (DAU)</h3>
            <p className="text-muted text-xs mt-0.5">Last 30 days — live from database</p>
          </div>
          <div className="flex items-center gap-1.5 text-success text-sm font-700 bg-green-50 px-3 py-1.5 rounded-xl">
            <TrendingUp size={14} /> Live Data
          </div>
        </div>
        {dauLoading ? (
          <SkeletonBox h="h-[250px]" />
        ) : dau.length === 0 ? (
          <div className="h-64 flex items-center justify-center text-muted text-sm">
            No activity data yet — users need to log in first.
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={dau}>
              <defs>
                <linearGradient id="dauGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#7C5CFC" stopOpacity={0.15} />
                  <stop offset="95%" stopColor="#7C5CFC" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis
                dataKey="date"
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 11, fill: '#9A96B8' }}
                interval={Math.ceil(dau.length / 6)}
                tickFormatter={(v) => new Date(v).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })}
              />
              <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#9A96B8' }} tickFormatter={formatNumber} />
              <Tooltip
                contentStyle={{ borderRadius: 12, border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', fontSize: 12 }}
                labelFormatter={(v) => new Date(v).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })}
                formatter={(v: number) => [formatNumber(v), 'Active Users']}
              />
              <Area type="monotone" dataKey="count" stroke="#7C5CFC" strokeWidth={2.5} fill="url(#dauGradient)" dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
        {/* Share Breakdown */}
        <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
          <h3 className="font-800 text-slate-800 mb-1">Share Breakdown</h3>
          <p className="text-muted text-xs mb-4">Last 30 days — by platform</p>
          {sharesLoading ? (
            <SkeletonBox h="h-44" />
          ) : shares.length === 0 ? (
            <div className="h-44 flex items-center justify-center text-muted text-sm">No shares recorded yet.</div>
          ) : (
            <div className="flex flex-col sm:flex-row items-center gap-4">
              <ResponsiveContainer width={150} height={150}>
                <PieChart>
                  <Pie data={shares} cx="50%" cy="50%" innerRadius={40} outerRadius={70} dataKey="count" paddingAngle={2}>
                    {shares.map((_: any, i: number) => (
                      <Cell key={i} fill={PLATFORM_COLORS[i % PLATFORM_COLORS.length]} />
                    ))}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
              <div className="space-y-2 flex-1 w-full">
                {shares.map((s: any, i: number) => (
                  <div key={s.platform} className="flex items-center gap-2">
                    <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: PLATFORM_COLORS[i % PLATFORM_COLORS.length] }} />
                    <div className="text-xs text-slate-700 flex-1 truncate">{s.platform.replace(/_/g, ' ')}</div>
                    <div className="text-xs font-800 text-slate-800">{formatNumber(Number(s.count))}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Top Searches */}
        <div className="bg-white rounded-2xl p-5 md:p-6 shadow-card border border-surface-border">
          <h3 className="font-800 text-slate-800 mb-1">🔍 Top Searches</h3>
          <p className="text-muted text-xs mb-4">Last 7 days</p>
          {searchLoading ? (
            <SkeletonBox h="h-44" />
          ) : searches.length === 0 ? (
            <div className="h-44 flex items-center justify-center text-muted text-sm">No search data yet.</div>
          ) : (
            <div className="space-y-2.5">
              {searches.slice(0, 8).map((s: any, i: number) => (
                <div key={s.term} className="flex items-center gap-3">
                  <span className="text-xs font-800 text-muted w-4 shrink-0">{i + 1}</span>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-700 text-slate-700 truncate">{s.term}</div>
                    <div className="h-1.5 bg-surface rounded-full mt-1.5 overflow-hidden">
                      <div
                        className="h-1.5 rounded-full bg-primary"
                        style={{ width: `${(Number(s.count) / Number(searches[0].count)) * 100}%` }}
                      />
                    </div>
                  </div>
                  <span className="text-xs font-700 text-muted shrink-0">{formatNumber(Number(s.count))}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
