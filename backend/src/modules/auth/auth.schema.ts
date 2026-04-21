// src/modules/auth/auth.schema.ts
import { z } from 'zod';

export const AdminLoginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(6, 'Password too short'),
});

export const GoogleAuthSchema = z.object({
  idToken: z.string().min(10, 'Invalid Google ID token'),
});

export const RefreshSchema = z.object({
  refreshToken: z.string().min(10),
});

export const LogoutSchema = z.object({
  refreshToken: z.string().min(10),
});

export type AdminLoginBody = z.infer<typeof AdminLoginSchema>;
export type GoogleAuthBody = z.infer<typeof GoogleAuthSchema>;
export type RefreshBody = z.infer<typeof RefreshSchema>;
