'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ShieldAlert, Download } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { downloadCsv } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';

const PAGE_SIZE = 50;

// Must match the `action` strings written by backend/src/modules/admin/admin.route.ts
const AUDIT_ACTIONS: { value: string; label: string }[] = [
  { value: 'approve_template', label: 'Approve Template' },
  { value: 'reject_template', label: 'Reject Template' },
  { value: 'feature_template', label: 'Feature Template' },
  { value: 'archive_template', label: 'Archive Template' },
  { value: 'coordinator_pick', label: 'Coordinator Pick' },
  { value: 'update_user', label: 'Update User' },
  { value: 'update_creator', label: 'Update Creator' },
  { value: 'update_config', label: 'Update Config' },
  { value: 'create_festival', label: 'Create Festival' },
  { value: 'update_festival', label: 'Update Festival' },
  { value: 'send_campaign', label: 'Send Campaign' },
];

export default function AuditLogPage() {
  const [page, setPage] = useState(1);
  const [filterAction, setFilterAction] = useState('');

  // Server-side filtering (?action=) and pagination (uses `total`)
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['admin-auditlogs', { page, filterAction }],
    queryFn: () => adminApi.getAuditLogs({ page, limit: PAGE_SIZE, action: filterAction || undefined }),
    staleTime: 30 * 1000,
    placeholderData: (prev) => prev,
  });

  const logs: any[] = data?.data ?? [];
  const total: number | undefined = typeof data?.total === 'number' ? data.total : undefined;
  const totalPages = total !== undefined ? Math.max(1, Math.ceil(total / PAGE_SIZE)) : undefined;
  // Fallback for older backends that don't return `total`
  const isLastPage = totalPages !== undefined ? page >= totalPages : logs.length < PAGE_SIZE;
  const filtered = logs;

  const exportCsv = () => downloadCsv(`audit-log-page-${page}`, logs, [
    { header: 'Timestamp', value: (l: any) => l.createdAt },
    { header: 'Action', value: (l: any) => l.action },
    { header: 'Admin ID', value: (l: any) => l.adminId },
    { header: 'Entity Type', value: (l: any) => l.entityType },
    { header: 'Entity ID', value: (l: any) => l.entityId },
    { header: 'Before', value: (l: any) => l.before },
    { header: 'After', value: (l: any) => l.after },
  ]);

  return (
    <div className="space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900">Audit Logs</h1>
          <p className="text-slate-500 text-xs mt-1">
            Track admin and manager actions, security events, and entity mutations
            {total !== undefined && ` (${total.toLocaleString('en-IN')} entries)`}
          </p>
        </div>
        <button
          onClick={exportCsv}
          disabled={logs.length === 0}
          title="Export the rows currently shown"
          className="btn-secondary text-xs flex items-center gap-1.5 self-start sm:self-auto disabled:opacity-50"
        >
          <Download size={13} /> Export Logs
        </button>
      </div>

      {isError && <QueryError error={error} onRetry={() => refetch()} />}

      {!isError && (
      <div className="bg-white rounded-xl border border-slate-200/80 shadow-sm overflow-hidden">
        {/* Filter bar */}
        <div className="p-3.5 border-b border-slate-200/80 flex flex-wrap gap-3 items-center bg-slate-50/50">
          <span className="flex items-center gap-1.5 text-xs font-semibold text-slate-700 shrink-0">
            <ShieldAlert size={14} className="text-primary" /> Filter:
          </span>
          <select
            value={filterAction}
            onChange={e => { setFilterAction(e.target.value); setPage(1); }}
            className="px-2.5 py-1 text-xs border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary bg-white text-slate-700"
          >
            <option value="">All Actions</option>
            {AUDIT_ACTIONS.map(a => <option key={a.value} value={a.value}>{a.label}</option>)}
          </select>
        </div>

        {/* Scrollable table */}
        <div className="overflow-x-auto">
          <table className="w-full data-table min-w-[600px]">
            <thead className="bg-slate-50 text-left border-b border-slate-200">
              <tr>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600 w-44">Timestamp</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600">Action</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600">Entity</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600 hidden md:table-cell">Changes</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i}>
                    <td colSpan={4}><div className="h-8 bg-slate-50 animate-pulse rounded" /></td>
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={4} className="text-center py-12 text-slate-400 text-xs">
                    <ShieldAlert size={24} className="mx-auto mb-2 opacity-40 text-slate-400" />
                    {filterAction ? 'No logs match this filter.' : 'No audit logs yet. Admin actions will appear here.'}
                  </td>
                </tr>
              ) : filtered.map((log: any) => (
                <tr key={log.id} className="border-t border-slate-100 hover:bg-slate-50/70 transition-colors">
                  <td className="py-2.5 px-4 text-xs text-slate-500 whitespace-nowrap tabular-nums">
                    {new Date(log.createdAt).toLocaleString('en-IN', {
                      day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'
                    })}
                  </td>
                  <td className="py-2.5 px-4">
                    <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full border ${
                      log.action?.includes('approve') ? 'bg-emerald-50 text-emerald-700 border-emerald-200' :
                      log.action?.includes('reject') ? 'bg-rose-50 text-rose-700 border-rose-200' :
                      log.action?.includes('update') || log.action?.includes('archive') ? 'bg-amber-50 text-amber-700 border-amber-200' :
                      'bg-slate-100 text-slate-700 border-slate-200'
                    }`}>
                      {log.action?.replace(/_/g, ' ')}
                    </span>
                  </td>
                  <td className="py-2.5 px-4 text-xs font-medium text-slate-700">
                    {log.entityType && (
                      <span>
                        <span className="text-slate-600">{log.entityType}</span>
                        {log.entityId && <span className="text-slate-400 font-mono text-[11px]"> #{log.entityId.slice(0, 8)}…</span>}
                      </span>
                    )}
                  </td>
                  <td className="py-2.5 px-4 text-xs text-slate-500 max-w-xs truncate hidden md:table-cell font-mono text-[11px]">
                    {log.after ? JSON.stringify(log.after).slice(0, 80) : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="p-3 border-t border-slate-200/80 flex items-center justify-between bg-slate-50/50">
          <div className="text-xs text-slate-500 font-medium">
            Page {page}{totalPages !== undefined && ` of ${totalPages}`}
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="btn-secondary text-xs py-1 px-2.5 disabled:opacity-40"
            >
              ← Prev
            </button>
            <button
              onClick={() => setPage(p => p + 1)}
              disabled={isLastPage}
              className="btn-secondary text-xs py-1 px-2.5 disabled:opacity-40"
            >
              Next →
            </button>
          </div>
        </div>
      </div>
      )}
    </div>
  );
}
