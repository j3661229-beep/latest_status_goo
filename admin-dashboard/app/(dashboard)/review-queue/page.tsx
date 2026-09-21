'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Eye, CheckCircle, XCircle, Clock, RefreshCw, Loader2, X, Pin } from 'lucide-react';
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

function ZoneOverlay({ template }: { template: any }) {
  // Render creator-defined photo and name zones so admin can verify placement
  const containerRef = { width: '100%', height: '100%', position: 'relative' as const };

  const photoZoneStyle: React.CSSProperties | null = template.photoZoneEnabled ? {
    position: 'absolute',
    left: `${(template.photoZoneX - (template.photoZoneSize || 0.2) / 2) * 100}%`,
    top: `${(template.photoZoneY - (template.photoZoneSize || 0.2) / 2) * 100}%`,
    width: `${(template.photoZoneSize || 0.2) * 100}%`,
    aspectRatio: '1',
    borderRadius: template.photoZoneShape === 'circle' ? '50%'
      : template.photoZoneShape === 'rounded' ? '12px' : '4px',
    border: '3px solid rgba(255,255,255,0.9)',
    overflow: 'hidden',
    boxShadow: '0 0 0 2px rgba(0,0,0,0.3)',
  } : null;

  const nameZoneStyle: React.CSSProperties = {
    position: 'absolute',
    left: `${(template.nameZoneX ?? 0.5) * 100}%`,
    top: `${(template.nameZoneY ?? 0.75) * 100}%`,
    transform: 'translateX(-50%)',
    color: template.nameColor ?? '#ffffff',
    fontSize: `${(template.nameFontSize ?? 0.04) * 100}cqh`,
    fontWeight: (template.nameZoneWeight ?? 'bold') as any,
    fontFamily: template.nameFont ?? 'system-ui',
    textShadow: '0 2px 8px rgba(0,0,0,0.7)',
    whiteSpace: 'nowrap',
    pointerEvents: 'none',
    textAlign: (template.nameZoneAlignment ?? 'center') as any,
  };

  return (
    <div style={containerRef}>
      {/* Photo zone overlay */}
      {photoZoneStyle && (
        <div style={photoZoneStyle}>
          {/* Sample face avatar */}
          <div style={{
            width: '100%', height: '100%',
            background: 'linear-gradient(135deg, #2563EB, #0EA5E9)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: '2em',
          }}>
            👤
          </div>
        </div>
      )}
      {/* Name zone overlay */}
      {template.nameZoneEnabled !== false && (
        <div style={nameZoneStyle}>
          Jayesh Jain
        </div>
      )}
    </div>
  );
}

