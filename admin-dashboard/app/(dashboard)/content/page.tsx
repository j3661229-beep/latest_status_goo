'use client';

// Yojana & News — editorial console for AI-generated shorts.
// Static-export friendly: one page, detail opens in a slide-over (no dynamic routes).
import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { AlertTriangle, ExternalLink, Loader2, X, RefreshCw } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { formatRelativeTime } from '@/lib/utils';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';
import { Pagination } from '@/components/Pagination';

type View = 'content' | 'jobs' | 'reports' | 'costs' | 'schedule';

const STATUS_TABS: { label: string; status: string }[] = [
  { label: 'Needs Review', status: 'NEEDS_REVIEW' },
  { label: 'Drafts', status: 'DRAFT' },
  { label: 'Script Ready', status: 'SCRIPT_READY' },
  { label: 'Generating', status: 'GENERATING' },
  { label: 'Approved', status: 'APPROVED' },
  { label: 'Published', status: 'PUBLISHED' },
  { label: 'Failed', status: 'FAILED' },
  { label: 'Correction', status: 'CORRECTION_REQUIRED' },
  { label: 'Expired', status: 'EXPIRED' },
  { label: 'Unpublished', status: 'UNPUBLISHED' },
  { label: 'Rejected', status: 'REJECTED' },
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

function DetailPanel({ id, onClose }: { id: string; onClose: () => void }) {
  const qc = useQueryClient();
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['content-detail', id],
    queryFn: () => adminApi.getContent(id),
  });
  const [prompt, setPrompt] = useState<null | { action: string; title: string; hint?: string; min: number; label: string; extra?: any }>(null);
  const [scheduleAt, setScheduleAt] = useState('');
  const [draft, setDraft] = useState<null | { title: string; hook: string; narration: string; attribution: string; captions: string }>(null);

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
      toast.success(r.needsRerender ? 'Saved — video must be regenerated before approval' : 'Saved');
      setDraft(null); refresh();
    },
    onError: (e) => toast.error(describeError(e)),
  });

  const v = data?.data;
  const status: string | undefined = v?.status;
  const busy = act.isPending;
  const run = (action: string, body?: any) => act.mutate({ action, body });

  const startEdit = () => setDraft({
    title: v.title ?? '', hook: v.hook ?? '', attribution: v.attribution ?? '',
    narration: v.script?.narration ?? '',
    captions: JSON.stringify(v.captions ?? [], null, 2),
  });
  const submitEdit = () => {
    if (!draft) return;
    let captions: any;
    try { captions = JSON.parse(draft.captions || '[]'); } catch { toast.error('Captions must be valid JSON'); return; }
    save.mutate({
      title: draft.title, hook: draft.hook || null, attribution: draft.attribution || null,
      script: { ...(v.script ?? {}), narration: draft.narration }, captions,
    });
  };

  return (
    <div className="fixed inset-0 z-[60] flex justify-end bg-black/50" onClick={onClose}>
      <div className="bg-white w-full max-w-3xl h-full overflow-y-auto p-6 space-y-5" onClick={e => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold text-slate-900">{v?.title ?? 'Loading…'}</h2>
            {v && <div className="flex gap-2 mt-1 items-center"><StatusBadge status={v.status} /><span className="text-xs text-slate-500">{v.kind} · {v.category} · v{v.scriptVersion}</span></div>}
          </div>
          <button onClick={onClose} aria-label="Close"><X size={22} /></button>
        </div>

        {isLoading && <Loader2 className="animate-spin" />}
        {isError && <QueryError error={error} onRetry={refetch} />}

        {v && (<>
          {(v.warnings?.length > 0 || v.publishBlockers?.length > 0) && (
            <div className="border border-amber-300 bg-amber-50 rounded-xl p-3 text-xs space-y-1">
              <div className="font-bold text-amber-800 flex items-center gap-1"><AlertTriangle size={14} /> Review warnings</div>
              {v.publishBlockers?.map((w: string) => <div key={'b' + w} className="text-rose-700">⛔ {w}</div>)}
              {v.warnings?.map((w: string) => <div key={w} className="text-amber-800">• {w}</div>)}
            </div>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div className="aspect-[9/16] bg-slate-900 rounded-xl overflow-hidden">
              {v.videoUrl
                ? <video src={v.videoUrl} poster={v.thumbnailUrl ?? undefined} controls playsInline className="w-full h-full object-contain" />
                : <div className="h-full flex items-center justify-center text-slate-400 text-xs p-4 text-center">No rendered video yet</div>}
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
              <h3 className="font-semibold text-sm">Script &amp; captions</h3>
              {!draft && <button className="btn-outline text-xs py-1" onClick={startEdit}>Edit</button>}
            </div>
            {!draft ? (
              <div className="text-sm bg-slate-50 rounded-lg p-3 whitespace-pre-wrap">
                {v.hook && <div className="font-semibold mb-1">{v.hook}</div>}
                {v.script?.narration ?? <span className="text-slate-400">No script yet</span>}
                {v.attribution && <div className="text-xs text-slate-500 mt-2">Attribution: {v.attribution}</div>}
              </div>
            ) : (
              <div className="space-y-2">
                {(['title', 'hook', 'attribution'] as const).map(k => (
                  <input key={k} value={draft[k]} onChange={e => setDraft({ ...draft, [k]: e.target.value })} placeholder={k}
                    className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
                ))}
                <textarea value={draft.narration} rows={6} onChange={e => setDraft({ ...draft, narration: e.target.value })}
                  placeholder="Narration" className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm" />
                <textarea value={draft.captions} rows={6} onChange={e => setDraft({ ...draft, captions: e.target.value })}
                  placeholder='[{"start":0,"end":3,"text":"…"}]' className="w-full border border-slate-200 rounded-lg px-3 py-2 text-xs font-mono" />
                <p className="text-xs text-amber-700">Editing the script or captions discards the rendered video; it must be regenerated and re-reviewed.</p>
                <div className="flex gap-2">
                  <button className="btn-ghost" onClick={() => setDraft(null)}>Cancel</button>
                  <button className="btn-primary" disabled={save.isPending} onClick={submitEdit}>{save.isPending ? 'Saving…' : 'Save'}</button>
                </div>
              </div>
            )}
          </section>

          <section className="border-t pt-4 space-y-2">
            <h3 className="font-semibold text-sm">Actions</h3>
            <div className="flex flex-wrap gap-2 items-center">
              {status === 'NEEDS_REVIEW' && <>
                <button className="btn-success" disabled={busy} onClick={() => run('approve')}>Approve</button>
                <button className="btn-danger" disabled={busy} onClick={() => setPrompt({ action: 'reject', title: 'Reject content', min: 10, label: 'Reject', hint: 'Recorded in the audit trail.' })}>Reject</button>
              </>}
              {status === 'APPROVED' && <>
                <button className="btn-success" disabled={busy} onClick={() => run('publish')}>Publish now</button>
                <input type="datetime-local" value={scheduleAt} onChange={e => setScheduleAt(e.target.value)} className="border border-slate-200 rounded-lg px-2 py-1 text-xs" />
                <button className="btn-outline" disabled={busy || !scheduleAt} onClick={() => run('publish', { scheduledAt: new Date(scheduleAt).toISOString() })}>Schedule</button>
                <button className="btn-danger" disabled={busy} onClick={() => setPrompt({ action: 'reject', title: 'Reject content', min: 10, label: 'Reject' })}>Reject</button>
              </>}
              {status === 'PUBLISHED' && <>
                <button className="btn-outline" disabled={busy} onClick={() => setPrompt({ action: 'correct', title: 'Take down for correction', min: 10, label: 'Take down', hint: 'Removes it from the feed until corrected and re-reviewed.' })}>Correct</button>
                <button className="btn-danger" disabled={busy} onClick={() => setPrompt({ action: 'correct', title: 'Withdraw content', min: 10, label: 'Withdraw', hint: 'Unpublishes and marks the source as withdrawn.', extra: { withdraw: true } })}>Withdraw</button>
                <button className="btn-outline" disabled={busy} onClick={() => setPrompt({ action: 'unpublish', title: 'Unpublish', min: 10, label: 'Unpublish' })}>Unpublish</button>
                <button className="btn-outline" disabled={busy} onClick={() => setPrompt({ action: 'expire', title: 'Mark expired', min: 10, label: 'Expire' })}>Expire</button>
              </>}
              {status === 'FAILED' && <button className="btn-primary" disabled={busy} onClick={() => run('retry')}>Retry</button>}
              {['EXPIRED', 'UNPUBLISHED', 'CORRECTION_REQUIRED', 'GENERATED'].includes(status!) &&
                <button className="btn-primary" disabled={busy} onClick={() => run('request-review')}>Send to review</button>}
              {['DRAFT', 'SOURCE_VERIFIED', 'SCRIPT_READY', 'GENERATING'].includes(status!) &&
                <span className="text-xs text-slate-500">Waiting for generation pipeline — no review actions yet.</span>}
            </div>
          </section>

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

function AttentionPanel() {
  const { data } = useQuery({ queryKey: ['content-attention'], queryFn: adminApi.getContentAttention, refetchInterval: 120_000 });
  const a = data?.data;
  if (!a || (a.overdueSchemes.length === 0 && a.needsReviewOver24h === 0 && a.openReports === 0)) return null;
  return (
    <div className="border border-amber-300 bg-amber-50 rounded-xl p-3 text-xs space-y-1">
      <div className="font-bold text-amber-800 flex items-center gap-1"><AlertTriangle size={14} /> Needs attention</div>
      {a.openReports > 0 && <div>• {a.openReports} open user report(s) — see the Reports tab</div>}
      {a.needsReviewOver24h > 0 && <div>• {a.needsReviewOver24h} item(s) waiting for review for over 24h</div>}
      {a.overdueSchemes.map((x: any) => <div key={x.id}>• Scheme “{x.name}”: {x.reason}</div>)}
    </div>
  );
}

function ContentList({ onOpen }: { onOpen: (id: string) => void }) {
  const [status, setStatus] = useState('NEEDS_REVIEW');
  const [kind, setKind] = useState('');
  const [category, setCategory] = useState('');
  const [page, setPage] = useState(1);
  const limit = 20;

  const counts = useQuery({ queryKey: ['content-counts'], queryFn: adminApi.getContentCounts });
  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['content-queue', status, kind, category, page],
    queryFn: () => adminApi.getContentQueue({ status, kind, category, page, limit }),
  });
  const countFor = (s: string) =>
    (counts.data?.data ?? []).filter((c: any) => c.status === s && (!kind || c.kind === kind)).reduce((a: number, c: any) => a + c.count, 0);

  return (
    <div className="space-y-4">
      <AttentionPanel />
      <div className="flex flex-wrap gap-1.5">
        {STATUS_TABS.map(t => (
          <button key={t.status} onClick={() => { setStatus(t.status); setPage(1); }}
            className={`text-xs px-3 py-1.5 rounded-full border ${status === t.status ? 'bg-primary text-white border-primary' : 'bg-white border-slate-200 text-slate-600'}`}>
            {t.label} <span className="opacity-70">({countFor(t.status)})</span>
          </button>
        ))}
      </div>
      <div className="flex gap-2 items-center">
        <select value={kind} onChange={e => { setKind(e.target.value); setPage(1); }} className="border border-slate-200 rounded-lg px-2 py-1.5 text-xs">
          <option value="">All content</option>
          <option value="SCHEME">Sarkari Yojana / Scholarships</option>
          <option value="NEWS">Daily News</option>
        </select>
        <input value={category} onChange={e => { setCategory(e.target.value); setPage(1); }} placeholder="Category (e.g. SCHOLARSHIP)"
          className="border border-slate-200 rounded-lg px-2 py-1.5 text-xs w-56" />
      </div>

      {isError && <QueryError error={error} onRetry={refetch} />}
      {isLoading && <Loader2 className="animate-spin" />}
      {data && data.data.length === 0 && <div className="text-sm text-slate-400 py-10 text-center">Nothing in this state.</div>}
      <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100">
        {data?.data.map((r: any) => (
          <button key={r.id} onClick={() => onOpen(r.id)} className="w-full text-left p-4 hover:bg-slate-50 flex justify-between gap-4">
            <div className="min-w-0">
              <div className="font-semibold text-sm text-slate-900 truncate">{r.title}</div>
              <div className="text-xs text-slate-500">{r.kind === 'NEWS' ? r.newsStory?.publisher : r.scheme?.department} · {r.category} · updated {formatRelativeTime(r.updatedAt)}</div>
              {r.warnings?.length > 0 && <div className="text-xs text-amber-700 mt-1 flex items-center gap-1"><AlertTriangle size={12} /> {r.warnings[0]}{r.warnings.length > 1 && ` (+${r.warnings.length - 1})`}</div>}
            </div>
            <StatusBadge status={r.status} />
          </button>
        ))}
        {data && <Pagination page={page} limit={limit} total={data.meta.total} onChange={setPage} />}
      </div>
    </div>
  );
}

function JobsView() {
  const qc = useQueryClient();
  const [state, setState] = useState('FAILED');
  const { data, isError, error, refetch } = useQuery({ queryKey: ['content-jobs', state], queryFn: () => adminApi.getContentJobs({ state, limit: 50 }) });
  const cancel = useMutation({
    mutationFn: (id: string) => adminApi.cancelContentJob(id),
    onSuccess: () => { toast.success('Job cancelled'); qc.invalidateQueries({ queryKey: ['content-jobs'] }); },
    onError: (e) => toast.error(describeError(e)),
  });
  return (
    <div className="space-y-3">
      <select value={state} onChange={e => setState(e.target.value)} className="border border-slate-200 rounded-lg px-2 py-1.5 text-xs">
        {['FAILED', 'QUEUED', 'RUNNING', 'SUCCEEDED', 'CANCELLED'].map(s => <option key={s}>{s}</option>)}
      </select>
      {isError && <QueryError error={error} onRetry={refetch} />}
      <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100">
        {data?.data.length === 0 && <div className="p-6 text-sm text-slate-400 text-center">No {state.toLowerCase()} jobs.</div>}
        {data?.data.map((j: any) => (
          <div key={j.id} className="p-3 text-xs flex justify-between gap-3">
            <div className="min-w-0">
              <div className="font-semibold">{j.type} · try {j.attempts}/{j.maxAttempts} · ${(j.costMicroUsd / 1e6).toFixed(4)}</div>
              <div className="text-slate-500">{formatRelativeTime(j.queuedAt)}</div>
              {j.failureReason && <div className="text-rose-600 break-words">{j.failureReason}</div>}
            </div>
            {(j.state === 'QUEUED' || j.state === 'RUNNING') &&
              <button className="btn-outline text-xs py-1" onClick={() => cancel.mutate(j.id)}>Cancel</button>}
          </div>
        ))}
      </div>
    </div>
  );
}

function ReportsView({ onOpen }: { onOpen: (id: string) => void }) {
  const qc = useQueryClient();
  const { data, isError, error, refetch } = useQuery({ queryKey: ['content-reports'], queryFn: () => adminApi.getContentReports({ status: 'OPEN' }) });
  const resolve = useMutation({
    mutationFn: ({ id, status }: { id: string; status: 'RESOLVED' | 'DISMISSED' }) => adminApi.resolveContentReport(id, status),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['content-reports'] }),
    onError: (e) => toast.error(describeError(e)),
  });
  return (
    <div className="bg-white rounded-xl border border-slate-200 divide-y divide-slate-100">
      {isError && <QueryError error={error} onRetry={refetch} />}
      {data?.data.length === 0 && <div className="p-6 text-sm text-slate-400 text-center">No open user reports.</div>}
      {data?.data.map((r: any) => (
        <div key={r.id} className="p-3 text-xs flex justify-between gap-3">
          <div>
            <button className="font-semibold text-blue-700" onClick={() => onOpen(r.shortVideo.id)}>{r.shortVideo.title}</button>
            <div>{r.reason} · {r.shortVideo.status} · {formatRelativeTime(r.createdAt)}</div>
            {r.note && <div className="text-slate-500">“{r.note}”</div>}
          </div>
          <div className="flex gap-1 shrink-0">
            <button className="btn-outline text-xs py-1" onClick={() => resolve.mutate({ id: r.id, status: 'RESOLVED' })}>Resolve</button>
            <button className="btn-ghost text-xs py-1" onClick={() => resolve.mutate({ id: r.id, status: 'DISMISSED' })}>Dismiss</button>
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
    <div className="space-y-3">
      {isError && <QueryError error={error} onRetry={refetch} />}
      {c && (<>
        <p className="text-xs text-slate-500">Estimates from configurable pricing — not provider billing.</p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[['This month', usd(c.thisMonthMicroUsd)], ['Per published video', usd(c.perPublishedVideoMicroUsd)],
            ['Per 1,000 views', usd(c.per1000ViewsMicroUsd)], ['Failed-job spend', usd(c.failedJobsCostMicroUsd)]].map(([k, v]) => (
            <div key={k} className="bg-white border border-slate-200 rounded-xl p-4"><div className="text-xs text-slate-500">{k}</div><div className="text-lg font-bold">{v}</div></div>
          ))}
        </div>
        <div className="bg-white border border-slate-200 rounded-xl divide-y divide-slate-100">
          {c.byStatus.map((s: any) => (
            <div key={s.status} className="p-3 text-xs flex justify-between"><span>{s.status} ({s.count})</span><span>{usd(s.costMicroUsd)}</span></div>
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
    onSuccess: () => { toast.success('Settings saved'); setForm(null); qc.invalidateQueries({ queryKey: ['content-settings'] }); },
    onError: (e) => toast.error(describeError(e)),
  });
  const run = useMutation({
    mutationFn: () => adminApi.runContentIngest(),
    onSuccess: () => toast.success('Ingest queued — the worker will pick it up shortly'),
    onError: (e) => toast.error(describeError(e)),
  });

  if (isError) return <QueryError error={error} onRetry={refetch} />;
  if (!s) return <Loader2 className="animate-spin" />;
  const set = (patch: any) => setForm({ ...s, ...patch });
  const num = (k: string, label: string, hint?: string) => (
    <label className="block text-xs">
      <span className="font-semibold text-slate-700">{label}</span>
      <input type="number" value={s[k]} onChange={e => set({ [k]: Number(e.target.value) })}
        className="mt-1 w-full border border-slate-200 rounded-lg px-2 py-1.5 text-sm" />
      {hint && <span className="text-slate-400">{hint}</span>}
    </label>
  );
  const feeds: Feed[] = s.feeds ?? [];
  const setFeed = (i: number, patch: Partial<Feed>) => set({ feeds: feeds.map((f, j) => (j === i ? { ...f, ...patch } : f)) });

  return (
    <div className="space-y-4 max-w-3xl">
      {!data?.sourceHostsConfigured && (
        <div className="border border-rose-300 bg-rose-50 rounded-xl p-3 text-xs text-rose-800">
          <b>CONTENT_SOURCE_HOSTS is empty on the server</b> — the worker will not fetch from any feed until the hosts you are permitted to use are added to that environment variable.
        </div>
      )}
      {data?.blockedFeeds?.length > 0 && data?.sourceHostsConfigured && (
        <div className="border border-amber-300 bg-amber-50 rounded-xl p-3 text-xs">Feeds blocked by the host allowlist: {data.blockedFeeds.join(', ')}</div>
      )}

      <div className="bg-white border border-slate-200 rounded-xl p-4 space-y-4">
        <label className="flex items-center gap-2 text-sm font-semibold">
          <input type="checkbox" checked={s.ingestEnabled} onChange={e => set({ ingestEnabled: e.target.checked })} />
          Scheduled news ingestion enabled
        </label>
        <div className="grid grid-cols-2 gap-4">
          {num('ingestIntervalMinutes', 'Ingest every (minutes)', '15–1440')}
          {num('maxNewVideosPerRun', 'New drafts per run', '0–20 (limits spend)')}
          {num('newsStaleHours', 'News is stale after (hours)', 'unpublished stale news is auto-rejected')}
          {num('newsAutoExpireHours', 'Auto-expire published news after (hours)', '0 = never')}
          {num('schemeVerifyMaxAgeDays', 'Scheme re-verification every (days)')}
          {num('developingFreshHours', 'Developing stories: max source age (hours)')}
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={s.autoGenerate} onChange={e => set({ autoGenerate: e.target.checked })} />
          Automatically generate scripts/videos for new drafts (never publishes — review is always required)
        </label>
        <div className="text-xs text-slate-500">Last ingest: {fmt(s.lastIngestAt)}</div>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl p-4 space-y-2">
        <div className="flex justify-between items-center">
          <h3 className="font-semibold text-sm">News feeds</h3>
          <button className="btn-outline text-xs py-1" onClick={() => set({ feeds: [...feeds, { name: '', url: 'https://', category: 'INDIA' }] })}>Add feed</button>
        </div>
        <p className="text-xs text-slate-500">Only add feeds whose terms permit automated retrieval and summarisation, and whose host is on the server allowlist.</p>
        {feeds.map((f, i) => (
          <div key={i} className="grid grid-cols-12 gap-2">
            <input placeholder="Publisher name" value={f.name} onChange={e => setFeed(i, { name: e.target.value })} className="col-span-3 border border-slate-200 rounded-lg px-2 py-1.5 text-xs" />
            <input placeholder="https://…/rss" value={f.url} onChange={e => setFeed(i, { url: e.target.value })} className="col-span-6 border border-slate-200 rounded-lg px-2 py-1.5 text-xs" />
            <input placeholder="Category" value={f.category} onChange={e => setFeed(i, { category: e.target.value })} className="col-span-2 border border-slate-200 rounded-lg px-2 py-1.5 text-xs" />
            <button aria-label="Remove feed" className="col-span-1" onClick={() => set({ feeds: feeds.filter((_, j) => j !== i) })}><X size={16} /></button>
          </div>
        ))}
        {feeds.length === 0 && <div className="text-xs text-slate-400">No feeds configured — nothing will be ingested.</div>}
      </div>

      <div className="flex gap-2">
        <button className="btn-primary" disabled={!form || save.isPending}
          onClick={() => { const { lastIngestAt, ...body } = form; save.mutate(body); }}>{save.isPending ? 'Saving…' : 'Save settings'}</button>
        <button className="btn-outline" disabled={run.isPending || feeds.length === 0 || !!form} onClick={() => run.mutate()}>Run ingest now</button>
      </div>
    </div>
  );
}

export default function ContentPage() {
  const [view, setView] = useState<View>('content');
  const [openId, setOpenId] = useState<string | null>(null);
  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-900">Yojana &amp; Daily News</h1>
        <p className="text-xs text-slate-500">AI-assisted shorts. Nothing is public until a reviewer approves and publishes it.</p>
      </div>
      <div className="flex gap-2 border-b border-slate-200">
        {(['content', 'schedule', 'jobs', 'reports', 'costs'] as View[]).map(v => (
          <button key={v} onClick={() => setView(v)}
            className={`px-4 py-2 text-sm capitalize border-b-2 -mb-px ${view === v ? 'border-primary text-primary font-semibold' : 'border-transparent text-slate-500'}`}>{v}</button>
        ))}
      </div>
      {view === 'content' && <ContentList onOpen={setOpenId} />}
      {view === 'jobs' && <JobsView />}
      {view === 'reports' && <ReportsView onOpen={setOpenId} />}
      {view === 'costs' && <CostsView />}
      {view === 'schedule' && <ScheduleView />}
      {openId && <DetailPanel id={openId} onClose={() => setOpenId(null)} />}
    </div>
  );
}
