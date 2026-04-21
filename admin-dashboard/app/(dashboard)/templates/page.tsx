'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, Star, Trash2, TrendingUp, Download } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatNumber, getStatusBadgeClass } from '@/lib/utils';

export default function TemplatesPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ['admin-templates', { search, statusFilter, typeFilter, page }],
    queryFn: () => adminApi.getTemplates({ search, status: statusFilter, type: typeFilter, page, limit: 20 }),
    staleTime: 60 * 1000,
  });

  const featureMutation = useMutation({
    mutationFn: ({ id, isFeatured }: { id: string; isFeatured: boolean }) => adminApi.featureTemplate(id, isFeatured),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-templates'] }),
  });

  const archiveMutation = useMutation({
    mutationFn: (id: string) => adminApi.archiveTemplate(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-templates'] }),
  });

  const templates = data?.data ?? [];
  const total = data?.total ?? 0;
  const totalPages = Math.ceil(total / 20);

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-900 text-slate-800">Template Manager</h1>
          <p className="text-muted text-sm mt-1">
            {isLoading ? 'Loading...' : `${total} total templates in the system`}
          </p>
        </div>
        <button className="btn-ghost flex items-center gap-2 text-sm self-start sm:self-auto">
          <Download size={14} /> Export CSV
        </button>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-wrap gap-2 bg-white rounded-2xl p-3 md:p-4 border border-surface-border shadow-card">
        <div className="relative flex-1 min-w-[180px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
          <input
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search templates..."
            className="w-full pl-9 pr-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(1); }}
          className="px-3 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700">
          <option value="">All Status</option>
          <option value="APPROVED">Approved</option>
          <option value="PENDING">Pending</option>
          <option value="REJECTED">Rejected</option>
          <option value="DRAFT">Draft</option>
          <option value="ARCHIVED">Archived</option>
        </select>
        <select value={typeFilter} onChange={e => { setTypeFilter(e.target.value); setPage(1); }}
          className="px-3 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700">
          <option value="">All Types</option>
          <option value="IMAGE">Image</option>
          <option value="VIDEO">Video</option>
        </select>
      </div>

      {/* Data Table — scrollable on mobile */}
      <div className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full data-table min-w-[640px]">
            <thead className="bg-surface">
              <tr>
                <th className="text-left">Template</th>
                <th className="text-left hidden md:table-cell">Category</th>
                <th className="text-left hidden lg:table-cell">Creator</th>
                <th className="text-right">Uses</th>
                <th className="text-left">Status</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>
                    <td colSpan={6}>
                      <div className="h-12 bg-slate-50 animate-pulse rounded" />
                    </td>
                  </tr>
                ))
              ) : templates.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-12 text-muted">
                    No templates found
                    {(search || statusFilter || typeFilter) && (
                      <button className="block mx-auto mt-2 text-primary text-sm underline"
                        onClick={() => { setSearch(''); setStatusFilter(''); setTypeFilter(''); }}>
                        Clear filters
                      </button>
                    )}
                  </td>
                </tr>
              ) : templates.map((t: any) => (
                <tr key={t.id}>
                  <td>
                    <div className="flex items-center gap-3">
                      <div
                        className="w-8 h-11 rounded-lg shrink-0 flex items-center justify-center text-white text-sm"
                        style={{ background: t.gradient || 'linear-gradient(135deg,#7C5CFC,#FF6B9D)' }}
                      >
                        {t.type === 'VIDEO' ? '🎬' : '🖼'}
                      </div>
                      <div>
                        <div className="font-700 text-slate-800 text-sm">{t.nameEn || t.nameHi}</div>
                        <div className="text-xs text-muted">{t.nameHi}</div>
                      </div>
                    </div>
                  </td>
                  <td className="hidden md:table-cell">
                    <span className="text-sm text-muted-foreground">{t.category?.nameEn || '—'}</span>
                  </td>
                  <td className="hidden lg:table-cell">
                    <span className="text-sm text-muted-foreground">{t.creator?.name || '—'}</span>
                  </td>
                  <td className="text-right">
                    <span className="text-sm font-700 text-slate-700">{formatNumber(t.useCount || 0)}</span>
                  </td>
                  <td>
                    <span className={getStatusBadgeClass(t.status)}>{t.status}</span>
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end gap-1">
                      <button
                        onClick={() => featureMutation.mutate({ id: t.id, isFeatured: !t.isFeatured })}
                        className={`p-1.5 rounded-lg hover:bg-surface transition-colors ${t.isFeatured ? 'text-amber-500' : 'text-muted hover:text-amber-500'}`}
                        title={t.isFeatured ? 'Unfeature' : 'Feature'}
                      >
                        <Star size={13} className={t.isFeatured ? 'fill-amber-500' : ''} />
                      </button>
                      <button
                        onClick={() => { if (confirm('Archive this template?')) archiveMutation.mutate(t.id); }}
                        className="p-1.5 rounded-lg hover:bg-surface text-muted hover:text-danger transition-colors"
                        title="Archive"
                      >
                        <Trash2 size={13} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="p-4 border-t border-surface-border flex items-center justify-between text-sm">
            <span className="text-muted">Page {page} of {totalPages}</span>
            <div className="flex gap-2">
              <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
                className="px-3 py-1.5 border rounded-lg hover:bg-surface disabled:opacity-40 text-slate-700">← Prev</button>
              <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}
                className="px-3 py-1.5 border rounded-lg hover:bg-surface disabled:opacity-40 text-slate-700">Next →</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
