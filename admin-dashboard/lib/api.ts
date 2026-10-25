// lib/api.ts — Typed API client for admin dashboard
import axios, { AxiosError, InternalAxiosRequestConfig } from 'axios';
import { API_BASE_URL, getAccessToken, refreshTokens, clearTokens, redirectToLogin } from './auth';

const BASE_URL = API_BASE_URL;

export const api = axios.create({
  baseURL: BASE_URL,
  timeout: 15_000,
  headers: { 'Content-Type': 'application/json' },
});

// Attach auth token
api.interceptors.request.use((config) => {
  const token = getAccessToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// On 401: refresh once (single-flight across concurrent requests), retry the
// original request once; if refresh fails, clear tokens and go to /login.
api.interceptors.response.use(
  (res) => res,
  async (error: AxiosError) => {
    const original = error.config as (InternalAxiosRequestConfig & { _retry?: boolean }) | undefined;
    const isAuthCall = original?.url?.includes('/auth/');
    if (typeof window === 'undefined' || error.response?.status !== 401 || !original || original._retry || isAuthCall) {
      return Promise.reject(error);
    }
    original._retry = true;
    try {
      const token = await refreshTokens();
      original.headers.Authorization = `Bearer ${token}`;
      return api(original);
    } catch {
      clearTokens();
      redirectToLogin();
      return Promise.reject(error);
    }
  }
);

/** Drop undefined / null / '' params so the backend doesn't see empty filters. */
export function cleanParams(params?: Record<string, any>) {
  if (!params) return undefined;
  const out: Record<string, any> = {};
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') out[k] = v;
  }
  return out;
}

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
    api.get('/admin/templates', { params: cleanParams(params) }).then(r => r.data),
  getPendingTemplates: (params?: Record<string, any>) =>
    api.get('/admin/templates/pending', { params: cleanParams(params) }).then(r => r.data),
  approveTemplate: (id: string, note?: string) =>
    api.post(`/admin/templates/${id}/approve`, { note }).then(r => r.data),
  rejectTemplate: (id: string, note: string) =>
    api.post(`/admin/templates/${id}/reject`, { note }).then(r => r.data),
  featureTemplate: (id: string, isFeatured: boolean) =>
    api.post(`/admin/templates/${id}/feature`, { isFeatured }).then(r => r.data),
  patchTemplate: (id: string, data: Record<string, any>) =>
    api.patch(`/admin/templates/${id}`, data).then(r => r.data),
  // Coordinator Picks
  // Backend returns { data, total }; older versions returned a bare array — normalize.
  getCoordinatorPicks: () =>
    api.get('/admin/coordinator-picks').then(r => {
      const d = r.data;
      const data: any[] = Array.isArray(d) ? d : Array.isArray(d?.data) ? d.data : [];
      return { data, total: typeof d?.total === 'number' ? d.total : data.length };
    }),
  setCoordinatorPick: (id: string, isCoordinatorPick: boolean, coordinatorNote?: string, coordinatorState?: string) =>
    api.patch(`/admin/templates/${id}/coordinator-pick`, { isCoordinatorPick, coordinatorNote, coordinatorState }).then(r => r.data),
  archiveTemplate: (id: string) =>
    api.delete(`/admin/templates/${id}`).then(r => r.data),

  // Users
  getMe: () => api.get('/user/me').then(r => r.data),
  getUsers: (params?: Record<string, any>) =>
    api.get('/admin/users', { params: cleanParams(params) }).then(r => r.data),
  patchUser: (id: string, data: Record<string, any>) =>
    api.patch(`/admin/users/${id}`, data).then(r => r.data),

  // Creators
  getCreators: (params?: Record<string, any>) =>
    api.get('/admin/creators', { params: cleanParams(params) }).then(r => r.data),
  patchCreator: (id: string, data: Record<string, any>) =>
    api.patch(`/admin/creators/${id}`, data).then(r => r.data),
  inviteCreator: (data: { email: string; name: string; displayName?: string; bio?: string }) =>
    api.post('/admin/creators/invite', data).then(r => r.data),

  // Categories
  getCategories: () => api.get('/admin/categories').then(r => r.data),
  createCategory: (data: Record<string, any>) =>
    api.post('/admin/categories', data).then(r => r.data),
  updateCategory: (id: string, data: Record<string, any>) =>
    api.put(`/admin/categories/${id}`, data).then(r => r.data),
  deleteCategory: (id: string) =>
    api.delete(`/admin/categories/${id}`).then(r => r.data),

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
  sendTestPush: (data: { title: string; body: string; imageUrl?: string; deepLink?: string; testTarget: string; targetType?: string }) =>
    api.post('/admin/campaigns/test', data).then(r => r.data),

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
    api.get('/admin/audit-log', { params: cleanParams(params) }).then(r => r.data),

  // AI Shorts content (Sarkari Yojana + Daily News)
  getContentQueue: (params?: Record<string, any>) =>
    api.get('/admin/content/review-queue', { params: cleanParams(params) }).then(r => r.data),
  getContentCounts: () => api.get('/admin/content/status-counts').then(r => r.data),
  getContent: (id: string) => api.get(`/admin/content/${id}`).then(r => r.data),
  editContent: (id: string, body: Record<string, any>) =>
    api.patch(`/admin/content/${id}`, body).then(r => r.data),
  contentAction: (id: string, action: string, body: Record<string, any> = {}) =>
    api.post(`/admin/content/${id}/${action}`, body).then(r => r.data),
  getContentJobs: (params?: Record<string, any>) =>
    api.get('/admin/content/jobs', { params: cleanParams(params) }).then(r => r.data),
  cancelContentJob: (id: string) => api.post(`/admin/content/jobs/${id}/cancel`).then(r => r.data),
  getContentCosts: () => api.get('/admin/content/costs').then(r => r.data),
  getContentReports: (params?: Record<string, any>) =>
    api.get('/admin/content/reports', { params: cleanParams(params) }).then(r => r.data),
  resolveContentReport: (id: string, status: 'RESOLVED' | 'DISMISSED') =>
    api.post(`/admin/content/reports/${id}/resolve`, { status }).then(r => r.data),
  getContentSettings: () => api.get('/admin/content/settings').then(r => r.data),
  putContentSettings: (body: Record<string, any>) => api.put('/admin/content/settings', body).then(r => r.data),
  runContentIngest: () => api.post('/admin/content/ingest/run').then(r => r.data),
  getContentHealth: () => api.get('/admin/content/health').then(r => r.data),
  getContentAttention: () => api.get('/admin/content/attention').then(r => r.data),
  // Schemes (Sarkari Yojana)
  getSchemes: (params?: Record<string, any>) =>
    api.get('/admin/content/schemes', { params: cleanParams(params) }).then(r => r.data),
  getScheme: (id: string) => api.get(`/admin/content/schemes/${id}`).then(r => r.data),
  createScheme: (body: Record<string, any>) => api.post('/admin/content/schemes', body).then(r => r.data),
  updateScheme: (id: string, body: Record<string, any>) => api.put(`/admin/content/schemes/${id}`, body).then(r => r.data),
  deleteScheme: (id: string) => api.delete(`/admin/content/schemes/${id}`).then(r => r.data),
  verifyScheme: (id: string) => api.post(`/admin/content/schemes/${id}/verify`).then(r => r.data),
  // Creating a draft never generates a video (drafts are CARD_ONLY).
  createSchemeDraft: (id: string) => api.post(`/admin/content/schemes/${id}/draft`, {}).then(r => r.data),
  seedSchemes: () => api.post('/admin/content/schemes/seed').then(r => r.data),
  // Format + video (explicit admin actions only)
  setContentFormat: (id: string, format: 'CARD_ONLY' | 'CARD_WITH_VIDEO') =>
    api.patch(`/admin/content/${id}/format`, { format }).then(r => r.data),
  publishCard: (id: string, body: Record<string, any> = {}) => api.post(`/admin/content/${id}/publish-card`, body).then(r => r.data),
  generateVideo: (id: string) => api.post(`/admin/content/${id}/video/generate`).then(r => r.data),
};
