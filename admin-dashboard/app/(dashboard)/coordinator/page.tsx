'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Pin, Search, Trash2, Edit3, Plus, RefreshCw, X } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { toast } from '@/lib/toast';
import { useDebounce } from '@/lib/hooks';
import { QueryError } from '@/components/QueryError';

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
  const debouncedSearch = useDebounce(searchApproved.trim(), 300);

  const { data: picksResponse, isLoading, isError, error, refetch, isRefetching } = useQuery({
    queryKey: ['admin-coordinator-picks'],
    queryFn: () => adminApi.getCoordinatorPicks(),
    staleTime: 30 * 1000,
  });

  // getCoordinatorPicks() normalizes the response to { data, total }
  const picks: any[] = picksResponse?.data ?? [];

  // 2. Fetch approved templates for pinning
  const {
    data: approvedTemplatesData,
    isLoading: approvedLoading,
    isError: approvedIsError,
    error: approvedError,
    refetch: refetchApproved,
  } = useQuery({
    queryKey: ['approved-templates-for-pin', debouncedSearch],
    queryFn: () => adminApi.getTemplates({ status: 'APPROVED', search: debouncedSearch || undefined, limit: 15 }),
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
    onError: (err) => toast.apiError(err, 'Failed to update coordinator pick'),
    onSuccess: (_d, vars) => {
      toast.success(vars.isCoordinatorPick ? 'Coordinator pick saved' : 'Removed from coordinator picks');
      queryClient.invalidateQueries({ queryKey: ['admin-coordinator-picks'] });
      queryClient.invalidateQueries({ queryKey: ['review-queue'] });
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
          <div className="flex items-center gap-2.5">
            <div className="p-1.5 rounded-lg bg-amber-50 text-amber-600 border border-amber-200/60">
              <Pin size={18} />
            </div>
            <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900">Coordinator Picks</h1>
          </div>
          <p className="text-slate-500 text-xs mt-1">
            Pinned templates that feature at the top of the mobile app home screen for specific states or all users.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <button
            onClick={() => refetch()}
            disabled={isLoading || isRefetching}
            className="btn-secondary text-xs flex items-center gap-1.5 disabled:opacity-50"
          >
            <RefreshCw size={13} className={isRefetching ? 'animate-spin' : ''} />
            Refresh
          </button>
          <button
            onClick={() => setShowAddModal(true)}
            className="btn-primary text-xs flex items-center gap-1.5"
          >
            <Plus size={15} /> Pin New Template
          </button>
        </div>
      </div>

      {/* State Filter Pills */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
        {['All', ...INDIAN_STATES].map((state) => (
          <button
            key={state}
            onClick={() => setSelectedState(state)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold whitespace-nowrap transition-colors ${
              selectedState === state
                ? 'bg-primary text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-900 border border-slate-200'
            }`}
          >
            {state}
          </button>
        ))}
      </div>

      {/* Grid of Coordinator Picks */}
      {isLoading ? (
        <div className="py-20 text-center text-slate-400 text-xs">Loading coordinator picks...</div>
      ) : isError ? (
        <QueryError error={error} onRetry={() => refetch()} />
      ) : filteredPicks.length === 0 ? (
        <div className="bg-white rounded-xl border border-slate-200/80 p-12 text-center shadow-sm">
          <div className="w-10 h-10 rounded-lg bg-amber-50 text-amber-600 border border-amber-200/60 flex items-center justify-center mx-auto mb-3">
            <Pin size={20} />
          </div>
          <h3 className="font-bold text-slate-800 text-sm mb-1">No Coordinator Picks in this category</h3>
          <p className="text-slate-500 text-xs max-w-md mx-auto mb-4">
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
              className="bg-white rounded-xl border border-slate-200/80 shadow-sm overflow-hidden flex flex-col hover:border-slate-300 transition-all group"
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
                    className="w-full h-full object-cover group-hover:scale-[1.02] transition-transform duration-300"
                  />
                ) : (
                  <div className="p-4 text-center text-white font-bold text-sm drop-shadow">
                    {template.nameHi || template.nameEn}
                  </div>
                )}

                {/* State Tag */}
                <div className="absolute top-2.5 left-2.5 bg-black/60 backdrop-blur-md text-white text-[10px] font-semibold px-2 py-0.5 rounded-md border border-white/20">
                  📍 {template.coordinatorState || 'All India'}
                </div>

                {/* Status Pin Badge */}
                <div className="absolute top-2.5 right-2.5 bg-amber-500 text-white p-1 rounded-md shadow-xs">
                  <Pin size={12} className="fill-white" />
                </div>

                {/* Hover overlay with note */}
                {template.coordinatorNote && (
                  <div className="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black/90 via-black/60 to-transparent text-white text-xs">
                    <span className="font-semibold text-amber-300 text-[11px]">Coordinator Note:</span>
                    <p className="line-clamp-2 mt-0.5 text-white/90 text-[11px] leading-snug">{template.coordinatorNote}</p>
                  </div>
                )}
              </div>

              {/* Card Body */}
              <div className="p-3.5 flex-1 flex flex-col justify-between">
                <div>
                  <h4 className="font-bold text-slate-900 text-xs truncate">
                    {template.nameHi || template.nameEn}
                  </h4>
                  <p className="text-[11px] text-slate-500 truncate mt-0.5">
                    {template.nameEn} · {template.category?.nameEn || 'Template'}
                  </p>
                </div>

                {/* Actions */}
                <div className="mt-3 pt-2.5 border-t border-slate-100 flex items-center justify-between gap-2">
                  <button
                    onClick={() => {
                      setEditingTemplate(template);
                      setEditNote(template.coordinatorNote || '');
                      setEditState(template.coordinatorState || '');
                    }}
                    className="btn-secondary text-xs py-1 px-2.5 flex items-center gap-1.5 flex-1 justify-center"
                  >
                    <Edit3 size={12} /> Edit Note
                  </button>
                  <button
                    onClick={() => {
                      if (confirm('Remove this template from Coordinator Picks?')) {
                        setPickMutation.mutate({ id: template.id, isCoordinatorPick: false });
                      }
                    }}
                    className="text-rose-500 hover:bg-rose-50 p-1.5 rounded-md transition-colors"
                    title="Unpin"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal: Edit Coordinator Pick Note / State */}
      {editingTemplate && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-5 shadow-xl space-y-4 border border-slate-200">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100">
              <h3 className="font-bold text-slate-900 text-sm">Edit Coordinator Pick</h3>
              <button
                onClick={() => setEditingTemplate(null)}
                className="text-slate-400 hover:text-slate-600 p-1 rounded-md"
              >
                <X size={18} />
              </button>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">Target Region / State</label>
              <select
                value={editState}
                onChange={(e) => setEditState(e.target.value)}
                className="w-full border border-slate-300 rounded-lg px-3 py-2 text-xs bg-white text-slate-700 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
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
              <label className="block text-xs font-semibold text-slate-700 uppercase tracking-wider mb-1.5">
                Coordinator Note / Badge Text (optional)
              </label>
              <textarea
                value={editNote}
                onChange={(e) => setEditNote(e.target.value)}
                placeholder="e.g. Recommended for Ganesh Chaturthi celebrations!"
                rows={3}
                className="w-full border border-slate-300 rounded-lg px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary resize-none"
              />
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
              <button onClick={() => setEditingTemplate(null)} className="btn-secondary text-xs px-3.5 py-1.5">
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
                className="btn-primary text-xs px-3.5 py-1.5 flex items-center gap-1.5"
              >
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Pin an Approved Template */}
      {showAddModal && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl max-w-2xl w-full p-5 shadow-xl space-y-4 max-h-[85vh] flex flex-col border border-slate-200">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100">
              <div>
                <h3 className="font-bold text-slate-900 text-sm">Pin Template as Coordinator Pick</h3>
                <p className="text-slate-500 text-xs">Search approved templates to feature in the app feed</p>
              </div>
              <button onClick={() => setShowAddModal(false)} className="text-slate-400 hover:text-slate-600 p-1 rounded-md">
                <X size={18} />
              </button>
            </div>

            {/* Search Input */}
            <div className="relative">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                value={searchApproved}
                onChange={(e) => setSearchApproved(e.target.value)}
                placeholder="Search approved templates by name or tag..."
                className="w-full pl-9 pr-3.5 py-2 text-xs border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-slate-800"
              />
            </div>

            {/* Template List */}
            <div className="flex-1 overflow-y-auto space-y-2 pr-1">
              {approvedLoading && (
                <div className="py-8 text-center text-slate-400 text-xs">Loading approved templates...</div>
              )}
              {approvedIsError && (
                <QueryError error={approvedError} onRetry={() => refetchApproved()} title="Failed to load templates" />
              )}
              {!approvedLoading && !approvedIsError && (approvedTemplatesData?.data ?? []).length === 0 && (
                <div className="py-8 text-center text-slate-400 text-xs">
                  {debouncedSearch ? `No approved templates match "${debouncedSearch}"` : 'No approved templates found'}
                </div>
              )}
              {(approvedTemplatesData?.data ?? []).map((tpl: any) => (
                <div
                  key={tpl.id}
                  className="flex items-center justify-between p-2.5 rounded-lg border border-slate-200/80 hover:border-slate-300 transition-colors bg-slate-50/50 hover:bg-slate-50"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div
                      className="w-10 h-14 rounded-md overflow-hidden bg-slate-800 shrink-0"
                      style={{ background: tpl.gradient }}
                    >
                      {(tpl.imageUrl || tpl.imageThumbUrl) && (
                        <img src={tpl.imageUrl || tpl.imageThumbUrl} alt="" className="w-full h-full object-cover" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="font-semibold text-xs text-slate-900 truncate">
                        {tpl.nameHi || tpl.nameEn}
                      </div>
                      <div className="text-[11px] text-slate-500 truncate">
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
                    className="btn-primary text-xs py-1 px-2.5 shrink-0 flex items-center gap-1 bg-amber-500 hover:bg-amber-600 border-none"
                  >
                    <Pin size={11} /> Pin This
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
