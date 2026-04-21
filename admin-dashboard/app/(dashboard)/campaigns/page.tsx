'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Send, Users, Eye, Phone, Clock } from 'lucide-react';
import { adminApi } from '@/lib/api';

const SEGMENTS = [
  { key: 'all', label: 'All Users', description: 'Send to all app users', icon: '👥' },
  { key: 'hindi', label: 'Hindi Users', description: 'Users with language set to Hindi', icon: '🇮🇳' },
  { key: 'marathi', label: 'Marathi Users', description: 'Users with language set to Marathi', icon: '🟠' },
  { key: 'free', label: 'Free Users', description: 'Non-premium users (upsell opportunity)', icon: '🆓' },
  { key: 'premium', label: 'Premium Users', description: 'Active premium subscribers', icon: '⭐' },
  { key: 'inactive_7d', label: 'Inactive 7+ Days', description: 'Re-engage dormant users', icon: '💤' },
  { key: 'premium_expiring', label: 'Premium Expiring', description: 'Users expiring in 3 days', icon: '⏰' },
] as const;

export default function CampaignsPage() {
  const queryClient = useQueryClient();
  const [form, setForm] = useState({
    title: '',
    body: '',
    imageUrl: '',
    deepLink: '',
    targetSegment: 'all',
    scheduledAt: '',
  });

  const sendMutation = useMutation({
    mutationFn: adminApi.sendCampaign,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      setForm({ title: '', body: '', imageUrl: '', deepLink: '', targetSegment: 'all', scheduledAt: '' });
    },
  });

  const { data: history } = useQuery({
    queryKey: ['campaigns'],
    queryFn: adminApi.getCampaigns,
  });

  const selectedSegment = SEGMENTS.find(s => s.key === form.targetSegment);
  const charCount = form.body.length;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-900 text-slate-800">Push Campaigns</h1>
        <p className="text-muted text-sm mt-1">Compose and send push notifications to your users via OneSignal</p>
      </div>

      <div className="grid grid-cols-3 gap-6">
        {/* Compose Form */}
        <div className="col-span-2 bg-white rounded-2xl p-6 shadow-card border border-surface-border space-y-5">
          <h2 className="font-800 text-slate-800">Compose Notification</h2>

          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">
              Title *
            </label>
            <input
              value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              placeholder="e.g. 🙏 आज का स्टेटस तैयार है!"
              className="w-full px-4 py-3 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary font-devanagari"
            />
          </div>

          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">
              Message Body * <span className={`ml-2 ${charCount > 130 ? 'text-danger' : 'text-muted'}`}>({charCount}/140)</span>
            </label>
            <textarea
              value={form.body}
              onChange={e => setForm(f => ({ ...f, body: e.target.value }))}
              placeholder="नए devotional और motivational status देखें। अभी share करें!"
              rows={3}
              maxLength={140}
              className="w-full px-4 py-3 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary resize-none"
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">
                Image URL (Optional)
              </label>
              <input
                value={form.imageUrl}
                onChange={e => setForm(f => ({ ...f, imageUrl: e.target.value }))}
                placeholder="https://assets.statusgo.app/..."
                className="w-full px-4 py-3 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary"
              />
            </div>
            <div>
              <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">
                Deep Link Screen
              </label>
              <select
                value={form.deepLink}
                onChange={e => setForm(f => ({ ...f, deepLink: e.target.value }))}
                className="w-full px-4 py-3 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary bg-white"
              >
                <option value="">None (open app)</option>
                <option value="home">Home</option>
                <option value="discover">Discover</option>
                <option value="premium">Premium</option>
                <option value="creator_templates">Creator Templates</option>
              </select>
            </div>
          </div>

          {/* Target Segment */}
          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-3 block">
              Target Segment *
            </label>
            <div className="grid grid-cols-2 gap-2">
              {SEGMENTS.map(seg => (
                <button
                  key={seg.key}
                  onClick={() => setForm(f => ({ ...f, targetSegment: seg.key }))}
                  className={`text-left px-3 py-3 rounded-xl border transition-all ${
                    form.targetSegment === seg.key
                      ? 'border-primary bg-primary/5 shadow-sm'
                      : 'border-surface-border hover:border-slate-300'
                  }`}
                >
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="text-base">{seg.icon}</span>
                    <span className={`text-sm font-700 ${form.targetSegment === seg.key ? 'text-primary' : 'text-slate-700'}`}>
                      {seg.label}
                    </span>
                  </div>
                  <div className="text-xs text-muted pl-6">{seg.description}</div>
                </button>
              ))}
            </div>
          </div>

          {/* Schedule */}
          <div>
            <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-2 block">
              Schedule (Optional — leave empty to send now)
            </label>
            <input
              type="datetime-local"
              value={form.scheduledAt}
              onChange={e => setForm(f => ({ ...f, scheduledAt: e.target.value }))}
              className="px-4 py-3 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary"
            />
          </div>

          <div className="flex gap-3 pt-2">
            <button
              onClick={() => sendMutation.mutate(form)}
              disabled={!form.title || !form.body || sendMutation.isPending}
              className="btn-primary flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed"
            >
              <Send size={14} />
              {form.scheduledAt ? 'Schedule Campaign' : 'Send Now'}
            </button>
            {sendMutation.isSuccess && (
              <div className="flex items-center gap-2 text-success text-sm font-700">
                ✅ Campaign sent successfully!
              </div>
            )}
          </div>
        </div>

        {/* Live Preview */}
        <div className="space-y-4">
          <div className="bg-white rounded-2xl p-5 shadow-card border border-surface-border">
            <h3 className="font-800 text-slate-800 mb-4 flex items-center gap-2">
              <Phone size={15} /> Notification Preview
            </h3>

            {/* Android notification preview */}
            <div className="bg-slate-900 rounded-2xl p-4 space-y-2">
              <div className="bg-slate-800 rounded-xl p-3">
                <div className="flex items-center gap-2 mb-2">
                  <div className="w-4 h-4 rounded-sm bg-primary" />
                  <span className="text-white/60 text-[10px] font-600">Status Go · now</span>
                </div>
                <div className="text-white text-xs font-700 mb-1">
                  {form.title || '🙏 Notification title here'}
                </div>
                <div className="text-white/70 text-[11px] leading-relaxed">
                  {form.body || 'Notification message body will appear here. Keep it short and engaging!'}
                </div>
              </div>
            </div>

            <div className="mt-4 pt-4 border-t border-surface-border">
              <div className="text-xs text-muted mb-2 font-600">Target Summary</div>
              <div className="flex items-center gap-2">
                <span className="text-xl">{selectedSegment?.icon}</span>
                <div>
                  <div className="text-sm font-700 text-slate-700">{selectedSegment?.label}</div>
                  <div className="text-xs text-muted">{selectedSegment?.description}</div>
                </div>
              </div>
            </div>
          </div>

          {/* Tips */}
          <div className="bg-primary/5 rounded-2xl p-4 border border-primary/10">
            <div className="text-xs font-800 text-primary mb-2">💡 Best Practices</div>
            <ul className="space-y-1.5 text-xs text-muted">
              <li>• Send Hindi notifications at 7:30–9 AM IST</li>
              <li>• Keep message under 80 characters for best display</li>
              <li>• Use emojis to increase open rates</li>
              <li>• Festival alerts: 2 days before = highest engagement</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Campaign History */}
      <h2 className="text-xl font-900 text-slate-800 mt-8 mb-4">Recent Campaigns</h2>
      <div className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden">
        <table className="w-full data-table">
          <thead className="bg-surface text-left">
            <tr>
              <th className="py-3 px-4">Title</th>
              <th className="py-3 px-4">Target Segment</th>
              <th className="py-3 px-4 text-center">Status</th>
              <th className="py-3 px-4 text-right">Sent / Scheduled</th>
            </tr>
          </thead>
          <tbody>
            {(history?.data || []).map((camp: any) => (
              <tr key={camp.id} className="border-t border-surface-border">
                <td className="py-3 px-4">
                  <div className="font-700 text-sm text-slate-800">{camp.title}</div>
                  <div className="text-xs text-muted truncate max-w-sm">{camp.body}</div>
                </td>
                <td className="py-3 px-4">
                  <div className="text-xs font-600 bg-surface px-2 py-1 rounded inline-block text-slate-600">
                    {SEGMENTS.find(s => s.key === camp.targetSegment)?.label || camp.targetSegment}
                  </div>
                </td>
                <td className="py-3 px-4 text-center">
                  <span className={`text-xs font-700 px-2 py-1 rounded-full ${camp.status === 'sent' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700'}`}>
                    {camp.status.toUpperCase()}
                  </span>
                </td>
                <td className="py-3 px-4 text-right text-xs text-muted">
                  {new Date(camp.scheduledAt || camp.sentAt || camp.createdAt).toLocaleString()}
                </td>
              </tr>
            ))}
            {(!history?.data || history.data.length === 0) && (
              <tr><td colSpan={4} className="text-center py-6 text-muted text-sm">No campaigns sent yet</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
