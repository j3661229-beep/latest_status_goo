'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ShieldAlert, Download } from 'lucide-react';
import { adminApi } from '@/lib/api';

export default function AuditLogPage() {
  const [page, setPage] = useState(1);
  const [filterAction, setFilterAction] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['admin-auditlogs', { page, filterAction }],
    queryFn: () => adminApi.getAuditLogs({ page, limit: 50 }),
    staleTime: 30 * 1000,
  });

  const logs: any[] = data?.data ?? [];
  const isLastPage = logs.length < 50;

  // Client-side filter since backend doesn't support action filter yet
  const filtered = filterAction
    ? logs.filter(l => l.action?.toLowerCase().includes(filterAction.toLowerCase()))
    : logs;

  return (
    <div className="space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-900 text-slate-800">Audit Logs</h1>
          <p className="text-muted text-sm mt-1">Track admin and manager actions on the platform</p>
        </div>
        <button className="btn-ghost flex items-center gap-2 text-sm self-start sm:self-auto">
          <Download size={14} /> Export Logs
        </button>
      </div>

      <div className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden">
        {/* Filter bar */}
        <div className="p-4 border-b border-surface-border flex flex-wrap gap-3 items-center">
          <span className="flex items-center gap-2 text-sm font-700 text-slate-700 shrink-0">
            <ShieldAlert size={16} className="text-primary" /> Filter:
          </span>
          <select
            value={filterAction}
            onChange={e => setFilterAction(e.target.value)}
            className="px-3 py-1.5 text-sm border border-surface-border rounded-lg focus:outline-none focus:border-primary bg-surface"
          >
            <option value="">All Actions</option>
            <option value="approve">Approve Template</option>
            <option value="reject">Reject Template</option>
            <option value="suspend">Suspend Creator</option>
            <option value="ban">Ban User</option>
            <option value="config">Update Config</option>
          </select>
          {filtered.length !== logs.length && (
            <span className="text-xs text-muted">{filtered.length} of {logs.length} shown</span>
          )}
        </div>

        {/* Scrollable table */}
        <div className="overflow-x-auto">
          <table className="w-full data-table min-w-[600px]">
            <thead className="bg-surface">
              <tr>
                <th className="text-left w-44">Timestamp</th>
                <th className="text-left">Action</th>
                <th className="text-left">Entity</th>
                <th className="text-left hidden md:table-cell">Changes</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i}>
                    <td colSpan={4}><div className="h-10 bg-slate-50 animate-pulse rounded" /></td>
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={4} className="text-center py-12 text-muted">
                    <ShieldAlert size={28} className="mx-auto mb-2 opacity-30" />
                    {filterAction ? 'No logs match this filter.' : 'No audit logs yet. Admin actions will appear here.'}
                  </td>
                </tr>
              ) : filtered.map((log: any) => (
                <tr key={log.id}>
                  <td className="text-xs text-slate-600 whitespace-nowrap">
                    {new Date(log.createdAt).toLocaleString('en-IN', {
                      day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'
                    })}
                  </td>
                  <td>
                    <span className={`text-[11px] font-800 px-2 py-0.5 rounded uppercase ${
                      log.action?.includes('approve') ? 'bg-green-100 text-green-700' :
                      log.action?.includes('reject') ? 'bg-red-100 text-red-700' :
                      log.action?.includes('suspend') || log.action?.includes('ban') ? 'bg-orange-100 text-orange-700' :
                      'bg-slate-100 text-slate-700'
                    }`}>
                      {log.action?.replace(/_/g, ' ')}
                    </span>
                  </td>
                  <td className="text-xs font-600 text-slate-700">
                    {log.entityType && (
                      <span>
                        <span className="text-muted">{log.entityType}</span>
                        {log.entityId && <span className="text-muted opacity-50"> #{log.entityId.slice(0, 8)}…</span>}
                      </span>
                    )}
                  </td>
                  <td className="text-xs text-muted max-w-xs truncate hidden md:table-cell">
                    {log.after ? JSON.stringify(log.after).slice(0, 80) : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="p-4 border-t border-surface-border flex items-center justify-between">
          <div className="text-xs text-muted">Page {page}</div>
          <div className="flex gap-2">
            <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
              className="px-3 py-1.5 text-sm border rounded-lg hover:bg-surface disabled:opacity-40 text-slate-700">
              ← Prev
            </button>
            <button onClick={() => setPage(p => p + 1)} disabled={isLastPage}
              className="px-3 py-1.5 text-sm border rounded-lg hover:bg-surface disabled:opacity-40 text-slate-700">
              Next →
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
