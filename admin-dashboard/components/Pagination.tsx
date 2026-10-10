'use client';

import { ChevronLeft, ChevronRight } from 'lucide-react';

export function Pagination({ page, limit, total, onChange }: {
  page: number;
  limit: number;
  total: number;
  onChange: (page: number) => void;
}) {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  if (total <= limit && page === 1) return null;
  const from = total === 0 ? 0 : (page - 1) * limit + 1;
  const to = Math.min(page * limit, total);
  return (
    <div className="flex items-center justify-between px-4 py-3 border-t border-slate-100 text-xs text-slate-500">
      <span>
        Showing <span className="font-semibold text-slate-700">{from}–{to}</span> of{' '}
        <span className="font-semibold text-slate-700">{total.toLocaleString('en-IN')}</span>
      </span>
      <div className="flex items-center gap-1.5">
        <button
          className="btn-outline px-2 py-1 text-xs disabled:opacity-40 disabled:pointer-events-none"
          disabled={page <= 1}
          onClick={() => onChange(page - 1)}
          aria-label="Previous page"
        >
          <ChevronLeft size={14} />
        </button>
        <span className="px-2 font-medium text-slate-700">{page} / {totalPages}</span>
        <button
          className="btn-outline px-2 py-1 text-xs disabled:opacity-40 disabled:pointer-events-none"
          disabled={page >= totalPages}
          onClick={() => onChange(page + 1)}
          aria-label="Next page"
        >
          <ChevronRight size={14} />
        </button>
      </div>
    </div>
  );
}
