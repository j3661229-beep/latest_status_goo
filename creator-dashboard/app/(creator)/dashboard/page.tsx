'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { Upload, CheckCircle, XCircle, Clock, Eye, BadgeCheck, ArrowRight } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { creatorApi } from '@/lib/api';
import { getStatusConfig, templateName } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';

function StatCard({ label, value, sub, icon: Icon, color = 'blue' }: any) {
  const iconBg = color === 'emerald' ? 'bg-emerald-50 text-emerald-600 border-emerald-100' : 'bg-blue-50 text-blue-600 border-blue-100';
  return (
    <div className="stat-card">
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">{label}</span>
        <div className={`w-8 h-8 rounded-lg border flex items-center justify-center shrink-0 ${iconBg}`}>
          <Icon size={16} />
        </div>
      </div>
      <div className="text-2xl font-bold text-slate-900 tracking-tight tabular-nums mb-1">{value}</div>
      {sub && <div className="text-xs text-slate-500 leading-tight">{sub}</div>}
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

export default function CreatorDashboardPage() {
  const { data: stats, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['creator-stats'],
    queryFn: () => creatorApi.getStats(),
    staleTime: 2 * 60 * 1000,
    refetchInterval: 5 * 60 * 1000,
  });

  // Real per-template totals (backend has no time-series endpoint for creators).
  const usesByTemplate = (stats?.topTemplates ?? []).map((t: any) => ({
    name: templateName(t).slice(0, 18),
    uses: t.useCount ?? 0,
  }));
  const hasUsage = usesByTemplate.some((d: any) => d.uses > 0);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Creator Studio</h1>
          <p className="text-slate-500 text-sm mt-0.5">Template performance, usage analytics, and status updates</p>
        </div>
        <Link href="/upload" className="btn-primary text-xs self-start sm:self-auto flex items-center gap-1.5">
          <Upload size={14} /> Upload New Template
        </Link>
      </div>

      {isError && <QueryError error={error} onRetry={() => refetch()} title="Could not load your stats" />}

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {isLoading ? (
          Array.from({ length: 4 }).map((_, i) => <SkeletonCard key={i} />)
        ) : (
          <>
            <StatCard
              label="Total Uploads"
              value={stats?.totalUploads ?? 0}
              sub={`${stats?.approved ?? 0} approved · ${stats?.pending ?? 0} pending`}
              icon={Upload}
              color="blue"
            />
            <StatCard
              label="Approval Rate"
              value={`${(stats?.approvalRate ?? 0).toFixed(1)}%`}
              sub="Acceptance standard"
              icon={CheckCircle}
              color="emerald"
            />
            <StatCard
              label="Total App Uses"
              value={(stats?.totalAppUses ?? 0).toLocaleString()}
              sub="User personalizations"
              icon={Eye}
              color="blue"
            />
            <StatCard
              label="Creator Status"
              value={stats?.isVerified ? 'Verified' : 'Active'}
              sub={stats?.isVerified ? 'Official Verified Creator' : 'Standard Creator Account'}
              icon={stats?.isVerified ? BadgeCheck : Clock}
              color={stats?.isVerified ? 'emerald' : 'blue'}
            />
          </>
        )}
      </div>

      {/* Chart + Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Uses chart */}
        <div className="lg:col-span-2 bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h3 className="text-sm font-semibold text-slate-900">Uses by Top Template</h3>
              <p className="text-slate-400 text-xs mt-0.5">All-time uses of your top live templates</p>
            </div>
          </div>
          {isLoading ? (
            <div className="h-48 bg-slate-50 rounded-lg animate-pulse" />
          ) : !hasUsage ? (
            <div className="h-48 flex flex-col items-center justify-center text-slate-400 text-xs">
              <div className="text-2xl mb-1.5 opacity-60">📊</div>
              <p>No user engagements recorded yet</p>
              <p className="text-[11px] mt-0.5 text-slate-400">Once users share your posters on WhatsApp, views will appear here.</p>
            </div>
          ) : (
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={usesByTemplate} barSize={24}>
                <XAxis dataKey="name" interval={0} axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#64748b' }} />
                <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: '#64748b' }} />
                <Tooltip
                  contentStyle={{ borderRadius: 8, border: '1px solid #e2e8f0', fontSize: 12, boxShadow: '0 2px 4px rgba(0,0,0,0.05)' }}
                  formatter={(v: number) => [v.toLocaleString(), 'Uses']}
                />
                <Bar dataKey="uses" fill="#2563EB" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* Quick Actions & Guidelines */}
        <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm space-y-4">
          <h3 className="text-sm font-semibold text-slate-900">Quick Actions</h3>
          <div className="space-y-2">
            <Link
              href="/upload"
              className="flex items-center gap-2.5 p-2.5 rounded-lg border border-slate-200/70 hover:border-blue-300 hover:bg-blue-50/40 transition-all text-xs font-semibold text-slate-700"
            >
              <div className="w-7 h-7 rounded-md bg-blue-50 text-blue-600 flex items-center justify-center shrink-0">
                <Upload size={14} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-slate-900">Upload New Template</div>
                <div className="text-slate-400 font-normal text-[11px]">Artwork or video status</div>
              </div>
            </Link>

            {(stats?.rejected ?? 0) > 0 && (
              <Link
                href="/templates?status=REJECTED"
                className="flex items-center gap-2.5 p-2.5 rounded-lg border border-rose-200 bg-rose-50/50 hover:bg-rose-50 transition-all text-xs font-semibold text-rose-700"
              >
                <div className="w-7 h-7 rounded-md bg-rose-100 text-rose-600 flex items-center justify-center shrink-0">
                  <XCircle size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <div>Fix Rejected ({stats?.rejected})</div>
                  <div className="text-rose-500 font-normal text-[11px]">Update metadata or zones</div>
                </div>
              </Link>
            )}

            {(stats?.pending ?? 0) > 0 && (
              <Link
                href="/templates?status=PENDING"
                className="flex items-center gap-2.5 p-2.5 rounded-lg border border-amber-200 bg-amber-50/50 hover:bg-amber-50 transition-all text-xs font-semibold text-amber-700"
              >
                <div className="w-7 h-7 rounded-md bg-amber-100 text-amber-600 flex items-center justify-center shrink-0">
                  <Clock size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <div>Pending Review ({stats?.pending})</div>
                  <div className="text-amber-500 font-normal text-[11px]">Under moderation</div>
                </div>
              </Link>
            )}
          </div>

          <div className="pt-3 border-t border-slate-100">
            <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-2">Upload Standards</div>
            <ul className="space-y-1.5 text-xs text-slate-500">
              <li className="flex items-start gap-1.5">
                <span className="text-emerald-600 font-bold">✓</span> Portrait 1080×1920px (9:16 aspect ratio)
              </li>
              <li className="flex items-start gap-1.5">
                <span className="text-emerald-600 font-bold">✓</span> Configure user photo & name zones
              </li>
              <li className="flex items-start gap-1.5">
                <span className="text-emerald-600 font-bold">✓</span> High resolution, clean Hindi/English text
              </li>
              <li className="flex items-start gap-1.5">
                <span className="text-rose-500 font-bold">✕</span> No third-party watermarks or logos
              </li>
            </ul>
          </div>
        </div>
      </div>

      {/* Top Templates */}
      <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold text-slate-900">My Top Templates</h3>
          <Link href="/templates" className="text-blue-600 text-xs font-medium hover:underline inline-flex items-center gap-1">
            View all <ArrowRight size={12} />
          </Link>
        </div>
        {isLoading ? (
          <div className="space-y-2">
            {[1, 2, 3].map(i => (
              <div key={i} className="h-12 bg-slate-50 rounded-lg animate-pulse" />
            ))}
          </div>
        ) : !stats?.topTemplates || stats.topTemplates.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-10 text-slate-400 text-xs">
            <div className="text-2xl mb-1.5 opacity-60">🖼️</div>
            <p className="font-semibold text-slate-600">No approved templates yet</p>
            <Link href="/upload" className="mt-2.5 btn-primary text-xs px-3.5 py-1.5">Upload your first template</Link>
          </div>
        ) : (
          <div className="divide-y divide-slate-100">
            {stats.topTemplates.map((t: any, i: number) => (
              <div key={t.id ?? i} className="flex items-center gap-3.5 py-2.5 first:pt-0 last:pb-0 hover:bg-slate-50/50 rounded-lg px-1 transition-colors">
                <div
                  className="w-8 h-11 rounded-md shrink-0 border border-slate-200/60 bg-cover bg-center flex items-center justify-center"
                  style={{
                    backgroundImage: t.imageThumbUrl || t.imageUrl ? `url(${t.imageThumbUrl || t.imageUrl})` : undefined,
                    background: !t.imageThumbUrl && !t.imageUrl ? (t.gradient || 'linear-gradient(135deg,#2563EB,#0EA5E9)') : undefined,
                  }}
                />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="font-semibold text-slate-800 text-sm truncate">{templateName(t)}</span>
                    <span className={getStatusConfig(t.status).cls}>{getStatusConfig(t.status).label}</span>
                  </div>
                  <div className="flex gap-3 text-xs text-slate-400">
                    <span>{(t.useCount ?? 0).toLocaleString()} uses</span>
                    <span>·</span>
                    <span>{(t.shareCount ?? 0).toLocaleString()} shares</span>
                  </div>
                </div>
                {t.status === 'APPROVED' && (t.useCount ?? 0) > 0 && (
                  <div className="text-right shrink-0">
                    <div className="text-sm font-bold text-slate-800 tabular-nums">
                      {(((t.shareCount ?? 0) / (t.useCount ?? 1)) * 100).toFixed(0)}%
                    </div>
                    <div className="text-[10px] text-slate-400">share rate</div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
