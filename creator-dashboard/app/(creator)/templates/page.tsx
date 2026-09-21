'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, Filter, Plus, Trash2, Edit } from 'lucide-react';
import Link from 'next/link';
import { creatorApi } from '@/lib/api';

export default function CreatorTemplatesPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['creator-templates', { search, statusFilter, typeFilter }],
    queryFn: () => creatorApi.getTemplates({ status: statusFilter, type: typeFilter }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => creatorApi.deleteTemplate(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['creator-templates'] }),
  });

  const templates = data?.data || [];
  const total = data?.total || 0;

  const BADGE: any = {
    APPROVED: 'badge-approved',
    PENDING: 'badge-pending',
    REJECTED: 'badge-rejected',
    DRAFT: 'badge-draft',
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-900 text-slate-800">My Templates</h1>
          <p className="text-muted text-sm mt-1">{total} templates uploaded</p>
        </div>
        <Link href="/upload" className="btn-primary flex items-center gap-2 text-sm">
          <Plus size={14} /> Upload New
        </Link>
      </div>

      {/* Filter Bar */}
      <div className="flex gap-3 bg-white rounded-2xl p-4 border border-surface-border shadow-card">
        <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)}
          className="px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700">
          <option value="">All Status</option>
          <option value="APPROVED">Approved</option>
          <option value="PENDING">Pending Review</option>
          <option value="REJECTED">Rejected</option>
          <option value="DRAFT">Drafts</option>
        </select>
        <select value={typeFilter} onChange={e => setTypeFilter(e.target.value)}
          className="px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700">
          <option value="">All Types</option>
          <option value="IMAGE">Image</option>
          <option value="VIDEO">Video</option>
        </select>
      </div>

      {/* Data Grid */}
      {isLoading ? (
        <div className="text-center py-12 text-muted">Loading templates...</div>
      ) : templates.length === 0 ? (
        <div className="text-center py-12 bg-white rounded-2xl border border-surface-border">
          <div className="text-4xl mb-3">🖼️</div>
          <div className="font-800 text-slate-700 mb-1">No templates found</div>
          <div className="text-sm text-muted">You haven't uploaded any templates yet.</div>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {templates.map((t: any) => (
            <div key={t.id} className="bg-white rounded-2xl border border-surface-border overflow-hidden shadow-card hover:shadow-lg hover:border-blue-200 transition-all group">
              <div 
                className="h-44 bg-slate-100 flex items-center justify-center relative"
                style={{ background: t.gradient || 'linear-gradient(135deg, #2563EB, #0EA5E9)' }}
              >
                <div className="absolute top-2 right-2">
                  <span className={BADGE[t.status]}>{t.status}</span>
                </div>
                <div className="font-800 text-white px-4 text-center leading-tight drop-shadow-md">
                  {t.nameEn || t.nameHi}
                </div>
                {t.type === 'VIDEO' && <span className="absolute bottom-2 left-2 badge-video">VIDEO</span>}
              </div>
              <div className="p-4">
                <div className="font-700 text-slate-800 flex justify-between">
                  <span>{t.category?.nameEn || 'Uncategorized'}</span>
                  <div className="flex gap-1 text-muted">
                    {t.status === 'DRAFT' && (
                      <button 
                        onClick={() => { if(confirm('Delete template?')) deleteMutation.mutate(t.id); }}
                        className="p-1 hover:text-danger rounded"
                      >
                        <Trash2 size={14} />
                      </button>
                    )}
                    {['DRAFT', 'REJECTED'].includes(t.status) && (
                      <button className="p-1 hover:text-primary rounded">
                        <Edit size={14} />
                      </button>
                    )}
                  </div>
                </div>
                <div className="flex gap-4 text-xs text-muted mt-3">
                  <span>👁 {(t.useCount || 0).toLocaleString()} uses</span>
                  <span>🔗 {(t.shareCount || 0).toLocaleString()} shares</span>
                </div>
                {t.status === 'REJECTED' && (
                  <div className="mt-3 bg-red-50 text-danger text-[10px] font-600 p-2 rounded-lg border border-red-100">
                    Reason: {t.reviewNote || 'Does not meet guidelines.'}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
