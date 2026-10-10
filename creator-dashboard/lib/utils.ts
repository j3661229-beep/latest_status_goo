// lib/utils.ts — shared helpers for Creator Studio

/** Prefer the backend's `{ error }` message over axios' generic "Request failed with status code …". */
export function getErrorMessage(err: unknown, fallback = 'Something went wrong'): string {
  const e = err as any;
  return e?.response?.data?.error || e?.response?.data?.message || e?.message || fallback;
}

/** Single source of truth for template status badges. */
export const STATUS_CONFIG: Record<string, { label: string; cls: string }> = {
  DRAFT: { label: 'Draft', cls: 'badge-draft' },
  PENDING: { label: 'Pending review', cls: 'badge-pending' },
  APPROVED: { label: 'Live', cls: 'badge-approved' },
  REJECTED: { label: 'Rejected', cls: 'badge-rejected' },
  ARCHIVED: { label: 'Archived', cls: 'badge-draft' },
};

export function getStatusConfig(status: string) {
  return STATUS_CONFIG[status] ?? STATUS_CONFIG.DRAFT;
}

export function formatNumber(n: number | null | undefined): string {
  const v = n ?? 0;
  if (v >= 100_000) return `${(v / 100_000).toFixed(1)}L`;
  if (v >= 1_000) return `${(v / 1_000).toFixed(1)}K`;
  return String(v);
}

/** Client-side CSV download of already-loaded rows. */
export function downloadCsv(filename: string, rows: Record<string, unknown>[], columns?: string[]) {
  if (typeof window === 'undefined' || rows.length === 0) return;
  const cols = columns ?? Object.keys(rows[0]);
  const esc = (v: unknown) => {
    if (v === null || v === undefined) return '';
    const s = v instanceof Date ? v.toISOString() : typeof v === 'object' ? JSON.stringify(v) : String(v);
    return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const csv = [cols.join(','), ...rows.map((r) => cols.map((c) => esc(r[c])).join(','))].join('\r\n');
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

/** Short display name for a template, preferring English. */
export function templateName(t: any): string {
  return t?.nameEn || t?.nameHi || t?.nameMr || 'Untitled';
}

/** Network error / timeout / 5xx — worth trying another upload path. A 4xx is a real rejection. */
export function isRetryableError(err: unknown): boolean {
  const status = (err as any)?.response?.status;
  return !status || status >= 500;
}
