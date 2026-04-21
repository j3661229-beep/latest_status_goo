'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { User, BadgeCheck, CheckCircle, Save, Camera } from 'lucide-react';
import { creatorApi } from '@/lib/api';

export default function CreatorProfilePage() {
  const queryClient = useQueryClient();
  const [form, setForm] = useState<any>({});
  const [hasChanges, setHasChanges] = useState(false);

  const { data: profile, isLoading } = useQuery({
    queryKey: ['creator-profile'],
    queryFn: () => creatorApi.getProfile(),
  });

  const updateMutation = useMutation({
    mutationFn: (data: any) => creatorApi.updateProfile(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['creator-profile'] });
      setHasChanges(false);
      alert('Profile updated successfully!');
    },
  });

  if (!isLoading && profile && Object.keys(form).length === 0 && !hasChanges) {
    setForm({
      displayName: profile.displayName || profile.user?.name || '',
      bio: profile.bio || '',
      portfolioUrl: profile.portfolioUrl || '',
      specialization: profile.specialization?.join(', ') || '',
    });
  }

  const handleChange = (key: string, val: string) => {
    setForm((f: any) => ({ ...f, [key]: val }));
    setHasChanges(true);
  };

  const handleSave = () => {
    const data = {
      ...form,
      specialization: form.specialization.split(',').map((s: string) => s.trim()).filter(Boolean)
    };
    updateMutation.mutate(data);
  };

  if (isLoading) return <div className="text-center py-12">Loading profile...</div>;

  const isVerified = profile?.isVerified;

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-900 text-slate-800">Creator Profile</h1>
          <p className="text-muted text-sm mt-1">Manage your public creator identity</p>
        </div>
        <button 
          onClick={handleSave}
          disabled={!hasChanges || updateMutation.isPending}
          className="btn-primary flex items-center gap-2 disabled:opacity-50"
        >
          <Save size={16} /> Save Changes
        </button>
      </div>

      <div className="grid grid-cols-3 gap-6">
        <div className="col-span-1 space-y-6">
          <div className="bg-white rounded-2xl p-6 shadow-card border border-surface-border text-center">
            <div className="relative w-24 h-24 mx-auto mb-4">
              <div className="w-full h-full rounded-2xl bg-primary/10 flex items-center justify-center overflow-hidden">
                {profile?.user?.profilePhoto ? (
                  <img src={profile.user.profilePhoto} alt="Profile" className="w-full h-full object-cover" />
                ) : (
                  <User size={32} className="text-primary" />
                )}
              </div>
              <button className="absolute -bottom-2 -right-2 w-8 h-8 rounded-full bg-white border border-surface-border shadow-sm flex items-center justify-center text-muted hover:text-primary transition-colors">
                <Camera size={14} />
              </button>
            </div>
            <h3 className="font-800 text-slate-800 text-lg flex items-center justify-center gap-1.5">
              {form.displayName || 'Anonymous'}
              {isVerified && <BadgeCheck size={18} className="text-success" />}
            </h3>
            <p className="text-sm text-muted mt-1">{profile?.user?.email}</p>

            <div className="mt-6 pt-6 border-t border-surface-border space-y-3">
              <div className="flex justify-between items-center text-sm">
                <span className="text-muted font-600">Verification</span>
                {isVerified ? (
                  <span className="text-success font-700 flex items-center gap-1"><CheckCircle size={14}/> Verified</span>
                ) : (
                  <span className="text-amber-600 font-700">Pending</span>
                )}
              </div>
              <div className="flex justify-between items-center text-sm">
                <span className="text-muted font-600">Approval Rate</span>
                <span className="text-slate-800 font-800">{profile?.approvalRate?.toFixed(1) || 0}%</span>
              </div>
            </div>
          </div>
        </div>

        <div className="col-span-2 space-y-6">
          <div className="bg-white rounded-2xl p-6 shadow-card border border-surface-border space-y-5">
            <h3 className="font-800 text-slate-800 border-b border-surface-border pb-3">Profile Information</h3>
            
            <div>
              <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">Display Name *</label>
              <input
                value={form.displayName}
                onChange={e => handleChange('displayName', e.target.value)}
                className="w-full px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary"
              />
            </div>

            <div>
              <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">Short Bio</label>
              <textarea
                value={form.bio}
                onChange={e => handleChange('bio', e.target.value)}
                rows={3}
                placeholder="Tell users a bit about yourself and your style..."
                className="w-full px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary resize-none"
              />
            </div>

            <div>
              <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">Portfolio / Instagram URL</label>
              <input
                value={form.portfolioUrl}
                onChange={e => handleChange('portfolioUrl', e.target.value)}
                placeholder="https://instagram.com/yourhandle"
                className="w-full px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary"
              />
            </div>

            <div>
              <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">Specialization Tags</label>
              <input
                value={form.specialization}
                onChange={e => handleChange('specialization', e.target.value)}
                placeholder="e.g. Devotional, Nature, Video Editing"
                className="w-full px-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary"
              />
              <p className="text-xs text-muted mt-1">Comma separated</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
