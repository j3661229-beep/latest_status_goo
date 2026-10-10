'use client';

import { AlertCircle, RotateCw } from 'lucide-react';
import { getErrorMessage } from '../lib/utils';

/** Inline error state for a failed useQuery, with a retry button. */
export function QueryError({ error, onRetry, title = 'Failed to load data' }: {
  error: unknown;
  onRetry: () => void;
  title?: string;
}) {
  return (
    <div className="bg-white border border-rose-200 rounded-xl p-6 flex flex-col items-center text-center gap-2 shadow-sm">
      <AlertCircle size={22} className="text-rose-500" />
      <div className="text-sm font-semibold text-slate-800">{title}</div>
      <div className="text-xs text-slate-500 max-w-md">{getErrorMessage(error)}</div>
      <button onClick={onRetry} className="btn-outline mt-2 gap-1.5 text-xs py-1.5">
        <RotateCw size={13} /> Retry
      </button>
    </div>
  );
}
