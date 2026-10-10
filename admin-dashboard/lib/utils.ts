import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** All money amounts from the backend are integers in paise (₹1 = 100 paise). */
export function formatCurrency(paiseAmount: number): string {
  const rupees = (Number(paiseAmount) || 0) / 100;
  return `₹${rupees.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
}

export function formatNumber(n: number): string {
  if (n >= 100_000) return `${(n / 100_000).toFixed(1)}L`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return n.toString();
}

export function formatRelativeTime(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const diffMs = Date.now() - d.getTime();
  const diffMins = Math.floor(diffMs / 60_000);
  const diffHours = Math.floor(diffMs / 3_600_000);
  const diffDays = Math.floor(diffMs / 86_400_000);

  if (diffMins < 1) return 'just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  return `${diffDays}d ago`;
}

export function getStatusBadgeClass(status: string): string {
  const map: Record<string, string> = {
    APPROVED: 'badge-approved',
    PENDING: 'badge-pending',
    REJECTED: 'badge-rejected',
    DRAFT: 'badge-draft',
    ARCHIVED: 'badge-draft',
  };
  return map[status] ?? 'badge-draft';
}

/** Extract the most useful human-readable message from an axios/unknown error. */
export function getErrorMessage(err: unknown, fallback = 'Something went wrong'): string {
  const e = err as any;
  return e?.response?.data?.error || e?.response?.data?.message || e?.message || fallback;
}

function csvCell(value: unknown): string {
  if (value === null || value === undefined) return '';
  const s = value instanceof Date ? value.toISOString() : typeof value === 'object' ? JSON.stringify(value) : String(value);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/**
 * Client-side CSV export of the currently loaded rows.
 * `columns` maps header label → accessor.
 */
export function downloadCsv<T>(
  filename: string,
  rows: T[],
  columns: { header: string; value: (row: T) => unknown }[],
) {
  const lines = [
    columns.map(c => csvCell(c.header)).join(','),
    ...rows.map(r => columns.map(c => csvCell(c.value(r))).join(',')),
  ];
  // BOM so Excel opens UTF-8 (Hindi/Marathi) correctly
  const blob = new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename.endsWith('.csv') ? filename : `${filename}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
