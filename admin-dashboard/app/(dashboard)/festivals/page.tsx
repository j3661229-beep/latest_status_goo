'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Edit2, Calendar, Ban, CheckCircle } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';

export default function FestivalsPage() {
  const queryClient = useQueryClient();
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  
  const [form, setForm] = useState({
    nameEn: '', nameHi: '', nameMr: '', emoji: '🎉', date: '', notifyDaysBefore: 2, isActive: true, isRecurring: true
  });

  const { data: festivalRes, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['admin-festivals'],
    queryFn: adminApi.getFestivals,
  });

  const createMutation = useMutation({
    mutationFn: adminApi.createFestival,
    onError: (err) => toast.apiError(err, 'Failed to create festival'),
    onSuccess: () => {
      toast.success('Festival created');
      queryClient.invalidateQueries({ queryKey: ['admin-festivals'] });
      setIsFormOpen(false);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: any }) => adminApi.updateFestival(id, data),
    onError: (err) => toast.apiError(err, 'Failed to update festival'),
    onSuccess: () => {
      toast.success('Festival updated');
      queryClient.invalidateQueries({ queryKey: ['admin-festivals'] });
      setEditId(null);
      setIsFormOpen(false);
    },
  });

  const handleEdit = (f: any) => {
    setEditId(f.id);
    setForm({
      nameEn: f.nameEn, nameHi: f.nameHi, nameMr: f.nameMr, emoji: f.emoji,
      date: new Date(f.date).toISOString().split('T')[0], notifyDaysBefore: f.notifyDaysBefore,
      isActive: f.isActive, isRecurring: f.isRecurring ?? true
    });
    setIsFormOpen(true);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editId) {
      // PUT /admin/festivals/:id does not accept isRecurring — don't send it.
      const { isRecurring: _ignored, ...data } = form;
      updateMutation.mutate({ id: editId, data });
    } else {
      // POST always creates the festival as active; isActive isn't read on create.
      const { isActive: _ignored, ...data } = form;
      createMutation.mutate(data);
    }
  };

  const festivals = festivalRes?.data || [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900 tracking-tight">Festivals &amp; Events</h1>
          <p className="text-slate-500 text-sm mt-0.5">Manage platform content events, calendar highlights, and reminders</p>
        </div>
        <button 
          onClick={() => { setEditId(null); setForm({ nameEn: '', nameHi: '', nameMr: '', emoji: '🎉', date: '', notifyDaysBefore: 2, isActive: true, isRecurring: true }); setIsFormOpen(true); }}
          className="btn-primary flex items-center gap-1.5 text-xs py-1.5 px-3 self-start sm:self-auto"
        >
          <Plus size={14} /> Add Festival
        </button>
      </div>

      {isFormOpen && (
        <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-sm mb-6 animate-in fade-in duration-150">
          <h2 className="text-base font-semibold text-slate-900 mb-4">{editId ? 'Edit Festival' : 'Create Festival'}</h2>
          <form className="space-y-4" onSubmit={handleSubmit}>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
              <div>
                <label className="text-xs font-medium text-slate-700 block mb-1">Name (English) *</label>
                <input required value={form.nameEn ?? ''} onChange={e => setForm(f => ({ ...f, nameEn: e.target.value }))} className="w-full px-3 py-2 border border-slate-300 rounded-lg bg-white focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 text-sm" placeholder="Diwali" />
              </div>
              <div>
                <label className="text-xs font-medium text-slate-700 block mb-1">Name (Hindi) *</label>
                <input required value={form.nameHi ?? ''} onChange={e => setForm(f => ({ ...f, nameHi: e.target.value }))} className="w-full px-3 py-2 border border-slate-300 rounded-lg bg-white focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 text-sm font-devanagari" placeholder="दीपावली" />
              </div>
              <div>
                <label className="text-xs font-medium text-slate-700 block mb-1">Name (Marathi) *</label>
                <input required value={form.nameMr ?? ''} onChange={e => setForm(f => ({ ...f, nameMr: e.target.value }))} className="w-full px-3 py-2 border border-slate-300 rounded-lg bg-white focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 text-sm font-devanagari" placeholder="दिवाळी" />
              </div>
            </div>
            
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-3.5">
              <div>
                <label className="text-xs font-medium text-slate-700 block mb-1">Event Date *</label>
                <input type="date" required value={form.date ?? ''} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} className="w-full px-3 py-2 border border-slate-300 rounded-lg bg-white focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 text-sm" />
              </div>
              <div>
                <label className="text-xs font-medium text-slate-700 block mb-1">Notify Days Before</label>
                <input type="number" min="0" value={form.notifyDaysBefore ?? 0} onChange={e => setForm(f => ({ ...f, notifyDaysBefore: parseInt(e.target.value) || 0 }))} className="w-full px-3 py-2 border border-slate-300 rounded-lg bg-white focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 text-sm" />
              </div>
              <div>
                <label className="text-xs font-medium text-slate-700 block mb-1">Emoji Icon</label>
                <input required value={form.emoji ?? ''} onChange={e => setForm(f => ({ ...f, emoji: e.target.value }))} className="w-full px-3 py-2 border border-slate-300 rounded-lg bg-white focus:outline-none focus:border-blue-600 focus:ring-1 focus:ring-blue-600 text-sm text-center text-lg" />
              </div>
              <div className="flex flex-col justify-center gap-1.5 sm:mt-5">
                {editId ? (
                  <>
                    <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-slate-700">
                      <input type="checkbox" checked={form.isActive} onChange={e => setForm(f => ({ ...f, isActive: e.target.checked }))} className="rounded border-slate-300 text-blue-600 focus:ring-blue-500" />
                      <span>Active Status</span>
                    </label>
                    <span className="text-[11px] text-slate-400" title="Recurrence can only be set when creating a festival">
                      {form.isRecurring ? 'Recurs yearly' : 'One-time event'} (set at creation)
                    </span>
                  </>
                ) : (
                  <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-slate-700">
                    <input type="checkbox" checked={form.isRecurring} onChange={e => setForm(f => ({ ...f, isRecurring: e.target.checked }))} className="rounded border-slate-300 text-blue-600 focus:ring-blue-500" />
                    <span>Recurs yearly</span>
                  </label>
                )}
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
              <button type="button" onClick={() => setIsFormOpen(false)} className="btn-ghost text-xs py-1.5 px-3" disabled={createMutation.isPending || updateMutation.isPending}>Cancel</button>
              <button type="submit" className="btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5" disabled={createMutation.isPending || updateMutation.isPending}>
                {(createMutation.isPending || updateMutation.isPending) && (
                  <div className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                )}
                {editId ? (updateMutation.isPending ? 'Saving...' : 'Save Changes') : (createMutation.isPending ? 'Creating...' : 'Create Festival')}
              </button>
            </div>
          </form>
        </div>
      )}

      {isError && <QueryError error={error} onRetry={() => refetch()} />}

      {/* List */}
      {!isError && (
      <div className="bg-white rounded-xl border border-slate-200/80 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full data-table min-w-[600px]">
            <thead>
              <tr>
                <th className="text-left w-12">Icon</th>
                <th className="text-left">Festival Name</th>
                <th className="text-left">Date</th>
                <th className="text-center">Notifications</th>
                <th className="text-center">Status</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr><td colSpan={6} className="text-center py-8 text-slate-400 text-xs">Loading festivals...</td></tr>
              ) : festivals.length === 0 ? (
                <tr><td colSpan={6} className="text-center py-8 text-slate-400 text-xs">No festivals registered</td></tr>
              ) : festivals.map((f: any) => (
                <tr key={f.id} className={!f.isActive ? 'opacity-50 bg-slate-50/50' : ''}>
                  <td className="text-xl text-center">{f.emoji}</td>
                  <td>
                    <div className="font-semibold text-slate-800 text-sm">{f.nameEn}</div>
                    <div className="text-xs text-slate-400 font-devanagari">{f.nameHi} · {f.nameMr}</div>
                  </td>
                  <td>
                    <div className="flex items-center gap-1.5 text-xs text-slate-600 tabular-nums">
                      <Calendar size={13} className="text-blue-600" />
                      <span>{new Date(f.date).toLocaleDateString()}</span>
                    </div>
                  </td>
                  <td className="text-center">
                    <span className="text-xs bg-slate-50 border border-slate-200/60 px-2 py-0.5 rounded-md text-slate-600 tabular-nums">{f.notifyDaysBefore} days before</span>
                  </td>
                  <td className="text-center">
                    {f.isActive ? (
                      <span className="badge-approved inline-flex items-center gap-1"><CheckCircle size={11}/> Active</span>
                    ) : (
                      <span className="badge-rejected inline-flex items-center gap-1"><Ban size={11}/> Disabled</span>
                    )}
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end gap-1">
                      <button onClick={() => handleEdit(f)} className="p-1.5 rounded-md hover:bg-slate-100 text-slate-400 hover:text-blue-600 transition-colors" title="Edit">
                        <Edit2 size={13} />
                      </button>
                      <button onClick={() => updateMutation.mutate({ id: f.id, data: { isActive: !f.isActive } })} disabled={updateMutation.isPending} className="p-1.5 rounded-md hover:bg-slate-100 text-slate-400 hover:text-amber-600 transition-colors" title="Toggle Active">
                        <Ban size={13} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      )}
    </div>
  );
}
