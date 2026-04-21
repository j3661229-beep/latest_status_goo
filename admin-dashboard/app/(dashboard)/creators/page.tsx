'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { BadgeCheck, Ban, Download, UserPlus, X, CheckCircle, AlertCircle } from 'lucide-react';
import { adminApi } from '@/lib/api';

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
      setError(err?.response?.data?.error || 'Failed to invite creator.');
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div className="bg-white rounded-3xl shadow-2xl w-full max-w-md p-6 relative animate-in fade-in zoom-in-95 duration-200">
        <button onClick={onClose} className="absolute top-4 right-4 text-muted hover:text-slate-700 transition-colors">
          <X size={20} />
        </button>

        <div className="flex items-center gap-3 mb-5">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <UserPlus size={18} className="text-primary" />
          </div>
          <div>
            <h2 className="font-900 text-slate-800 text-lg">Invite Creator</h2>
            <p className="text-muted text-xs">They'll sign in with Google using this email</p>
          </div>
        </div>

        {success && (
          <div className="flex items-start gap-2 bg-green-50 border border-green-200 text-green-700 rounded-2xl px-4 py-3 mb-4 text-sm">
            <CheckCircle size={15} className="shrink-0 mt-0.5" />
            <span>{success}</span>
          </div>
        )}
        {error && (
          <div className="flex items-start gap-2 bg-red-50 border border-red-200 text-red-700 rounded-2xl px-4 py-3 mb-4 text-sm">
            <AlertCircle size={15} className="shrink-0 mt-0.5" />
            <span>{error}</span>
          </div>
        )}

        <div className="space-y-3">
          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-1.5 block">
              Gmail Address *
            </label>
            <input
              type="email"
              value={form.email}
              onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
              placeholder="creator@gmail.com"
              className="w-full border border-surface-border rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary bg-surface"
            />
          </div>
          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-1.5 block">
              Full Name *
            </label>
            <input
              type="text"
              value={form.name}
              onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
              placeholder="Rahul Sharma"
              className="w-full border border-surface-border rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary bg-surface"
            />
          </div>
          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-1.5 block">
              Display Name
            </label>
            <input
              type="text"
              value={form.displayName}
              onChange={e => setForm(f => ({ ...f, displayName: e.target.value }))}
              placeholder="Rahul S. (public name)"
              className="w-full border border-surface-border rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary bg-surface"
            />
          </div>
          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-1.5 block">
              Bio (optional)
            </label>
            <textarea
              value={form.bio}
              onChange={e => setForm(f => ({ ...f, bio: e.target.value }))}
              placeholder="Short bio about this creator…"
              rows={2}
              className="w-full border border-surface-border rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary bg-surface resize-none"
            />
          </div>
        </div>

        <div className="flex gap-3 mt-5">
          <button onClick={onClose} className="flex-1 btn-ghost text-sm">Cancel</button>
          <button
            onClick={() => { setError(''); setSuccess(''); inviteMutation.mutate(); }}
            disabled={!form.email || !form.name || inviteMutation.isPending}
            className="flex-1 btn-primary text-sm flex items-center justify-center gap-2 disabled:opacity-50"
          >
            {inviteMutation.isPending ? (
              <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
            ) : (
              <UserPlus size={15} />
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

  const { data, isLoading } = useQuery({
    queryKey: ['admin-creators', { verifiedFilter, suspendedFilter }],
    queryFn: () => adminApi.getCreators({ isVerified: verifiedFilter, isSuspended: suspendedFilter }),
  });

  const updateCreatorMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => adminApi.patchCreator(id, data),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-creators'] }),
  });

  const creators = data?.data || [];
  const total = data?.total || 0;

  return (
    <>
      {showInvite && <InviteModal onClose={() => setShowInvite(false)} />}

      <div className="space-y-5">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h1 className="text-xl md:text-2xl font-900 text-slate-800">Creators</h1>
            <p className="text-muted text-sm mt-1">
              Manage creator profiles, verification, and privileges ({total} total)
            </p>
          </div>
          <div className="flex items-center gap-2 self-start sm:self-auto">
            <button
              onClick={() => setShowInvite(true)}
              className="btn-primary flex items-center gap-2 text-sm"
            >
              <UserPlus size={15} /> Invite Creator
            </button>
            <button className="btn-ghost flex items-center gap-2 text-sm">
              <Download size={14} /> Export CSV
            </button>
          </div>
        </div>

        {/* Filter Bar */}
        <div className="flex flex-wrap gap-2 bg-white rounded-2xl p-3 md:p-4 border border-surface-border shadow-card">
          <select
            value={verifiedFilter}
            onChange={e => setVerifiedFilter(e.target.value)}
            className="px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700"
          >
            <option value="">All Verification Status</option>
            <option value="true">Verified</option>
            <option value="false">Unverified</option>
          </select>
          <select
            value={suspendedFilter}
            onChange={e => setSuspendedFilter(e.target.value)}
            className="px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700"
          >
            <option value="">All Account Status</option>
            <option value="false">Active Only</option>
            <option value="true">Suspended</option>
          </select>
        </div>

        {/* Table */}
        <div className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full data-table min-w-[640px]">
              <thead className="bg-surface">
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
                        <div className="h-12 bg-slate-50 animate-pulse rounded" />
                      </td>
                    </tr>
                  ))
                ) : creators.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-12">
                      <div className="text-3xl mb-2">👤</div>
                      <p className="font-700 text-slate-600 text-sm">No creators yet.</p>
                      <button
                        onClick={() => setShowInvite(true)}
                        className="mt-3 btn-primary text-xs px-4"
                      >
                        Invite your first creator →
                      </button>
                    </td>
                  </tr>
                ) : (
                  creators.map((c: any) => (
                    <tr key={c.id} className={c.isSuspended ? 'bg-red-50/50' : ''}>
                      <td>
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-full bg-secondary/10 flex items-center justify-center text-secondary font-800 shrink-0">
                            {c.user?.name?.[0]?.toUpperCase() || 'C'}
                          </div>
                          <div>
                            <div className="font-700 text-slate-800 text-sm flex items-center gap-1">
                              {c.user?.name}
                              {c.isVerified && <BadgeCheck size={14} className="text-success" />}
                            </div>
                            <div className="text-xs text-muted">{c.user?.email}</div>
                          </div>
                        </div>
                      </td>
                      <td className="text-right">
                        <div className="text-sm font-700 text-slate-800">{c.totalUploads} uploads</div>
                        <div className="text-xs text-muted">{c.approvedCount} approved</div>
                      </td>
                      <td className="text-right">
                        <span
                          className={`text-sm font-800 ${
                            c.approvalRate >= 80
                              ? 'text-success'
                              : c.approvalRate >= 50
                              ? 'text-amber-500'
                              : 'text-danger'
                          }`}
                        >
                          {c.approvalRate.toFixed(1)}%
                        </span>
                      </td>
                      <td>
                        {c.isVerified ? (
                          <span className="text-xs text-success font-700 flex items-center gap-1 bg-green-50 px-2 py-1 rounded w-fit">
                            <BadgeCheck size={12} /> Verified
                          </span>
                        ) : (
                          <span className="text-xs text-slate-500 font-700 flex items-center gap-1 bg-slate-100 px-2 py-1 rounded w-fit">
                            Unverified
                          </span>
                        )}
                      </td>
                      <td>
                        {c.isSuspended ? (
                          <span className="text-xs text-danger font-700 bg-red-100 px-2 py-1 rounded w-fit inline-block">
                            Suspended
                          </span>
                        ) : (
                          <span className="text-xs text-slate-600 font-600">Active</span>
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
                            className={`p-1.5 rounded-lg hover:bg-surface transition-colors disabled:opacity-30 ${
                              c.isVerified ? 'text-success hover:text-danger' : 'text-muted hover:text-success'
                            }`}
                            title={c.isVerified ? 'Remove Verification' : 'Verify Creator'}
                          >
                            {updateCreatorMutation.isPending && updateCreatorMutation.variables?.id === c.id ? (
                                <div className="w-4 h-4 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
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
                            className={`p-1.5 rounded-lg hover:bg-surface transition-colors ${
                              c.isSuspended ? 'text-danger hover:text-success' : 'text-muted hover:text-danger'
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
        </div>
      </div>
    </>
  );
}
