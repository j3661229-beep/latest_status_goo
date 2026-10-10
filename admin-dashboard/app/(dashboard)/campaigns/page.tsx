'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { 
  Send, Users, Eye, Phone, Clock, Sparkles, Smartphone, 
  CheckCircle2, AlertCircle, RefreshCw, Layers, Bell, ArrowRight
} from 'lucide-react';
import { adminApi } from '@/lib/api';
import { toast } from '@/lib/toast';
import { getErrorMessage } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';

const SEGMENTS = [
  { key: 'all', label: 'All Users', description: 'Send to all app users', icon: '👥' },
  { key: 'hindi', label: 'Hindi Users', description: 'Users with language set to Hindi', icon: '🇮🇳' },
  { key: 'marathi', label: 'Marathi Users', description: 'Users with language set to Marathi', icon: '🟠' },
  { key: 'free', label: 'Free Users', description: 'Non-premium users (upsell opportunity)', icon: '🆓' },
  { key: 'premium', label: 'Premium Users', description: 'Active premium subscribers', icon: '⭐' },
  { key: 'inactive_7d', label: 'Inactive 7+ Days', description: 'Re-engage dormant users', icon: '💤' },
  { key: 'premium_expiring', label: 'Premium Expiring', description: 'Users expiring in 3 days', icon: '⏰' },
] as const;

const PRESETS = [
  {
    title: '🙏 सुप्रभात! आज का नया स्टेटस तैयार है',
    body: 'आज का दिन मंगलमय हो। नए भक्ति और सुविचार स्टेटस अपने प्रियजनों के साथ शेयर करें!',
    notifType: 'DAILY_STATUS',
    targetSegment: 'hindi',
    deepLink: 'home',
    label: '🌅 Daily Status (Hindi)',
  },
  {
    title: '🙏 शुभ सकाळ! आजचा नवा स्टेटस तयार आहे',
    body: 'आजचा दिवस आनंदाचा जावो. भक्ती आणि सुविचार स्टेटस आपल्या आप्तेष्टांसोबत शेअर करा!',
    notifType: 'DAILY_STATUS',
    targetSegment: 'marathi',
    deepLink: 'home',
    label: '🌅 Daily Status (Marathi)',
  },
  {
    title: '🎉 आगामी सणाच्या हार्दिक शुभेच्छा!',
    body: 'खास सणाचे सुंदर स्टेटस आणि शुभेच्छा कार्ड्स आता उपलब्ध आहेत. आत्ताच डाऊनलोड करा!',
    notifType: 'FESTIVAL_ALERT',
    targetSegment: 'all',
    deepLink: 'discover',
    label: '🎉 Festival Special',
  },
  {
    title: '⭐ विशेष ऑफर: Status Go Premium वर 50% सूट!',
    body: 'अमर्यादित स्टेटस, नो वॉटरमार्क आणि सर्व प्रीमियम फ्रेम्स फक्त ₹49 मध्ये मिळवा.',
    notifType: 'PREMIUM_OFFER',
    targetSegment: 'free',
    deepLink: 'premium',
    label: '⭐ Premium 50% Off',
  },
  {
    title: '✨ 50+ नए भक्ति व सुविचार स्टेटस अपलोड हुए',
    body: 'आज ही अपनी फोटो और नाम के साथ नया स्टेटस बनाएं और व्हाट्सएप्प पर लगाएं।',
    notifType: 'NEW_CONTENT',
    targetSegment: 'all',
    deepLink: 'home',
    label: '✨ New Uploads Live',
  },
];

