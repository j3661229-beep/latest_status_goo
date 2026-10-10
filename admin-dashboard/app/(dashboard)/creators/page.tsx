'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { BadgeCheck, Ban, Download, UserPlus, X, CheckCircle, AlertCircle } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { toast } from '@/lib/toast';
import { downloadCsv } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';
import { Pagination } from '@/components/Pagination';

const PAGE_SIZE = 20;

// ── Invite Creator Modal ──────────────────────────────────────────
function InviteModal({ onClose }: { onClose: () => void }) {
  const queryClient = useQueryClient();
  const [form, setForm] = useState({ email: '', name: '', displayName: '', bio: '' });
  const [success, setSuccess] = useState('');
  const [error, setError] = useState('');

  const inviteMutation = useMutation({
    mutationFn: () => adminApi.inviteCreator(form),
    onSuccess: (data) => {
      setSuccess(data.message || 'Creator invited! They can now sign in with Google using their email.');
      queryClient.invalidateQueries({ queryKey: ['admin-creators'] });
      setForm({ email: '', name: '', displayName: '', bio: '' });
    },
    onError: (err: any) => {
      setError(err?.response?.data?.error || err?.message || 'Failed to invite creator.');
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 backdrop-blur-xs p-4">
      <div className="bg-white rounded-xl shadow-lg border border-slate-200/80 w-full max-w-md p-6 relative animate-in fade-in zoom-in-95 duration-150">
        <button onClick={onClose} className="absolute top-4 right-4 text-slate-400 hover:text-slate-600 transition-colors">
          <X size={18} />
        </button>

        <div className="flex items-center gap-3 mb-5">
          <div className="w-9 h-9 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center shrink-0">
            <UserPlus size={16} />
          </div>
          <div>
            <h2 className="font-bold text-slate-900 text-base">Invite Creator</h2>
            <p className="text-slate-500 text-xs">They will sign in with Google using this email address</p>
          </div>
        </div>

        {success && (
          <div className="flex items-start gap-2 bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-lg px-3.5 py-2.5 mb-4 text-xs font-medium">
            <CheckCircle size={14} className="shrink-0 mt-0.5" />
            <span>{success}</span>
          </div>
        )}
        {error && (
          <div className="flex items-start gap-2 bg-rose-50 border border-rose-200 text-rose-700 rounded-lg px-3.5 py-2.5 mb-4 text-xs font-medium">
            <AlertCircle size={14} className="shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        <div className="space-y-3">
          <div>
            <label className="text-xs font-medium text-slate-700 mb-1 block">
              Gmail Address *
            </label>
            <input
              type="email"
              value={form.email}
              onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
              placeholder="creator@gmail.com"
              className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white"
            />
          </div>
          <div>
            <label className="text-xs font-medium text-slate-700 mb-1 block">
              Full Name *
            </label>
            <input
              type="text"
              value={form.name}
              onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
              placeholder="Rahul Sharma"
              className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white"
            />
          </div>
          <div>
            <label className="text-xs font-medium text-slate-700 mb-1 block">
              Display Name
            </label>
            <input
              type="text"
              value={form.displayName}
              onChange={e => setForm(f => ({ ...f, displayName: e.target.value }))}
              placeholder="Rahul S. (public name)"
              className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white"
            />
          </div>
          <div>
            <label className="text-xs font-medium text-slate-700 mb-1 block">
              Bio (optional)
            </label>
            <textarea
              value={form.bio}
              onChange={e => setForm(f => ({ ...f, bio: e.target.value }))}
              placeholder="Short bio about this creator…"
              rows={2}
              className="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white resize-none"
            />
          </div>
        </div>

        <div className="flex gap-2.5 mt-5">
          <button onClick={onClose} className="flex-1 btn-ghost text-xs py-2">Cancel</button>
          <button
            onClick={() => { setError(''); setSuccess(''); inviteMutation.mutate(); }}
            disabled={!form.email || !form.name || inviteMutation.isPending}
            className="flex-1 btn-primary text-xs py-2 flex items-center justify-center gap-1.5 disabled:opacity-50"
          >
            {inviteMutation.isPending ? (
              <div className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <UserPlus size={14} />
            )}
            {inviteMutation.isPending ? 'Inviting…' : 'Invite Creator'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Main Page ─────────────────────────────────────────────────────
export default function CreatorsPage() {
  const queryClient = useQueryClient();
  const [verifiedFilter, setVerifiedFilter] = useState('');
  const [suspendedFilter, setSuspendedFilter] = useState('');
  const [showInvite, setShowInvite] = useState(false);
  const [page, setPage] = useState(1);

  // Empty filters are omitted by adminApi (cleanParams), so "All" sends nothing.
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['admin-creators', { verifiedFilter, suspendedFilter, page }],
    queryFn: () => adminApi.getCreators({
      isVerified: verifiedFilter || undefined,
      isSuspended: suspendedFilter || undefined,
      page,
      limit: PAGE_SIZE,
    }),
    placeholderData: (prev) => prev,
  });

  const updateCreatorMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => adminApi.patchCreator(id, data),
    onError: (err) => toast.apiError(err, 'Failed to update creator'),
    onSuccess: () => {
      toast.success('Creator updated');
      queryClient.invalidateQueries({ queryKey: ['admin-creators'] });
    },
  });

  const exportCsv = () => downloadCsv(`creators-page-${page}`, creators, [
    { header: 'Name', value: (c: any) => c.user?.name },
    { header: 'Email', value: (c: any) => c.user?.email },
    { header: 'Display Name', value: (c: any) => c.displayName },
    { header: 'Total Uploads', value: (c: any) => c.totalUploads },
    { header: 'Approved', value: (c: any) => c.approvedCount },
    { header: 'Rejected', value: (c: any) => c.rejectedCount },
    { header: 'Approval Rate %', value: (c: any) => c.approvalRate },
    { header: 'Verified', value: (c: any) => (c.isVerified ? 'yes' : 'no') },
    { header: 'Suspended', value: (c: any) => (c.isSuspended ? 'yes' : 'no') },
    { header: 'Suspended Reason', value: (c: any) => c.suspendedReason },
  ]);

  const creators = data?.data || [];
  const total = data?.total || 0;

  return (
    <>
      {showInvite && <InviteModal onClose={() => setShowInvite(false)} />}

      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h1 className="text-xl md:text-2xl font-bold text-slate-900 tracking-tight">Creators</h1>
            <p className="text-slate-500 text-sm mt-0.5">
              Manage creator profiles, verification, and privileges ({total} total)
            </p>
          </div>
          <div className="flex items-center gap-2 self-start sm:self-auto">
            <button
              onClick={() => setShowInvite(true)}
              className="btn-primary flex items-center gap-1.5 text-xs py-1.5 px-3"
            >
              <UserPlus size={14} /> Invite Creator
            </button>
            <button
              onClick={exportCsv}
              disabled={creators.length === 0}
              title="Export the rows currently shown"
              className="btn-outline flex items-center gap-1.5 text-xs py-1.5 px-3 disabled:opacity-50"
            >
              <Download size={13} /> Export CSV
            </button>
          </div>
        </div>

        {/* Filter Bar */}
        <div className="flex flex-wrap gap-2.5 bg-white rounded-xl p-3 border border-slate-200/80 shadow-sm">
          <select
            value={verifiedFilter}
            onChange={e => { setVerifiedFilter(e.target.value); setPage(1); }}
            className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
          >
            <option value="">All Verification Status</option>
            <option value="true">Verified</option>
            <option value="false">Unverified</option>
          </select>
          <select
            value={suspendedFilter}
            onChange={e => { setSuspendedFilter(e.target.value); setPage(1); }}
            className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
          >
            <option value="">All Account Status</option>
            <option value="false">Active Only</option>
            <option value="true">Suspended</option>
          </select>
        </div>

        {isError && <QueryError error={error} onRetry={() => refetch()} />}

        {/* Table */}
        {!isError && (
        <div className="bg-white rounded-xl border border-slate-200/80 shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full data-table min-w-[640px]">
              <thead>
                <tr>
                  <th className="text-left">Creator Profile</th>
                  <th className="text-right">Templates</th>
                  <th className="text-right">Approval Rate</th>
                  <th className="text-left">Verification</th>
                  <th className="text-left">Status</th>
                  <th className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {isLoading ? (
                  Array.from({ length: 4 }).map((_, i) => (
                    <tr key={i}>
                      <td colSpan={6}>
                        <div className="h-10 bg-slate-50 animate-pulse rounded" />
                      </td>
                    </tr>
                  ))
                ) : creators.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-12">
                      <div className="text-3xl mb-2">👤</div>
                      <p className="font-semibold text-slate-700 text-sm">
                        {verifiedFilter || suspendedFilter ? 'No creators match these filters.' : 'No creators yet.'}
                      </p>
                      <button
                        onClick={() => setShowInvite(true)}
                        className="mt-3 btn-primary text-xs px-3.5 py-1.5"
                      >
                        Invite your first creator →
                      </button>
                    </td>
                  </tr>
                ) : (
                  creators.map((c: any) => (
                    <tr key={c.id} className={c.isSuspended ? 'bg-rose-50/40' : ''}>
                      <td>
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-700 font-semibold text-xs shrink-0">
                            {c.user?.name?.[0]?.toUpperCase() || 'C'}
                          </div>
                          <div className="min-w-0">
                            <div className="font-semibold text-slate-800 text-sm flex items-center gap-1">
                              <span className="truncate">{c.user?.name}</span>
                              {c.isVerified && <BadgeCheck size={14} className="text-blue-600 shrink-0" />}
                            </div>
                            <div className="text-xs text-slate-400 truncate">{c.user?.email}</div>
                          </div>
                        </div>
                      </td>
                      <td className="text-right">
                        <div className="text-xs font-semibold text-slate-800 tabular-nums">{c.totalUploads} uploads</div>
                        <div className="text-[11px] text-slate-400 tabular-nums">{c.approvedCount} approved</div>
                      </td>
                      <td className="text-right">
                        <span
                          className={`text-xs font-semibold tabular-nums ${
                            c.approvalRate >= 80
                              ? 'text-emerald-600'
                              : c.approvalRate >= 50
                              ? 'text-amber-600'
                              : 'text-rose-600'
                          }`}
                        >
                          {Number(c.approvalRate ?? 0).toFixed(1)}%
                        </span>
                      </td>
                      <td>
                        {c.isVerified ? (
                          <span className="badge-approved inline-flex items-center gap-1">
                            <BadgeCheck size={11} /> Verified
                          </span>
                        ) : (
                          <span className="badge-draft inline-flex items-center gap-1">
                            Unverified
                          </span>
                        )}
                      </td>
                      <td>
                        {c.isSuspended ? (
                          <span className="badge-rejected inline-block">
                            Suspended
                          </span>
                        ) : (
                          <span className="text-xs text-slate-600 font-medium">Active</span>
                        )}
                      </td>
                      <td className="text-right">
                        <div className="flex justify-end gap-1">
                          <button
                            onClick={() => {
                              const msg = c.isVerified ? 'Remove verification?' : 'Verify this creator?';
                              if (confirm(msg)) {
                                updateCreatorMutation.mutate({ id: c.id, data: { isVerified: !c.isVerified } });
                              }
                            }}
                            disabled={updateCreatorMutation.isPending}
                            className={`p-1.5 rounded-md hover:bg-slate-100 transition-colors disabled:opacity-30 ${
                              c.isVerified ? 'text-blue-600 hover:text-rose-600' : 'text-slate-400 hover:text-blue-600'
                            }`}
                            title={c.isVerified ? 'Remove Verification' : 'Verify Creator'}
                          >
                            {updateCreatorMutation.isPending && updateCreatorMutation.variables?.id === c.id ? (
                                <div className="w-3.5 h-3.5 border-2 border-slate-300 border-t-slate-600 rounded-full animate-spin" />
                            ) : (
                                <BadgeCheck size={14} />
                            )}
                          </button>
                          <button
                            onClick={() => {
                              if (c.isSuspended) {
                                if (confirm('Unsuspend this creator?')) {
                                  updateCreatorMutation.mutate({
                                    id: c.id,
                                    data: { isSuspended: false, suspendedReason: null },
                                  });
                                }
                              } else {
                                const reason = prompt('Reason for suspension (optional):');
                                if (reason !== null) {
                                  updateCreatorMutation.mutate({
                                    id: c.id,
                                    data: { isSuspended: true, suspendedReason: reason },
                                  });
                                }
                              }
                            }}
                            className={`p-1.5 rounded-md hover:bg-slate-100 transition-colors ${
                              c.isSuspended ? 'text-rose-600 hover:text-emerald-600' : 'text-slate-400 hover:text-rose-600'
                            }`}
                            title={c.isSuspended ? 'Unsuspend Creator' : 'Suspend Creator'}
                          >
                            <Ban size={14} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <Pagination page={page} limit={PAGE_SIZE} total={total} onChange={setPage} />
        </div>
        )}
      </div>
    </>
  );
}
