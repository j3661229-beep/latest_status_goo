'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  Plus, Edit2, Trash2, Layers, Search, Sparkles, CheckCircle2,
  XCircle, ArrowUpDown, X, Palette, AlertCircle
} from 'lucide-react';
import { adminApi } from '@/lib/api';
import { toast } from '@/lib/toast';
import { QueryError } from '@/components/QueryError';

const GRADIENT_PRESETS = [
  { label: 'Electric Indigo', value: 'from-indigo-500 to-purple-600' },
  { label: 'Sunset Coral', value: 'from-rose-500 to-orange-500' },
  { label: 'Festival Gold', value: 'from-amber-400 to-amber-600' },
  { label: 'Emerald Sage', value: 'from-emerald-500 to-teal-600' },
  { label: 'Ocean Cyan', value: 'from-cyan-500 to-blue-600' },
  { label: 'Neon Fuchsia', value: 'from-violet-600 to-fuchsia-600' },
  { label: 'Midnight Slate', value: 'from-slate-700 to-slate-900' },
];

const EMOJI_SUGGESTIONS = ['🌅', '🌙', '🌸', '🕉️', '🎂', '💼', '⚡', '💖', '🙏', '🚀', '🎉', '🔥', '🏆', '🌟', '🚩'];

export default function CategoriesPage() {
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  const initialForm = {
    nameEn: '',
    nameHi: '',
    nameMr: '',
    nameGu: '',
    namePa: '',
    slug: '',
    emoji: '✨',
    gradient: 'from-indigo-500 to-purple-600',
    description: '',
    sortOrder: 0,
    isActive: true,
  };

  const [form, setForm] = useState(initialForm);

  const { data: categoryRes, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['admin-categories'],
    queryFn: adminApi.getCategories,
  });

  const categories = categoryRes?.data || [];

  const createMutation = useMutation({
    mutationFn: adminApi.createCategory,
    onError: (err) => toast.apiError(err, 'Failed to create category'),
    onSuccess: () => {
      toast.success('Category created successfully');
      queryClient.invalidateQueries({ queryKey: ['admin-categories'] });
      closeModal();
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: any }) => adminApi.updateCategory(id, data),
    onError: (err) => toast.apiError(err, 'Failed to update category'),
    onSuccess: () => {
      toast.success('Category updated successfully');
      queryClient.invalidateQueries({ queryKey: ['admin-categories'] });
      closeModal();
    },
  });

  const deleteMutation = useMutation({
    mutationFn: adminApi.deleteCategory,
    onError: (err) => toast.apiError(err, 'Failed to delete category'),
    onSuccess: () => {
      toast.success('Category deleted successfully');
      queryClient.invalidateQueries({ queryKey: ['admin-categories'] });
      setDeleteConfirmId(null);
    },
  });

  const openCreateModal = () => {
    setEditId(null);
    setForm({
      ...initialForm,
      sortOrder: categories.length ? Math.max(...categories.map((c: any) => c.sortOrder ?? 0)) + 10 : 0,
    });
    setIsModalOpen(true);
  };

  const openEditModal = (cat: any) => {
    setEditId(cat.id);
    setForm({
      nameEn: cat.nameEn || '',
      nameHi: cat.nameHi || '',
      nameMr: cat.nameMr || '',
      nameGu: cat.nameGu || '',
      namePa: cat.namePa || '',
      slug: cat.slug || '',
      emoji: cat.emoji || '✨',
      gradient: cat.gradient || 'from-indigo-500 to-purple-600',
      description: cat.description || '',
      sortOrder: cat.sortOrder ?? 0,
      isActive: cat.isActive ?? true,
    });
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditId(null);
    setForm(initialForm);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const payload: any = {
      nameEn: form.nameEn.trim(),
      nameHi: form.nameHi.trim(),
      nameMr: form.nameMr.trim(),
      nameGu: form.nameGu.trim() || undefined,
      namePa: form.namePa.trim() || undefined,
      emoji: form.emoji.trim() || '✨',
      gradient: form.gradient,
      description: form.description.trim() || undefined,
      sortOrder: Number(form.sortOrder) || 0,
      isActive: Boolean(form.isActive),
    };

    if (form.slug.trim()) {
      payload.slug = form.slug.trim().toLowerCase();
    }

    if (editId) {
      updateMutation.mutate({ id: editId, data: payload });
    } else {
      createMutation.mutate(payload);
    }
  };

  const handleToggleActive = (cat: any) => {
    updateMutation.mutate({
      id: cat.id,
      data: { isActive: !cat.isActive },
    });
  };

  const filtered = categories.filter((c: any) => {
    const q = search.toLowerCase();
    return (
      c.nameEn?.toLowerCase().includes(q) ||
      c.nameHi?.toLowerCase().includes(q) ||
      c.nameMr?.toLowerCase().includes(q) ||
      c.slug?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-indigo-600/10 text-indigo-600 flex items-center justify-center">
              <Layers size={18} />
            </div>
            <h1 className="text-xl md:text-2xl font-bold text-slate-900 tracking-tight">Categories</h1>
          </div>
          <p className="text-slate-500 text-sm mt-1">
            Organize status templates with multilingual tags, gradients, and custom sorting
          </p>
        </div>

        <button
          onClick={openCreateModal}
          className="btn-primary flex items-center justify-center gap-2 py-2 px-4 text-xs font-semibold rounded-lg shadow-sm w-full sm:w-auto"
        >
          <Plus size={16} /> Add New Category
        </button>
      </div>

      {/* Filter / Search Bar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 bg-white p-3 rounded-xl border border-slate-200/80 shadow-xs">
        <div className="relative flex-1">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Search by name, Hindi, Marathi, or slug..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-1.5 text-sm rounded-lg border border-slate-200 focus:outline-none focus:border-indigo-600 focus:ring-1 focus:ring-indigo-600"
          />
        </div>
        <div className="text-xs font-medium text-slate-500 px-2 flex items-center justify-between sm:justify-end gap-2">
          <span>Total: <strong className="text-slate-900">{categories.length}</strong></span>
          <span>·</span>
          <span>Active: <strong className="text-emerald-600">{categories.filter((c: any) => c.isActive).length}</strong></span>
        </div>
      </div>

      {/* Error state */}
      {isError && (
        <QueryError
          title="Could not load categories"
          error={error}
          onRetry={refetch}
        />
      )}

      {/* Loading state */}
      {isLoading && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <div key={i} className="h-44 bg-white rounded-xl border border-slate-200/80 animate-pulse p-4" />
          ))}
        </div>
      )}

      {/* Categories Grid */}
      {!isLoading && !isError && (
        <>
          {filtered.length === 0 ? (
            <div className="bg-white rounded-xl border border-slate-200/80 p-12 text-center">
              <div className="w-12 h-12 rounded-full bg-indigo-50 text-indigo-600 flex items-center justify-center mx-auto mb-3">
                <Layers size={24} />
              </div>
              <h3 className="text-base font-semibold text-slate-900">No categories found</h3>
              <p className="text-slate-500 text-sm max-w-sm mx-auto mt-1 mb-5">
                {search ? 'No categories matched your search term.' : 'Get started by creating your first template category.'}
              </p>
              {!search && (
                <button onClick={openCreateModal} className="btn-primary text-xs py-2 px-4">
                  <Plus size={14} className="inline mr-1" /> Create Category
                </button>
              )}
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {filtered.map((cat: any) => {
                const templateCount = cat._count?.templates ?? cat.templateCount ?? 0;
                return (
                  <div
                    key={cat.id}
                    className="bg-white rounded-xl border border-slate-200/80 shadow-xs hover:shadow-md transition-shadow flex flex-col overflow-hidden group"
                  >
                    {/* Gradient Header Banner */}
                    <div className={`h-14 bg-gradient-to-r ${cat.gradient || 'from-indigo-500 to-purple-600'} p-3 flex items-center justify-between text-white relative`}>
                      <span className="text-2xl drop-shadow-sm select-none">{cat.emoji || '✨'}</span>
                      <div className="flex items-center gap-1.5 bg-black/25 backdrop-blur-xs px-2 py-0.5 rounded-full text-[11px] font-semibold">
                        <span>#{cat.sortOrder ?? 0}</span>
                      </div>
                    </div>

                    {/* Card Content */}
                    <div className="p-4 flex-1 flex flex-col justify-between space-y-3">
                      <div>
                        <div className="flex items-start justify-between gap-2">
                          <h3 className="font-bold text-slate-900 text-base leading-snug">
                            {cat.nameEn}
                          </h3>
                          <button
                            onClick={() => handleToggleActive(cat)}
                            title={cat.isActive ? 'Active (Click to deactivate)' : 'Inactive (Click to activate)'}
                            className={`text-[11px] font-semibold px-2 py-0.5 rounded-full border transition-colors shrink-0 ${
                              cat.isActive
                                ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'
                                : 'bg-slate-100 text-slate-500 border-slate-200 hover:bg-slate-200'
                            }`}
                          >
                            {cat.isActive ? 'Active' : 'Inactive'}
                          </button>
                        </div>

                        {/* Localized names */}
                        <div className="mt-1 flex flex-wrap gap-x-2 text-xs text-slate-600">
                          {cat.nameHi && <span className="font-devanagari font-medium">{cat.nameHi}</span>}
                          {cat.nameMr && <span className="font-devanagari text-slate-400">· {cat.nameMr}</span>}
                        </div>

                        {/* Slug */}
                        <div className="mt-2 text-[11px] text-slate-400 font-mono truncate">
                          /{cat.slug}
                        </div>

                        {cat.description && (
                          <p className="mt-1.5 text-xs text-slate-500 line-clamp-2">
                            {cat.description}
                          </p>
                        )}
                      </div>

                      {/* Footer: Templates count & Actions */}
                      <div className="pt-3 border-t border-slate-100 flex items-center justify-between gap-2">
                        <span className="text-xs font-medium text-slate-500">
                          <strong className="text-slate-800">{templateCount}</strong> templates
                        </span>

                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => openEditModal(cat)}
                            className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
                            title="Edit Category"
                          >
                            <Edit2 size={15} />
                          </button>

                          {deleteConfirmId === cat.id ? (
                            <div className="flex items-center gap-1">
                              <button
                                onClick={() => deleteMutation.mutate(cat.id)}
                                disabled={deleteMutation.isPending}
                                className="text-[11px] bg-rose-600 text-white font-semibold px-2 py-1 rounded hover:bg-rose-700 transition-colors"
                              >
                                Confirm
                              </button>
                              <button
                                onClick={() => setDeleteConfirmId(null)}
                                className="text-[11px] text-slate-500 hover:text-slate-800 px-1"
                              >
                                Cancel
                              </button>
                            </div>
                          ) : (
                            <button
                              onClick={() => setDeleteConfirmId(cat.id)}
                              className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                              title="Delete Category"
                            >
                              <Trash2 size={15} />
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}

      {/* Create / Edit Modal Dialog */}
      {isModalOpen && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs animate-in fade-in duration-150 overflow-y-auto">
          <div className="bg-white rounded-2xl border border-slate-200 shadow-xl w-full max-w-lg my-8 overflow-hidden animate-in zoom-in-95 duration-150">
            {/* Modal Header */}
            <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-indigo-50 text-indigo-600 flex items-center justify-center">
                  <Layers size={16} />
                </div>
                <h2 className="text-base font-bold text-slate-900">
                  {editId ? 'Edit Category' : 'Create New Category'}
                </h2>
              </div>
              <button
                onClick={closeModal}
                className="text-slate-400 hover:text-slate-600 p-1 rounded-lg"
              >
                <X size={18} />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleSubmit} className="p-6 space-y-4 max-h-[75vh] overflow-y-auto">
              {/* Names row */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    English *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="Good Morning"
                    value={form.nameEn}
                    onChange={(e) => setForm({ ...form, nameEn: e.target.value })}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 focus:outline-none focus:border-indigo-600 focus:ring-1 focus:ring-indigo-600"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Hindi *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="सुप्रभात"
                    value={form.nameHi}
                    onChange={(e) => setForm({ ...form, nameHi: e.target.value })}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 font-devanagari focus:outline-none focus:border-indigo-600 focus:ring-1 focus:ring-indigo-600"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Marathi *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="शुभ सकाळ"
                    value={form.nameMr}
                    onChange={(e) => setForm({ ...form, nameMr: e.target.value })}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 font-devanagari focus:outline-none focus:border-indigo-600 focus:ring-1 focus:ring-indigo-600"
                  />
                </div>
              </div>

              {/* Optional Gujarati & Punjabi */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-600 block mb-1">
                    Gujarati (Optional)
                  </label>
                  <input
                    type="text"
                    placeholder="શુભ સવાર"
                    value={form.nameGu}
                    onChange={(e) => setForm({ ...form, nameGu: e.target.value })}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 focus:outline-none focus:border-indigo-600"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-600 block mb-1">
                    Punjabi (Optional)
                  </label>
                  <input
                    type="text"
                    placeholder="ਸਤਿ ਸ਼੍ਰੀ ਅਕਾਲ"
                    value={form.namePa}
                    onChange={(e) => setForm({ ...form, namePa: e.target.value })}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 focus:outline-none focus:border-indigo-600"
                  />
                </div>
              </div>

              {/* Slug & Sort Order */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Custom Slug (Optional)
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. good-morning"
                    value={form.slug}
                    onChange={(e) => setForm({ ...form, slug: e.target.value })}
                    className="w-full px-3 py-2 text-sm font-mono rounded-lg border border-slate-300 focus:outline-none focus:border-indigo-600"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-700 block mb-1">
                    Sort Order (Lower = first)
                  </label>
                  <input
                    type="number"
                    value={form.sortOrder}
                    onChange={(e) => setForm({ ...form, sortOrder: parseInt(e.target.value) || 0 })}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 focus:outline-none focus:border-indigo-600"
                  />
                </div>
              </div>

              {/* Emoji Picker */}
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Emoji Icon *
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    required
                    value={form.emoji}
                    onChange={(e) => setForm({ ...form, emoji: e.target.value })}
                    className="w-16 text-center text-xl py-2 px-2 border border-slate-300 rounded-lg focus:outline-none focus:border-indigo-600"
                  />
                  <div className="flex flex-wrap gap-1 items-center flex-1">
                    {EMOJI_SUGGESTIONS.map((em) => (
                      <button
                        key={em}
                        type="button"
                        onClick={() => setForm({ ...form, emoji: em })}
                        className={`w-7 h-7 rounded text-base hover:bg-slate-100 transition-colors ${
                          form.emoji === em ? 'bg-indigo-100 ring-1 ring-indigo-500' : ''
                        }`}
                      >
                        {em}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {/* Gradient Preset */}
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Theme Gradient
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {GRADIENT_PRESETS.map((gp) => (
                    <button
                      key={gp.value}
                      type="button"
                      onClick={() => setForm({ ...form, gradient: gp.value })}
                      className={`h-9 rounded-lg bg-gradient-to-r ${gp.value} text-white text-[11px] font-semibold flex items-center justify-center transition-all ${
                        form.gradient === gp.value ? 'ring-2 ring-indigo-600 ring-offset-2 scale-[1.02]' : 'opacity-85 hover:opacity-100'
                      }`}
                    >
                      {gp.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Description */}
              <div>
                <label className="text-xs font-semibold text-slate-700 block mb-1">
                  Description (Optional)
                </label>
                <textarea
                  rows={2}
                  placeholder="Short explanation for users or creators..."
                  value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 focus:outline-none focus:border-indigo-600"
                />
              </div>

              {/* Status Toggle */}
              <div className="flex items-center justify-between pt-2">
                <div>
                  <span className="text-sm font-semibold text-slate-900 block">Category Status</span>
                  <span className="text-xs text-slate-500">Enable or hide from the mobile app and creator studio</span>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.isActive}
                    onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
                </label>
              </div>

              {/* Submit Buttons */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={closeModal}
                  className="btn-ghost text-xs py-2 px-4"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createMutation.isPending || updateMutation.isPending}
                  className="btn-primary text-xs py-2 px-5 flex items-center gap-1.5"
                >
                  {(createMutation.isPending || updateMutation.isPending) && (
                    <div className="w-3.5 h-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  )}
                  {editId ? 'Save Changes' : 'Create Category'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
