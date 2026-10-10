'use client';

import { Suspense, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Upload, CheckCircle, Image, Video, ChevronRight, ChevronLeft, Send, AlertCircle, Crosshair, Clock,
} from 'lucide-react';
import { creatorApi } from '@/lib/api';
import { uploadToCloudinary } from '@/lib/cloudinary';
import { getErrorMessage, getStatusConfig, isRetryableError } from '@/lib/utils';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';
import TemplateEditor, { type ZoneConfig } from '@/components/TemplateEditor';

type Step = 1 | 2 | 3;
type FitMode = 'contain' | 'cover';

const STEPS = [
  { step: 1, label: 'Details' },
  { step: 2, label: 'Upload & Overlay' },
  { step: 3, label: 'Review & Submit' },
];

// Must match backend /upload/template allow-list.
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const VIDEO_TYPES = ['video/mp4'];
const IMAGE_MAX_BYTES = 10 * 1024 * 1024;
const VIDEO_MAX_BYTES = 50 * 1024 * 1024;
const EDITABLE_STATUSES = ['DRAFT', 'REJECTED'];
const SAMPLE_NAME = 'आपका नाम';

const GRADIENTS = [
  'linear-gradient(135deg, #2563EB 0%, #0EA5E9 100%)',
  'linear-gradient(135deg, #1D4ED8 0%, #3B82F6 100%)',
  'linear-gradient(135deg, #0284C7 0%, #38BDF8 100%)',
  'linear-gradient(135deg, #0F172A 0%, #2563EB 100%)',
  'linear-gradient(135deg, #F7971E 0%, #FFD200 100%)',
  'linear-gradient(135deg, #10B981 0%, #2DD4BF 100%)',
  'linear-gradient(135deg, #FF6B9D 0%, #FFB347 100%)',
  'linear-gradient(135deg, #EF4444 0%, #F97316 100%)',
];

const defaultZones: ZoneConfig = {
  photo: { enabled: false, x: 0.5, y: 0.25, size: 0.2, shape: 'circle' },
  name: { enabled: true, x: 0.5, y: 0.75, fontSize: 0.04, color: '#ffffff', font: 'Nunito' },
};

const defaultForm = {
  type: 'IMAGE' as 'IMAGE' | 'VIDEO',
  categoryId: '',
  nameHi: '', nameMr: '', nameEn: '',
  quoteHi: '', quoteMr: '', quoteEn: '',
  tags: '',
  gradient: GRADIENTS[0],
  imageFile: null as File | null,
  fitMode: 'contain' as FitMode,
  zones: defaultZones,
};
type FormState = typeof defaultForm;

const inputCls =
  'w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 bg-white';
const labelCls = 'text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2 block';

const parseTags = (s: string) => s.split(',').map(t => t.trim()).filter(Boolean);
const orNull = (s: string) => (s.trim() ? s.trim() : null);

function validateFile(file: File): string | null {
  if (IMAGE_TYPES.includes(file.type)) {
    return file.size > IMAGE_MAX_BYTES ? 'Images must be 10 MB or smaller.' : null;
  }
  if (VIDEO_TYPES.includes(file.type)) {
    return file.size > VIDEO_MAX_BYTES ? 'Videos must be 50 MB or smaller.' : null;
  }
  return 'Unsupported file type. Use JPEG, PNG or WebP images, or MP4 video.';
}

/** Map a template from the API into wizard form state (edit mode). */
function templateToForm(t: any): FormState {
  return {
    type: t.type === 'VIDEO' ? 'VIDEO' : 'IMAGE',
    categoryId: t.categoryId ?? '',
    nameHi: t.nameHi ?? '', nameMr: t.nameMr ?? '', nameEn: t.nameEn ?? '',
    quoteHi: t.quoteHi ?? '', quoteMr: t.quoteMr ?? '', quoteEn: t.quoteEn ?? '',
    tags: (t.tags ?? []).join(', '),
    gradient: t.gradient || GRADIENTS[0],
    imageFile: null,
    fitMode: t.fitMode === 'cover' ? 'cover' : 'contain',
    zones: {
      photo: {
        enabled: !!t.photoZoneEnabled,
        x: t.photoZoneX ?? defaultZones.photo.x,
        y: t.photoZoneY ?? defaultZones.photo.y,
        size: t.photoZoneSize ?? defaultZones.photo.size,
        shape: (['circle', 'square', 'rounded'].includes(t.photoZoneShape) ? t.photoZoneShape : 'circle'),
      },
      name: {
        enabled: !!t.nameZoneEnabled,
        x: t.nameZoneX ?? defaultZones.name.x,
        y: t.nameZoneY ?? defaultZones.name.y,
        fontSize: t.nameFontSize ?? defaultZones.name.fontSize,
        color: t.nameColor ?? defaultZones.name.color,
        font: t.nameFont ?? defaultZones.name.font,
      },
    },
  };
}

