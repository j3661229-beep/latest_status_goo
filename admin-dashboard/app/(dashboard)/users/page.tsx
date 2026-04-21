'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Search, Download, Edit2, Ban, CheckCircle, Shield } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatRelativeTime } from '@/lib/utils';

export default function UsersPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [planFilter, setPlanFilter] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['admin-users', { search, roleFilter, planFilter }],
    queryFn: () => adminApi.getUsers({ search, role: roleFilter, plan: planFilter }),
  });

  const updateUserMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: any }) => adminApi.patchUser(id, data),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin-users'] }),
  });

  const users = data?.data || [];
  const total = data?.total || 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-900 text-slate-800">Users</h1>
          <p className="text-muted text-sm mt-1">Manage app users, roles, and subscriptions ({total} total)</p>
        </div>
        <button className="btn-ghost flex items-center gap-2 text-sm">
          <Download size={14} /> Export CSV
        </button>
      </div>

      {/* Filter Bar */}
      <div className="flex gap-3 bg-white rounded-2xl p-4 border border-surface-border shadow-card">
        <div className="relative flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search by name or email..."
            className="w-full pl-9 pr-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface"
          />
        </div>
        <select value={roleFilter} onChange={e => setRoleFilter(e.target.value)}
          className="px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700">
          <option value="">All Roles</option>
          <option value="USER">User</option>
          <option value="CREATOR">Creator</option>
          <option value="MANAGER">Manager</option>
          <option value="SUPER_ADMIN">Super Admin</option>
        </select>
        <select value={planFilter} onChange={e => setPlanFilter(e.target.value)}
          className="px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-surface text-slate-700">
          <option value="">All Plans</option>
          <option value="FREE">Free</option>
          <option value="PREMIUM">Premium</option>
          <option value="ANNUAL">Annual</option>
        </select>
      </div>

      {/* Data Table */}
      <div className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden">
        <table className="w-full data-table">
          <thead className="bg-surface">
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
              <tr><td colSpan={6} className="text-center py-8 text-muted">Loading...</td></tr>
            ) : users.length === 0 ? (
              <tr><td colSpan={6} className="text-center py-8 text-muted">No users found</td></tr>
            ) : users.map((u: any) => (
              <tr key={u.id} className={!u.isActive ? 'opacity-60' : ''}>
                <td>
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-800 shrink-0">
                      {u.name?.[0]?.toUpperCase() || 'U'}
                    </div>
                    <div>
                      <div className="font-700 text-slate-800 text-sm">{u.name}</div>
                      <div className="text-xs text-muted">{u.email}</div>
                    </div>
                  </div>
                </td>
                <td>
                  <span className={`text-xs font-700 px-2 py-1 rounded-md ${
                    u.role === 'SUPER_ADMIN' ? 'bg-purple-100 text-purple-700' :
                    u.role === 'CREATOR' ? 'bg-amber-100 text-amber-700' :
                    'bg-slate-100 text-slate-600'
                  }`}>
                    {u.role}
                  </span>
                </td>
                <td>
                  <div className="flex items-center gap-1.5">
                    {u.plan !== 'FREE' && <Shield size={12} className="text-success" />}
                    <span className="text-sm font-600 text-slate-700">{u.plan}</span>
                  </div>
                </td>
                <td>
                  {u.isActive ? (
                    <span className="text-xs text-success font-700 flex items-center gap-1"><CheckCircle size={12} /> Active</span>
                  ) : (
                    <span className="text-xs text-danger font-700 flex items-center gap-1"><Ban size={12} /> Banned</span>
                  )}
                </td>
                <td className="text-right text-sm text-slate-600">{new Date(u.createdAt).toLocaleDateString()}</td>
                <td className="text-right">
                  <div className="flex justify-end gap-1">
                    <button 
                      onClick={() => {
                        const newPlan = window.prompt(`Update plan for ${u.name} (FREE/PREMIUM/ANNUAL):`, u.plan);
                        if(newPlan && ['FREE', 'PREMIUM', 'ANNUAL'].includes(newPlan.toUpperCase())) {
                          updateUserMutation.mutate({ id: u.id, data: { plan: newPlan.toUpperCase() } });
                        }
                      }}
                      className="p-1.5 rounded-lg hover:bg-surface text-muted hover:text-primary transition-colors" title="Edit Plan">
                      <Edit2 size={13} />
                    </button>
                    <button 
                      onClick={() => {
                        if(confirm(`Are you sure you want to ${u.isActive ? 'ban' : 'unban'} ${u.name}?`)) {
                          updateUserMutation.mutate({ id: u.id, data: { isActive: !u.isActive } });
                        }
                      }}
                      className={`p-1.5 rounded-lg hover:bg-surface transition-colors ${u.isActive ? 'text-muted hover:text-danger' : 'text-danger hover:text-success'}`} 
                      title={u.isActive ? "Ban User" : "Unban User"}
                    >
                      <Ban size={13} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
