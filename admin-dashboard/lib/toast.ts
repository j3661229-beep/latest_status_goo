// lib/toast.ts — tiny dependency-free toast store (rendered by components/Toaster).
import { getErrorMessage } from './utils';

export type ToastKind = 'success' | 'error' | 'info';
export interface ToastItem { id: number; kind: ToastKind; message: string }

type Listener = (toasts: ToastItem[]) => void;

let toasts: ToastItem[] = [];
let nextId = 1;
const listeners = new Set<Listener>();

function emit() { listeners.forEach(l => l(toasts)); }

export function subscribeToasts(l: Listener) {
  listeners.add(l);
  l(toasts);
  return () => { listeners.delete(l); };
}

export function dismissToast(id: number) {
  toasts = toasts.filter(t => t.id !== id);
  emit();
}

function push(kind: ToastKind, message: string, ttl = 4000) {
  const id = nextId++;
  toasts = [...toasts, { id, kind, message }].slice(-5);
  emit();
  setTimeout(() => dismissToast(id), ttl);
}

export const toast = {
  success: (m: string) => push('success', m),
  info: (m: string) => push('info', m),
  error: (m: string) => push('error', m, 6000),
  /** Show the backend error message (err.response.data.error) or a fallback. */
  apiError: (err: unknown, fallback = 'Request failed') => push('error', getErrorMessage(err, fallback), 6000),
};
