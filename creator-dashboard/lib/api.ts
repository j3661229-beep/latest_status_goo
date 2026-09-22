// lib/api.ts — Typed API client for creator dashboard
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
    const token = localStorage.getItem('creator_access_token');
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (typeof window !== 'undefined' && error.response?.status === 401) {
      localStorage.removeItem('creator_access_token');
      if (!window.location.pathname.startsWith('/login')) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

// ── Auth ─────────────────────────────────────────────────────────
export const authApi = {
  // Exchange Google idToken for our backend JWT (Creator Studio only)
  creatorGoogleLogin: (idToken: string) =>
    axios
      .post(`${BASE_URL}/auth/google/creator`, { idToken })
      .then((r) => r.data),

  // Creator email & password login (for invited creators / demo)
  creatorLogin: (email: string, password: string) =>
    axios
      .post(`${BASE_URL}/auth/creator/login`, { email, password })
      .then((r) => r.data),
};

// ── Creator API functions ────────────────────────────────────────
export const creatorApi = {
  // Stats
  getStats: () => api.get('/creator/stats').then(r => r.data),

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
    }).then(r => r.data);
  },

  getCloudinarySignature: (data: { folder: string; tags?: string[] }) =>
    api.post('/creator/upload/sign-cloudinary', data).then(r => r.data),

  // Profile
  getProfile: () => api.get('/creator/profile').then(r => r.data),
  updateProfile: (data: Record<string, any>) =>
    api.patch('/creator/profile', data).then(r => r.data),
};
