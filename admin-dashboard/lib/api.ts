// lib/api.ts — Typed API client for admin dashboard
import axios from 'axios';

const BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000/api/v1';

export const api = axios.create({
  baseURL: BASE_URL,
  timeout: 15_000,
  headers: { 'Content-Type': 'application/json' },
});

// Attach auth token; redirect to /login on 401
api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('admin_access_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (typeof window !== 'undefined' && error.response?.status === 401) {
      localStorage.removeItem('admin_access_token');
      if (!window.location.pathname.startsWith('/login')) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

// ── Auth ────────────────────────────────────────────────────────
export const authApi = {
  adminLogin: (email: string, password: string) =>
    axios.post(`${BASE_URL}/auth/admin/login`, { email, password }).then(r => r.data),
};

// ── Admin API functions ──────────────────────────────────────────
export const adminApi = {
  // Stats
  getStats: () => api.get('/admin/stats').then(r => r.data),
  getRevenue: () => api.get('/admin/revenue').then(r => r.data),

  // Templates
  getTemplates: (params?: Record<string, any>) =>
    api.get('/admin/templates', { params }).then(r => r.data),
  getPendingTemplates: (params?: Record<string, any>) =>
    api.get('/admin/templates/pending', { params }).then(r => r.data),
  approveTemplate: (id: string, note?: string) =>
    api.post(`/admin/templates/${id}/approve`, { note }).then(r => r.data),
  rejectTemplate: (id: string, note: string) =>
    api.post(`/admin/templates/${id}/reject`, { note }).then(r => r.data),
  featureTemplate: (id: string, isFeatured: boolean) =>
    api.post(`/admin/templates/${id}/feature`, { isFeatured }).then(r => r.data),
  patchTemplate: (id: string, data: Record<string, any>) =>
    api.patch(`/admin/templates/${id}`, data).then(r => r.data),
  archiveTemplate: (id: string) =>
    api.delete(`/admin/templates/${id}`).then(r => r.data),

  // Users
  getUsers: (params?: Record<string, any>) =>
    api.get('/admin/users', { params }).then(r => r.data),
  patchUser: (id: string, data: Record<string, any>) =>
    api.patch(`/admin/users/${id}`, data).then(r => r.data),

  // Creators
  getCreators: (params?: Record<string, any>) =>
    api.get('/admin/creators', { params }).then(r => r.data),
  patchCreator: (id: string, data: Record<string, any>) =>
    api.patch(`/admin/creators/${id}`, data).then(r => r.data),
  inviteCreator: (data: { email: string; name: string; displayName?: string; bio?: string }) =>
    api.post('/admin/creators/invite', data).then(r => r.data),

  // Festivals
  getFestivals: () => api.get('/admin/festivals').then(r => r.data),
  createFestival: (data: Record<string, any>) =>
    api.post('/admin/festivals', data).then(r => r.data),
  updateFestival: (id: string, data: Record<string, any>) =>
    api.put(`/admin/festivals/${id}`, data).then(r => r.data),

  // Push Campaigns
  getCampaigns: () => api.get('/admin/campaigns').then(r => r.data),
  sendCampaign: (data: Record<string, any>) =>
    api.post('/admin/campaigns/send', data).then(r => r.data),

  // Analytics
  getDau: (days = 30) => api.get('/admin/analytics/dau', { params: { days } }).then(r => r.data),
  getSearches: () => api.get('/admin/analytics/searches').then(r => r.data),
  getShares: () => api.get('/admin/analytics/shares').then(r => r.data),

  // Config
  getConfigs: () => api.get('/admin/config').then(r => r.data),
  updateConfig: (key: string, value: string) =>
    api.put('/admin/config', { key, value }).then(r => r.data),

  // Audit Log
  getAuditLogs: (params?: Record<string, any>) =>
    api.get('/admin/audit-log', { params }).then(r => r.data),
};
