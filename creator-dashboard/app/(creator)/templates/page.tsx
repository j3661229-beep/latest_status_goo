'use client';

import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Trash2, Edit } from 'lucide-react';
import Link from 'next/link';
import { creatorApi } from '@/lib/api';
import { getErrorMessage, getStatusConfig, STATUS_CONFIG, templateName } from '@/lib/utils';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';

const VALID_STATUSES = Object.keys(STATUS_CONFIG);

export default function CreatorTemplatesPage() {
  // useSearchParams requires a Suspense boundary in Next 15 client pages.
  return (
    <Suspense fallback={<div className="h-64 bg-white rounded-xl border border-slate-200/80 animate-pulse" />}>
      <CreatorTemplatesContent />
    </Suspense>
  );
}

function CreatorTemplatesContent() {
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const initialStatus = searchParams.get('status') ?? '';
  const [statusFilter, setStatusFilter] = useState(VALID_STATUSES.includes(initialStatus) ? initialStatus : '');
  const [typeFilter, setTypeFilter] = useState('');

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['creator-templates', { statusFilter, typeFilter }],
    queryFn: () => {
      const params: Record<string, string | number> = { limit: 50 };
      if (statusFilter) params.status = statusFilter;
      if (typeFilter) params.type = typeFilter;
      return creatorApi.getTemplates(params);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => creatorApi.deleteTemplate(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['creator-templates'] });
      toast.success('Draft deleted');
    },
    onError: (err) => toast.error(getErrorMessage(err, 'Could not delete template')),
  });

  const templates = data?.data || [];
  const total = data?.total || 0;

  return (
    <div className="space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">My Templates</h1>
          <p className="text-slate-500 text-sm mt-0.5">{total} total templates created</p>
        </div>
        <Link href="/upload" className="btn-primary text-xs flex items-center gap-1.5 self-start sm:self-auto">
          <Plus size={14} /> Upload New Template
        </Link>
      </div>

      {/* Filter Bar */}
      <div className="flex flex-wrap gap-2.5 bg-white rounded-xl p-3 border border-slate-200/80 shadow-sm">
        <select
          value={statusFilter}
          onChange={e => setStatusFilter(e.target.value)}
          className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
        >
          <option value="">All Statuses</option>
          <option value="APPROVED">Approved</option>
          <option value="PENDING">Pending Review</option>
          <option value="REJECTED">Rejected</option>
          <option value="DRAFT">Drafts</option>
        </select>
        <select
          value={typeFilter}
          onChange={e => setTypeFilter(e.target.value)}
          className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
        >
          <option value="">All Types</option>
          <option value="IMAGE">Image</option>
          <option value="VIDEO">Video</option>
        </select>
      </div>

      {/* Data Grid */}
      {isError ? (
        <QueryError error={error} onRetry={() => refetch()} title="Could not load your templates" />
      ) : isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[1, 2, 3].map(i => (
            <div key={i} className="bg-white rounded-xl h-64 animate-pulse border border-slate-200/80" />
          ))}
        </div>
      ) : templates.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-slate-200/80 shadow-sm">
          <div className="text-3xl mb-2">🖼️</div>
          <div className="font-semibold text-slate-700 text-sm mb-1">No templates found</div>
          <div className="text-xs text-slate-400">
            {statusFilter || typeFilter ? 'Try clearing the filters above.' : 'Upload your first artwork to get started.'}
          </div>
          <Link href="/upload" className="mt-3 btn-primary text-xs px-3.5 py-1.5 inline-flex">Upload Template</Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {templates.map((t: any) => (
            <div
              key={t.id}
              className="bg-white rounded-xl border border-slate-200/80 overflow-hidden shadow-sm hover:border-slate-300 transition-all flex flex-col"
            >
              <div 
                className="h-44 bg-slate-100 flex items-center justify-center relative overflow-hidden"
                style={{ background: t.gradient || 'linear-gradient(135deg, #2563EB, #0EA5E9)' }}
              >
                {t.imageUrl ? (
                  <img src={t.imageUrl} alt={t.nameEn} className="w-full h-full object-cover absolute inset-0" />
                ) : (
                  <div className="font-bold text-white text-sm px-4 text-center leading-tight drop-shadow">
                    {templateName(t)}
                  </div>
                )}
                <div className="absolute top-2 right-2">
                  <span className={getStatusConfig(t.status).cls}>
                    {getStatusConfig(t.status).label}
                  </span>
                </div>
                {t.type === 'VIDEO' && (
                  <span className="absolute bottom-2 left-2 badge-video">VIDEO</span>
                )}
              </div>
              <div className="p-4 flex-1 flex flex-col justify-between">
                <div>
                  <div className="flex items-start justify-between gap-2 mb-1">
                    <div className="font-semibold text-slate-900 text-sm truncate">{templateName(t)}</div>
                    <div className="flex gap-1 text-slate-400">
                      {t.status === 'DRAFT' && (
                        <button 
                          onClick={() => { if (confirm('Delete template?')) deleteMutation.mutate(t.id); }}
                          className="p-1 hover:text-rose-600 rounded transition-colors"
                          title="Delete draft"
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                      {['DRAFT', 'REJECTED'].includes(t.status) && (
                        <Link href={`/upload?edit=${t.id}`} className="p-1 hover:text-blue-600 rounded transition-colors" title="Edit">
                          <Edit size={14} />
                        </Link>
                      )}
                    </div>
                  </div>
                  <div className="text-xs text-slate-400 mb-3">
                    {t.category?.nameEn || 'Uncategorized'}
                  </div>
                </div>

                <div>
                  <div className="flex gap-4 text-xs text-slate-500 pt-2 border-t border-slate-100">
                    <span>👁 {(t.useCount || 0).toLocaleString()} uses</span>
                    <span>🔗 {(t.shareCount || 0).toLocaleString()} shares</span>
                  </div>
                  {t.status === 'REJECTED' && (
                    <div className="mt-2.5 bg-rose-50 text-rose-700 text-[11px] p-2 rounded-md border border-rose-100">
                      Reason: {t.reviewNote || 'Does not meet guidelines.'}
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
