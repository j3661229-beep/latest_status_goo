'use client';

import { AlertCircle, RefreshCw } from 'lucide-react';
import { getErrorMessage } from '../lib/utils';

export function QueryError({ error, onRetry, title = 'Could not load data' }: { error: unknown; onRetry?: () => void; title?: string }) {
  return (
    <div className="bg-white border border-rose-200 rounded-xl p-6 flex flex-col items-center text-center gap-2">
      <AlertCircle size={22} className="text-rose-500" />
      <div className="text-sm font-semibold text-slate-800">{title}</div>
      <div className="text-xs text-slate-500 max-w-md">{getErrorMessage(error)}</div>
      {onRetry && (
        <button
          onClick={onRetry}
          className="mt-2 inline-flex items-center gap-1.5 text-xs font-semibold text-slate-700 bg-white border border-slate-200 hover:bg-slate-50 rounded-lg px-3 py-1.5"
        >
          <RefreshCw size={12} /> Retry
        </button>
      )}
    </div>
  );
}
