'use client';

// Yojana & News — editorial console: news cards by default, AI video only on explicit request.
// Static-export friendly: one page, detail opens in a slide-over (no dynamic routes).
import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  AlertTriangle, ExternalLink, Loader2, X, RefreshCw, Plus, Play,
  CheckCircle, Trash2, Landmark, Sparkles, Filter
} from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatRelativeTime } from '@/lib/utils';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';
import { Pagination } from '@/components/Pagination';

type View = 'content' | 'schemes' | 'schedule' | 'jobs' | 'reports' | 'costs';

const STATUS_TABS: { label: string; status: string }[] = [
  { label: 'Needs Review', status: 'NEEDS_REVIEW' },
  { label: 'Drafts', status: 'DRAFT' },
  { label: 'Approved', status: 'APPROVED' },
  { label: 'Published', status: 'PUBLISHED' },
  { label: 'Failed', status: 'FAILED' },
  { label: 'Correction', status: 'CORRECTION_REQUIRED' },
  { label: 'Expired', status: 'EXPIRED' },
  { label: 'Unpublished', status: 'UNPUBLISHED' },
  { label: 'Rejected', status: 'REJECTED' },
];

const SCHEME_CATEGORIES = [
  'FARMER', 'HEALTHCARE', 'HOUSING', 'SKILLS', 'WOMEN', 'EDUCATION', 'FINANCE', 'YOUTH', 'SENIOR_CITIZEN', 'GENERAL'
];

/** Backend errors carry `message` and, for failed pre-flight checks, a `problems` list. */
function describeError(err: any): string {
  const d = err?.response?.data;
  if (d?.problems?.length) return `${d.message}: ${d.problems.join('; ')}`;
  return d?.message || d?.error || err?.message || 'Request failed';
}

const fmt = (d?: string | null) => (d ? new Date(d).toLocaleString('en-IN') : '—');

function StatusBadge({ status }: { status: string }) {
  const cls =
    status === 'PUBLISHED' || status === 'APPROVED' ? 'badge-approved'
    : status === 'FAILED' || status === 'REJECTED' ? 'badge-rejected'
    : status === 'DRAFT' ? 'badge-draft' : 'badge-pending';
  return <span className={cls}>{status.replace(/_/g, ' ')}</span>;
}

