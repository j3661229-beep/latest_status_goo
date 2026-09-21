'use client';

import { useState, useEffect } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { Upload, CheckCircle, Image, Video, ChevronRight, ChevronLeft, Send, AlertCircle, Crosshair } from 'lucide-react';
import { creatorApi } from '@/lib/api';
import { uploadToCloudinary } from '@/lib/cloudinary';

type Step = 1 | 2 | 3;

const STEPS = [
  { step: 1, label: 'Details' },
  { step: 2, label: 'Upload & Overlay' },
  { step: 3, label: 'Review & Submit' },
];

const defaultForm = {
  type: 'IMAGE' as 'IMAGE' | 'VIDEO',
  categoryId: '',
  primaryLanguage: 'HINDI',
  nameHi: '', nameMr: '', nameEn: '',
  quoteHi: '', quoteMr: '', quoteEn: '',
  tags: '',
  photoZoneEnabled: false,
  photoZoneX: 0.5, photoZoneY: 0.25, photoZoneSize: 0.2, photoZoneShape: 'circle',
  nameZoneEnabled: true,
  nameZoneX: 0.5, nameZoneY: 0.75,
  gradient: 'linear-gradient(135deg, #2563EB 0%, #0EA5E9 100%)',
  imageFile: null as File | null,
  isPremium: false,
};

