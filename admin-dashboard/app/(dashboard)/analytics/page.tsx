'use client';

import { useQuery } from '@tanstack/react-query';
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer,
} from 'recharts';
import { adminApi } from '@/lib/api';
import { formatNumber } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';
import { TrendingUp } from 'lucide-react';

const PLATFORM_COLORS = ['#25D366', '#128C7E', '#E4405F', '#1877F2', '#2563EB'];

function SkeletonBox({ h = 'h-64' }: { h?: string }) {
  return <div className={`${h} rounded-xl bg-slate-100 animate-pulse border border-slate-200/60`} />;
}

export default function AnalyticsPage() {
  const { data: dauData, isLoading: dauLoading, isError: dauError, error: dauErr, refetch: refetchDau } = useQuery({
    queryKey: ['dau'],
    queryFn: () => adminApi.getDau(30),
    staleTime: 5 * 60 * 1000,
  });
  const { data: searchesData, isLoading: searchLoading, isError: searchError, error: searchErr, refetch: refetchSearches } = useQuery({
    queryKey: ['searches'],
    queryFn: adminApi.getSearches,
    staleTime: 5 * 60 * 1000,
  });
  const { data: sharesData, isLoading: sharesLoading, isError: sharesError, error: sharesErr, refetch: refetchShares } = useQuery({
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
        <h1 className="text-xl md:text-2xl font-bold text-slate-900 tracking-tight">Analytics</h1>
        <p className="text-slate-500 text-sm mt-0.5">User behavior, engagement, and platform insights</p>
      </div>

      {(dauError || searchError || sharesError) && (
        <QueryError
          title="Some analytics failed to load"
          error={dauErr ?? sharesErr ?? searchErr}
          onRetry={() => {
            if (dauError) refetchDau();
            if (sharesError) refetchShares();
            if (searchError) refetchSearches();
          }}
        />
      )}

      {/* Summary Chips */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
          <div className="text-xs text-slate-500 font-medium mb-1">Today's DAU</div>
          <div className="text-2xl font-bold text-blue-600 tabular-nums">{formatNumber(totalDau)}</div>
          <div className="text-[11px] text-slate-400 mt-0.5">Daily active users</div>
        </div>
        <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
          <div className="text-xs text-slate-500 font-medium mb-1">Total Shares (30d)</div>
          <div className="text-2xl font-bold text-blue-600 tabular-nums">{formatNumber(totalShares)}</div>
          <div className="text-[11px] text-slate-400 mt-0.5">WhatsApp &amp; Instagram shares</div>
        </div>
        <div className="col-span-2 md:col-span-1 bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
          <div className="text-xs text-slate-500 font-medium mb-1">Top Search Today</div>
          <div className="text-lg font-bold text-slate-800 truncate">{searches[0]?.term || '—'}</div>
          <div className="text-[11px] text-slate-400 mt-0.5">{searches[0]?.count ? `${searches[0].count} queries` : 'No search data'}</div>
        </div>
      </div>

      {/* DAU Chart */}
      <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-5">
          <div>
            <h3 className="font-semibold text-slate-900 text-sm">Daily Active Users (DAU)</h3>
            <p className="text-slate-400 text-xs mt-0.5">Last 30 days active sessions</p>
          </div>
          <div className="flex items-center gap-1.5 text-emerald-700 text-xs font-semibold bg-emerald-50 border border-emerald-200/70 px-2.5 py-1 rounded-md self-start sm:self-auto">
            <TrendingUp size={13} /> Live Stream
          </div>
        </div>
        {dauLoading ? (
          <div className="h-60 rounded-lg bg-slate-100 animate-pulse" />
        ) : dau.length === 0 ? (
          <div className="h-60 flex items-center justify-center text-slate-400 text-xs">
            No activity data yet — users need to log in first.
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={dau}>
              <defs>
                <linearGradient id="dauGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#2563EB" stopOpacity={0.12} />
                  <stop offset="95%" stopColor="#2563EB" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis
                dataKey="date"
                axisLine={false}
                tickLine={false}
                tick={{ fontSize: 11, fill: '#64748b' }}
                interval={Math.ceil(dau.length / 6)}
                tickFormatter={(v) => new Date(v).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })}
              />
              <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#64748b' }} tickFormatter={formatNumber} />
              <Tooltip
                contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', boxShadow: '0 2px 8px rgba(0,0,0,0.05)', fontSize: 12 }}
                labelFormatter={(v) => new Date(v).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })}
                formatter={(v: number) => [formatNumber(v), 'Active Users']}
              />
              <Area type="monotone" dataKey="count" stroke="#2563EB" strokeWidth={2} fill="url(#dauGradient)" dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {/* Share Breakdown */}
        <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
          <h3 className="font-semibold text-slate-900 text-sm mb-0.5">Share Breakdown</h3>
          <p className="text-slate-400 text-xs mb-4">Last 30 days distribution by destination</p>
          {sharesLoading ? (
            <div className="h-44 rounded-lg bg-slate-100 animate-pulse" />
          ) : shares.length === 0 ? (
            <div className="h-44 flex items-center justify-center text-slate-400 text-xs">No shares recorded yet.</div>
          ) : (
            <div className="flex flex-col sm:flex-row items-center gap-4">
              <ResponsiveContainer width={150} height={150}>
                <PieChart>
                  <Pie data={shares} cx="50%" cy="50%" innerRadius={40} outerRadius={68} dataKey="count" paddingAngle={2}>
                    {shares.map((_: any, i: number) => (
                      <Cell key={i} fill={PLATFORM_COLORS[i % PLATFORM_COLORS.length]} />
                    ))}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
              <div className="space-y-2 flex-1 w-full">
                {shares.map((s: any, i: number) => (
                  <div key={s.platform} className="flex items-center gap-2">
                    <div className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: PLATFORM_COLORS[i % PLATFORM_COLORS.length] }} />
                    <div className="text-xs text-slate-700 flex-1 truncate">{s.platform.replace(/_/g, ' ')}</div>
                    <div className="text-xs font-semibold text-slate-900 tabular-nums">{formatNumber(Number(s.count))}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Top Searches */}
        <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
          <h3 className="font-semibold text-slate-900 text-sm mb-0.5">Top Searches</h3>
          <p className="text-slate-400 text-xs mb-4">Most queried search terms (last 7 days)</p>
          {searchLoading ? (
            <div className="h-44 rounded-lg bg-slate-100 animate-pulse" />
          ) : searches.length === 0 ? (
            <div className="h-44 flex items-center justify-center text-slate-400 text-xs">No search data yet.</div>
          ) : (
            <div className="space-y-2.5">
              {searches.slice(0, 8).map((s: any, i: number) => (
                <div key={s.term} className="flex items-center gap-3">
                  <span className="text-xs font-semibold text-slate-400 w-4 shrink-0">{i + 1}</span>
                  <div className="flex-1 min-w-0">
                    <div className="text-xs font-medium text-slate-700 truncate">{s.term}</div>
                    <div className="h-1.5 bg-slate-100 rounded-full mt-1 overflow-hidden">
                      <div
                        className="h-1.5 rounded-full bg-blue-600"
                        style={{ width: `${(Number(s.count) / Number(searches[0].count)) * 100}%` }}
                      />
                    </div>
                  </div>
                  <span className="text-xs font-medium text-slate-500 tabular-nums shrink-0">{formatNumber(Number(s.count))}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
