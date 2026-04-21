'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Eye, CheckCircle, XCircle, Clock, RefreshCw, Loader2, X } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatRelativeTime } from '@/lib/utils';

const REJECTION_REASONS = [
  'Image resolution too low (minimum 1080×1920px required)',
  'Quote missing in one or more languages (Hindi, Marathi, English required)',
  'Content not appropriate for our platform',
  'Overlay zones not configured — please set name/photo zones',
  'Duplicate content already exists in the app',
  'Copyright music or watermark detected in video',
];

function PreviewModal({ template, onClose }: { template: any; onClose: () => void }) {
  return (
    <div className="fixed inset-0 bg-black/90 flex items-center justify-center z-[60] p-4 backdrop-blur-md">
      <button onClick={onClose} className="absolute top-4 right-4 text-white hover:text-primary transition-colors">
        <X size={32} />
      </button>
      <div className="max-w-4xl w-full max-h-[90vh] flex flex-col items-center">
        <div className="relative rounded-2xl overflow-hidden shadow-2xl bg-slate-900 aspect-[9/16] h-[75vh]">
          {template.type === 'VIDEO' ? (
            <video src={template.videoUrl || template.imageUrl} controls autoPlay className="w-full h-full object-contain" />
          ) : (
            <img src={template.imageUrl} alt={template.nameEn} className="w-full h-full object-contain" />
          )}
        </div>
        <div className="mt-6 text-center text-white">
          <h2 className="text-2xl font-900">{template.nameEn || template.nameHi}</h2>
          <p className="text-white/60 mt-1">{template.quoteHi}</p>
        </div>
      </div>
    </div>
  );
}

function RejectModal({ templateName, onConfirm, onCancel, isRejecting }: {
  templateName: string;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
  isRejecting?: boolean;
}) {
  const [reason, setReason] = useState('');
  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
      <div className="bg-white rounded-2xl p-6 max-w-md w-full shadow-2xl">
        <h3 className="font-900 text-slate-800 text-lg mb-1">❌ Reject Template</h3>
        <p className="text-muted text-sm mb-4">
          This reason will be sent directly to the creator via push notification.
        </p>
        <div className="mb-3 space-y-1.5">
          <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-1.5 block">Quick Select</label>
          {REJECTION_REASONS.map(r => (
            <button key={r} onClick={() => setReason(r)}
              disabled={isRejecting}
              className={`w-full text-left text-xs px-3 py-2 rounded-lg border transition-colors ${
                reason === r ? 'border-danger bg-red-50 text-danger font-700' : 'border-surface-border text-muted hover:border-slate-300'
              }`}>
              {r}
            </button>
          ))}
        </div>
        <textarea value={reason} onChange={e => setReason(e.target.value)}
          disabled={isRejecting}
          placeholder="Or write a custom reason..."
          rows={3}
          className="w-full border border-surface-border rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-primary resize-none mt-2" />
        <div className="text-xs text-muted text-right mb-4">{reason.length} chars (min 10)</div>
        <div className="flex gap-3">
          <button onClick={onCancel} disabled={isRejecting} className="btn-ghost flex-1">Cancel</button>
          <button onClick={() => reason.length >= 10 && onConfirm(reason)}
            disabled={reason.length < 10 || isRejecting}
            className="btn-danger flex-1 disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-2">
            {isRejecting ? <Loader2 size={16} className="animate-spin" /> : null}
            {isRejecting ? 'Sending...' : 'Send Rejection'}
          </button>
        </div>
      </div>
    </div>
  );
}

