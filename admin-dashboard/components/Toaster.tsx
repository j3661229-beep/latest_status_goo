'use client';

import { useEffect, useState } from 'react';
import { CheckCircle2, AlertCircle, Info, X } from 'lucide-react';
import { subscribeToasts, dismissToast, type ToastItem } from '../lib/toast';
import { cn } from '../lib/utils';

export function Toaster() {
  const [items, setItems] = useState<ToastItem[]>([]);
  useEffect(() => subscribeToasts(setItems), []);

  return (
    <div className="fixed bottom-4 right-4 z-[100] flex flex-col gap-2 w-[340px] max-w-[calc(100vw-2rem)]" aria-live="polite">
      {items.map(t => {
        const Icon = t.kind === 'success' ? CheckCircle2 : t.kind === 'error' ? AlertCircle : Info;
        return (
          <div
            key={t.id}
            role={t.kind === 'error' ? 'alert' : 'status'}
            className={cn(
              'flex items-start gap-2.5 bg-white border rounded-lg px-3.5 py-2.5 shadow-sm text-sm',
              t.kind === 'success' && 'border-emerald-200 text-emerald-800',
              t.kind === 'error' && 'border-rose-200 text-rose-700',
              t.kind === 'info' && 'border-slate-200 text-slate-700',
            )}
          >
            <Icon size={16} className="shrink-0 mt-0.5" />
            <span className="flex-1 break-words">{t.message}</span>
            <button onClick={() => dismissToast(t.id)} className="text-slate-400 hover:text-slate-600" aria-label="Dismiss">
              <X size={14} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
