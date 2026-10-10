'use client';

import { useEffect, useState } from 'react';
import { CheckCircle2, AlertCircle, Info, X } from 'lucide-react';
import { subscribeToasts, dismissToast, type ToastItem } from '../lib/toast';

const styles = {
  success: { cls: 'border-emerald-200 text-emerald-800', Icon: CheckCircle2, icon: 'text-emerald-600' },
  error: { cls: 'border-rose-200 text-rose-800', Icon: AlertCircle, icon: 'text-rose-600' },
  info: { cls: 'border-slate-200 text-slate-800', Icon: Info, icon: 'text-blue-600' },
} as const;

export function Toaster() {
  const [items, setItems] = useState<ToastItem[]>([]);
  useEffect(() => subscribeToasts(setItems), []);

  return (
    <div className="fixed bottom-4 right-4 z-[100] flex flex-col gap-2 w-[min(360px,calc(100vw-2rem))]" aria-live="polite">
      {items.map((t) => {
        const s = styles[t.kind];
        return (
          <div key={t.id} className={`flex items-start gap-2.5 bg-white border rounded-lg shadow-sm px-3.5 py-3 text-sm ${s.cls}`}>
            <s.Icon size={16} className={`shrink-0 mt-0.5 ${s.icon}`} />
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
