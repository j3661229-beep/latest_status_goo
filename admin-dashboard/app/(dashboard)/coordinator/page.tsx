'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Pin, Search, Trash2, Edit3, CheckCircle, Plus, Sparkles, RefreshCw, X, Eye } from 'lucide-react';
import { adminApi } from '@/lib/api';

const INDIAN_STATES = [
  'All India (National)',
  'Maharashtra',
  'Uttar Pradesh',
  'Bihar',
  'Madhya Pradesh',
  'Rajasthan',
  'Gujarat',
  'West Bengal',
  'Karnataka',
  'Tamil Nadu',
  'Punjab',
  'Haryana',
  'Delhi',
];

export default function CoordinatorPicksPage() {
  const queryClient = useQueryClient();
  const [selectedState, setSelectedState] = useState('All');
  const [editingTemplate, setEditingTemplate] = useState<any | null>(null);
  const [editNote, setEditNote] = useState('');
  const [editState, setEditState] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchApproved, setSearchApproved] = useState('');

  // 1. Fetch coordinator picks
  const { data: picks = [], isLoading, refetch, isRefetching } = useQuery({
    queryKey: ['admin-coordinator-picks'],
    queryFn: () => adminApi.getCoordinatorPicks(),
    staleTime: 30 * 1000,
  });

  // 2. Fetch approved templates for pinning
  const { data: approvedTemplatesData } = useQuery({
    queryKey: ['approved-templates-for-pin', searchApproved],
    queryFn: () => adminApi.getTemplates({ status: 'APPROVED', search: searchApproved, limit: 15 }),
    enabled: showAddModal,
  });

  // 3. Mutation to set / update coordinator pick
  const setPickMutation = useMutation({
    mutationFn: ({ id, isCoordinatorPick, coordinatorNote, coordinatorState }: {
      id: string;
      isCoordinatorPick: boolean;
      coordinatorNote?: string;
      coordinatorState?: string;
    }) => adminApi.setCoordinatorPick(id, isCoordinatorPick, coordinatorNote, coordinatorState),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-coordinator-picks'] });
      setEditingTemplate(null);
      setShowAddModal(false);
    },
  });

  const filteredPicks = picks.filter((p: any) => {
    if (selectedState === 'All') return true;
    if (selectedState === 'All India (National)') return !p.coordinatorState;
    return p.coordinatorState === selectedState;
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-amber-500/10 text-amber-600">
              <Pin size={20} />
            </div>
            <h1 className="text-xl md:text-2xl font-900 text-slate-800">Coordinator Picks</h1>
          </div>
          <p className="text-muted text-sm mt-1">
            Pinned templates that feature at the top of the mobile app home screen for specific states or all users.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => refetch()}
            disabled={isLoading || isRefetching}
            className="btn-ghost flex items-center gap-2 text-sm disabled:opacity-50"
          >
            <RefreshCw size={14} className={isRefetching ? 'animate-spin' : ''} />
            Refresh
          </button>
          <button
            onClick={() => setShowAddModal(true)}
            className="btn-primary flex items-center gap-2 text-sm bg-gradient-brand shadow-primary/20"
          >
            <Plus size={16} /> Pin New Template
          </button>
        </div>
      </div>

      {/* State Filter Pills */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
        {['All', ...INDIAN_STATES].map((state) => (
          <button
            key={state}
            onClick={() => setSelectedState(state)}
            className={`px-3.5 py-1.5 rounded-xl text-xs font-700 whitespace-nowrap transition-all ${
              selectedState === state
                ? 'bg-primary text-white shadow-sm shadow-blue-500/25'
                : 'bg-white text-slate-600 hover:bg-blue-50/50 hover:text-primary border border-slate-200'
            }`}
          >
            {state}
          </button>
        ))}
      </div>

      {/* Grid of Coordinator Picks */}
      {isLoading ? (
        <div className="py-20 text-center text-muted">Loading coordinator picks...</div>
      ) : filteredPicks.length === 0 ? (
        <div className="bg-white rounded-2xl border border-surface-border p-12 text-center">
          <div className="w-12 h-12 rounded-2xl bg-amber-500/10 text-amber-500 flex items-center justify-center mx-auto mb-3">
            <Pin size={24} />
          </div>
          <h3 className="font-800 text-slate-800 text-base mb-1">No Coordinator Picks in this category</h3>
          <p className="text-muted text-sm max-w-md mx-auto mb-4">
            Pin high-quality templates to elevate them directly into the mobile home feed's top carousel.
          </p>
          <button
            onClick={() => setShowAddModal(true)}
            className="btn-primary text-xs inline-flex items-center gap-1.5"
          >
            <Plus size={14} /> Pin a Template Now
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {filteredPicks.map((template: any) => (
            <div
              key={template.id}
              className="bg-white rounded-2xl border border-surface-border shadow-card overflow-hidden flex flex-col group hover:shadow-lg transition-all"
            >
              {/* Image / Thumbnail Container */}
              <div
                className="aspect-[9/12] relative overflow-hidden bg-slate-100 flex items-center justify-center"
                style={{ background: template.gradient || 'linear-gradient(135deg, #2563EB, #0EA5E9)' }}
              >
                {template.imageUrl || template.imageThumbUrl ? (
                  <img
                    src={template.imageUrl || template.imageThumbUrl}
                    alt={template.nameEn || template.nameHi}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="p-4 text-center text-white font-800 text-base drop-shadow">
                    {template.nameHi || template.nameEn}
                  </div>
                )}

                {/* State Tag */}
                <div className="absolute top-3 left-3 bg-black/60 backdrop-blur-md text-white text-[11px] font-700 px-2.5 py-1 rounded-lg border border-white/20">
                  📍 {template.coordinatorState || 'All India'}
                </div>

                {/* Status Pin Badge */}
                <div className="absolute top-3 right-3 bg-amber-500 text-white p-1.5 rounded-lg shadow-md">
                  <Pin size={14} className="fill-white" />
                </div>

                {/* Hover overlay with note */}
                {template.coordinatorNote && (
                  <div className="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black/90 via-black/60 to-transparent text-white text-xs">
                    <span className="font-800 text-amber-300">Coordinator Note:</span>
                    <p className="line-clamp-2 mt-0.5 text-white/90">{template.coordinatorNote}</p>
                  </div>
                )}
              </div>

              {/* Card Body */}
              <div className="p-3.5 flex-1 flex flex-col justify-between">
                <div>
                  <h4 className="font-800 text-slate-800 text-sm truncate">
                    {template.nameHi || template.nameEn}
                  </h4>
                  <p className="text-xs text-muted truncate mt-0.5">
                    {template.nameEn} · {template.category?.nameEn || 'Template'}
                  </p>
                </div>

                {/* Actions */}
                <div className="mt-4 pt-3 border-t border-surface-border flex items-center justify-between gap-2">
                  <button
                    onClick={() => {
                      setEditingTemplate(template);
                      setEditNote(template.coordinatorNote || '');
                      setEditState(template.coordinatorState || '');
                    }}
                    className="btn-ghost text-xs py-1.5 px-2.5 flex items-center gap-1.5 flex-1 justify-center"
                  >
                    <Edit3 size={13} /> Edit Note
                  </button>
                  <button
                    onClick={() => {
                      if (confirm('Remove this template from Coordinator Picks?')) {
                        setPickMutation.mutate({ id: template.id, isCoordinatorPick: false });
                      }
                    }}
                    className="text-red-500 hover:bg-red-50 p-2 rounded-lg transition-colors"
                    title="Unpin"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal: Edit Coordinator Pick Note / State */}
      {editingTemplate && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-900 text-slate-800 text-lg">Edit Coordinator Pick</h3>
              <button
                onClick={() => setEditingTemplate(null)}
                className="text-muted hover:text-slate-800"
              >
                <X size={20} />
              </button>
            </div>

            <div>
              <label className="block text-xs font-700 text-slate-600 mb-1">Target Region / State</label>
              <select
                value={editState}
                onChange={(e) => setEditState(e.target.value)}
                className="w-full border border-surface-border rounded-xl px-3 py-2 text-sm bg-surface focus:outline-none focus:border-primary"
              >
                <option value="">All India (National - shown to everyone)</option>
                {INDIAN_STATES.filter((s) => s !== 'All India (National)').map((st) => (
                  <option key={st} value={st}>
                    {st}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-xs font-700 text-slate-600 mb-1">
                Coordinator Note / Badge Text (optional)
              </label>
              <textarea
                value={editNote}
                onChange={(e) => setEditNote(e.target.value)}
                placeholder="e.g. Recommended for Ganesh Chaturthi celebrations!"
                rows={3}
                className="w-full border border-surface-border rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-primary resize-none"
              />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button onClick={() => setEditingTemplate(null)} className="btn-ghost text-sm">
                Cancel
              </button>
              <button
                onClick={() => {
                  setPickMutation.mutate({
                    id: editingTemplate.id,
                    isCoordinatorPick: true,
                    coordinatorNote: editNote.trim() || undefined,
                    coordinatorState: editState || undefined,
                  });
                }}
                disabled={setPickMutation.isPending}
                className="btn-primary text-sm flex items-center gap-1.5"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Pin an Approved Template */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl space-y-4 max-h-[85vh] flex flex-col">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-900 text-slate-800 text-lg">Pin Template as Coordinator Pick</h3>
                <p className="text-muted text-xs">Search approved templates to feature in the app feed</p>
              </div>
              <button onClick={() => setShowAddModal(false)} className="text-muted hover:text-slate-800">
                <X size={20} />
              </button>
            </div>

            {/* Search Input */}
            <div className="relative">
              <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted" />
              <input
                value={searchApproved}
                onChange={(e) => setSearchApproved(e.target.value)}
                placeholder="Search approved templates by name or tag..."
                className="w-full pl-10 pr-4 py-2.5 text-sm border border-surface-border rounded-xl focus:outline-none focus:border-primary"
              />
            </div>

            {/* Template List */}
            <div className="flex-1 overflow-y-auto space-y-2 pr-1">
              {(approvedTemplatesData?.data ?? []).map((tpl: any) => (
                <div
                  key={tpl.id}
                  className="flex items-center justify-between p-3 rounded-xl border border-surface-border hover:border-primary/50 transition-all bg-surface/50"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div
                      className="w-12 h-16 rounded-lg overflow-hidden bg-slate-800 shrink-0"
                      style={{ background: tpl.gradient }}
                    >
                      {tpl.imageUrl && (
                        <img src={tpl.imageUrl} alt="" className="w-full h-full object-cover" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="font-800 text-sm text-slate-800 truncate">
                        {tpl.nameHi || tpl.nameEn}
                      </div>
                      <div className="text-xs text-muted truncate">
                        {tpl.nameEn} · {tpl.category?.nameEn || 'General'}
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={() => {
                      setEditingTemplate(tpl);
                      setEditNote('Pinned by Coordinator');
                      setEditState('');
                    }}
                    className="btn-primary text-xs py-1.5 px-3 shrink-0 flex items-center gap-1 bg-amber-500 hover:bg-amber-600 border-none"
                  >
                    <Pin size={12} /> Pin This
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
