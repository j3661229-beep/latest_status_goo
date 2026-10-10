// lib/toast.ts — minimal pub/sub toast store (no deps). Rendered by components/Toaster.tsx.
export type ToastKind = 'success' | 'error' | 'info';
export interface ToastItem { id: number; kind: ToastKind; message: string }

type Listener = (items: ToastItem[]) => void;
let items: ToastItem[] = [];
let nextId = 1;
const listeners = new Set<Listener>();

function emit() {
  listeners.forEach((l) => l(items));
}

export function dismissToast(id: number) {
  items = items.filter((t) => t.id !== id);
  emit();
}

function push(kind: ToastKind, message: string, durationMs = 4000) {
  const id = nextId++;
  items = [...items, { id, kind, message }];
  emit();
  setTimeout(() => dismissToast(id), durationMs);
}

export const toast = {
  success: (m: string) => push('success', m),
  error: (m: string) => push('error', m, 6000),
  info: (m: string) => push('info', m),
};

export function subscribeToasts(l: Listener) {
  listeners.add(l);
  l(items);
  return () => {
    listeners.delete(l);
  };
}