// ── Step Indicator ──────────────────────────────────────────
function StepIndicator({ current }: { current: Step }) {
  return (
    <div className="flex items-center justify-center gap-2 mb-6">
      {STEPS.map(({ step, label }) => {
        const done = step < current;
        const active = step === current;
        return (
          <div key={step} className="flex items-center gap-2">
            <div
              className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold transition-all ${
                done
                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                  : active
                  ? 'bg-blue-600 text-white shadow-sm'
                  : 'bg-slate-100 text-slate-400 border border-slate-200'
              }`}
            >
              {done ? <CheckCircle size={12} /> : <span>{step}</span>}
              <span>{label}</span>
            </div>
            {step < 3 && (
              <div className={`w-8 h-0.5 ${step < current ? 'bg-emerald-400' : 'bg-slate-200'}`} />
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Live Phone Preview ──────────────────────────────────────
function PhonePreview({
  form,
  existingMediaUrl,
  onUpdate,
}: {
  form: FormState;
  existingMediaUrl: string | null;
  onUpdate?: (partial: Partial<FormState>) => void;
}) {
  const [objectUrl, setObjectUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!form.imageFile) {
      setObjectUrl(null);
      return;
    }
    const url = URL.createObjectURL(form.imageFile);
    setObjectUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [form.imageFile]);

  const previewUrl = objectUrl ?? existingMediaUrl;
  const fitMode = form.fitMode || 'contain';
  const { photo, name } = form.zones;
  const quote = form.quoteHi || form.quoteMr || form.quoteEn;

  return (
    <div className="sticky top-6">
      {/* Header with Title & Fit Toggle */}
      <div className="flex items-center justify-between mb-3 px-1">
        <h3 className="font-semibold text-slate-800 text-sm flex items-center gap-1.5">
          <span>📱</span> Live Preview
        </h3>
        {previewUrl && (
          <div className="flex bg-slate-100 p-0.5 rounded-lg text-[11px] font-semibold border border-slate-200">
            {(['contain', 'cover'] as const).map(mode => (
              <button
                key={mode}
                type="button"
                onClick={() => onUpdate?.({ fitMode: mode })}
                className={`px-2.5 py-0.5 rounded-md transition-all ${
                  fitMode === mode ? 'bg-white text-blue-600 shadow-sm font-semibold' : 'text-slate-500 hover:text-slate-700'
                }`}
              >
                {mode === 'contain' ? 'Fit (No Crop)' : 'Fill (9:16)'}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="relative mx-auto w-52 transition-all">
        <div className="bg-slate-900 rounded-[34px] p-3 shadow-2xl ring-1 ring-slate-800/80">
          <div className="relative z-20 flex justify-center mb-1.5">
            <div className="w-16 h-3 bg-black rounded-full" />
          </div>

          <div className="rounded-[24px] overflow-hidden bg-slate-950 aspect-[9/16] relative flex items-center justify-center">
            {previewUrl ? (
              form.type === 'IMAGE' ? (
                fitMode === 'cover' ? (
                  <img src={previewUrl} alt="Template preview" className="absolute inset-0 w-full h-full object-cover" />
                ) : (
                  <>
                    <div
                      className="absolute inset-0 bg-cover bg-center filter blur-xl scale-125 opacity-55"
                      style={{ backgroundImage: `url(${previewUrl})` }}
                    />
                    <div className="absolute inset-0 bg-black/30 backdrop-blur-xs" />
                    <img src={previewUrl} alt="Template preview" className="relative z-0 max-w-full max-h-full object-contain drop-shadow-md" />
                  </>
                )
              ) : fitMode === 'cover' ? (
                <video src={previewUrl} autoPlay loop muted playsInline className="absolute inset-0 w-full h-full object-cover" />
              ) : (
                <>
                  <div className="absolute inset-0" style={{ background: form.gradient }} />
                  <div className="absolute inset-0 bg-black/30" />
                  <video src={previewUrl} autoPlay loop muted playsInline className="relative z-0 max-w-full max-h-full object-contain" />
                </>
              )
            ) : (
              <div className="absolute inset-0 w-full h-full" style={{ background: form.gradient }} />
            )}

            {/* Mock WhatsApp status header */}
            <div className="absolute top-2 left-2 right-2 flex items-center gap-1.5 z-10">
              <div className="flex-1 h-0.5 bg-white/70 rounded-full" />
              <div className="flex-1 h-0.5 bg-white/40 rounded-full" />
              <div className="flex-1 h-0.5 bg-white/40 rounded-full" />
            </div>

            {photo.enabled && (
              <div
                className="absolute border-2 border-white/90 border-dashed flex items-center justify-center z-10 shadow-sm bg-black/15"
                style={{
                  left: `${(photo.x - photo.size / 2) * 100}%`,
                  top: `${(photo.y - photo.size / 2) * 100}%`,
                  width: `${photo.size * 100}%`,
                  aspectRatio: '1',
                  borderRadius: photo.shape === 'circle' ? '50%' : photo.shape === 'rounded' ? '16%' : '4px',
                }}
              >
                <span className="text-white text-[8px] font-extrabold text-center leading-tight drop-shadow">Photo<br />Zone</span>
              </div>
            )}

            {/* Name zone shows where the *user's* name is rendered */}
            {name.enabled && (
              <div
                className="absolute font-bold text-center transform -translate-x-1/2 z-10 whitespace-nowrap"
                style={{
                  left: `${name.x * 100}%`,
                  top: `${name.y * 100}%`,
                  fontSize: '10px',
                  color: name.color,
                  fontFamily: `"${name.font}", sans-serif`,
                  textShadow: '0 1px 4px rgba(0,0,0,0.8)',
                }}
              >
                {SAMPLE_NAME}
              </div>
            )}

            <div className="absolute inset-x-3 bottom-6 text-center z-10">
              {quote && (
                <p className="text-white text-[8px] font-semibold leading-relaxed drop-shadow-md line-clamp-2">{quote}</p>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="mt-3 text-center text-xs text-muted flex items-center justify-center gap-1.5">
        <span>1080×1920px (9:16)</span>
        <span>•</span>
        <span className={fitMode === 'contain' ? 'text-blue-600 font-bold' : 'text-slate-500'}>
          {fitMode === 'contain' ? 'Full Image Visible (No Crop)' : 'Filled (Cover)'}
        </span>
      </div>
    </div>
  );
}

// ── Page wrapper (useSearchParams needs Suspense in Next 15) ─────────
export default function UploadTemplatePage() {
  return (
    <Suspense fallback={<div className="h-96 bg-white rounded-xl border border-slate-200/80 animate-pulse" />}>
      <UploadWizard />
    </Suspense>
  );
}

function UploadWizard() {
  const searchParams = useSearchParams();
  const editId = searchParams.get('edit');

  // Edit mode: there is no detail endpoint, so look the template up among the creator's
  // editable (DRAFT / REJECTED) templates.
  const editQuery = useQuery({
    queryKey: ['creator-template-edit', editId],
    enabled: !!editId,
    queryFn: async () => {
      const pages = await Promise.all(
        EDITABLE_STATUSES.map(status => creatorApi.getTemplates({ status, limit: 50 })),
      );
      return pages.flatMap((p: any) => p?.data ?? []).find((t: any) => t.id === editId) ?? null;
    },
    staleTime: 0,
  });

  if (editId) {
    if (editQuery.isLoading) {
      return <div className="h-96 bg-white rounded-xl border border-slate-200/80 animate-pulse" />;
    }
    if (editQuery.isError) {
      return <QueryError error={editQuery.error} onRetry={() => editQuery.refetch()} title="Could not load template" />;
    }
    if (!editQuery.data) {
      return (
        <div className="bg-white rounded-xl border border-slate-200/80 p-8 text-center space-y-2">
          <AlertCircle size={22} className="text-amber-500 mx-auto" />
          <div className="text-sm font-semibold text-slate-800">This template can't be edited</div>
          <p className="text-xs text-slate-500">Only your Draft or Rejected templates can be edited.</p>
          <Link href="/templates" className="btn-primary text-xs inline-flex mt-2">Back to My Templates</Link>
        </div>
      );
    }
    return <WizardForm key={editId} existing={editQuery.data} />;
  }

  return <WizardForm key="new" existing={null} />;
}

function WizardForm({ existing }: { existing: any | null }) {
  const queryClient = useQueryClient();
  const isEdit = !!existing;
  const initialForm = existing ? templateToForm(existing) : defaultForm;

  const [step, setStep] = useState<Step>(1);
  const [form, setForm] = useState<FormState>(initialForm);
  const [dragging, setDragging] = useState(false);
  const [fileError, setFileError] = useState('');
  const [submitError, setSubmitError] = useState('');
  const [result, setResult] = useState<{ status: string } | null>(null);
  // Remember the draft id so a retry after a partial failure doesn't create duplicate drafts.
  const draftIdRef = useRef<string | null>(existing?.id ?? null);

  const existingMediaUrl: string | null = existing ? (existing.imageUrl || existing.videoUrl || null) : null;

  const { data: categoriesData, isLoading: categoriesLoading, isError: categoriesError, refetch: refetchCategories } = useQuery({
    queryKey: ['categories'],
    queryFn: () => creatorApi.getCategories(),
    staleTime: 10 * 60 * 1000,
  });
  // Categories come ONLY from the real DB — never use fake hardcoded IDs
  const CATEGORIES: { id: string; label: string }[] = (categoriesData?.data ?? []).map((c: any) => ({
    id: c.id,
    label: `${c.emoji || ''} ${c.nameEn} / ${c.nameHi}`.trim(),
  }));

  const uploadMedia = async (file: File): Promise<{ url: string; duration?: number; viaCloudinary: boolean }> => {
    try {
      const res = await creatorApi.uploadTemplateMedia(file);
      return { url: res.url, viaCloudinary: false };
    } catch (err) {
      // Only fall back on network errors / 5xx — a 4xx (bad type, too large, forbidden) is final.
      if (!isRetryableError(err)) throw err;
      const signData = await creatorApi.getCloudinarySignature({ folder: 'templates' });
      const res = await uploadToCloudinary(file, signData);
      return { url: res.url, duration: res.duration, viaCloudinary: true };
    }
  };

  const saveMutation = useMutation({
    mutationFn: async (f: FormState) => {
      const tags = parseTags(f.tags);
      const tagsChanged = f.tags.trim() !== initialForm.tags.trim();

      // 1. Create DRAFT (new templates only)
      let templateId = draftIdRef.current;
      if (!templateId) {
        const created = await creatorApi.createTemplate({
          type: f.type,
          categoryId: f.categoryId,
          gradient: f.gradient,
          ...(tags.length > 0 && { tags }),
        });
        templateId = created.template.id as string;
        draftIdRef.current = templateId;
      }

      // 2. Upload media (only when a new file was chosen)
      const media: Record<string, any> = {};
      if (f.imageFile) {
        const up = await uploadMedia(f.imageFile);
        if (f.type === 'IMAGE') {
          media.imageUrl = up.url;
        } else {
          media.videoUrl = up.url;
          if (up.viaCloudinary) media.videoThumbUrl = up.url.replace(/\.[^.]+$/, '.jpg');
          if (up.duration) media.videoDuration = Math.round(up.duration);
        }
      }

      // 3. Persist metadata
      const { photo, name } = f.zones;
      await creatorApi.updateTemplate(templateId, {
        type: f.type,
        categoryId: f.categoryId,
        fitMode: f.fitMode,
        nameHi: orNull(f.nameHi), nameMr: orNull(f.nameMr), nameEn: orNull(f.nameEn),
        quoteHi: orNull(f.quoteHi), quoteMr: orNull(f.quoteMr), quoteEn: orNull(f.quoteEn),
        ...(tagsChanged && { tags }),
        photoZoneEnabled: photo.enabled,
        photoZoneX: photo.x, photoZoneY: photo.y,
        photoZoneSize: photo.size, photoZoneShape: photo.shape,
        nameZoneEnabled: name.enabled,
        nameZoneX: name.x, nameZoneY: name.y,
        nameFontSize: name.fontSize, nameColor: name.color, nameFont: name.font,
        gradient: f.gradient,
        ...media,
      });

      // 4. Submit for review
      const submitted = await creatorApi.submitTemplate(templateId);
      return { status: submitted?.template?.status ?? 'PENDING' };
    },
    onSuccess: (res) => {
      setSubmitError('');
      setResult(res);
      queryClient.invalidateQueries({ queryKey: ['creator-templates'] });
      queryClient.invalidateQueries({ queryKey: ['creator-stats'] });
      toast.success(res.status === 'APPROVED' ? 'Template is live' : 'Submitted — pending review');
    },
    onError: (err: any) => {
      const missing = err?.response?.data?.missing;
      const msg = getErrorMessage(err, 'Upload failed') + (Array.isArray(missing) ? `: ${missing.join(', ')}` : '');
      setSubmitError(msg);
      toast.error(msg);
    },
  });

  const update = (partial: Partial<FormState>) => setForm(f => ({ ...f, ...partial }));

  const hasName = !!(form.nameHi.trim() || form.nameMr.trim() || form.nameEn.trim());
  const hasMedia = !!form.imageFile || !!existingMediaUrl;

  const canProceed = () => {
    if (step === 1) return !!form.categoryId && hasName;
    if (step === 2) return hasMedia;
    return true;
  };

  const handleFileChange = (file: File) => {
    const problem = validateFile(file);
    if (problem) {
      setFileError(problem);
      return;
    }
    setFileError('');
    update({ imageFile: file, type: file.type.startsWith('video/') ? 'VIDEO' : 'IMAGE' });
  };

  const resetForNew = () => {
    draftIdRef.current = null;
    setForm(defaultForm);
    setResult(null);
    setSubmitError('');
    setStep(1);
  };

  const acceptTypes = form.type === 'IMAGE' ? IMAGE_TYPES.join(',') : VIDEO_TYPES.join(',');
  const categoryLabel = CATEGORIES.find(c => c.id === form.categoryId)?.label ?? existing?.category?.nameEn ?? '—';

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">{isEdit ? 'Edit Template' : 'Upload Template'}</h1>
        <p className="text-slate-500 text-sm mt-1">
          {isEdit ? 'Update your template and resubmit it for review' : 'Complete all 3 steps to submit your template for review'}
        </p>
      </div>

      {isEdit && existing.status === 'REJECTED' && (
        <div className="flex items-start gap-2.5 bg-rose-50 border border-rose-200 text-rose-700 rounded-lg px-3.5 py-2.5 text-xs">
          <AlertCircle size={15} className="shrink-0 mt-0.5 text-rose-600" />
          <div>
            <div className="font-semibold">This template was rejected</div>
            <div className="mt-0.5">Reason: {existing.reviewNote || 'No reason provided.'}</div>
          </div>
        </div>
      )}

      <StepIndicator current={step} />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Form Area */}
        <div className={`${step === 2 ? 'lg:col-span-3' : 'lg:col-span-2'} bg-white rounded-xl p-6 border border-slate-200/80 shadow-sm`}>

          {/* STEP 1: Details */}
          {step === 1 && (
            <div className="space-y-5">
              <h2 className="font-semibold text-slate-900 text-base">Step 1: Details</h2>

              {/* Template Type */}
              <div>
                <label className={labelCls}>Template Type</label>
                <div className="flex gap-2.5">
                  {(['IMAGE', 'VIDEO'] as const).map(t => (
                    <button
                      key={t}
                      type="button"
                      onClick={() => {
                        // Switching type invalidates an already-picked file of the other kind.
                        if (t !== form.type) update({ type: t, imageFile: null });
                      }}
                      className={`flex items-center gap-2 px-4 py-2 rounded-lg border text-sm font-semibold transition-all ${
                        form.type === t
                          ? 'border-blue-600 bg-blue-50 text-blue-700 shadow-sm'
                          : 'border-slate-200 text-slate-600 hover:border-slate-300'
                      }`}
                    >
                      {t === 'IMAGE' ? <Image size={15} /> : <Video size={15} />}
                      {t}
                    </button>
                  ))}
                </div>
              </div>

              {/* Names */}
              <div>
                <label className={labelCls}>Template Name * <span className="normal-case font-medium text-slate-400 tracking-normal">(at least one language)</span></label>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
                  <input value={form.nameHi} onChange={e => update({ nameHi: e.target.value })} maxLength={100} placeholder="हिंदी नाम" className={inputCls} />
                  <input value={form.nameMr} onChange={e => update({ nameMr: e.target.value })} maxLength={100} placeholder="मराठी नाव" className={inputCls} />
                  <input value={form.nameEn} onChange={e => update({ nameEn: e.target.value })} maxLength={100} placeholder="English name" className={inputCls} />
                </div>
              </div>

              {/* Quotes */}
              <div>
                <label className={labelCls}>Quote <span className="normal-case font-medium text-slate-400 tracking-normal">(optional, per language)</span></label>
                <div className="space-y-2">
                  <textarea value={form.quoteHi} onChange={e => update({ quoteHi: e.target.value })} rows={2} placeholder="हिंदी सुविचार" className={`${inputCls} resize-none`} />
                  <textarea value={form.quoteMr} onChange={e => update({ quoteMr: e.target.value })} rows={2} placeholder="मराठी सुविचार" className={`${inputCls} resize-none`} />
                  <textarea value={form.quoteEn} onChange={e => update({ quoteEn: e.target.value })} rows={2} placeholder="English quote" className={`${inputCls} resize-none`} />
                </div>
              </div>

              {/* Category */}
              <div>
                <label className={labelCls}>Category *</label>
                {categoriesLoading ? (
                  <div className="grid grid-cols-2 gap-2">
                    {[1, 2, 3, 4].map(i => <div key={i} className="h-10 bg-slate-50 rounded-lg animate-pulse" />)}
                  </div>
                ) : categoriesError ? (
                  <QueryError error={null} onRetry={() => refetchCategories()} title="Could not load categories" />
                ) : CATEGORIES.length === 0 ? (
                  <div className="text-xs text-slate-500">No categories are available yet. Please contact an admin.</div>
                ) : (
                  <div className="grid grid-cols-2 gap-2">
                    {CATEGORIES.map(cat => (
                      <button
                        key={cat.id}
                        type="button"
                        onClick={() => update({ categoryId: cat.id })}
                        className={`text-left px-3.5 py-2.5 rounded-lg border text-sm transition-all ${
                          form.categoryId === cat.id
                            ? 'border-blue-600 bg-blue-50 text-blue-700 font-semibold shadow-sm'
                            : 'border-slate-200 text-slate-700 font-medium hover:border-slate-300'
                        }`}
                      >
                        {cat.label}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Tags */}
              <div>
                <label className={labelCls}>Tags</label>
                <input value={form.tags} onChange={e => update({ tags: e.target.value })} placeholder="e.g. good morning, devotional, diwali" className={inputCls} />
                <p className="text-[11px] text-slate-400 mt-1">Comma separated — helps users find your template in search</p>
              </div>

              {/* Gradient picker */}
              <div>
                <label className={labelCls}>Background Gradient</label>
                <div className="flex gap-2 flex-wrap">
                  {GRADIENTS.map(g => (
                    <button key={g} type="button" onClick={() => update({ gradient: g })}
                      className={`w-9 h-9 rounded-lg border-2 transition-transform hover:scale-105 ${form.gradient === g ? 'border-slate-800 scale-105 shadow-sm' : 'border-transparent'}`}
                      style={{ background: g }}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* STEP 2: Upload & Overlay */}
          {step === 2 && (
            <div className="space-y-5">
              <h2 className="font-semibold text-slate-900 text-base">Step 2: Display & Overlay Configuration</h2>

              {/* Upload Zone */}
              <div>
                <label className={labelCls}>
                  Media File ({form.type === 'IMAGE' ? 'JPEG, PNG, WebP up to 10 MB' : 'MP4 up to 50 MB'}) *
                </label>
                <div
                  className={`upload-zone border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors ${dragging ? 'border-blue-500 bg-blue-50/50' : hasMedia ? 'border-emerald-400 bg-emerald-50/20' : 'border-slate-200 hover:border-slate-300'}`}
                  onDragOver={e => { e.preventDefault(); setDragging(true); }}
                  onDragLeave={() => setDragging(false)}
                  onDrop={e => { e.preventDefault(); setDragging(false); const f = e.dataTransfer.files[0]; if (f) handleFileChange(f); }}
                  onClick={() => document.getElementById('template-upload')?.click()}
                >
                  <input type="file" id="template-upload" className="hidden"
                    accept={acceptTypes}
                    onChange={e => { const f = e.target.files?.[0]; e.target.value = ''; if (f) handleFileChange(f); }}
                  />
                  {form.imageFile ? (
                    <div className="space-y-1">
                      <div className="w-9 h-9 rounded-lg bg-emerald-100 text-emerald-700 flex items-center justify-center mx-auto mb-2">
                        <CheckCircle size={18} />
                      </div>
                      <div className="text-sm font-semibold text-slate-800">{form.imageFile.name}</div>
                      <div className="text-xs text-slate-500">{(form.imageFile.size / (1024 * 1024)).toFixed(2)} MB — click to replace</div>
                    </div>
                  ) : existingMediaUrl ? (
                    <div className="space-y-1">
                      <div className="w-9 h-9 rounded-lg bg-emerald-100 text-emerald-700 flex items-center justify-center mx-auto mb-2">
                        <CheckCircle size={18} />
                      </div>
                      <div className="text-sm font-semibold text-slate-800">Current media will be kept</div>
                      <div className="text-xs text-slate-500">Click or drop a file to replace it</div>
                    </div>
                  ) : (
                    <div className="space-y-1">
                      <div className="w-9 h-9 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center mx-auto mb-2">
                        <Upload size={18} />
                      </div>
                      <div className="text-sm font-semibold text-slate-700">Click to upload or drag & drop</div>
                      <div className="text-xs text-slate-400">{form.type === 'IMAGE' ? 'JPEG, PNG, WebP (high-res recommended)' : 'MP4 (vertical 9:16 recommended)'}</div>
                    </div>
                  )}
                </div>
                {fileError && (
                  <div className="mt-2 flex items-center gap-1.5 text-xs text-rose-600 font-medium">
                    <AlertCircle size={13} /> {fileError}
                  </div>
                )}
              </div>

              {/* Fit Mode Selector */}
              {hasMedia && (
                <div className="bg-blue-50/70 border border-blue-100 rounded-xl p-3.5 flex items-center justify-between">
                  <div className="space-y-0.5">
                    <div className="text-xs font-semibold text-slate-800 flex items-center gap-1.5">
                      <span>🖼️</span> Display Mode
                    </div>
                    <div className="text-xs text-slate-500">
                      {form.fitMode === 'contain'
                        ? 'Full media & all words visible without any edge cropping'
                        : 'Cropped to fill 9:16 vertical full screen'}
                    </div>
                  </div>
                  <div className="flex bg-white rounded-lg p-0.5 border border-blue-200 shadow-sm text-xs font-semibold">
                    {(['contain', 'cover'] as const).map(mode => (
                      <button
                        key={mode}
                        type="button"
                        onClick={() => update({ fitMode: mode })}
                        className={`px-3 py-1 rounded-md transition-all ${
                          form.fitMode === mode ? 'bg-blue-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900'
                        }`}
                      >
                        {mode === 'contain' ? 'Fit (No Crop)' : 'Fill (9:16)'}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Overlay Configuration — drag & drop zone editor */}
              <div className="border border-slate-200/80 rounded-xl p-4 space-y-4">
                <div className="font-semibold text-slate-800 text-sm flex items-center gap-2">
                  <Crosshair size={16} className="text-blue-600" />
                  Overlay Zone Configuration
                </div>
                <TemplateEditor
                  file={form.imageFile}
                  mediaUrl={existingMediaUrl}
                  fitMode={form.fitMode}
                  gradient={form.gradient}
                  templateType={form.type}
                  zones={form.zones}
                  onZonesChange={zones => update({ zones })}
                />
              </div>
            </div>
          )}

          {/* STEP 3: Review & Submit */}
          {step === 3 && (
            <div className="space-y-5">
              <h2 className="font-semibold text-slate-900 text-base">Step 3: Review & Submit</h2>

              {result ? (
                <div className="text-center py-12">
                  <div className="w-12 h-12 rounded-full bg-amber-50 border border-amber-200 text-amber-600 flex items-center justify-center mx-auto mb-3">
                    {result.status === 'APPROVED' ? <CheckCircle size={22} className="text-emerald-600" /> : <Clock size={22} />}
                  </div>
                  <div className="font-bold text-lg text-slate-900 mb-1.5">
                    {result.status === 'APPROVED' ? 'Template is live' : 'Pending review'}
                  </div>
                  <div className="mb-3">
                    <span className={getStatusConfig(result.status).cls}>{getStatusConfig(result.status).label}</span>
                  </div>
                  <p className="text-slate-500 text-xs max-w-sm mx-auto mb-5">
                    {result.status === 'APPROVED'
                      ? 'Your template is now visible to users in the app.'
                      : "Your template has been submitted for admin review. You'll be notified once it's reviewed."}
                  </p>
                  <div className="flex items-center justify-center gap-2">
                    <Link href="/templates" className="btn-outline text-xs">View My Templates</Link>
                    <button type="button" onClick={resetForNew} className="btn-primary text-xs">Upload Another Template</button>
                  </div>
                </div>
              ) : (
                <>
                  {/* Summary */}
                  <div className="bg-slate-50 rounded-xl p-4 space-y-3 border border-slate-200/70">
                    <div className="grid grid-cols-2 gap-3 text-xs">
                      <div><span className="text-slate-500 font-medium">Type:</span> <span className="font-semibold text-slate-800 ml-1.5">{form.type}</span></div>
                      <div><span className="text-slate-500 font-medium">Category:</span> <span className="font-semibold text-slate-800 ml-1.5">{categoryLabel}</span></div>
                      <div className="col-span-2"><span className="text-slate-500 font-medium">Name:</span> <span className="font-semibold text-slate-800 ml-1.5">{[form.nameHi, form.nameMr, form.nameEn].filter(s => s.trim()).join(' · ') || '—'}</span></div>
                      <div className="col-span-2"><span className="text-slate-500 font-medium">Tags:</span> <span className="font-semibold text-slate-800 ml-1.5">{parseTags(form.tags).join(', ') || '—'}</span></div>
                      <div><span className="text-slate-500 font-medium">Display:</span> <span className="font-semibold text-slate-800 ml-1.5">{form.fitMode === 'contain' ? 'Fit (No Crop)' : 'Fill (9:16)'}</span></div>
                      <div><span className="text-slate-500 font-medium">Photo Zone:</span> <span className="font-semibold text-slate-800 ml-1.5">{form.zones.photo.enabled ? 'Enabled' : 'Disabled'}</span></div>
                    </div>
                  </div>

                  {/* Checklist */}
                  <div className="space-y-2">
                    {[
                      { ok: !!form.categoryId, label: 'Category selected', required: true },
                      { ok: hasName, label: 'Name in at least one language', required: true },
                      { ok: hasMedia, label: 'Media file attached', required: true },
                      { ok: form.zones.name.enabled, label: 'Name overlay zone configured', required: false },
                    ].map(({ ok, label, required }) => (
                      <div key={label} className={`flex items-center gap-2 text-xs ${ok ? 'text-emerald-700' : required ? 'text-rose-600' : 'text-slate-400'}`}>
                        <CheckCircle size={14} />
                        <span className="font-medium">{label}</span>
                        {!ok && <span className="text-[11px] opacity-80">({required ? 'required' : 'optional'})</span>}
                      </div>
                    ))}
                  </div>

                  {submitError && (
                    <div className="flex items-start gap-2.5 bg-rose-50 border border-rose-200 text-rose-700 rounded-lg px-3.5 py-2.5 text-xs font-medium">
                      <AlertCircle size={15} className="shrink-0 mt-0.5 text-rose-600" />
                      <span>{submitError}</span>
                    </div>
                  )}

                  <button
                    type="button"
                    onClick={() => saveMutation.mutate(form)}
                    disabled={saveMutation.isPending || !form.categoryId || !hasName || !hasMedia}
                    className="btn-primary w-full flex items-center justify-center gap-2 py-2.5 text-sm disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    {saveMutation.isPending ? (
                      <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    ) : (
                      <Send size={15} />
                    )}
                    {saveMutation.isPending ? 'Submitting Template...' : isEdit ? 'Save & Resubmit for Review' : 'Submit for Review'}
                  </button>
                  <p className="text-[11px] text-slate-400 text-center">Templates are typically reviewed within 24 hours.</p>
                </>
              )}
            </div>
          )}

          {/* Navigation */}
          {!result && (
            <div className="flex justify-between mt-8 pt-6 border-t border-surface-border">
              <button type="button" onClick={() => setStep(s => (s > 1 ? (s - 1) as Step : s))}
                disabled={step === 1}
                className="btn-ghost flex items-center gap-2 disabled:opacity-30 disabled:cursor-not-allowed">
                <ChevronLeft size={14} /> Previous
              </button>
              {step < 3 ? (
                <button type="button" onClick={() => setStep(s => (s < 3 ? (s + 1) as Step : s))}
                  disabled={!canProceed()}
                  className="btn-primary flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed">
                  Next <ChevronRight size={14} />
                </button>
              ) : null}
            </div>
          )}
        </div>

        {/* Live Preview (step 2 has the interactive editor canvas instead) */}
        {step !== 2 && <PhonePreview form={form} existingMediaUrl={existingMediaUrl} onUpdate={update} />}
      </div>
    </div>
  );
}
