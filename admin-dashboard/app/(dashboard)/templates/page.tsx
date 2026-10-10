'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, Star, Trash2, Download } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatNumber, getStatusBadgeClass, downloadCsv } from '@/lib/utils';
import { useDebounce } from '@/lib/hooks';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';

export default function TemplatesPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [page, setPage] = useState(1);

  const debouncedSearch = useDebounce(search.trim(), 300);

  // GET /admin/templates?search=… (empty params are stripped by adminApi)
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['admin-templates', { search: debouncedSearch, statusFilter, typeFilter, page }],
    queryFn: () => adminApi.getTemplates({
      search: debouncedSearch || undefined,
      status: statusFilter || undefined,
      type: typeFilter || undefined,
      page,
      limit: 20,
    }),
    staleTime: 60 * 1000,
    placeholderData: (prev) => prev,
  });

  const featureMutation = useMutation({
    mutationFn: ({ id, isFeatured }: { id: string; isFeatured: boolean }) => adminApi.featureTemplate(id, isFeatured),
    onError: (err) => toast.apiError(err, 'Failed to update featured flag'),
    onSuccess: (_d, vars) => {
      toast.success(vars.isFeatured ? 'Marked as featured' : 'Removed from featured');
      queryClient.invalidateQueries({ queryKey: ['admin-templates'] });
    },
  });

  const archiveMutation = useMutation({
    mutationFn: (id: string) => adminApi.archiveTemplate(id),
    onError: (err) => toast.apiError(err, 'Failed to archive template'),
    onSuccess: () => {
      toast.success('Template archived');
      queryClient.invalidateQueries({ queryKey: ['admin-templates'] });
    },
  });

  const templates = data?.data ?? [];
  const total = data?.total ?? 0;
  const totalPages = Math.ceil(total / 20);

  const exportCsv = () => downloadCsv(`templates-page-${page}`, templates, [
    { header: 'ID', value: (t: any) => t.id },
    { header: 'Name (EN)', value: (t: any) => t.nameEn },
    { header: 'Name (HI)', value: (t: any) => t.nameHi },
    { header: 'Name (MR)', value: (t: any) => t.nameMr },
    { header: 'Type', value: (t: any) => t.type },
    { header: 'Status', value: (t: any) => t.status },
    { header: 'Category', value: (t: any) => t.category?.nameEn },
    { header: 'Creator', value: (t: any) => t.creator?.name },
    { header: 'Uses', value: (t: any) => t.useCount ?? 0 },
    { header: 'Shares', value: (t: any) => t.shareCount ?? 0 },
    { header: 'Premium', value: (t: any) => (t.isPremium ? 'yes' : 'no') },
    { header: 'Featured', value: (t: any) => (t.isFeatured ? 'yes' : 'no') },
    { header: 'Tags', value: (t: any) => (t.tags || []).join(' ') },
    { header: 'Created', value: (t: any) => t.createdAt },
  ]);

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Templates</h1>
          <p className="text-slate-500 text-sm mt-0.5">
            {isLoading ? 'Loading...' : `${total} total status templates`}
          </p>
        </div>
        <button
          onClick={exportCsv}
          disabled={templates.length === 0}
          title="Export the rows currently shown"
          className="btn-outline text-xs self-start sm:self-auto flex items-center gap-1.5 disabled:opacity-50"
        >
          <Download size={13} /> Export CSV
        </button>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-wrap gap-2.5 bg-white rounded-xl p-3 border border-slate-200/80 shadow-sm">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search templates by name or tag..."
            className="w-full pl-9 pr-3.5 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white placeholder:text-slate-400"
          />
        </div>
        <select
          value={statusFilter}
          onChange={e => { setStatusFilter(e.target.value); setPage(1); }}
          className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
        >
          <option value="">All Statuses</option>
          <option value="APPROVED">Approved</option>
          <option value="PENDING">Pending</option>
          <option value="REJECTED">Rejected</option>
          <option value="DRAFT">Draft</option>
          <option value="ARCHIVED">Archived</option>
        </select>
        <select
          value={typeFilter}
          onChange={e => { setTypeFilter(e.target.value); setPage(1); }}
          className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
        >
          <option value="">All Types</option>
          <option value="IMAGE">Image</option>
          <option value="VIDEO">Video</option>
        </select>
      </div>

      {isError && <QueryError error={error} onRetry={() => refetch()} />}

      {/* Data Table */}
      {!isError && (
      <div className="bg-white rounded-xl border border-slate-200/80 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full data-table min-w-[640px]">
            <thead>
              <tr>
                <th className="text-left">Template</th>
                <th className="text-left hidden md:table-cell">Category</th>
                <th className="text-left hidden lg:table-cell">Creator</th>
                <th className="text-right">Total Uses</th>
                <th className="text-left">Status</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>
                    <td colSpan={6} className="py-4">
                      <div className="h-9 bg-slate-50 animate-pulse rounded-md" />
                    </td>
                  </tr>
                ))
              ) : templates.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-12 text-slate-400 text-sm">
                    No templates found matching the criteria
                    {(search || statusFilter || typeFilter) && (
                      <button
                        className="block mx-auto mt-2 text-blue-600 text-xs font-medium underline"
                        onClick={() => { setSearch(''); setStatusFilter(''); setTypeFilter(''); setPage(1); }}
                      >
                        Reset filters
                      </button>
                    )}
                  </td>
                </tr>
              ) : templates.map((t: any) => (
                <tr key={t.id} className="hover:bg-slate-50/60 transition-colors">
                  <td>
                    <div className="flex items-center gap-3">
                      <div
                        className="w-8 h-10 rounded-md shrink-0 border border-slate-200/60 bg-cover bg-center flex items-center justify-center text-xs"
                        style={{
                          backgroundImage: t.imageThumbUrl || t.imageUrl ? `url(${t.imageThumbUrl || t.imageUrl})` : undefined,
                          background: !t.imageThumbUrl && !t.imageUrl ? (t.gradient || 'linear-gradient(135deg,#2563EB,#0EA5E9)') : undefined,
                        }}
                      >
                        {!t.imageThumbUrl && !t.imageUrl && (t.type === 'VIDEO' ? '🎬' : '🖼')}
                      </div>
                      <div className="min-w-0">
                        <div className="font-semibold text-slate-900 text-sm truncate">{t.nameEn || t.nameHi || 'Untitled'}</div>
                        <div className="text-xs text-slate-400 truncate">{t.nameHi}</div>
                      </div>
                    </div>
                  </td>
                  <td className="hidden md:table-cell">
                    <span className="text-xs text-slate-500 font-medium bg-slate-50 px-2 py-0.5 rounded border border-slate-200/60">
                      {t.category?.nameEn || 'General'}
                    </span>
                  </td>
                  <td className="hidden lg:table-cell">
                    <span className="text-xs text-slate-600 font-medium">{t.creator?.name || 'Status Go Team'}</span>
                  </td>
                  <td className="text-right">
                    <span className="text-sm font-semibold text-slate-700 tabular-nums">{formatNumber(t.useCount || 0)}</span>
                  </td>
                  <td>
                    <span className={getStatusBadgeClass(t.status)}>{t.status}</span>
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end items-center gap-1">
                      <button
                        onClick={() => featureMutation.mutate({ id: t.id, isFeatured: !t.isFeatured })}
                        className={`p-1.5 rounded-md hover:bg-slate-100 transition-colors ${t.isFeatured ? 'text-amber-500' : 'text-slate-400 hover:text-amber-500'}`}
                        title={t.isFeatured ? 'Unmark Featured' : 'Mark as Featured'}
                      >
                        <Star size={14} className={t.isFeatured ? 'fill-amber-500' : ''} />
                      </button>
                      <button
                        onClick={() => { if (confirm('Archive this template?')) archiveMutation.mutate(t.id); }}
                        className="p-1.5 rounded-md hover:bg-rose-50 text-slate-400 hover:text-rose-600 transition-colors"
                        title="Archive template"
                      >
                        <Trash2 size={14} />
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
          <div className="px-4 py-3 border-t border-slate-200/80 flex items-center justify-between text-xs text-slate-500 bg-slate-50/40">
            <span>Showing page {page} of {totalPages} ({total} templates)</span>
            <div className="flex gap-1.5">
              <button
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
                className="btn-outline text-xs px-2.5 py-1 disabled:opacity-40"
              >
                Previous
              </button>
              <button
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                disabled={page === totalPages}
                className="btn-outline text-xs px-2.5 py-1 disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>
      )}
    </div>
  );
}