// ── Step Indicator ──────────────────────────────────────────
function StepIndicator({ current }: { current: Step }) {
  return (
    <div className="flex items-center justify-center gap-2 mb-8">
      {STEPS.map(({ step, label }) => {
        const done = step < current;
        const active = step === current;
        return (
          <div key={step} className="flex items-center gap-2">
            <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-800 transition-all ${
              done ? 'bg-success text-white' :
              active ? 'bg-primary text-white shadow-sm' :
              'bg-surface-border text-muted'
            }`}>
              {done ? <CheckCircle size={12} /> : <span>{step}</span>}
              {(done || active) && <span>{label}</span>}
            </div>
            {step < 3 && <div className={`w-8 h-0.5 ${step < current ? 'bg-success' : 'bg-surface-border'}`} />}
          </div>
        );
      })}
    </div>
  );
}

// ── Live Phone Preview ──────────────────────────────────────
function PhonePreview({ form }: { form: typeof defaultForm }) {
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => {
    if (form.imageFile) {
      const isVideo = form.type === 'VIDEO';
      const url = URL.createObjectURL(form.imageFile);
      setPreviewUrl(url);
      return () => URL.revokeObjectURL(url);
    } else {
      setPreviewUrl(null);
    }
  }, [form.imageFile, form.type]);

  return (
    <div className="sticky top-0">
      <h3 className="font-800 text-slate-800 mb-3 text-sm">📱 Live Preview</h3>
      <div className="relative mx-auto w-44">
        {/* Phone frame */}
        <div className="bg-slate-900 rounded-[32px] p-3 shadow-2xl">
          {/* Screen */}
          <div className="rounded-[24px] overflow-hidden bg-black aspect-[9/16] relative"
            style={{ 
              background: previewUrl && form.type === 'IMAGE' ? `url(${previewUrl}) center/cover no-repeat` : form.gradient 
            }}>
            {previewUrl && form.type === 'VIDEO' && (
              <video 
                src={previewUrl} 
                autoPlay loop muted playsInline 
                className="absolute inset-0 w-full h-full object-cover" 
              />
            )}
            {/* Mock WhatsApp status header */}
            <div className="absolute top-2 left-2 right-2 flex items-center gap-1.5">
              <div className="flex-1 h-0.5 bg-white/50 rounded-full" />
              <div className="flex-1 h-0.5 bg-white/30 rounded-full" />
              <div className="flex-1 h-0.5 bg-white/30 rounded-full" />
            </div>

            {/* Photo zone */}
            {form.photoZoneEnabled && (
              <div
                className="absolute border-2 border-white/80 border-dashed rounded-full flex items-center justify-center"
                style={{
                  left: `${(form.photoZoneX - form.photoZoneSize / 2) * 100}%`,
                  top: `${(form.photoZoneY - form.photoZoneSize / 2) * 100}%`,
                  width: `${form.photoZoneSize * 100}%`,
                  aspectRatio: '1',
                }}
              >
                <span className="text-white/60 text-[8px] font-800 text-center leading-tight">Photo<br/>Zone</span>
              </div>
            )}

            {/* Name zone */}
            {form.nameZoneEnabled && (
              <div
                className="absolute text-white font-900 text-center transform -translate-x-1/2"
                style={{
                  left: `${form.nameZoneX * 100}%`,
                  top: `${form.nameZoneY * 100}%`,
                  fontSize: '9px',
                  textShadow: '0 1px 4px rgba(0,0,0,0.5)',
                }}
              >
                {form.nameHi || 'टेम्पलेट का नाम'}
              </div>
            )}

            {/* Content */}
            <div className="absolute inset-x-4 bottom-8 text-center">
              {form.quoteHi && (
                <p className="text-white text-[7px] font-600 leading-relaxed"
                  style={{ textShadow: '0 1px 4px rgba(0,0,0,0.5)' }}>
                  {form.quoteHi.slice(0, 60)}...
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
      <div className="mt-3 text-center text-xs text-muted">1080×1920px (9:16 ratio)</div>
    </div>
  );
}

// ── Main Upload Page ──────────────────────────────────────────
export default function UploadTemplatePage() {
  const [step, setStep] = useState<Step>(1);
  const [form, setForm] = useState(defaultForm);
  const [dragging, setDragging] = useState(false);
  const [submitOk, setSubmitOk] = useState(false);

  const { data: categoriesData, isLoading: categoriesLoading } = useQuery({
    queryKey: ['categories'],
    queryFn: () =>
      fetch(`${process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000/api/v1'}/categories`)
        .then(r => r.json()),
    staleTime: 10 * 60 * 1000,
  });
  // Categories come ONLY from the real DB — never use fake hardcoded IDs
  const CATEGORIES: { id: string; label: string }[] = (categoriesData?.data ?? []).map((c: any) => ({
    id: c.id,
    label: `${c.emoji || ''} ${c.nameEn} / ${c.nameHi}`.trim(),
  }));

  const uploadMutation = useMutation({
    mutationFn: async (formData: typeof defaultForm) => {
      const defaultName = formData.nameHi || `Status_${Date.now()}`;
      // 1. Create DRAFT template
      const res1 = await creatorApi.createTemplate({
        type: formData.type,
        categoryId: formData.categoryId,
        gradient: formData.gradient,
        tags: formData.tags.split(',').map(s => s.trim()).filter(Boolean),
      });

      const templateId = res1.template.id;

      // 2. Upload to GCS via backend API
      let imageUrl = '';
      let videoUrl = '';
      let videoThumbUrl = '';
      let videoDuration = 0;

      if (formData.imageFile) {
        let uploadRes: { url: string; duration?: number };
        try {
          uploadRes = await creatorApi.uploadTemplateMedia(formData.imageFile);
        } catch {
          // Fallback to Cloudinary if backend upload fails
          const signData = await creatorApi.getCloudinarySignature({ 
            folder: 'templates'
          });
          uploadRes = await uploadToCloudinary(formData.imageFile, signData);
        }
        
        if (formData.type === 'IMAGE') {
          imageUrl = uploadRes.url;
        } else {
          videoUrl = uploadRes.url;
          videoThumbUrl = uploadRes.url.replace(/\.[^.]+$/, '.jpg');
          videoDuration = uploadRes.duration || 0;
        }
      }

      // 3. Update all metadata onto it
      await creatorApi.updateTemplate(templateId, {
        nameHi: defaultName, nameMr: defaultName, nameEn: defaultName,
        quoteHi: formData.quoteHi, quoteMr: formData.quoteHi, quoteEn: formData.quoteHi,
        tags: [],
        isPremium: formData.isPremium,
        photoZoneEnabled: formData.photoZoneEnabled,
        photoZoneX: formData.photoZoneX, photoZoneY: formData.photoZoneY,
        photoZoneSize: formData.photoZoneSize, photoZoneShape: formData.photoZoneShape,
        nameZoneEnabled: formData.nameZoneEnabled,
        nameZoneX: formData.nameZoneX, nameZoneY: formData.nameZoneY,
        gradient: formData.gradient,
        imageUrl,
        videoUrl,
        videoThumbUrl,
        videoDuration,
      });

      // 4. Submit for review
      await creatorApi.submitTemplate(templateId);
      return templateId;
    },
    onSuccess: () => {
      setSubmitOk(true);
    },
    onError: (err: any) => {
      alert('Upload failed: ' + err.message);
    }
  });

  const update = (partial: Partial<typeof defaultForm>) =>
    setForm(f => ({ ...f, ...partial }));

  const canProceed = () => {
    if (step === 1) return !!form.categoryId;
    if (step === 2) return true;
    return true;
  };

  const handleFileChange = (file: File) => {
    const isVideo = file.type.startsWith('video/');
    update({ imageFile: file, type: isVideo ? 'VIDEO' : 'IMAGE' });
  };

  const handleSubmit = () => {
    uploadMutation.mutate(form);
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-900 text-slate-800">Upload Template</h1>
        <p className="text-muted text-sm mt-1">
          Complete all 3 steps to submit your template for review
        </p>
      </div>

      <StepIndicator current={step} />

      <div className="grid grid-cols-3 gap-6">
        {/* Form Area */}
        <div className="col-span-2 bg-white rounded-2xl p-6 shadow-card border border-surface-border">

          {/* STEP 1: Details */}
          {step === 1 && (
            <div className="space-y-5">
              <h2 className="font-800 text-slate-800 text-base">Step 1: Details</h2>

              {/* Template Type */}
              <div>
                <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-3 block">Template Type</label>
                <div className="flex gap-3">
                  {(['IMAGE', 'VIDEO'] as const).map(t => (
                    <button key={t} onClick={() => update({ type: t })}
                      className={`flex items-center gap-2 px-5 py-3 rounded-xl border-2 font-800 text-sm transition-all ${
                        form.type === t ? 'border-primary bg-primary/5 text-primary' : 'border-surface-border text-muted hover:border-slate-300'
                      }`}>
                      {t === 'IMAGE' ? <Image size={16} /> : <Video size={16} />}
                      {t}
                      {t === 'VIDEO' && <span className="text-[10px] bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full ml-1">PREMIUM</span>}
                    </button>
                  ))}
                </div>
              </div>

              {/* Category */}
              <div>
                <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-3 block">Category *</label>
                <div className="grid grid-cols-2 gap-2">
                  {CATEGORIES.map(cat => (
                    <button key={cat.id} onClick={() => update({ categoryId: cat.id })}
                      className={`text-left px-4 py-3 rounded-xl border text-sm font-700 transition-all ${
                        form.categoryId === cat.id
                          ? 'border-primary bg-primary/5 text-primary'
                          : 'border-surface-border text-slate-700 hover:border-slate-300'
                      }`}>
                      {cat.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Gradient picker */}
              <div>
                <label className="text-xs font-700 text-slate-600 uppercase tracking-wide mb-3 block">Background Gradient</label>
                <div className="flex gap-2 flex-wrap">
                  {[
                    'linear-gradient(135deg, #2563EB 0%, #0EA5E9 100%)',
                    'linear-gradient(135deg, #1D4ED8 0%, #3B82F6 100%)',
                    'linear-gradient(135deg, #0284C7 0%, #38BDF8 100%)',
                    'linear-gradient(135deg, #0F172A 0%, #2563EB 100%)',
                    'linear-gradient(135deg, #F7971E 0%, #FFD200 100%)',
                    'linear-gradient(135deg, #10B981 0%, #2DD4BF 100%)',
                    'linear-gradient(135deg, #FF6B9D 0%, #FFB347 100%)',
                    'linear-gradient(135deg, #EF4444 0%, #F97316 100%)',
                  ].map(g => (
                    <button key={g} onClick={() => update({ gradient: g })}
                      className={`w-10 h-10 rounded-lg transition-transform ${form.gradient === g ? 'ring-2 ring-offset-2 ring-primary scale-110' : 'hover:scale-105'}`}
                      style={{ background: g }}
                    />
                  ))}
                </div>
              </div>

              {/* isPremium */}
              <label className="flex items-center gap-3 cursor-pointer">
                <div className={`w-11 h-6 rounded-full transition-colors relative ${form.isPremium ? 'bg-amber-400' : 'bg-slate-200'}`}
                  onClick={() => update({ isPremium: !form.isPremium })}>
                  <div className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${form.isPremium ? 'translate-x-5' : ''}`} />
                </div>
                <span className="text-sm font-700 text-slate-700">⭐ Premium Template</span>
                <span className="text-xs text-muted">(Paid users only)</span>
              </label>
            </div>
          )}

          {/* STEP 2: Upload & Overlay */}
          {step === 2 && (
            <div className="space-y-5">
              <h2 className="font-800 text-slate-800 text-base">Step 2: Upload & Configure Overlay Zones</h2>

              {/* Upload Zone */}
              <div
                className={`upload-zone ${dragging ? 'border-primary bg-primary/5' : ''}`}
                onDragOver={e => { e.preventDefault(); setDragging(true); }}
                onDragLeave={() => setDragging(false)}
                onDrop={e => { e.preventDefault(); setDragging(false); const f = e.dataTransfer.files[0]; if (f) handleFileChange(f); }}
                onClick={() => document.getElementById('template-upload')?.click()}
              >
                <Upload size={32} className="text-primary/50 mb-3" />
                <div className="font-800 text-slate-700 mb-1">
                  {form.imageFile ? '✅ ' + form.imageFile.name : 'Drop file here or click to upload'}
                </div>
                <div className="text-xs text-muted">
                  {form.type === 'IMAGE' ? 'JPG / PNG / WebP — 1080×1920px — max 5MB' : 'MP4 — 1080×1920px — max 50MB — max 30s'}
                </div>
                <input type="file" id="template-upload" className="hidden"
                  accept={form.type === 'IMAGE' ? 'image/*' : 'video/mp4'}
                  onChange={e => { const f = e.target.files?.[0]; if (f) handleFileChange(f); }}
                />
              </div>

              {/* Overlay Configuration */}
              <div className="border border-surface-border rounded-xl p-4 space-y-4">
                <div className="font-800 text-slate-700 text-sm flex items-center gap-2">
                  <Crosshair size={16} className="text-primary" />
                  Overlay Zone Configuration
                </div>

                {/* Photo Zone */}
                <label className="flex items-center gap-3 cursor-pointer">
                  <div className={`w-10 h-5 rounded-full transition-colors relative ${form.photoZoneEnabled ? 'bg-primary' : 'bg-slate-200'}`}
                    onClick={() => update({ photoZoneEnabled: !form.photoZoneEnabled })}>
                    <div className={`absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform ${form.photoZoneEnabled ? 'translate-x-5' : ''}`} />
                  </div>
                  <span className="text-sm font-700 text-slate-700">📸 Photo Zone (user's face photo)</span>
                </label>

                {form.photoZoneEnabled && (
                  <div className="grid grid-cols-2 gap-3 pl-4">
                    {[
                      { label: 'Position X (0–1)', key: 'photoZoneX', min: 0, max: 1, step: 0.05 },
                      { label: 'Position Y (0–1)', key: 'photoZoneY', min: 0, max: 1, step: 0.05 },
                      { label: 'Size (0–1)', key: 'photoZoneSize', min: 0.05, max: 0.5, step: 0.05 },
                    ].map(({ label, key, min, max, step }) => (
                      <div key={key}>
                        <label className="text-xs text-muted font-600 mb-1 block">{label}: {(form as any)[key]}</label>
                        <input type="range" min={min} max={max} step={step}
                          value={(form as any)[key]}
                          onChange={e => update({ [key]: parseFloat(e.target.value) } as any)}
                          className="w-full accent-primary"
                        />
                      </div>
                    ))}
                  </div>
                )}

                {/* Name Zone */}
                <label className="flex items-center gap-3 cursor-pointer">
                  <div className={`w-10 h-5 rounded-full transition-colors relative ${form.nameZoneEnabled ? 'bg-primary' : 'bg-slate-200'}`}
                    onClick={() => update({ nameZoneEnabled: !form.nameZoneEnabled })}>
                    <div className={`absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform ${form.nameZoneEnabled ? 'translate-x-5' : ''}`} />
                  </div>
                  <span className="text-sm font-700 text-slate-700">✏️ Name Zone (user's display name)</span>
                </label>

                {form.nameZoneEnabled && (
                  <div className="grid grid-cols-2 gap-3 pl-4">
                    {[
                      { label: 'Name X (0–1)', key: 'nameZoneX', min: 0, max: 1, step: 0.05 },
                      { label: 'Name Y (0–1)', key: 'nameZoneY', min: 0, max: 1, step: 0.05 },
                    ].map(({ label, key, min, max, step }) => (
                      <div key={key}>
                        <label className="text-xs text-muted font-600 mb-1 block">{label}: {(form as any)[key]}</label>
                        <input type="range" min={min} max={max} step={step}
                          value={(form as any)[key]}
                          onChange={e => update({ [key]: parseFloat(e.target.value) } as any)}
                          className="w-full accent-primary"
                        />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* STEP 3: Review & Submit */}
          {step === 3 && (
            <div className="space-y-5">
              <h2 className="font-800 text-slate-800 text-base">Step 3: Review & Submit</h2>

              {submitOk ? (
                <div className="text-center py-12">
                  <div className="text-6xl mb-4">🎉</div>
                  <div className="font-900 text-xl text-slate-800 mb-2">Template Submitted!</div>
                  <p className="text-muted text-sm mb-6">Your template has been submitted for admin review. You'll get a push notification once it's reviewed (usually within 24 hours).</p>
                  <button onClick={() => { setStep(1); setForm(defaultForm); setSubmitOk(false); }}
                    className="btn-primary">Upload Another Template</button>
                </div>
              ) : (
                <>
                  {/* Summary */}
                  <div className="bg-surface rounded-2xl p-5 space-y-4">
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div><span className="text-muted font-600">Type:</span> <span className="font-800 text-slate-700 ml-2">{form.type}</span></div>
                      <div><span className="text-muted font-600">Category:</span> <span className="font-800 text-slate-700 ml-2">{CATEGORIES.find(c => c.id === form.categoryId)?.label ?? '—'}</span></div>
                      <div><span className="text-muted font-600">Premium:</span> <span className="font-800 text-slate-700 ml-2">{form.isPremium ? 'Yes ⭐' : 'No (Free)'}</span></div>
                      <div><span className="text-muted font-600">Photo Zone:</span> <span className="font-800 text-slate-700 ml-2">{form.photoZoneEnabled ? '✅ Enabled' : '❌ Disabled'}</span></div>
                    </div>
                    <hr className="border-surface-border" />
                    <div className="space-y-2 text-sm">
                      <div><span className="text-muted">Will use auto-generated name</span></div>
                    </div>
                  </div>

                  {/* Checklist */}
                  <div className="space-y-2">
                    {[
                      { ok: !!form.categoryId, label: 'Category selected' },
                      { ok: form.nameZoneEnabled, label: 'Name overlay zone configured' },
                    ].map(({ ok, label }) => (
                      <div key={label} className={`flex items-center gap-2 text-sm ${ok ? 'text-success' : 'text-danger'}`}>
                        <CheckCircle size={14} />
                        <span className="font-700">{label}</span>
                        {!ok && <span className="text-xs ml-1">(required)</span>}
                      </div>
                    ))}
                  </div>

                  <button 
                    onClick={handleSubmit} 
                    disabled={uploadMutation.isPending}
                    className="btn-primary w-full flex items-center justify-center gap-2 py-3 text-base disabled:opacity-60 disabled:cursor-wait"
                  >
                    {uploadMutation.isPending ? (
                      <div className="w-5 h-5 border-3 border-white/30 border-t-white rounded-full animate-spin" />
                    ) : (
                      <Send size={16} />
                    )}
                    {uploadMutation.isPending ? 'Submitting Template...' : 'Submit for Review'}
                  </button>
                  <p className="text-xs text-muted text-center">You'll receive a push notification when your template is reviewed (typically within 24 hours)</p>
                </>
              )}
            </div>
          )}

          {/* Navigation */}
          {!submitOk && (
            <div className="flex justify-between mt-8 pt-6 border-t border-surface-border">
              <button onClick={() => setStep(s => (s > 1 ? (s - 1) as Step : s))}
                disabled={step === 1}
                className="btn-ghost flex items-center gap-2 disabled:opacity-30 disabled:cursor-not-allowed">
                <ChevronLeft size={14} /> Previous
              </button>
              {step < 3 ? (
                <button onClick={() => setStep(s => (s < 3 ? (s + 1) as Step : s))}
                  disabled={!canProceed()}
                  className="btn-primary flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed">
                  Next <ChevronRight size={14} />
                </button>
              ) : null}
            </div>
          )}
        </div>

        {/* Live Preview */}
        <PhonePreview form={form} />
      </div>
    </div>
  );
}