export default function CampaignsPage() {
  const queryClient = useQueryClient();
  const [form, setForm] = useState({
    title: '',
    body: '',
    imageUrl: '',
    deepLink: '',
    targetSegment: 'all',
    notifType: 'NEW_CONTENT',
    scheduledAt: '',
  });

  const [testTarget, setTestTarget] = useState('');
  const [testStatus, setTestStatus] = useState<string | null>(null);

  const sendMutation = useMutation({
    mutationFn: adminApi.sendCampaign,
    onError: (err) => toast.apiError(err, 'Failed to send campaign'),
    onSuccess: () => {
      toast.success('Campaign sent');
      queryClient.invalidateQueries({ queryKey: ['campaigns'] });
      setForm({
        title: '',
        body: '',
        imageUrl: '',
        deepLink: '',
        targetSegment: 'all',
        notifType: 'NEW_CONTENT',
        scheduledAt: '',
      });
    },
  });

  const testMutation = useMutation({
    mutationFn: adminApi.sendTestPush,
    onSuccess: (data: any) => {
      setTestStatus(`✅ Test sent successfully! Delivered to: ${data.deliveredTo || 'device'}`);
      setTimeout(() => setTestStatus(null), 6000);
    },
    onError: (err: any) => {
      setTestStatus(`❌ Failed to send test: ${getErrorMessage(err)}`);
    },
  });

  const { data: history, isLoading: isHistoryLoading, isError: isHistoryError, error: historyError, refetch } = useQuery({
    queryKey: ['campaigns'],
    queryFn: adminApi.getCampaigns,
  });

  const selectedSegment = SEGMENTS.find(s => s.key === form.targetSegment);
  const charCount = form.body.length;

  const handleApplyPreset = (preset: typeof PRESETS[0]) => {
    setForm(f => ({
      ...f,
      title: preset.title,
      body: preset.body,
      notifType: preset.notifType,
      targetSegment: preset.targetSegment,
      deepLink: preset.deepLink,
    }));
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 flex items-center gap-2">
            <Bell className="text-primary" size={22} /> Push & In-App Campaigns
          </h1>
          <p className="text-slate-500 text-xs mt-1">
            Compose and broadcast push notifications to mobile users via OneSignal & sync to in-app notification inbox
          </p>
        </div>

        <button
          onClick={() => refetch()}
          className="btn-secondary text-xs flex items-center gap-1.5 self-start sm:self-auto"
        >
          <RefreshCw size={13} className={isHistoryLoading ? 'animate-spin' : ''} />
          Refresh Stats
        </button>
      </div>

      {/* Quick Presets */}
      <div className="bg-white rounded-xl p-4 border border-slate-200/80 shadow-sm">
        <div className="text-xs font-semibold text-slate-600 uppercase tracking-wider mb-2.5 flex items-center gap-1.5">
          <Sparkles size={14} className="text-amber-500" /> Quick Message Presets (Click to autofill)
        </div>
        <div className="flex flex-wrap gap-2">
          {PRESETS.map((p, idx) => (
            <button
              key={idx}
              onClick={() => handleApplyPreset(p)}
              className="text-xs font-medium px-3 py-1.5 rounded-lg border border-slate-200 bg-slate-50/70 hover:bg-primary/5 hover:border-primary/30 hover:text-primary transition-colors text-slate-700 flex items-center gap-1.5"
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Compose Form */}
        <div className="lg:col-span-2 bg-white rounded-xl p-5 md:p-6 shadow-sm border border-slate-200/80 space-y-4">
          <div className="flex justify-between items-center pb-2 border-b border-slate-100">
            <h2 className="font-bold text-slate-900 text-base flex items-center gap-2">
              <Send size={16} className="text-primary" /> Compose Notification
            </h2>
            <div className="flex items-center gap-2">
              <span className="text-xs font-medium text-slate-500">Type:</span>
              <select
                value={form.notifType}
                onChange={e => setForm(f => ({ ...f, notifType: e.target.value }))}
                className="text-xs font-semibold px-2.5 py-1 rounded-lg border border-slate-300 bg-slate-50 text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
              >
                <option value="DAILY_STATUS">🙏 Daily Status</option>
                <option value="FESTIVAL_ALERT">🎉 Festival Alert</option>
                <option value="NEW_CONTENT">✨ New Content</option>
                <option value="PREMIUM_OFFER">⭐ Premium Offer</option>
                <option value="WELCOME">👋 Welcome</option>
              </select>
            </div>
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5 block">
              Title *
            </label>
            <input
              value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              placeholder="e.g. 🙏 आज का स्टेटस तैयार है!"
              className="w-full px-3.5 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary font-devanagari bg-white text-slate-800"
            />
          </div>

          <div>
            <div className="flex justify-between items-center mb-1.5">
              <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                Message Body *
              </label>
              <span className={`text-[11px] font-medium tabular-nums ${charCount > 130 ? 'text-rose-600 font-semibold' : 'text-slate-400'}`}>
                {charCount}/140
              </span>
            </div>
            <textarea
              value={form.body}
              onChange={e => setForm(f => ({ ...f, body: e.target.value }))}
              placeholder="नए devotional और motivational status देखें। अभी share करें!"
              rows={3}
              maxLength={140}
              className="w-full px-3.5 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary resize-none font-devanagari bg-white text-slate-800"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5 block">
                Image Banner URL (Optional)
              </label>
              <input
                value={form.imageUrl}
                onChange={e => setForm(f => ({ ...f, imageUrl: e.target.value }))}
                placeholder="https://storage.googleapis.com/... or Cloudinary"
                className="w-full px-3.5 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary bg-white text-slate-800"
              />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5 block">
                Deep Link Screen
              </label>
              <select
                value={form.deepLink}
                onChange={e => setForm(f => ({ ...f, deepLink: e.target.value }))}
                className="w-full px-3.5 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary bg-white text-slate-800"
              >
                <option value="">Open App (Default)</option>
                <option value="home">Home Feed</option>
                <option value="discover">Discover / Festivals</option>
                <option value="premium">Premium Subscription</option>
                <option value="saved">Saved Status</option>
                <option value="notifications">In-App Notifications</option>
              </select>
            </div>
          </div>

          {/* Target Segment */}
          <div>
            <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider mb-2 block">
              Target Audience Segment *
            </label>
            <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
              {SEGMENTS.map(seg => (
                <button
                  type="button"
                  key={seg.key}
                  onClick={() => setForm(f => ({ ...f, targetSegment: seg.key }))}
                  className={`text-left px-3 py-2.5 rounded-lg border transition-all ${
                    form.targetSegment === seg.key
                      ? 'border-primary bg-primary/5 shadow-xs ring-1 ring-primary/20'
                      : 'border-slate-200 hover:border-slate-300 bg-slate-50/50 hover:bg-slate-50'
                  }`}
                >
                  <div className="flex items-center gap-2 mb-0.5">
                    <span className="text-base">{seg.icon}</span>
                    <span className={`text-xs font-semibold ${form.targetSegment === seg.key ? 'text-primary' : 'text-slate-800'}`}>
                      {seg.label}
                    </span>
                  </div>
                  <div className="text-[11px] text-slate-500 line-clamp-1">{seg.description}</div>
                </button>
              ))}
            </div>
          </div>

          {/* Schedule */}
          <div>
            <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5 block">
              Schedule for Later (Optional — leave empty to dispatch immediately)
            </label>
            <input
              type="datetime-local"
              value={form.scheduledAt}
              onChange={e => setForm(f => ({ ...f, scheduledAt: e.target.value }))}
              className="px-3.5 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary bg-white text-slate-700"
            />
          </div>

          {/* Action Buttons */}
          <div className="flex items-center gap-3 pt-2">
            <button
              onClick={() => sendMutation.mutate(form)}
              disabled={!form.title || !form.body || sendMutation.isPending}
              className="btn-primary px-5 py-2.5 text-sm font-semibold rounded-lg shadow-sm flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
            >
              <Send size={15} />
              {sendMutation.isPending
                ? 'Dispatching...'
                : form.scheduledAt
                ? 'Schedule Campaign'
                : 'Send Broadcast Now'}
            </button>
            {sendMutation.isSuccess && (
              <div className="flex items-center gap-1.5 text-emerald-700 text-xs font-semibold bg-emerald-50 px-3 py-1.5 rounded-lg border border-emerald-200">
                <CheckCircle2 size={15} /> Campaign initiated & logged in-app!
              </div>
            )}
            {sendMutation.isError && (
              <div className="flex items-center gap-1.5 text-rose-700 text-xs font-semibold bg-rose-50 px-3 py-1.5 rounded-lg border border-rose-200">
                <AlertCircle size={15} /> {getErrorMessage(sendMutation.error, 'Error sending campaign')}
              </div>
            )}
          </div>

          {/* Test Push Card */}
          <div className="mt-4 pt-4 border-t border-slate-200/80 bg-slate-50/70 p-3.5 rounded-lg border border-slate-200/70">
            <div className="text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
              <Smartphone size={14} className="text-primary" /> Direct Test Push (To My Device)
            </div>
            <p className="text-xs text-slate-500 mb-2.5">
              Test notification on your device before sending to all users. Enter your phone number, user ID, or OneSignal Player ID.
            </p>
            <div className="flex gap-2">
              <input
                value={testTarget}
                onChange={e => setTestTarget(e.target.value)}
                placeholder="Phone (e.g. 9876543210) or OneSignal Player ID"
                className="flex-1 px-3 py-2 text-xs border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary bg-white text-slate-700"
              />
              <button
                type="button"
                onClick={() =>
                  testMutation.mutate({
                    title: form.title || 'Test Notification',
                    body: form.body || 'This is a test notification from Status Go Admin Dashboard.',
                    imageUrl: form.imageUrl,
                    deepLink: form.deepLink,
                    testTarget,
                  })
                }
                disabled={!testTarget || testMutation.isPending}
                className="px-3.5 py-2 text-xs font-semibold rounded-lg bg-slate-800 hover:bg-slate-900 text-white disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5 transition-colors shadow-sm"
              >
                {testMutation.isPending ? 'Sending...' : 'Send Test'}
              </button>
            </div>
            {testStatus && (
              <div className={`mt-2 text-xs font-semibold ${testStatus.startsWith('✅') ? 'text-emerald-700' : 'text-rose-700'}`}>
                {testStatus}
              </div>
            )}
          </div>
        </div>

        {/* Live Preview Column */}
        <div className="space-y-4">
          {/* Android Status Bar Preview */}
          <div className="bg-white rounded-xl p-5 shadow-sm border border-slate-200/80">
            <h3 className="font-bold text-slate-900 mb-3 flex items-center gap-2 text-sm">
              <Phone size={15} className="text-primary" /> Android Push Preview
            </h3>

            <div className="bg-slate-950 rounded-xl p-3.5 space-y-2 text-white border border-slate-800">
              <div className="bg-slate-900/90 rounded-lg p-3 border border-slate-800 shadow-sm">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-1.5">
                    <div className="w-4 h-4 rounded bg-primary flex items-center justify-center text-[9px] font-bold text-white">
                      SG
                    </div>
                    <span className="text-white/70 text-[11px] font-semibold">Status Go · now</span>
                  </div>
                  <span className="text-[10px] text-white/40">via OneSignal</span>
                </div>

                <div className="text-white text-xs font-bold mb-1 font-devanagari leading-snug">
                  {form.title || '🙏 आज का स्टेटस तैयार है!'}
                </div>
                <div className="text-white/80 text-[11px] leading-relaxed font-devanagari">
                  {form.body || 'नए devotional और motivational status देखें। अभी share करें!'}
                </div>

                {form.imageUrl && (
                  <div className="mt-2.5 rounded-md overflow-hidden h-28 bg-slate-800 flex items-center justify-center">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={form.imageUrl}
                      alt="Banner Preview"
                      className="w-full h-full object-cover"
                      onError={e => {
                        (e.target as any).style.display = 'none';
                      }}
                    />
                  </div>
                )}
              </div>
            </div>

            {/* In-App Notification Center Card Preview */}
            <div className="mt-4 pt-4 border-t border-slate-200/80">
              <h3 className="font-bold text-slate-800 mb-2 flex items-center gap-2 text-xs">
                <Layers size={14} className="text-primary" /> Mobile In-App Inbox Preview
              </h3>

              <div className="border border-slate-200/80 rounded-lg p-3 bg-slate-50/50 hover:bg-slate-50 transition-colors">
                <div className="flex items-start gap-2.5">
                  <div className="w-7 h-7 rounded-full bg-primary/10 text-primary flex items-center justify-center shrink-0 text-xs">
                    {form.notifType === 'DAILY_STATUS' ? '🙏' : form.notifType === 'FESTIVAL_ALERT' ? '🎉' : form.notifType === 'PREMIUM_OFFER' ? '⭐' : '📢'}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-slate-900 truncate font-devanagari">
                        {form.title || 'सुप्रभात स्टेटस'}
                      </span>
                      <span className="text-[10px] text-slate-400">अभी</span>
                    </div>
                    <p className="text-[11px] text-slate-600 mt-0.5 line-clamp-2 font-devanagari">
                      {form.body || 'नए devotional status देखें...'}
                    </p>
                    {form.deepLink && (
                      <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-primary mt-1">
                        खोलें <ArrowRight size={10} />
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Target Summary */}
            <div className="mt-4 pt-4 border-t border-slate-200/80">
              <div className="text-[11px] font-semibold text-slate-500 mb-1.5 uppercase tracking-wider">Selected Target Audience</div>
              <div className="flex items-center gap-2.5 bg-slate-50 p-2.5 rounded-lg border border-slate-200/80">
                <span className="text-lg">{selectedSegment?.icon}</span>
                <div>
                  <div className="text-xs font-bold text-slate-800">{selectedSegment?.label}</div>
                  <div className="text-[11px] text-slate-500">{selectedSegment?.description}</div>
                </div>
              </div>
            </div>
          </div>

          {/* Delivery Tips */}
          <div className="bg-blue-50/60 rounded-xl p-4 border border-blue-100">
            <div className="text-xs font-bold text-blue-900 mb-2 flex items-center gap-1.5">
              💡 Engagement Insights
            </div>
            <ul className="space-y-1.5 text-xs text-slate-600">
              <li>• <strong className="font-semibold text-slate-800">Morning Window:</strong> 7:00 AM – 9:00 AM IST gives highest WhatsApp status shares</li>
              <li>• <strong className="font-semibold text-slate-800">Festivals:</strong> Send 24–48 hours prior to festival day</li>
              <li>• <strong className="font-semibold text-slate-800">Devanagari text:</strong> Directly renders in clean font on all 40+ user devices</li>
              <li>• <strong className="font-semibold text-slate-800">Deep links:</strong> Directs users straight into the right screen without search</li>
            </ul>
          </div>
        </div>
      </div>

      {/* Campaign History */}
      {isHistoryError ? (
        <QueryError error={historyError} onRetry={() => refetch()} title="Failed to load campaign history" />
      ) : (
      <div className="bg-white rounded-xl border border-slate-200/80 shadow-sm overflow-hidden">
        <div className="p-4 border-b border-slate-200/80 flex justify-between items-center bg-slate-50/50">
          <h2 className="text-sm font-bold text-slate-900 flex items-center gap-2">
            <Clock size={16} className="text-slate-500" /> Recent Broadcast Campaigns
          </h2>
          <span className="text-xs text-slate-500 font-medium">
            {(history?.data || []).length} Campaigns Recorded
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full data-table">
            <thead className="bg-slate-50 text-left border-b border-slate-200">
              <tr>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600">Title & Message</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600">Target</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600 text-center">Status</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600 text-center">OneSignal ID</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600 text-right">Sent / Scheduled</th>
                <th className="py-2.5 px-4 text-xs font-semibold text-slate-600 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {(history?.data || []).map((camp: any) => (
                <tr key={camp.id} className="border-t border-slate-100 hover:bg-slate-50/70 transition-colors">
                  <td className="py-3 px-4">
                    <div className="font-semibold text-xs text-slate-800 font-devanagari">{camp.title}</div>
                    <div className="text-[11px] text-slate-500 truncate max-w-sm font-devanagari mt-0.5">{camp.body}</div>
                    {camp.deepLink && (
                      <span className="text-[10px] text-primary font-medium mt-0.5 inline-block">
                        Link: {camp.deepLink}
                      </span>
                    )}
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-xs font-medium bg-slate-100 px-2 py-0.5 rounded inline-block text-slate-700 border border-slate-200/80">
                      {SEGMENTS.find(s => s.key === camp.targetSegment)?.label || camp.targetSegment}
                    </div>
                  </td>
                  <td className="py-3 px-4 text-center">
                    <span className={`text-[11px] font-semibold px-2.5 py-0.5 rounded-full ${
                      camp.status === 'sent'
                        ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                        : 'bg-amber-50 text-amber-700 border border-amber-200'
                    }`}>
                      {String(camp.status ?? '').toUpperCase()}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-center">
                    <span className="text-[11px] font-mono text-slate-500 bg-slate-100 px-2 py-0.5 rounded">
                      {camp.oneSignalId ? camp.oneSignalId.slice(0, 14) + '...' : 'simulated'}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-right text-xs text-slate-500 tabular-nums">
                    {new Date(camp.scheduledAt || camp.sentAt || camp.createdAt).toLocaleString('en-IN', {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    })}
                  </td>
                  <td className="py-3 px-4 text-right">
                    <button
                      onClick={() => {
                        setForm({
                          title: camp.title,
                          body: camp.body,
                          imageUrl: camp.imageUrl || '',
                          deepLink: camp.deepLink || '',
                          targetSegment: camp.targetSegment || 'all',
                          notifType: 'NEW_CONTENT',
                          scheduledAt: '',
                        });
                        window.scrollTo({ top: 0, behavior: 'smooth' });
                      }}
                      className="text-xs text-primary hover:underline font-semibold"
                    >
                      Copy
                    </button>
                  </td>
                </tr>
              ))}
              {(!history?.data || history.data.length === 0) && (
                <tr>
                  <td colSpan={6} className="text-center py-8 text-slate-400 text-xs">
                    No broadcast campaigns sent yet. Use the composer above to initiate your first campaign!
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
      )}
    </div>
  );
}