function PreviewModal({ template, onClose }: { template: any; onClose: () => void }) {
  return (
    <div className="fixed inset-0 bg-black/90 flex items-center justify-center z-[60] p-4 backdrop-blur-md">
      <button onClick={onClose} className="absolute top-4 right-4 text-white hover:text-primary transition-colors">
        <X size={32} />
      </button>
      <div className="max-w-4xl w-full max-h-[90vh] flex gap-6 items-start">
        {/* Template preview with zone overlay */}
        <div className="relative rounded-2xl overflow-hidden shadow-2xl bg-slate-900 aspect-[9/16] h-[75vh] flex-shrink-0"
          style={{ containerType: 'size' }}>
          {template.type === 'VIDEO' ? (
            <video src={template.videoUrl || template.imageUrl} controls autoPlay className="absolute inset-0 w-full h-full object-contain" />
          ) : (
            <img src={template.imageUrl} alt={template.nameEn} className="absolute inset-0 w-full h-full object-contain" />
          )}
          {/* Zone overlays on top of the image */}
          <ZoneOverlay template={template} />
        </div>

        {/* Metadata panel */}
        <div className="flex-1 text-white space-y-4 min-w-[240px]">
          <div>
            <h2 className="text-xl font-900">{template.nameEn || template.nameHi}</h2>
            <p className="text-white/50 text-sm">{template.nameHi} · {template.nameMr}</p>
          </div>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-white/50">Category</span>
              <span className="font-700">{template.category?.nameEn ?? '—'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-white/50">Type</span>
              <span className="font-700">{template.type}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-white/50">Creator</span>
              <span className="font-700">{template.creator?.name ?? 'Unknown'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-white/50">Premium</span>
              <span className="font-700">{template.isPremium ? '⭐ Yes' : 'No (Free)'}</span>
            </div>
          </div>
          <div className="border-t border-white/10 pt-3 space-y-1 text-xs">
            <div className="text-white/50 uppercase tracking-wider font-700 mb-2">Zone Config</div>
            <div className="flex justify-between">
              <span className="text-white/50">Photo Zone</span>
              <span className={template.photoZoneEnabled ? 'text-green-400' : 'text-white/30'}>
                {template.photoZoneEnabled ? `✓ ${template.photoZoneShape ?? 'circle'} @ ${Math.round((template.photoZoneX ?? 0.5) * 100)}%, ${Math.round((template.photoZoneY ?? 0.25) * 100)}%` : 'Disabled'}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-white/50">Name Zone</span>
              <span className={template.nameZoneEnabled !== false ? 'text-blue-400' : 'text-white/30'}>
                {template.nameZoneEnabled !== false ? `✓ @ ${Math.round((template.nameZoneX ?? 0.5) * 100)}%, ${Math.round((template.nameZoneY ?? 0.75) * 100)}%` : 'Disabled'}
              </span>
            </div>
          </div>
          {template.quoteHi && (
            <div className="border-t border-white/10 pt-3">
              <div className="text-white/50 text-xs uppercase tracking-wider mb-1">Quote (Hindi)</div>
              <p className="text-sm text-white/80 leading-relaxed">{template.quoteHi}</p>
            </div>
          )}
          <div className="bg-white/10 rounded-xl p-3 text-xs text-white/60">
            <p className="font-700 text-white/80 mb-1">👆 Zone Preview</p>
            <p>The overlays show exactly where the user's photo (👤) and name "Jayesh Jain" will appear. Verify positioning before approving.</p>
          </div>
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

function ReviewCard({ template, onApprove, onReject, onPreview, onToggleCoordinatorPick, isApproving, isRejecting }: {
  template: any;
  onApprove: () => void;
  onReject: () => void;
  onPreview: () => void;
  onToggleCoordinatorPick?: () => void;
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
        style={{ background: template.gradient || 'linear-gradient(135deg,#2563EB,#0EA5E9)' }}>
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
        {template.isCoordinatorPick && (
          <div className="absolute top-2 left-2 bg-amber-500 text-white text-[10px] font-800 px-2 py-0.5 rounded-md flex items-center gap-1 shadow">
            <Pin size={10} className="fill-white" /> Coordinator Pick
          </div>
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
            <button
              onClick={onToggleCoordinatorPick}
              className={`col-span-2 flex items-center justify-center gap-1.5 text-xs py-2 rounded-xl font-700 transition-colors ${
                template.isCoordinatorPick
                  ? 'bg-amber-100 text-amber-800 border border-amber-300 hover:bg-amber-200'
                  : 'btn-ghost border border-surface-border text-slate-700 hover:bg-amber-50'
              }`}
            >
              <Pin size={12} className={template.isCoordinatorPick ? 'fill-amber-600' : ''} />
              {template.isCoordinatorPick ? 'Pinned Pick' : 'Pin to Coordinator'}
            </button>
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
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'rejected' | 'coordinator'>('pending');
  const [approvingId, setApprovingId] = useState<string | null>(null);
  const [rejectingId, setRejectingId] = useState<string | null>(null);

  const { data, isLoading, refetch, isRefetching } = useQuery({
    queryKey: ['review-queue', activeTab],
    queryFn: async () => {
      if (activeTab === 'pending') return adminApi.getPendingTemplates({ page: 1, limit: 20 });
      if (activeTab === 'coordinator') {
        const res = await adminApi.getCoordinatorPicks();
        return { data: res, total: res.length };
      }
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

  const toggleCoordinatorMutation = useMutation({
    mutationFn: ({ id, isCoordinatorPick }: { id: string; isCoordinatorPick: boolean }) =>
      adminApi.setCoordinatorPick(id, isCoordinatorPick),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['review-queue'] });
      queryClient.invalidateQueries({ queryKey: ['admin-coordinator-picks'] });
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
    { key: 'coordinator', label: 'Coordinator Picks', color: 'text-amber-500' },
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
              onToggleCoordinatorPick={() => toggleCoordinatorMutation.mutate({
                id: template.id,
                isCoordinatorPick: !template.isCoordinatorPick,
              })}
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