function ReviewCard({ template, onApprove, onReject, onPreview, isApproving, isRejecting }: {
  template: any;
  onApprove: () => void;
  onReject: () => void;
  onPreview: () => void;
  isApproving?: boolean;
  isRejecting?: boolean;
}) {
  const isPending = template.status === 'PENDING';
  const isApproved = template.status === 'APPROVED';
  const isRejected = template.status === 'REJECTED';

  const badgeClass = isPending ? 'badge-pending' : isApproved ? 'badge-success' : 'badge-danger';

  return (
    <div className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden">
      {/* Thumbnail */}
      <div className="h-36 md:h-44 relative flex items-center justify-center"
        style={{ background: template.gradient || 'linear-gradient(135deg,#7C5CFC,#FF6B9D)' }}>
        <div className="text-center text-white px-4">
          {template.imageUrl ? (
            <img src={template.imageUrl} alt={template.nameEn} className="h-full w-full object-cover absolute inset-0" />
          ) : (
            <>
              <div className="font-800 text-base leading-tight drop-shadow">{template.nameHi || template.nameEn}</div>
              <div className="text-xs opacity-70 mt-1">{template.quoteHi?.slice(0, 50)}</div>
            </>
          )}
        </div>
        {template.type === 'VIDEO' && (
          <div className="absolute top-2 right-2 badge-video">VIDEO</div>
        )}
      </div>

      <div className="p-4">
        <div className="flex items-start justify-between mb-2">
          <div>
            <div className="font-800 text-slate-800 text-sm">{template.nameEn || template.nameHi}</div>
            <div className="text-xs text-muted">{template.nameHi} · {template.nameMr}</div>
          </div>
          <span className={`${badgeClass} shrink-0`}>{template.status}</span>
        </div>

        <div className="flex flex-wrap gap-1.5 mb-3">
          <span className="text-xs bg-surface text-muted-foreground px-2 py-0.5 rounded-full font-600">
            {template.category?.nameEn || template.category?.nameHi || 'Uncategorized'}
          </span>
          {(template.tags || []).slice(0, 2).map((tag: string) => (
            <span key={tag} className="text-xs bg-surface text-muted-foreground px-2 py-0.5 rounded-full font-600">
              #{tag}
            </span>
          ))}
        </div>

        <div className="flex items-center gap-2 mb-4 text-xs text-muted">
          <div className="w-5 h-5 rounded-full bg-gradient-brand flex items-center justify-center text-white text-[9px] font-800 shrink-0">
            {(template.creator?.name || 'U')[0]}
          </div>
          <span className="truncate">{template.creator?.name || 'Unknown Creator'}</span>
          <span>·</span>
          <Clock size={11} className="shrink-0" />
          <span className="whitespace-nowrap">{formatRelativeTime(template.submittedAt)}</span>
        </div>

        <div className="grid grid-cols-3 gap-1.5">
          <button onClick={onPreview} className="flex items-center justify-center gap-1 btn-ghost text-xs py-2">
            <Eye size={13} /> Preview
          </button>
          
          {isPending ? (
            <>
              <button onClick={onApprove} disabled={isApproving || isRejecting}
                className="flex items-center justify-center gap-1 btn-success text-xs py-2 disabled:opacity-50">
                {isApproving ? <Loader2 size={13} className="animate-spin" /> : <CheckCircle size={13} />}
                {isApproving ? '...' : 'Approve'}
              </button>
              <button onClick={onReject} disabled={isApproving || isRejecting}
                className="flex items-center justify-center gap-1 btn-danger text-xs py-2 disabled:opacity-50">
                {isRejecting ? <Loader2 size={13} className="animate-spin" /> : <XCircle size={13} />}
                {isRejecting ? '...' : 'Reject'}
              </button>
            </>
          ) : (
            <div className="col-span-2 flex items-center justify-center text-[10px] font-800 text-muted uppercase tracking-wider bg-surface rounded-lg">
              Action completed
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function ReviewQueuePage() {
  const queryClient = useQueryClient();
  const [rejectTarget, setRejectTarget] = useState<{ id: string; name: string } | null>(null);
  const [previewTarget, setPreviewTarget] = useState<any | null>(null);
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'rejected'>('pending');
  const [approvingId, setApprovingId] = useState<string | null>(null);
  const [rejectingId, setRejectingId] = useState<string | null>(null);

  const { data, isLoading, refetch, isRefetching } = useQuery({
    queryKey: ['review-queue', activeTab],
    queryFn: () => {
      if (activeTab === 'pending') return adminApi.getPendingTemplates({ page: 1, limit: 20 });
      return adminApi.getTemplates({ status: activeTab.toUpperCase(), page: 1, limit: 20 });
    },
    staleTime: 30 * 1000,
  });

  const approveMutation = useMutation({
    mutationFn: (id: string) => adminApi.approveTemplate(id),
    onMutate: (id) => setApprovingId(id),
    onSettled: () => setApprovingId(null),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['review-queue'] });
      queryClient.invalidateQueries({ queryKey: ['admin-stats'] });
    },
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, note }: { id: string; note: string }) => adminApi.rejectTemplate(id, note),
    onMutate: ({ id }) => setRejectingId(id),
    onSettled: () => setRejectingId(null),
    onSuccess: () => {
      setRejectTarget(null);
      queryClient.invalidateQueries({ queryKey: ['review-queue'] });
      queryClient.invalidateQueries({ queryKey: ['admin-stats'] });
    },
  });

  const templates = data?.data ?? [];
  const total = data?.total ?? 0;

  const tabs = [
    { key: 'pending', label: 'Pending', color: 'text-amber-600' },
    { key: 'approved', label: 'Approved', color: 'text-success' },
    { key: 'rejected', label: 'Rejected', color: 'text-danger' },
  ] as const;

  return (
    <div className="space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-900 text-slate-800">Review Queue</h1>
          <p className="text-muted text-sm mt-1">Template submissions awaiting approval</p>
        </div>
        <button onClick={() => refetch()} disabled={isLoading || isRefetching}
          className="btn-ghost flex items-center gap-2 self-start sm:self-auto disabled:opacity-50">
          <RefreshCw size={14} className={isRefetching ? 'animate-spin' : ''} /> 
          {isRefetching ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-surface p-1 rounded-xl w-fit border border-surface-border">
        {tabs.map(tab => (
          <button key={tab.key} onClick={() => setActiveTab(tab.key)}
            className={`px-4 py-2 rounded-lg text-sm font-700 transition-colors ${
              activeTab === tab.key ? 'bg-white text-slate-800 shadow-sm' : 'text-muted hover:text-slate-600'
            }`}>
            {tab.label}
            {activeTab === tab.key && total > 0 && (
              <span className={`ml-2 text-xs px-1.5 py-0.5 rounded-full bg-primary/10 text-primary`}>
                {total}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Content */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[1, 2, 3].map(i => (
            <div key={i} className="bg-white rounded-2xl h-72 animate-pulse border border-surface-border" />
          ))}
        </div>
      ) : templates.length === 0 ? (
        <div className="bg-white rounded-2xl p-16 text-center border border-surface-border">
          <div className="text-5xl mb-4">{activeTab === 'pending' ? '🎉' : '📭'}</div>
          <div className="font-800 text-slate-700 text-lg">
            {activeTab === 'pending' ? 'All clear! No pending templates.' : `No ${activeTab} templates.`}
          </div>
          <div className="text-muted text-sm mt-1">
            {activeTab === 'pending' ? 'Check back later for new submissions.' : ''}
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {templates.map((template: any) => (
            <ReviewCard
              key={template.id}
              template={template}
              onPreview={() => setPreviewTarget(template)}
              onApprove={() => approveMutation.mutate(template.id)}
              onReject={() => setRejectTarget({ id: template.id, name: template.nameEn ?? template.nameHi ?? 'Template' })}
              isApproving={approvingId === template.id}
              isRejecting={rejectingId === template.id}
            />
          ))}
        </div>
      )}

      {previewTarget && (
        <PreviewModal
          template={previewTarget}
          onClose={() => setPreviewTarget(null)}
        />
      )}

      {rejectTarget && (
        <RejectModal
          templateName={rejectTarget.name}
          onConfirm={(note) => rejectMutation.mutate({ id: rejectTarget.id, note })}
          onCancel={() => setRejectTarget(null)}
          isRejecting={rejectingId === rejectTarget.id}
        />
      )}
    </div>
  );
}
