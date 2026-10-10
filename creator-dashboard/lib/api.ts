// lib/api.ts — Typed API client for creator dashboard
import axios, { type AxiosError, type InternalAxiosRequestConfig } from 'axios';
import { BASE_URL, getAccessToken, refreshTokens, clearTokens, redirectToLogin } from './auth';

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

// On 401: refresh once (single-flight, shared by concurrent requests), retry the original
// request once; if refresh fails, clear tokens and send the user to /login.
api.interceptors.response.use(
  (res) => res,
  async (error: AxiosError) => {
    const original = error.config as (InternalAxiosRequestConfig & { _retry?: boolean }) | undefined;
    const isAuthCall = original?.url?.startsWith('/auth/');
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

// ── Auth ─────────────────────────────────────────────────────────
export const authApi = {
  // Exchange Google idToken for our backend JWT (Creator Studio only)
  creatorGoogleLogin: (idToken: string) =>
    axios.post(`${BASE_URL}/auth/google/creator`, { idToken }).then((r) => r.data),

  // Creator email & password login (for invited creators)
  creatorLogin: (email: string, password: string) =>
    axios.post(`${BASE_URL}/auth/creator/login`, { email, password }).then((r) => r.data),
};

// ── Creator API functions ────────────────────────────────────────
export const creatorApi = {
  // Stats
  getStats: () => api.get('/creator/stats').then(r => r.data),

  // Categories (public endpoint: GET /categories → { data, total })
  getCategories: () => api.get('/categories').then(r => r.data),

  // Templates
  getTemplates: (params?: Record<string, any>) =>
    api.get('/creator/templates', { params }).then(r => r.data),
  createTemplate: (data: Record<string, any>) =>
    api.post('/creator/templates', data).then(r => r.data),
  updateTemplate: (id: string, data: Record<string, any>) =>
    api.put(`/creator/templates/${id}`, data).then(r => r.data),
  submitTemplate: (id: string) =>
    api.post(`/creator/templates/${id}/submit`).then(r => r.data),
  deleteTemplate: (id: string) =>
    api.delete(`/creator/templates/${id}`).then(r => r.data),

  uploadTemplateMedia: (file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post('/upload/template', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 120_000,
    }).then(r => r.data);
  },

  uploadProfilePhoto: (file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    return api.post('/upload/profile-photo', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 60_000,
    }).then(r => r.data as { url: string });
  },

  getCloudinarySignature: (data: { folder: string; tags?: string[] }) =>
    api.post('/creator/upload/sign-cloudinary', data).then(r => r.data),

  // Profile
  getProfile: () => api.get('/creator/profile').then(r => r.data),
  updateProfile: (data: Record<string, any>) =>
    api.patch('/creator/profile', data).then(r => r.data),
};
