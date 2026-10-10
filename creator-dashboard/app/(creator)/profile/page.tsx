'use client';

import { useEffect, useRef, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { User, BadgeCheck, CheckCircle, Save, Camera } from 'lucide-react';
import { creatorApi } from '@/lib/api';
import { getErrorMessage } from '@/lib/utils';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';

const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const PHOTO_MAX_BYTES = 10 * 1024 * 1024;

export default function CreatorProfilePage() {
  const queryClient = useQueryClient();
  const [form, setForm] = useState<any>({});
  const [hasChanges, setHasChanges] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data: profile, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['creator-profile'],
    queryFn: () => creatorApi.getProfile(),
  });

  const updateMutation = useMutation({
    mutationFn: (data: any) => creatorApi.updateProfile(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['creator-profile'] });
      setHasChanges(false);
      toast.success('Profile updated');
    },
    onError: (err) => toast.error(getErrorMessage(err, 'Could not update profile')),
  });

  const photoMutation = useMutation({
    mutationFn: (file: File) => creatorApi.uploadProfilePhoto(file),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['creator-profile'] });
      toast.success('Profile photo updated');
    },
    onError: (err) => toast.error(getErrorMessage(err, 'Photo upload failed')),
  });

  const handlePhotoSelected = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    if (!PHOTO_TYPES.includes(file.type)) {
      toast.error('Only JPEG, PNG or WebP images are allowed');
      return;
    }
    if (file.size > PHOTO_MAX_BYTES) {
      toast.error('Photo must be 10 MB or smaller');
      return;
    }
    photoMutation.mutate(file);
  };

  // Initialise the form once the profile arrives (and whenever it reloads with no unsaved edits).
  useEffect(() => {
    if (!profile || hasChanges) return;
    setForm({
      displayName: profile.displayName || profile.user?.name || '',
      bio: profile.bio || '',
      portfolioUrl: profile.portfolioUrl || '',
      specialization: profile.specialization?.join(', ') || '',
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile]);

  const handleChange = (key: string, val: string) => {
    setForm((f: any) => ({ ...f, [key]: val }));
    setHasChanges(true);
  };

  const handleSave = () => {
    const data = {
      ...form,
      specialization: (form.specialization ?? '').split(',').map((s: string) => s.trim()).filter(Boolean)
    };
    updateMutation.mutate(data);
  };

  if (isLoading) return <div className="text-center py-12 text-sm text-slate-500">Loading profile...</div>;
  if (isError) return <QueryError error={error} onRetry={() => refetch()} title="Could not load your profile" />;

  const isVerified = profile?.isVerified;

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900 tracking-tight">Creator Profile</h1>
          <p className="text-slate-500 text-sm mt-0.5">Manage your public creator identity</p>
        </div>
        <button 
          onClick={handleSave}
          disabled={!hasChanges || updateMutation.isPending}
          className="btn-primary flex items-center gap-1.5 text-xs py-1.5 px-3.5 self-start sm:self-auto disabled:opacity-50"
        >
          <Save size={14} /> Save Changes
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        <div className="md:col-span-1 space-y-5">
          <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80 text-center">
            <div className="relative w-20 h-20 mx-auto mb-3.5">
              <div className="w-full h-full rounded-xl bg-blue-50 border border-blue-100 flex items-center justify-center overflow-hidden">
                {profile?.user?.profilePhoto ? (
                  <img src={profile.user.profilePhoto} alt="Profile" className="w-full h-full object-cover" />
                ) : (
                  <User size={28} className="text-blue-600" />
                )}
              </div>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                className="hidden"
                onChange={handlePhotoSelected}
              />
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={photoMutation.isPending}
                aria-label="Change profile photo"
                title="Change profile photo"
                className="absolute -bottom-1.5 -right-1.5 w-7 h-7 rounded-full bg-white border border-slate-200 shadow-sm flex items-center justify-center text-slate-500 hover:text-blue-600 transition-colors disabled:opacity-60"
              >
                {photoMutation.isPending ? (
                  <div className="w-3 h-3 border-2 border-blue-600/30 border-t-blue-600 rounded-full animate-spin" />
                ) : (
                  <Camera size={12} />
                )}
              </button>
            </div>
            <h3 className="font-semibold text-slate-900 text-base flex items-center justify-center gap-1">
              <span className="truncate">{form.displayName || 'Anonymous'}</span>
              {isVerified && <BadgeCheck size={16} className="text-blue-600 shrink-0" />}
            </h3>
            <p className="text-xs text-slate-400 mt-0.5 truncate">{profile?.user?.email}</p>

            <div className="mt-5 pt-4 border-t border-slate-100 space-y-2.5">
              <div className="flex justify-between items-center text-xs">
                <span className="text-slate-500 font-medium">Verification</span>
                {isVerified ? (
                  <span className="badge-approved inline-flex items-center gap-1"><CheckCircle size={11}/> Verified</span>
                ) : (
                  <span className="badge-pending">Pending</span>
                )}
              </div>
              <div className="flex justify-between items-center text-xs">
                <span className="text-slate-500 font-medium">Approval Rate</span>
                <span className="text-slate-800 font-semibold tabular-nums">{profile?.approvalRate?.toFixed(1) || 0}%</span>
              </div>
            </div>
          </div>
        </div>

        <div className="md:col-span-2">
          <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80 space-y-4">
            <h3 className="font-semibold text-slate-900 text-sm border-b border-slate-100 pb-3">Profile Information</h3>
            
            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">Display Name *</label>
              <input
                value={form.displayName ?? ''}
                onChange={e => handleChange('displayName', e.target.value)}
                className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white"
              />
            </div>

            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">Short Bio</label>
              <textarea
                value={form.bio ?? ''}
                onChange={e => handleChange('bio', e.target.value)}
                rows={3}
                placeholder="Tell users a bit about yourself and your style..."
                className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white resize-none"
              />
            </div>

            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">Portfolio / Instagram URL</label>
              <input
                value={form.portfolioUrl ?? ''}
                onChange={e => handleChange('portfolioUrl', e.target.value)}
                placeholder="https://instagram.com/yourhandle"
                className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white"
              />
            </div>

            <div>
              <label className="text-xs font-medium text-slate-700 mb-1.5 block">Specialization Tags</label>
              <input
                value={form.specialization ?? ''}
                onChange={e => handleChange('specialization', e.target.value)}
                placeholder="e.g. Devotional, Nature, Video Editing"
                className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white"
              />
              <p className="text-[11px] text-slate-400 mt-1">Comma separated</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