function PromptModal({ title, hint, minLength, confirmLabel, onConfirm, onCancel, busy }: {
  title: string; hint?: string; minLength: number; confirmLabel: string;
  onConfirm: (text: string) => void; onCancel: () => void; busy: boolean;
}) {
  const [text, setText] = useState('');
  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-[70] p-4">
      <div className="bg-white rounded-xl p-6 max-w-md w-full shadow-2xl">
        <h3 className="font-bold text-slate-800 text-lg mb-1">{title}</h3>
        {hint && <p className="text-xs text-slate-500 mb-3">{hint}</p>}
        <textarea value={text} onChange={e => setText(e.target.value)} rows={4} disabled={busy}
          className="w-full border border-slate-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-primary resize-none" />
        <div className="text-xs text-slate-400 text-right mb-3">{text.trim().length} chars (min {minLength})</div>
        <div className="flex gap-3">
          <button className="btn-ghost flex-1" onClick={onCancel} disabled={busy}>Cancel</button>
          <button className="btn-primary flex-1 disabled:opacity-40" disabled={busy || text.trim().length < minLength}
            onClick={() => onConfirm(text.trim())}>
            {busy ? <Loader2 size={14} className="animate-spin inline" /> : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}

const FORMAT_LABEL: Record<string, string> = { CARD_ONLY: 'Card only', CARD_WITH_VIDEO: 'Card + Video' };
const VIDEO_LABEL: Record<string, string> = {
  NOT_REQUESTED: 'No video', QUEUED: 'Video queued', GENERATING: 'Generating video', READY: 'Video ready', FAILED: 'Video failed',
};

function FormatBadge({ format }: { format?: string }) {
  return <span className={format === 'CARD_WITH_VIDEO' ? 'badge-pending' : 'badge-draft'}>{FORMAT_LABEL[format ?? 'CARD_ONLY'] ?? format}</span>;
}

/** Hidden for plain cards that never asked for a video. */
function VideoStateBadge({ item }: { item: any }) {
  if (item.format !== 'CARD_WITH_VIDEO') return null;
  const st: string = item.videoState ?? 'NOT_REQUESTED';
  const cls = st === 'FAILED' ? 'badge-rejected' : st === 'READY' && item.videoApprovedAt ? 'badge-approved' : 'badge-pending';
  const label = st === 'READY' ? (item.videoApprovedAt ? 'Video live' : 'Video awaiting approval') : VIDEO_LABEL[st] ?? st;
  return <span className={cls}>{label}</span>;
}

function DetailPanel({ id, onClose }: { id: string; onClose: () => void }) {
  const qc = useQueryClient();
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['content-detail', id],
    queryFn: () => adminApi.getContent(id),
    refetchInterval: 5_000,
  });
  const [prompt, setPrompt] = useState<null | { action: string; title: string; hint?: string; min: number; label: string; extra?: any }>(null);
  const [scheduleAt, setScheduleAt] = useState('');
  const [draft, setDraft] = useState<null | { title: string; hook: string; narration: string; attribution: string; captions: string; description: string }>(null);

  const refresh = () => {
    qc.invalidateQueries({ queryKey: ['content-detail', id] });
    qc.invalidateQueries({ queryKey: ['content-queue'] });
    qc.invalidateQueries({ queryKey: ['content-counts'] });
  };

  const act = useMutation({
    mutationFn: ({ action, body }: { action: string; body?: any }) => adminApi.contentAction(id, action, body),
    onSuccess: (_r, v) => { toast.success(`Done: ${v.action}`); setPrompt(null); refresh(); },
    onError: (e) => toast.error(describeError(e)),
  });

  const save = useMutation({
    mutationFn: (body: any) => adminApi.editContent(id, body),
    onSuccess: (r) => {
      toast.success(r.needsRerender ? 'Saved — the old video was discarded; request a new one if needed' : 'Saved');
      setDraft(null); refresh();
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const genVideo = useMutation({
    mutationFn: () => adminApi.generateVideo(id),
    onSuccess: (r) => {
      toast.success(r?.duplicate ? 'Video is already queued' : 'Video generation queued');
      refresh();
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const setFormat = useMutation({
    mutationFn: (format: 'CARD_ONLY' | 'CARD_WITH_VIDEO') => adminApi.setContentFormat(id, format),
    onSuccess: () => { toast.success('Format updated'); refresh(); },
    onError: (e) => toast.error(describeError(e)),
  });

  const publishCard = useMutation({
    mutationFn: (body: Record<string, any> = {}) => adminApi.publishCard(id, body),
    onSuccess: () => { toast.success('Published as news card'); refresh(); },
    onError: (e) => toast.error(describeError(e)),
  });

  const v = data?.data;
  const status: string | undefined = v?.status;
  const busy = act.isPending || genVideo.isPending || setFormat.isPending || publishCard.isPending;
  const videoState: string = v?.videoState ?? 'NOT_REQUESTED';
  const withVideo = v?.format === 'CARD_WITH_VIDEO';
  const activeJob = (data?.jobs ?? []).find((j: any) => j.state === 'QUEUED' || j.state === 'RUNNING');
  const CARD_STATES = ['DRAFT', 'SOURCE_VERIFIED', 'NEEDS_REVIEW', 'APPROVED'];
  const run = (action: string, body?: any) => act.mutate({ action, body });

  const startEdit = () => setDraft({
    title: v.title ?? '', hook: v.hook ?? '', attribution: v.attribution ?? '', description: v.description ?? '',
    narration: v.script?.narration ?? '',
    captions: JSON.stringify(v.captions ?? [], null, 2),
  });
  const submitEdit = () => {
    if (!draft) return;
    const body: Record<string, any> = {
      title: draft.title, hook: draft.hook || null, attribution: draft.attribution || null, description: draft.description || null,
    };
    // Script/captions only exist for items that have (or want) a video.
    if (v.script || withVideo) {
      let captions: any;
      try { captions = JSON.parse(draft.captions || '[]'); } catch { toast.error('Captions must be valid JSON'); return; }
      if (draft.narration.trim().length >= 10) {
        body.script = { ...(v.script ?? {}), narration: draft.narration };
        body.captions = captions;
      }
    }
    save.mutate(body);
  };

  return (
    <div className="fixed inset-0 z-[60] flex justify-end bg-black/50" onClick={onClose}>
      <div className="bg-white w-full max-w-3xl h-full overflow-y-auto p-6 space-y-5 shadow-2xl" onClick={e => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold text-slate-900">{v?.title ?? 'Loading…'}</h2>
            {v && <div className="flex gap-2 mt-1 items-center flex-wrap"><StatusBadge status={v.status} /><FormatBadge format={v.format} /><VideoStateBadge item={v} /><span className="text-xs text-slate-500">{v.kind} · {v.category} · v{v.scriptVersion}</span></div>}
          </div>
          <button onClick={onClose} aria-label="Close" className="text-slate-400 hover:text-slate-700 p-1"><X size={22} /></button>
        </div>

        {isLoading && <Loader2 className="animate-spin text-primary" />}
        {isError && <QueryError error={error} onRetry={refetch} />}

        {v && (<>
          {(v.warnings?.length > 0 || v.publishBlockers?.length > 0) && (
            <div className="border border-amber-300 bg-amber-50 rounded-xl p-3 text-xs space-y-1">
              <div className="font-bold text-amber-800 flex items-center gap-1"><AlertTriangle size={14} /> Review warnings</div>
              {v.publishBlockers?.map((w: string) => <div key={'b' + w} className="text-rose-700">⛔ {w}</div>)}
              {v.warnings?.map((w: string) => <div key={w} className="text-amber-800">• {w}</div>)}
            </div>
          )}

          <section className="border border-slate-200 rounded-xl p-3 space-y-2">
            <h3 className="font-semibold text-sm">Content format</h3>
            <div className="flex flex-wrap gap-2">
              {(['CARD_ONLY', 'CARD_WITH_VIDEO'] as const).map(f => (
                <label key={f} className={`flex items-center gap-2 text-sm px-3 py-2 rounded-lg border cursor-pointer ${v.format === f ? 'border-primary bg-primary/5' : 'border-slate-200'} ${busy || ['QUEUED', 'GENERATING'].includes(videoState) ? 'opacity-60 cursor-not-allowed' : ''}`}>
                  <input type="radio" name="format" checked={v.format === f}
                    disabled={busy || ['QUEUED', 'GENERATING'].includes(videoState) || v.status === 'REJECTED'}
                    onChange={() => setFormat.mutate(f)} />
                  {FORMAT_LABEL[f]}
                </label>
              ))}
            </div>
            <p className="text-xs text-slate-500">
              {withVideo
                ? 'The card is published normally. A video is only made when you press “Generate video”, and only plays for users after you approve it.'
                : 'A normal news card (headline, summary, source). No video is generated.'}
            </p>
          </section>

          <div className="grid grid-cols-2 gap-4">
            <div className="aspect-[9/16] bg-slate-900 rounded-xl overflow-hidden flex flex-col items-center justify-center">
              {v.videoUrl
                ? <video src={v.videoUrl} poster={v.thumbnailUrl ?? undefined} controls playsInline className="w-full h-full object-contain" />
                : (
                  <div className="p-4 text-center space-y-2">
                    <div className="text-slate-400 text-xs">{withVideo ? 'No rendered video yet' : 'News card only — no video'}</div>
                    {['QUEUED', 'GENERATING'].includes(videoState) && (
                      <div className="text-xs text-blue-400 animate-pulse flex items-center justify-center gap-1">
                        <Loader2 size={12} className="animate-spin" /> {videoState === 'QUEUED' ? 'Queued…' : 'Generating…'}
                      </div>
                    )}
                  </div>
                )}
            </div>
            <div className="space-y-3 text-sm">
              {v.audioUrl && <div><div className="text-xs text-slate-500 mb-1">Narration</div><audio src={v.audioUrl} controls className="w-full" /></div>}
              <div className="text-xs text-slate-500 space-y-0.5">
                <div>Duration: {v.durationSec ? `${v.durationSec.toFixed(1)}s` : '—'}</div>
                <div>Est. cost: ${((v.costMicroUsd ?? 0) / 1e6).toFixed(4)}</div>
                <div>Published: {fmt(v.publishedAt)}</div>
                {v.correctionNote && <div className="text-rose-700">Correction: {v.correctionNote}</div>}
              </div>
              {v.scheme && (
                <div className="text-xs space-y-1 border-t pt-2">
                  <div className="font-semibold text-slate-700">Scheme source</div>
                  <div>{v.scheme.officialName} — {v.scheme.department ?? 'dept. unknown'}</div>
                  <div>Last verified: {fmt(v.scheme.lastVerifiedAt)}</div>
                  {v.scheme.applicationUrl && <a className="text-blue-600 inline-flex gap-1 items-center" href={v.scheme.applicationUrl} target="_blank" rel="noreferrer">Application URL <ExternalLink size={11} /></a>}
                  {v.scheme.sourceUrls.map((u: string) => <div key={u}><a className="text-blue-600 break-all" href={u} target="_blank" rel="noreferrer">{u}</a></div>)}
                </div>
              )}
              {v.newsStory && (
                <div className="text-xs space-y-1 border-t pt-2">
                  <div className="font-semibold text-slate-700">News source</div>
                  <div>{v.newsStory.publisher}: “{v.newsStory.originalHeadline}”</div>
                  <div>Published: {fmt(v.newsStory.publishedAt)}</div>
                  <div>Retrieved: {fmt(v.newsStory.retrievedAt)} · Re-checked: {fmt(v.newsStory.lastVerifiedAt)}</div>
                  <a className="text-blue-600 break-all" href={v.newsStory.canonicalUrl} target="_blank" rel="noreferrer">{v.newsStory.canonicalUrl}</a>
                  <div><button className="btn-outline text-xs py-1" disabled={busy} onClick={() => run('recheck')}><RefreshCw size={12} className="inline mr-1" />I re-checked the source now</button></div>
                </div>
              )}
            </div>
          </div>

          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-sm">Claims vs sources</h3>
            </div>
            {(v.claims ?? []).length === 0 && <div className="text-xs text-rose-600">No claims recorded — cannot be approved.</div>}
            {(v.claims ?? []).map((c: any, i: number) => (
              <div key={i} className="border border-slate-200 rounded-lg p-2 text-xs">
                <div className="text-slate-800">{c.text}</div>
                {c.sourceQuote && <div className="text-slate-500 italic mt-1">“{c.sourceQuote}”</div>}
                {c.sourceUrl && <a className="text-blue-600 break-all" href={c.sourceUrl} target="_blank" rel="noreferrer">{c.sourceUrl}</a>}
              </div>
            ))}
          </section>

          <section className="space-y-2">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-sm">Card text{withVideo || v.script ? ' & video script' : ''}</h3>
              {!draft && <button className="btn-outline text-xs py-1" onClick={startEdit}>Edit</button>}
            </div>
            {!draft ? (
              <div className="text-sm bg-slate-50 rounded-lg p-3 whitespace-pre-wrap">
                {v.hook && <div className="font-semibold mb-1">{v.hook}</div>}
                <div className="text-xs text-slate-500">Card summary (shown to users)</div>
                {v.description ?? <span className="text-slate-400">No summary yet — add one before publishing</span>}
                {v.script?.narration && <><div className="text-xs text-slate-500 mt-2">Video narration</div>{v.script.narration}</>}
                {v.attribution && <div className="text-xs text-slate-500 mt-2">Attribution: {v.attribution}</div>}
              </div>
            ) : (
              <div className="space-y-2">
                {(['title', 'hook', 'attribution'] as const).map(k => (
                  <input key={k} value={draft[k] ?? ''} onChange={e => setDraft({ ...draft, [k]: e.target.value })} placeholder={k}
                    className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
                ))}
                <textarea value={draft.description ?? ''} rows={4} onChange={e => setDraft({ ...draft, description: e.target.value })}
                  placeholder="Card summary (about 60 words) — this is what users read" className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
                {(v.script || withVideo) && <>
                  <textarea value={draft.narration ?? ''} rows={6} onChange={e => setDraft({ ...draft, narration: e.target.value })}
                    placeholder="Video narration" className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
                  <textarea value={draft.captions ?? ''} rows={6} onChange={e => setDraft({ ...draft, captions: e.target.value })}
                    placeholder='[{"start":0,"end":3,"text":"…"}]' className="w-full border border-slate-200 rounded-lg px-3 py-2 text-xs font-mono" />
                  <p className="text-xs text-amber-700">Editing the title, narration or captions discards an existing video (and its approval); request a new one if needed.</p>
                </>}
                <div className="flex gap-2">
                  <button className="btn-ghost" onClick={() => setDraft(null)}>Cancel</button>
                  <button className="btn-primary" disabled={save.isPending} onClick={submitEdit}>{save.isPending ? 'Saving…' : 'Save'}</button>
                </div>
              </div>
            )}
          </section>

          <section className="border-t pt-4 space-y-3">
            <h3 className="font-semibold text-sm">Card actions</h3>
            <div className="flex flex-wrap gap-2 items-center">
              {CARD_STATES.includes(status!) && (
                <button className="btn-primary" disabled={busy} onClick={() => publishCard.mutate({})}>
                  {publishCard.isPending ? 'Publishing…' : 'Publish as News Card'}
                </button>
              )}
              {['DRAFT', 'SOURCE_VERIFIED'].includes(status!) &&
                <button className="btn-outline" disabled={busy} onClick={() => run('request-review')}>Send to review</button>}
              {status === 'NEEDS_REVIEW' && <>
                <button className="btn-success" disabled={busy} onClick={() => run('approve')}>Approve</button>
              </>}
              {status === 'APPROVED' && <>
                <input type="datetime-local" value={scheduleAt ?? ''} onChange={e => setScheduleAt(e.target.value)} className="border border-slate-200 rounded-lg px-2 py-1 text-xs" />
                <button className="btn-outline" disabled={busy || !scheduleAt} onClick={() => publishCard.mutate({ scheduledAt: new Date(scheduleAt).toISOString() })}>Schedule</button>
              </>}
              {['DRAFT', 'SOURCE_VERIFIED', 'NEEDS_REVIEW', 'APPROVED', 'FAILED'].includes(status!) &&
                <button className="btn-danger" disabled={busy} onClick={() => setPrompt({ action: 'reject', title: 'Reject content', min: 10, label: 'Reject', hint: 'Recorded in the audit trail.' })}>Reject</button>}
              {status === 'PUBLISHED' && <>
                <button className="btn-outline" disabled={busy} onClick={() => setPrompt({ action: 'correct', title: 'Take down for correction', min: 10, label: 'Take down', hint: 'Removes it from the feed until corrected and re-reviewed.' })}>Correct</button>
                <button className="btn-danger" disabled={busy} onClick={() => setPrompt({ action: 'correct', title: 'Withdraw content', min: 10, label: 'Withdraw', hint: 'Unpublishes and marks the source as withdrawn.', extra: { withdraw: true } })}>Withdraw</button>
                <button className="btn-outline" disabled={busy} onClick={() => setPrompt({ action: 'unpublish', title: 'Unpublish', min: 10, label: 'Unpublish' })}>Unpublish</button>
                <button className="btn-outline" disabled={busy} onClick={() => setPrompt({ action: 'expire', title: 'Mark expired', min: 10, label: 'Expire' })}>Expire</button>
              </>}
              {['EXPIRED', 'UNPUBLISHED', 'CORRECTION_REQUIRED'].includes(status!) &&
                <button className="btn-primary" disabled={busy} onClick={() => run('request-review')}>Send to review</button>}
            </div>
            {withVideo && videoState !== 'NOT_REQUESTED' && videoState !== 'READY' && status !== 'PUBLISHED' && v.publishBlockers?.length === 0 && (
              <p className="text-xs text-slate-500">The card can be published now — it does not wait for the video.</p>
            )}
          </section>

          {withVideo && (
            <section className="border-t pt-4 space-y-3">
              <h3 className="font-semibold text-sm flex items-center gap-2">Video <VideoStateBadge item={v} /></h3>
              <div className="flex flex-wrap gap-2 items-center">
                {videoState === 'NOT_REQUESTED' && (
                  <button className="btn-primary flex items-center gap-1.5" disabled={busy || status === 'REJECTED' || status === 'EXPIRED'} onClick={() => genVideo.mutate()}>
                    {genVideo.isPending ? <Loader2 size={13} className="animate-spin" /> : <Play size={13} />}
                    Generate Video
                  </button>
                )}
                {(videoState === 'QUEUED' || videoState === 'GENERATING') && <>
                  <span className="text-xs text-blue-600 flex items-center gap-1.5 font-medium animate-pulse">
                    <Loader2 size={13} className="animate-spin" /> {videoState === 'QUEUED' ? 'Waiting for the worker…' : 'Generating — this can take a few minutes'}
                  </span>
                  {activeJob && <button className="btn-outline text-xs" disabled={busy}
                    onClick={() => adminApi.cancelContentJob(activeJob.id).then(() => { toast.success('Video request cancelled'); refresh(); }).catch((e: any) => toast.error(describeError(e)))}>
                    Cancel
                  </button>}
                </>}
                {videoState === 'READY' && !v.videoApprovedAt && <>
                  <button className="btn-success" disabled={busy} onClick={() => run('video/approve')}>Approve video</button>
                  <span className="text-xs text-slate-500">Preview it above. Users will not see the video until you approve it.</span>
                </>}
                {videoState === 'READY' && v.videoApprovedAt && (
                  <button className="btn-outline" disabled={busy} onClick={() => run('video/unapprove')}>Remove video from the feed</button>
                )}
                {videoState === 'READY' && (
                  <button className="btn-ghost text-xs" disabled={busy} onClick={() => run('video/discard')}>Discard video</button>
                )}
                {videoState === 'FAILED' && <>
                  <button className="btn-primary" disabled={busy} onClick={() => run('video/retry')}>Retry video</button>
                  <button className="btn-ghost text-xs" disabled={busy} onClick={() => run('video/discard')}>Discard</button>
                </>}
              </div>
              {videoState === 'FAILED' && (
                <div className="text-xs text-rose-700 bg-rose-50 border border-rose-200 rounded-lg p-2">
                  {v.videoFailureReason || 'Video generation failed.'} The card is not affected{status === 'PUBLISHED' ? ' and stays published' : ' and can still be published'}.
                </div>
              )}
              {v.videoRequestedAt && <div className="text-xs text-slate-400">Requested {formatRelativeTime(v.videoRequestedAt)}{v.videoApprovedAt ? ` · approved ${formatRelativeTime(v.videoApprovedAt)}` : ''}</div>}
            </section>
          )}

          <section className="space-y-1">
            <h3 className="font-semibold text-sm">Audit trail</h3>
            {(data.reviews ?? []).length === 0 && <div className="text-xs text-slate-400">No decisions recorded.</div>}
            {(data.reviews ?? []).map((r: any) => (
              <div key={r.id} className="text-xs border-b border-slate-100 py-1">
                <span className="font-semibold">{r.action}</span> by {r.actorId.slice(0, 8)} · {formatRelativeTime(r.createdAt)}
                {r.reason && <div className="text-slate-500">{r.reason}</div>}
              </div>
            ))}
          </section>

          {(data.jobs ?? []).length > 0 && (
            <section className="space-y-1">
              <h3 className="font-semibold text-sm">Jobs</h3>
              {data.jobs.map((j: any) => (
                <div key={j.id} className="text-xs flex justify-between border-b border-slate-100 py-1">
                  <span>{j.type} · {j.state} · try {j.attempts}/{j.maxAttempts}</span>
                  <span className="text-rose-600 truncate max-w-[50%]">{j.failureReason}</span>
                </div>
              ))}
            </section>
          )}
        </>)}

        {prompt && (
          <PromptModal title={prompt.title} hint={prompt.hint} minLength={prompt.min} confirmLabel={prompt.label} busy={busy}
            onCancel={() => setPrompt(null)}
            onConfirm={(text) => act.mutate({ action: prompt.action, body: prompt.action === 'correct' ? { note: text, ...prompt.extra } : { reason: text } })} />
        )}
      </div>
    </div>
  );
}

function WorkerHealth() {
  const { data } = useQuery({ queryKey: ['content-health'], queryFn: adminApi.getContentHealth, refetchInterval: 30_000 });
  const h = data?.data;
  if (!h) return null;
  const problems: string[] = [];
  if (!h.workerAlive) problems.push(h.lastTickAt ? `Worker has not reported since ${fmt(h.lastTickAt)} — background schedules may be delayed.` : 'Worker heartbeat starting or idle — in-process scheduler active.');
  if (h.failedJobs24h > 0) problems.push(`${h.failedJobs24h} pipeline job(s) failed in the last 24h — see Pipeline Jobs.`);
  if (h.stuckGenerating > 0) problems.push(`${h.stuckGenerating} video(s) stuck generating for over an hour.`);
  if (problems.length === 0) return <div className="text-xs text-emerald-700 bg-emerald-50 border border-emerald-200 rounded-xl px-3 py-2 flex items-center gap-1.5"><CheckCircle size={14} /> Worker &amp; Ingestion Healthy · last run {fmt(h.lastTickAt)}</div>;
  return (
    <div role="alert" className="border border-rose-300 bg-rose-50 rounded-xl p-3 text-xs text-rose-800 space-y-1">
      {problems.map(p => <div key={p}>{p}</div>)}
    </div>
  );
}

function AttentionPanel() {
  const { data } = useQuery({ queryKey: ['content-attention'], queryFn: adminApi.getContentAttention, refetchInterval: 60_000 });
  const a = data?.data;
  if (!a || (a.overdueSchemes.length === 0 && a.needsReviewOver24h === 0 && a.openReports === 0)) return null;
  return (
    <div className="border border-amber-300 bg-amber-50 rounded-xl p-3 text-xs space-y-1">
      <div className="font-bold text-amber-800 flex items-center gap-1"><AlertTriangle size={14} /> Needs attention</div>
      {a.openReports > 0 && <div>• {a.openReports} open user report(s) — see Reports</div>}
      {a.needsReviewOver24h > 0 && <div>• {a.needsReviewOver24h} item(s) waiting for review for over 24h</div>}
      {a.overdueSchemes.map((x: any) => <div key={x.id}>• Scheme “{x.name}”: {x.reason}</div>)}
    </div>
  );
}

function ContentList({ onOpen }: { onOpen: (id: string) => void }) {
  const [status, setStatus] = useState('NEEDS_REVIEW');
  const [kind, setKind] = useState('');
  const [category, setCategory] = useState('');
  const [format, setFormatFilter] = useState('');
  const [videoState, setVideoStateFilter] = useState('');
  const [page, setPage] = useState(1);
  const limit = 20;

  // Real-time polling every 8s
  const counts = useQuery({ queryKey: ['content-counts'], queryFn: adminApi.getContentCounts, refetchInterval: 8_000 });
  const { data, isLoading, isError, error, refetch, isFetching } = useQuery({
    queryKey: ['content-queue', status, kind, category, format, videoState, page],
    queryFn: () => adminApi.getContentQueue({ status, kind, category, format, videoState, page, limit }),
    refetchInterval: 8_000,
  });
  const countFor = (s: string) =>
    (counts.data?.data ?? []).filter((c: any) => c.status === s && (!kind || c.kind === kind)).reduce((a: number, c: any) => a + c.count, 0);

  return (
    <div className="space-y-4">
      <WorkerHealth />
      <AttentionPanel />
      <div className="flex flex-wrap gap-1.5 items-center justify-between">
        <div className="flex flex-wrap gap-1.5">
          {STATUS_TABS.map(t => (
            <button key={t.status} onClick={() => { setStatus(t.status); setPage(1); }}
              className={`text-xs px-3 py-1.5 rounded-full border transition-all ${status === t.status ? 'bg-primary text-white border-primary shadow-sm' : 'bg-white border-slate-200 text-slate-600 hover:border-slate-300'}`}>
              {t.label} <span className="opacity-70">({countFor(t.status)})</span>
            </button>
          ))}
        </div>
        <button
          onClick={() => { refetch(); counts.refetch(); }}
          className="btn-outline text-xs py-1 px-2.5 flex items-center gap-1.5"
          title="Refresh queue in real time"
        >
          <RefreshCw size={12} className={isFetching ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      <div className="flex gap-2 items-center">
        <select value={kind} onChange={e => { setKind(e.target.value); setPage(1); }} className="border border-slate-200 rounded-lg px-2 py-1.5 text-xs bg-white">
          <option value="">All content kinds</option>
          <option value="SCHEME">Sarkari Yojana / Schemes</option>
          <option value="NEWS">Daily News</option>
        </select>
        <select value={format} onChange={e => { setFormatFilter(e.target.value); setPage(1); }} className="border border-slate-200 rounded-lg px-2 py-1.5 text-xs bg-white">
          <option value="">All formats</option>
          <option value="CARD_ONLY">Card only</option>
          <option value="CARD_WITH_VIDEO">Card + Video</option>
        </select>
        <select value={videoState} onChange={e => { setVideoStateFilter(e.target.value); setPage(1); }} className="border border-slate-200 rounded-lg px-2 py-1.5 text-xs bg-white">
          <option value="">Any video state</option>
          {Object.entries(VIDEO_LABEL).map(([k, label]) => <option key={k} value={k}>{label}</option>)}
        </select>
        <input value={category} onChange={e => { setCategory(e.target.value); setPage(1); }} placeholder="Filter by category (e.g. FARMER)"
          className="border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs w-64 bg-white" />
      </div>

      {isError && <QueryError error={error} onRetry={refetch} />}
      {isLoading && <div className="py-12 flex justify-center"><Loader2 className="animate-spin text-primary" size={28} /></div>}
      {data && data.data.length === 0 && (
        <div className="bg-white rounded-xl border border-slate-200 p-12 text-center space-y-2">
          <div className="text-slate-400 text-sm">Nothing currently in <b>{status.replace(/_/g, ' ')}</b> state.</div>
          <p className="text-xs text-slate-400">New items start as plain news cards: Drafts &rarr; Needs Review &rarr; Approved &rarr; Published. A video is only made if you request one.</p>
        </div>
      )}
      {data && data.data.length > 0 && (
        <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 shadow-sm overflow-hidden">
          {data.data.map((r: any) => (
            <button key={r.id} onClick={() => onOpen(r.id)} className="w-full text-left p-4 hover:bg-slate-50 transition-colors flex justify-between gap-4 items-center">
              <div className="min-w-0">
                <div className="font-semibold text-sm text-slate-900 truncate">{r.title}</div>
                <div className="text-xs text-slate-500 mt-0.5">
                  <span className="font-medium text-slate-700">{r.kind}</span> · {r.kind === 'NEWS' ? (r.newsStory?.publisher ?? 'News') : (r.scheme?.department ?? 'Yojana')} · {r.category} · updated {formatRelativeTime(r.updatedAt)}
                </div>
                {r.warnings?.length > 0 && <div className="text-xs text-amber-700 mt-1 flex items-center gap-1"><AlertTriangle size={12} /> {r.warnings[0]}{r.warnings.length > 1 && ` (+${r.warnings.length - 1})`}</div>}
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <FormatBadge format={r.format} />
                <VideoStateBadge item={r} />
                <StatusBadge status={r.status} />
              </div>
            </button>
          ))}
          <Pagination page={page} limit={limit} total={data.meta.total} onChange={setPage} />
        </div>
      )}
    </div>
  );
}

function SchemesView({ onOpenDraft }: { onOpenDraft: (id: string) => void }) {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('');
  const [scope, setScope] = useState('');
  const [page, setPage] = useState(1);
  const [showAddModal, setShowAddModal] = useState(false);
  const limit = 15;

  const { data, isLoading, isError, error, refetch, isFetching } = useQuery({
    queryKey: ['content-schemes', search, category, scope, page],
    queryFn: () => adminApi.getSchemes({ search, category, scope, page, limit }),
    refetchInterval: 10_000,
  });

  const seedMutation = useMutation({
    mutationFn: () => adminApi.seedSchemes(),
    onSuccess: (res: any) => {
      toast.success(`Seeded ${res.created} official schemes (${res.existing} already existed)!`);
      qc.invalidateQueries({ queryKey: ['content-schemes'] });
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const draftMutation = useMutation({
    mutationFn: (schemeId: string) => adminApi.createSchemeDraft(schemeId),
    onSuccess: (res: any) => {
      toast.success('Yojana card draft created. Review it, then publish it as a news card or request a video.');
      qc.invalidateQueries({ queryKey: ['content-schemes'] });
      qc.invalidateQueries({ queryKey: ['content-queue'] });
      qc.invalidateQueries({ queryKey: ['content-counts'] });
      if (res?.data?.id) onOpenDraft(res.data.id);
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const verifyMutation = useMutation({
    mutationFn: (schemeId: string) => adminApi.verifyScheme(schemeId),
    onSuccess: () => {
      toast.success('Scheme source verified!');
      qc.invalidateQueries({ queryKey: ['content-schemes'] });
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const deleteMutation = useMutation({
    mutationFn: (schemeId: string) => adminApi.deleteScheme(schemeId),
    onSuccess: () => {
      toast.success('Scheme deleted');
      qc.invalidateQueries({ queryKey: ['content-schemes'] });
    },
    onError: (e) => toast.error(describeError(e)),
  });

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2 items-center justify-between">
        <div className="flex flex-wrap gap-2 items-center">
          <input
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search Yojana name, department..."
            className="border border-slate-200 rounded-lg px-3 py-1.5 text-xs w-64 bg-white"
          />
          <select value={category} onChange={e => { setCategory(e.target.value); setPage(1); }} className="border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs bg-white">
            <option value="">All Categories</option>
            {SCHEME_CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
          <select value={scope} onChange={e => { setScope(e.target.value); setPage(1); }} className="border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs bg-white">
            <option value="">All Scopes</option>
            <option value="CENTRAL">Central Schemes</option>
            <option value="STATE">State Schemes</option>
          </select>
          <button
            onClick={() => refetch()}
            className="btn-outline text-xs py-1.5 px-2.5 flex items-center gap-1"
            title="Refresh schemes list"
          >
            <RefreshCw size={12} className={isFetching ? 'animate-spin' : ''} />
          </button>
        </div>

        <div className="flex items-center gap-2">
          {(!data || data?.data?.length === 0) && (
            <button
              onClick={() => seedMutation.mutate()}
              disabled={seedMutation.isPending}
              className="btn-outline text-xs py-1.5 px-3 flex items-center gap-1.5 border-primary text-primary hover:bg-primary/5"
            >
              {seedMutation.isPending ? <Loader2 size={13} className="animate-spin" /> : <Sparkles size={13} />}
              Seed Top National Yojanas
            </button>
          )}
          <button
            onClick={() => setShowAddModal(true)}
            className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5 shadow-sm"
          >
            <Plus size={13} />
            Add New Yojana
          </button>
        </div>
      </div>

      {isError && <QueryError error={error} onRetry={refetch} />}
      {isLoading && <div className="py-12 flex justify-center"><Loader2 className="animate-spin text-primary" size={28} /></div>}

      {data && data.data.length === 0 && (
        <div className="bg-white rounded-xl border border-slate-200 p-12 text-center space-y-3">
          <Landmark className="mx-auto text-slate-300" size={44} />
          <h3 className="font-bold text-slate-800 text-base">No Government Schemes Found</h3>
          <p className="text-xs text-slate-500 max-w-md mx-auto">
            Get started instantly with India&apos;s most popular welfare schemes (PM Kisan, Ayushman Bharat, PM Awas Yojana, PM Vishwakarma, Sukanya Samriddhi).
          </p>
          <div className="pt-2">
            <button
              onClick={() => seedMutation.mutate()}
              disabled={seedMutation.isPending}
              className="btn-primary text-xs py-2 px-4 inline-flex items-center gap-2"
            >
              {seedMutation.isPending ? <Loader2 size={14} className="animate-spin" /> : <Sparkles size={14} />}
              Seed Top Official Yojanas Now
            </button>
          </div>
        </div>
      )}

      {data && data.data.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {data.data.map((s: any) => (
            <div key={s.id} className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm hover:border-slate-300 transition-all flex flex-col justify-between space-y-3">
              <div className="space-y-1.5">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <h3 className="font-bold text-slate-900 text-sm leading-snug">{s.nameHi || s.officialName}</h3>
                    {s.nameHi && <div className="text-xs text-slate-500 font-medium truncate">{s.officialName}</div>}
                  </div>
                  <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full shrink-0 ${s.reviewStatus === 'SOURCE_VERIFIED' ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-slate-100 text-slate-600'}`}>
                    {s.reviewStatus.replace(/_/g, ' ')}
                  </span>
                </div>

                <div className="flex flex-wrap gap-1.5 items-center pt-1 text-[11px]">
                  <span className="bg-blue-50 text-blue-700 px-2 py-0.5 rounded-md font-medium border border-blue-100">{s.category}</span>
                  <span className="bg-purple-50 text-purple-700 px-2 py-0.5 rounded-md font-medium border border-purple-100">{s.scope}</span>
                  {s.department && <span className="text-slate-500 truncate max-w-[200px]" title={s.department}>• {s.department}</span>}
                </div>

                {s.benefits?.length > 0 && (
                  <p className="text-xs text-slate-600 line-clamp-2 bg-slate-50 p-2 rounded-lg mt-2 border border-slate-100">
                    <span className="font-semibold text-slate-700">लाभ: </span>{s.benefits[0]}
                  </p>
                )}

                <div className="flex items-center gap-3 text-xs text-slate-500 pt-1">
                  {s.applicationUrl && (
                    <a href={s.applicationUrl} target="_blank" rel="noreferrer" className="text-primary hover:underline inline-flex items-center gap-1 font-medium">
                      Official Portal <ExternalLink size={11} />
                    </a>
                  )}
                  <span>· {s._count?.videos ?? 0} card(s) drafted</span>
                  {s.lastVerifiedAt && <span>· verified {formatRelativeTime(s.lastVerifiedAt)}</span>}
                </div>
              </div>

              <div className="border-t border-slate-100 pt-3 flex items-center justify-between gap-2">
                <button
                  className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5 flex-1 justify-center"
                  disabled={draftMutation.isPending}
                  onClick={() => draftMutation.mutate(s.id)}
                >
                  <Play size={12} />
                  Create Video Draft
                </button>

                {s.reviewStatus !== 'SOURCE_VERIFIED' && (
                  <button
                    className="btn-outline text-xs py-1.5 px-2.5 flex items-center gap-1 text-emerald-700 border-emerald-200 hover:bg-emerald-50"
                    disabled={verifyMutation.isPending}
                    onClick={() => verifyMutation.mutate(s.id)}
                  >
                    <CheckCircle size={12} /> Verify
                  </button>
                )}

                <button
                  className="btn-ghost text-xs p-1.5 text-rose-600 hover:bg-rose-50 rounded-lg"
                  title="Delete Scheme"
                  disabled={deleteMutation.isPending}
                  onClick={() => {
                    if (confirm(`Delete scheme "${s.nameHi || s.officialName}"?`)) {
                      deleteMutation.mutate(s.id);
                    }
                  }}
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {data && <Pagination page={page} limit={limit} total={data.meta.total} onChange={setPage} />}

      {showAddModal && (
        <AddSchemeModal
          onClose={() => setShowAddModal(false)}
          onSuccess={() => {
            setShowAddModal(false);
            qc.invalidateQueries({ queryKey: ['content-schemes'] });
          }}
        />
      )}
    </div>
  );
}

function AddSchemeModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const [form, setForm] = useState({
    slug: '',
    officialName: '',
    nameHi: '',
    category: 'FARMER',
    scope: 'CENTRAL',
    stateCode: '',
    department: '',
    benefits: '',
    eligibility: '',
    documents: '',
    applicationSteps: '',
    applicationUrl: '',
    sourceUrls: '',
  });

  const create = useMutation({
    mutationFn: (data: any) => adminApi.createScheme(data),
    onSuccess: () => {
      toast.success('Yojana added successfully!');
      onSuccess();
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.officialName || !form.nameHi) {
      toast.error('Official Name and Hindi Name are required');
      return;
    }
    const slug = form.slug.trim() || form.officialName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    const toArr = (v: string) => v.split('\n').map(s => s.trim()).filter(Boolean);

    create.mutate({
      slug,
      officialName: form.officialName.trim(),
      nameHi: form.nameHi.trim(),
      category: form.category,
      scope: form.scope,
      stateCode: form.stateCode.trim() || null,
      department: form.department.trim() || null,
      benefits: toArr(form.benefits),
      eligibility: toArr(form.eligibility),
      documents: toArr(form.documents),
      applicationSteps: toArr(form.applicationSteps),
      applicationUrl: form.applicationUrl.trim() || null,
      sourceUrls: toArr(form.sourceUrls).filter(u => u.startsWith('https://')),
    });
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-[70] p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl p-6 max-w-xl w-full shadow-2xl max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        <div className="flex justify-between items-center mb-4">
          <h3 className="font-bold text-slate-900 text-lg">Add Government Scheme (सरकारी योजना)</h3>
          <button onClick={onClose}><X size={20} className="text-slate-400" /></button>
        </div>

        <form onSubmit={submit} className="space-y-3.5 text-xs">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Hindi Name (हिंदी नाम) *</label>
              <input
                required
                value={form.nameHi}
                onChange={e => setForm({ ...form, nameHi: e.target.value })}
                placeholder="उदा. प्रधानमंत्री किसान सम्मान निधि"
                className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-sm"
              />
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Official Name (English) *</label>
              <input
                required
                value={form.officialName}
                onChange={e => setForm({ ...form, officialName: e.target.value })}
                placeholder="PM Kisan Samman Nidhi"
                className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-sm"
              />
            </div>
          </div>

          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Category</label>
              <select
                value={form.category}
                onChange={e => setForm({ ...form, category: e.target.value })}
                className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs bg-white"
              >
                {SCHEME_CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Scope</label>
              <select
                value={form.scope}
                onChange={e => setForm({ ...form, scope: e.target.value })}
                className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs bg-white"
              >
                <option value="CENTRAL">Central (केंद्र सरकार)</option>
                <option value="STATE">State (राज्य सरकार)</option>
              </select>
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Slug (URL friendly)</label>
              <input
                value={form.slug}
                onChange={e => setForm({ ...form, slug: e.target.value })}
                placeholder="pm-kisan"
                className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs"
              />
            </div>
          </div>

          <div>
            <label className="font-semibold text-slate-700 block mb-1">Department / Ministry</label>
            <input
              value={form.department}
              onChange={e => setForm({ ...form, department: e.target.value })}
              placeholder="उदा. कृषि एवं किसान कल्याण मंत्रालय"
              className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Official Application URL (https://)</label>
              <input
                type="url"
                value={form.applicationUrl}
                onChange={e => setForm({ ...form, applicationUrl: e.target.value })}
                placeholder="https://pmkisan.gov.in"
                className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs"
              />
            </div>
            <div>
              <label className="font-semibold text-slate-700 block mb-1">Official Source URLs (one per line)</label>
              <textarea
                rows={2}
                value={form.sourceUrls}
                onChange={e => setForm({ ...form, sourceUrls: e.target.value })}
                placeholder="https://myscheme.gov.in"
                className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs resize-none"
              />
            </div>
          </div>

          <div>
            <label className="font-semibold text-slate-700 block mb-1">Benefits (मुख्य लाभ - one per line)</label>
            <textarea
              rows={2}
              value={form.benefits}
              onChange={e => setForm({ ...form, benefits: e.target.value })}
              placeholder="₹6,000 प्रति वर्ष 3 समान किस्तों में बैंक खाते में"
              className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs resize-none"
            />
          </div>

          <div>
            <label className="font-semibold text-slate-700 block mb-1">Eligibility (पात्रता विवरण - one per line)</label>
            <textarea
              rows={2}
              value={form.eligibility}
              onChange={e => setForm({ ...form, eligibility: e.target.value })}
              placeholder="सभी पात्र किसान परिवार जिनके नाम कृषि भूमि है"
              className="w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs resize-none"
            />
          </div>

          <div className="flex gap-2 pt-2 justify-end">
            <button type="button" className="btn-ghost" onClick={onClose} disabled={create.isPending}>Cancel</button>
            <button type="submit" className="btn-primary" disabled={create.isPending}>
              {create.isPending ? <Loader2 size={13} className="animate-spin inline mr-1" /> : null}
              Save Scheme
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

function JobsView() {
  const qc = useQueryClient();
  const [state, setState] = useState('FAILED');
  const { data, isError, error, refetch, isFetching } = useQuery({
    queryKey: ['content-jobs', state],
    queryFn: () => adminApi.getContentJobs({ state, limit: 50 }),
    refetchInterval: 5_000,
  });
  const cancel = useMutation({
    mutationFn: (id: string) => adminApi.cancelContentJob(id),
    onSuccess: () => { toast.success('Job cancelled'); qc.invalidateQueries({ queryKey: ['content-jobs'] }); },
    onError: (e) => toast.error(describeError(e)),
  });
  return (
    <div className="space-y-3">
      <div className="flex justify-between items-center">
        <select value={state} onChange={e => setState(e.target.value)} className="border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs bg-white">
          {['FAILED', 'QUEUED', 'RUNNING', 'SUCCEEDED', 'CANCELLED'].map(s => <option key={s}>{s}</option>)}
        </select>
        <button onClick={() => refetch()} className="btn-outline text-xs py-1 px-2.5 flex items-center gap-1">
          <RefreshCw size={12} className={isFetching ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      {isError && <QueryError error={error} onRetry={refetch} />}
      <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 shadow-sm overflow-hidden">
        {data?.data.length === 0 && <div className="p-8 text-sm text-slate-400 text-center">No {state.toLowerCase()} jobs.</div>}
        {data?.data.map((j: any) => (
          <div key={j.id} className="p-3.5 text-xs flex justify-between gap-3 items-center hover:bg-slate-50">
            <div className="min-w-0">
              <div className="font-semibold text-slate-900">{j.type} · try {j.attempts}/{j.maxAttempts} · ${(j.costMicroUsd / 1e6).toFixed(4)}</div>
              <div className="text-slate-500 mt-0.5">{formatRelativeTime(j.queuedAt)}</div>
              {j.failureReason && <div className="text-rose-600 mt-1 break-words font-mono text-[11px] bg-rose-50 p-1.5 rounded">{j.failureReason}</div>}
            </div>
            {(j.state === 'QUEUED' || j.state === 'RUNNING') &&
              <button className="btn-outline text-xs py-1 px-2.5" onClick={() => cancel.mutate(j.id)}>Cancel</button>}
          </div>
        ))}
      </div>
    </div>
  );
}

function ReportsView({ onOpen }: { onOpen: (id: string) => void }) {
  const qc = useQueryClient();
  const { data, isError, error, refetch } = useQuery({ queryKey: ['content-reports'], queryFn: () => adminApi.getContentReports({ status: 'OPEN' }), refetchInterval: 15_000 });
  const resolve = useMutation({
    mutationFn: ({ id, status }: { id: string; status: 'RESOLVED' | 'DISMISSED' }) => adminApi.resolveContentReport(id, status),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['content-reports'] }),
    onError: (e) => toast.error(describeError(e)),
  });
  return (
    <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100 shadow-sm overflow-hidden">
      {isError && <QueryError error={error} onRetry={refetch} />}
      {data?.data.length === 0 && <div className="p-8 text-sm text-slate-400 text-center">No open user reports.</div>}
      {data?.data.map((r: any) => (
        <div key={r.id} className="p-3 text-xs flex justify-between gap-3 items-center hover:bg-slate-50">
          <div>
            <button className="font-semibold text-primary text-left" onClick={() => onOpen(r.shortVideo.id)}>{r.shortVideo.title}</button>
            <div className="text-slate-500 mt-0.5">{r.reason} · {r.shortVideo.status} · {formatRelativeTime(r.createdAt)}</div>
            {r.note && <div className="text-slate-600 italic mt-1">“{r.note}”</div>}
          </div>
          <div className="flex gap-1.5 shrink-0">
            <button className="btn-outline text-xs py-1 px-2.5" onClick={() => resolve.mutate({ id: r.id, status: 'RESOLVED' })}>Resolve</button>
            <button className="btn-ghost text-xs py-1 px-2.5 text-slate-500" onClick={() => resolve.mutate({ id: r.id, status: 'DISMISSED' })}>Dismiss</button>
          </div>
        </div>
      ))}
    </div>
  );
}

function CostsView() {
  const { data, isError, error, refetch } = useQuery({ queryKey: ['content-costs'], queryFn: adminApi.getContentCosts });
  const usd = (m?: number | null) => (m == null ? '—' : `$${(m / 1e6).toFixed(4)}`);
  const c = data?.data;
  return (
    <div className="space-y-4">
      {isError && <QueryError error={error} onRetry={refetch} />}
      {c && (<>
        <p className="text-xs text-slate-500">Estimates from configurable pricing — not provider billing.</p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[['This month', usd(c.thisMonthMicroUsd)], ['Per published video', usd(c.perPublishedVideoMicroUsd)],
            ['Per 1,000 views', usd(c.per1000ViewsMicroUsd)], ['Failed-job spend', usd(c.failedJobsCostMicroUsd)]].map(([k, v]) => (
            <div key={k} className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm"><div className="text-xs text-slate-500">{k}</div><div className="text-lg font-bold text-slate-900 mt-0.5">{v}</div></div>
          ))}
        </div>
        <div className="bg-white border border-slate-200 rounded-xl divide-y divide-slate-100 shadow-sm overflow-hidden">
          {c.byStatus.map((s: any) => (
            <div key={s.status} className="p-3 text-xs flex justify-between"><span>{s.status} ({s.count})</span><span className="font-mono">{usd(s.costMicroUsd)}</span></div>
          ))}
        </div>
      </>)}
    </div>
  );
}

type Feed = { name: string; url: string; category: string };

function ScheduleView() {
  const qc = useQueryClient();
  const { data, isError, error, refetch } = useQuery({ queryKey: ['content-settings'], queryFn: adminApi.getContentSettings });
  const [form, setForm] = useState<any>(null);
  const s = form ?? data?.data;

  const save = useMutation({
    mutationFn: (body: any) => adminApi.putContentSettings(body),
    onSuccess: () => {
      toast.success('Settings saved');
      setForm(null);
      qc.invalidateQueries({ queryKey: ['content-settings'] });
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const run = useMutation({
    mutationFn: () => adminApi.runContentIngest(),
    onSuccess: (res: any) => {
      const rep = res?.report;
      const ing = rep?.ingest;
      const created = ing?.created ?? 0;
      const dupes = ing?.duplicates ?? 0;
      const drafts = rep?.draftsCreated ?? 0;
      const errs = ing?.errors?.length ? ` (${ing.errors.join('; ')})` : '';
      toast.success(`Ingest complete! ${created} new stories, ${dupes} known, ${drafts} drafts created.${errs}`);
      qc.invalidateQueries({ queryKey: ['content-settings'] });
      qc.invalidateQueries({ queryKey: ['content-queue'] });
      qc.invalidateQueries({ queryKey: ['content-counts'] });
      qc.invalidateQueries({ queryKey: ['content-health'] });
      qc.invalidateQueries({ queryKey: ['content-jobs'] });
    },
    onError: (e) => toast.error(describeError(e)),
  });

  if (isError) return <QueryError error={error} onRetry={refetch} />;
  if (!s) return <div className="py-12 flex justify-center"><Loader2 className="animate-spin text-primary" size={28} /></div>;
  const set = (patch: any) => setForm({ ...s, ...patch });
  const num = (k: string, label: string, hint?: string) => (
    <label className="block text-xs">
      <span className="font-semibold text-slate-700">{label}</span>
      <input type="number" value={s[k] ?? ''} onChange={e => set({ [k]: Number(e.target.value) })}
        className="mt-1 w-full border border-slate-200 rounded-lg px-2.5 py-1.5 text-sm" />
      {hint && <span className="text-slate-400 block mt-0.5">{hint}</span>}
    </label>
  );
  const feeds: Feed[] = s.feeds ?? [];
  const setFeed = (i: number, patch: Partial<Feed>) => set({ feeds: feeds.map((f, j) => (j === i ? { ...f, ...patch } : f)) });

  return (
    <div className="space-y-4 max-w-3xl">
      {!data?.sourceHostsConfigured && (
        <div className="border border-rose-300 bg-rose-50 rounded-xl p-3 text-xs text-rose-800">
          <b>CONTENT_SOURCE_HOSTS is empty on the server</b> — the worker will not fetch from any feed until host allowlist is configured.
        </div>
      )}
      {data?.blockedFeeds?.length > 0 && data?.sourceHostsConfigured && (
        <div className="border border-amber-300 bg-amber-50 rounded-xl p-3 text-xs">Feeds blocked by the host allowlist: {data.blockedFeeds.join(', ')}</div>
      )}

      <div className="bg-white border border-slate-200 rounded-xl p-5 space-y-4 shadow-sm">
        <label className="flex items-center gap-2 text-sm font-semibold text-slate-900 cursor-pointer">
          <input type="checkbox" checked={s.ingestEnabled} onChange={e => set({ ingestEnabled: e.target.checked })} className="rounded text-primary focus:ring-primary" />
          Scheduled news ingestion enabled
        </label>
        <div className="grid grid-cols-2 gap-4">
          {num('ingestIntervalMinutes', 'Ingest every (minutes)', '15–1440')}
          {num('maxNewVideosPerRun', 'New card drafts per run', '0–20')}
          {num('newsStaleHours', 'News is stale after (hours)', 'stale news is not drafted')}
          {num('newsAutoExpireHours', 'Auto-expire published news after (hours)', '0 = never')}
          {num('schemeVerifyMaxAgeDays', 'Scheme re-verification every (days)')}
          {num('developingFreshHours', 'Developing stories: max source age (hours)')}
        </div>
        <p className="text-xs text-slate-500">
          New stories always arrive as plain news-card drafts. Videos are never generated automatically — open an item, choose “Card + Video” and press “Generate video”.
        </p>
        <div className="text-xs text-slate-500 pt-1 border-t border-slate-100 flex items-center justify-between">
          <span>Last ingest run: {fmt(s.lastIngestAt)}</span>
          <span className="text-emerald-700 font-medium">Auto-scheduler active</span>
        </div>
      </div>

      <div className={`border rounded-xl p-5 space-y-3 shadow-sm ${s.autoPublishEnabled ? 'bg-emerald-50 border-emerald-300' : 'bg-white border-slate-200'}`}>
        <label className="flex items-center gap-2 text-sm font-semibold cursor-pointer">
          <input type="checkbox" checked={!!s.autoPublishEnabled} onChange={e => set({ autoPublishEnabled: e.target.checked })} className="rounded text-emerald-600 focus:ring-emerald-500" />
          Auto-publish (hands-off){s.autoPublishEnabled ? ' — ON' : ' — OFF'}
        </label>
        <p className="text-xs text-slate-600">
          Publishes a video from the review queue only when every safety and editorial check passes: rendered video, thumbnail, verified claims, fresh source check, and no editorial warnings.
        </p>
        <div className="grid grid-cols-2 gap-4">
          {num('autoPublishMaxPerDay', 'Max auto-published per 24h', '0–100')}
          <label className="flex items-center gap-2 text-xs self-end pb-2 cursor-pointer">
            <input type="checkbox" checked={!!s.autoPublishSchemes} onChange={e => set({ autoPublishSchemes: e.target.checked })} className="rounded text-emerald-600 focus:ring-emerald-500" />
            Also auto-publish verified Yojana (Scheme) videos
          </label>
        </div>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl p-5 space-y-3 shadow-sm">
        <div className="flex justify-between items-center">
          <div>
            <h3 className="font-semibold text-sm text-slate-900">News Feeds (RSS / Atom)</h3>
            <p className="text-xs text-slate-500">Live feeds polled for real-time news and scheme updates.</p>
          </div>
          <button className="btn-outline text-xs py-1 px-2.5 flex items-center gap-1" onClick={() => set({ feeds: [...feeds, { name: '', url: 'https://', category: 'NEWS' }] })}>
            <Plus size={12} /> Add Feed
          </button>
        </div>
        {feeds.map((f, i) => (
          <div key={i} className="grid grid-cols-12 gap-2 items-center">
            <input placeholder="Publisher name" value={f.name ?? ''} onChange={e => setFeed(i, { name: e.target.value })} className="col-span-3 border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs" />
            <input placeholder="https://…/rss" value={f.url ?? ''} onChange={e => setFeed(i, { url: e.target.value })} className="col-span-6 border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs font-mono" />
            <input placeholder="Category" value={f.category ?? ''} onChange={e => setFeed(i, { category: e.target.value })} className="col-span-2 border border-slate-200 rounded-lg px-2.5 py-1.5 text-xs" />
            <button aria-label="Remove feed" className="col-span-1 text-slate-400 hover:text-rose-600 p-1 flex justify-center" onClick={() => set({ feeds: feeds.filter((_, j) => j !== i) })}>
              <X size={16} />
            </button>
          </div>
        ))}
        {feeds.length === 0 && <div className="text-xs text-slate-400 py-3 text-center">No feeds configured. Click Add Feed to add Google News, PIB, etc.</div>}
      </div>

      <div className="flex gap-3">
        <button className="btn-primary" disabled={!form || save.isPending}
          onClick={() => { const { lastIngestAt, ...body } = form; save.mutate(body); }}>
          {save.isPending ? <Loader2 size={13} className="animate-spin inline mr-1.5" /> : null}
          Save Settings
        </button>
        <button
          className="btn-outline flex items-center gap-1.5"
          disabled={run.isPending || feeds.length === 0}
          onClick={() => run.mutate()}
        >
          {run.isPending ? <Loader2 size={13} className="animate-spin" /> : <RefreshCw size={13} />}
          {run.isPending ? 'Fetching Real-Time News...' : 'Run Ingest Now'}
        </button>
      </div>
    </div>
  );
}

export default function ContentPage() {
  const [view, setView] = useState<View>('content');
  const [openId, setOpenId] = useState<string | null>(null);

  return (
    <div className="p-6 space-y-5 max-w-7xl mx-auto">
      <div>
        <h1 className="text-xl font-bold text-slate-900">Yojana &amp; Daily News</h1>
        <p className="text-xs text-slate-500">Real-time government schemes &amp; daily news AI shorts management.</p>
      </div>
      <div className="flex gap-2 border-b border-slate-200">
        {[
          { key: 'content', label: 'Review Queue' },
          { key: 'schemes', label: 'Yojana (Schemes)' },
          { key: 'schedule', label: 'News Schedule & Feeds' },
          { key: 'jobs', label: 'Pipeline Jobs' },
          { key: 'reports', label: 'User Reports' },
          { key: 'costs', label: 'Cost Tracking' },
        ].map(tab => (
          <button
            key={tab.key}
            onClick={() => setView(tab.key as View)}
            className={`px-4 py-2 text-sm border-b-2 -mb-px transition-colors ${view === tab.key ? 'border-primary text-primary font-semibold' : 'border-transparent text-slate-500 hover:text-slate-800'}`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {view === 'content' && <ContentList onOpen={setOpenId} />}
      {view === 'schemes' && <SchemesView onOpenDraft={setOpenId} />}
      {view === 'jobs' && <JobsView />}
      {view === 'reports' && <ReportsView onOpen={setOpenId} />}
      {view === 'costs' && <CostsView />}
      {view === 'schedule' && <ScheduleView />}
      {openId && <DetailPanel id={openId} onClose={() => setOpenId(null)} />}
    </div>
  );
}
