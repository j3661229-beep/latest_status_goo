'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Edit2, Calendar, Ban, CheckCircle } from 'lucide-react';
import { adminApi } from '@/lib/api';

export default function FestivalsPage() {
  const queryClient = useQueryClient();
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  
  const [form, setForm] = useState({
    nameEn: '', nameHi: '', nameMr: '', emoji: '🎉', date: '', notifyDaysBefore: 2, isActive: true, isRecurring: true
  });

  const { data: festivalRes, isLoading } = useQuery({
    queryKey: ['admin-festivals'],
    queryFn: adminApi.getFestivals,
  });

  const createMutation = useMutation({
    mutationFn: adminApi.createFestival,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-festivals'] });
      setIsFormOpen(false);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string, data: any }) => adminApi.updateFestival(id, data),
    onSuccess: () => {
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
      isActive: f.isActive, isRecurring: f.isRecurring
    });
    setIsFormOpen(true);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editId) {
      updateMutation.mutate({ id: editId, data: form });
    } else {
      createMutation.mutate(form);
    }
  };

  const festivals = festivalRes?.data || [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-900 text-slate-800">Festivals & Events</h1>
          <p className="text-muted text-sm mt-1">Manage platform content events and reminders</p>
        </div>
        <button 
          onClick={() => { setEditId(null); setForm({ nameEn: '', nameHi: '', nameMr: '', emoji: '🎉', date: '', notifyDaysBefore: 2, isActive: true, isRecurring: true }); setIsFormOpen(true); }}
          className="btn-primary flex items-center gap-2 text-sm"
        >
          <Plus size={14} /> Add Festival
        </button>
      </div>

      {isFormOpen && (
        <div className="bg-white rounded-2xl p-6 border border-surface-border shadow-card mb-6 animate-in slide-in-from-top-4">
          <h2 className="text-lg font-800 text-slate-800 mb-4">{editId ? 'Edit Festival' : 'Create Festival'}</h2>
          <form className="space-y-4" onSubmit={handleSubmit}>
            <div className="grid grid-cols-3 gap-4">
              <div>
                <label className="text-xs font-700 text-slate-600 block mb-1.5">Name (English) *</label>
                <input required value={form.nameEn} onChange={e => setForm(f => ({ ...f, nameEn: e.target.value }))} className="w-full px-4 py-2 border rounded-xl bg-surface focus:outline-none focus:border-primary text-sm" placeholder="Diwali" />
              </div>
              <div>
                <label className="text-xs font-700 text-slate-600 block mb-1.5">Name (Hindi) *</label>
                <input required value={form.nameHi} onChange={e => setForm(f => ({ ...f, nameHi: e.target.value }))} className="w-full px-4 py-2 border rounded-xl bg-surface focus:outline-none focus:border-primary text-sm font-devanagari" placeholder="दीपावली" />
              </div>
              <div>
                <label className="text-xs font-700 text-slate-600 block mb-1.5">Name (Marathi) *</label>
                <input required value={form.nameMr} onChange={e => setForm(f => ({ ...f, nameMr: e.target.value }))} className="w-full px-4 py-2 border rounded-xl bg-surface focus:outline-none focus:border-primary text-sm font-devanagari" placeholder="दिवाळी" />
              </div>
            </div>
            
            <div className="grid grid-cols-4 gap-4">
              <div>
                <label className="text-xs font-700 text-slate-600 block mb-1.5">Event Date *</label>
                <input type="date" required value={form.date} onChange={e => setForm(f => ({ ...f, date: e.target.value }))} className="w-full px-4 py-2 border rounded-xl bg-surface focus:outline-none focus:border-primary text-sm" />
              </div>
              <div>
                <label className="text-xs font-700 text-slate-600 block mb-1.5">Notify Days Before</label>
                <input type="number" min="0" value={form.notifyDaysBefore} onChange={e => setForm(f => ({ ...f, notifyDaysBefore: parseInt(e.target.value) }))} className="w-full px-4 py-2 border rounded-xl bg-surface focus:outline-none focus:border-primary text-sm" />
              </div>
              <div>
                <label className="text-xs font-700 text-slate-600 block mb-1.5">Emoji Icon</label>
                <input required value={form.emoji} onChange={e => setForm(f => ({ ...f, emoji: e.target.value }))} className="w-full px-4 py-2 border rounded-xl bg-surface focus:outline-none focus:border-primary text-sm text-center text-xl" />
              </div>
              <div className="flex items-center gap-4 mt-6">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" checked={form.isActive} onChange={e => setForm(f => ({ ...f, isActive: e.target.checked }))} className="rounded border-gray-300 text-primary focus:ring-primary" />
                  <span className="text-sm font-600 text-slate-700">Active Status</span>
                </label>
              </div>
            </div>
            <div className="flex justify-end gap-3 pt-2">
              <button type="button" onClick={() => setIsFormOpen(false)} className="btn-ghost" disabled={createMutation.isPending || updateMutation.isPending}>Cancel</button>
              <button type="submit" className="btn-primary flex items-center gap-2" disabled={createMutation.isPending || updateMutation.isPending}>
                {(createMutation.isPending || updateMutation.isPending) && (
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                )}
                {editId ? (updateMutation.isPending ? 'Saving...' : 'Save Changes') : (createMutation.isPending ? 'Creating...' : 'Create Festival')}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* List */}
      <div className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden">
        <table className="w-full data-table">
          <thead className="bg-surface">
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
               <tr><td colSpan={6} className="text-center py-8 text-muted">Loading...</td></tr>
            ) : festivals.length === 0 ? (
               <tr><td colSpan={6} className="text-center py-8 text-muted">No festivals registered</td></tr>
            ) : festivals.map((f: any) => (
              <tr key={f.id} className={!f.isActive ? 'opacity-50' : ''}>
                <td className="text-2xl text-center">{f.emoji}</td>
                <td>
                  <div className="font-700 text-slate-800 text-sm">{f.nameEn}</div>
                  <div className="text-xs text-muted">{f.nameHi} · {f.nameMr}</div>
                </td>
                <td>
                  <div className="flex items-center gap-2">
                    <Calendar size={14} className="text-primary" />
                    <span className="text-sm font-600 text-slate-700">{new Date(f.date).toLocaleDateString()}</span>
                  </div>
                </td>
                <td className="text-center">
                  <span className="text-xs bg-surface px-2 py-1 rounded-md text-slate-600">{f.notifyDaysBefore} days before</span>
                </td>
                <td className="text-center">
                  {f.isActive ? (
                    <span className="text-xs text-success font-700 inline-flex items-center gap-1"><CheckCircle size={12}/> Active</span>
                  ) : (
                    <span className="text-xs text-danger font-700 inline-flex items-center gap-1"><Ban size={12}/> Disabled</span>
                  )}
                </td>
                <td className="text-right">
                  <button onClick={() => handleEdit(f)} className="p-1.5 rounded-lg hover:bg-surface text-muted hover:text-primary transition-colors cursor-pointer" title="Edit">
                    <Edit2 size={14} />
                  </button>
                  <button onClick={() => updateMutation.mutate({ id: f.id, data: { isActive: !f.isActive } })} className="p-1.5 rounded-lg hover:bg-surface text-muted hover:text-amber-500 transition-colors mx-1 cursor-pointer" title="Toggle Active">
                    <Ban size={14} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
