import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCurrency(paiseAmount: number): string {
  return `₹${(paiseAmount / 100).toLocaleString('en-IN')}`;
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
