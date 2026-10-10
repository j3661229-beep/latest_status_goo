'use client';

import { useEffect, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, Download, Edit2, Ban, CheckCircle, Shield } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { downloadCsv, getErrorMessage } from '@/lib/utils';
import { useDebounce } from '@/lib/hooks';
import { getSessionUser } from '@/lib/auth';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';
import { Pagination } from '@/components/Pagination';

const PAGE_SIZE = 20;
const ROLES = ['USER', 'CREATOR', 'MANAGER', 'SUPER_ADMIN'] as const;

export default function UsersPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [planFilter, setPlanFilter] = useState('');
  const [page, setPage] = useState(1);
  const debouncedSearch = useDebounce(search.trim(), 300);

  // Only SUPER_ADMIN may change roles (backend returns 403 otherwise).
  const [session, setSession] = useState<{ userId: string; role: string } | null>(null);
  useEffect(() => { setSession(getSessionUser()); }, []);
  const canChangeRole = session?.role === 'SUPER_ADMIN';

  // Reset to first page whenever filters change
  useEffect(() => { setPage(1); }, [debouncedSearch, roleFilter, planFilter]);

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['admin-users', { search: debouncedSearch, roleFilter, planFilter, page }],
    queryFn: () => adminApi.getUsers({
      search: debouncedSearch || undefined,
      role: roleFilter || undefined,
      plan: planFilter || undefined,
      page,
      limit: PAGE_SIZE,
    }),
    placeholderData: (prev) => prev,
  });

  const updateUserMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: any }) => adminApi.patchUser(id, data),
    onError: (err: any) => {
      if (err?.response?.status === 403) {
        toast.error(getErrorMessage(err, 'You do not have permission to make this change.'));
      } else {
        toast.apiError(err, 'Failed to update user');
      }
    },
    onSuccess: () => {
      toast.success('User updated');
      queryClient.invalidateQueries({ queryKey: ['admin-users'] });
    },
  });

  const users = data?.data || [];
  const total = data?.total || 0;

  const exportCsv = () => downloadCsv(`users-page-${page}`, users, [
    { header: 'Name', value: (u: any) => u.name },
    { header: 'Email', value: (u: any) => u.email },
    { header: 'Role', value: (u: any) => u.role },
    { header: 'Plan', value: (u: any) => u.plan },
    { header: 'Plan Expires', value: (u: any) => u.planExpiresAt },
    { header: 'Language', value: (u: any) => u.language },
    { header: 'Active', value: (u: any) => (u.isActive ? 'yes' : 'no') },
    { header: 'Shares', value: (u: any) => u.totalShares },
    { header: 'Saves', value: (u: any) => u.totalSaves },
    { header: 'Last Active', value: (u: any) => u.lastActiveAt },
    { header: 'Joined', value: (u: any) => u.createdAt },
  ]);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900 tracking-tight">Users</h1>
          <p className="text-slate-500 text-sm mt-0.5">Manage app users, roles, and subscriptions ({total} total)</p>
        </div>
        <button
          onClick={exportCsv}
          disabled={users.length === 0}
          title="Export the rows currently shown"
          className="btn-outline flex items-center gap-2 text-xs py-1.5 px-3 self-start sm:self-auto disabled:opacity-50"
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
            onChange={e => setSearch(e.target.value)}
            placeholder="Search by name or email..."
            className="w-full pl-9 pr-3.5 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white placeholder:text-slate-400"
          />
        </div>
        <select
          value={roleFilter}
          onChange={e => setRoleFilter(e.target.value)}
          className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
        >
          <option value="">All Roles</option>
          <option value="USER">User</option>
          <option value="CREATOR">Creator</option>
          <option value="MANAGER">Manager</option>
          <option value="SUPER_ADMIN">Super Admin</option>
        </select>
        <select
          value={planFilter}
          onChange={e => setPlanFilter(e.target.value)}
          className="px-3 py-1.5 text-sm border border-slate-200 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white text-slate-700"
        >
          <option value="">All Plans</option>
          <option value="FREE">Free</option>
          <option value="PREMIUM">Premium</option>
          <option value="ANNUAL">Annual</option>
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
                <th className="text-left">User</th>
                <th className="text-left">Role</th>
                <th className="text-left">Plan</th>
                <th className="text-left">Status</th>
                <th className="text-right">Joined</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr><td colSpan={6} className="text-center py-8 text-slate-400 text-xs">Loading users...</td></tr>
              ) : users.length === 0 ? (
                <tr><td colSpan={6} className="text-center py-8 text-slate-400 text-xs">No users found</td></tr>
              ) : users.map((u: any) => (
                <tr key={u.id} className={!u.isActive ? 'opacity-60 bg-slate-50/50' : ''}>
                  <td>
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-blue-50 border border-blue-100 flex items-center justify-center text-blue-700 font-semibold text-xs shrink-0">
                        {u.name?.[0]?.toUpperCase() || 'U'}
                      </div>
                      <div className="min-w-0">
                        <div className="font-semibold text-slate-800 text-sm truncate">{u.name}</div>
                        <div className="text-xs text-slate-400 truncate">{u.email}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    {canChangeRole && u.id !== session?.userId ? (
                      <select
                        value={u.role}
                        disabled={updateUserMutation.isPending && updateUserMutation.variables?.id === u.id}
                        onChange={e => {
                          const role = e.target.value;
                          if (role !== u.role && confirm(`Change ${u.name || u.email}'s role from ${u.role} to ${role}?`)) {
                            updateUserMutation.mutate({ id: u.id, data: { role } });
                          }
                        }}
                        className="text-xs font-semibold px-2 py-1 border border-slate-200 rounded-md bg-white text-slate-700 focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 disabled:opacity-50"
                        aria-label="Change role"
                      >
                        {ROLES.map(r => <option key={r} value={r}>{r}</option>)}
                      </select>
                    ) : (
                    <span className={`text-xs font-semibold px-2 py-0.5 rounded-md ${
                      u.role === 'SUPER_ADMIN' ? 'bg-blue-50 text-blue-700 border border-blue-200/60' :
                      u.role === 'CREATOR' ? 'bg-purple-50 text-purple-700 border border-purple-200/60' :
                      'bg-slate-100 text-slate-600 border border-slate-200'
                    }`}>
                      {u.role}
                    </span>
                    )}
                  </td>
                  <td>
                    <div className="flex items-center gap-1.5">
                      {u.plan !== 'FREE' && <Shield size={12} className="text-amber-500" />}
                      <span className="text-xs font-medium text-slate-700">{u.plan}</span>
                    </div>
                  </td>
                  <td>
                    {u.isActive ? (
                      <span className="badge-approved inline-flex items-center gap-1"><CheckCircle size={11} /> Active</span>
                    ) : (
                      <span className="badge-rejected inline-flex items-center gap-1"><Ban size={11} /> Banned</span>
                    )}
                  </td>
                  <td className="text-right text-xs text-slate-500 tabular-nums">{new Date(u.createdAt).toLocaleDateString()}</td>
                  <td className="text-right">
                    <div className="flex justify-end gap-1">
                      <button 
                        onClick={() => {
                          const newPlan = window.prompt(`Update plan for ${u.name} (FREE/PREMIUM/ANNUAL):`, u.plan);
                          if(newPlan && ['FREE', 'PREMIUM', 'ANNUAL'].includes(newPlan.toUpperCase())) {
                            updateUserMutation.mutate({ id: u.id, data: { plan: newPlan.toUpperCase() } });
                          }
                        }}
                        className="p-1.5 rounded-md hover:bg-slate-100 text-slate-400 hover:text-blue-600 transition-colors" title="Edit Plan">
                        <Edit2 size={13} />
                      </button>
                      <button 
                        onClick={() => {
                          if(confirm(`Are you sure you want to ${u.isActive ? 'ban' : 'unban'} ${u.name}?`)) {
                            updateUserMutation.mutate({ id: u.id, data: { isActive: !u.isActive } });
                          }
                        }}
                        disabled={updateUserMutation.isPending}
                        className={`p-1.5 rounded-md hover:bg-slate-100 transition-colors disabled:opacity-30 ${u.isActive ? 'text-slate-400 hover:text-rose-600' : 'text-rose-600 hover:text-emerald-600'}`} 
                        title={u.isActive ? "Ban User" : "Unban User"}
                      >
                        {updateUserMutation.isPending && updateUserMutation.variables?.id === u.id ? (
                          <div className="w-3.5 h-3.5 border-2 border-slate-300 border-t-slate-600 rounded-full animate-spin" />
                        ) : (
                          <Ban size={13} />
                        )}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <Pagination page={page} limit={PAGE_SIZE} total={total} onChange={setPage} />
      </div>
      )}
    </div>
  );
}
