'use client';

import { useEffect, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Settings, Save, AlertTriangle, CheckCircle } from 'lucide-react';
import { adminApi } from '@/lib/api';

export default function ConfigPage() {
  const queryClient = useQueryClient();
  const [form, setForm] = useState<Record<string, string>>({});
  const [hasChanges, setHasChanges] = useState(false);
  const [savedKey, setSavedKey] = useState<string | null>(null);

  const { data: configData, isLoading } = useQuery({
    queryKey: ['admin-configs'],
    queryFn: adminApi.getConfigs,
    staleTime: 60 * 1000,
  });

  // Populate form from DB on first load
  useEffect(() => {
    if (configData?.data && Object.keys(form).length === 0) {
      const initial: Record<string, string> = {};
      configData.data.forEach((c: any) => { initial[c.key] = c.value; });
      setForm(initial);
    }
  }, [configData]);

  // Save one key at a time to the real endpoint (PUT /admin/config)
  const updateMutation = useMutation({
    mutationFn: ({ key, value }: { key: string; value: string }) =>
      adminApi.updateConfig(key, value),
    onSuccess: (_, { key }) => {
      queryClient.invalidateQueries({ queryKey: ['admin-configs'] });
      setSavedKey(key);
      setTimeout(() => setSavedKey(null), 2000);
    },
  });

  const handleChange = (key: string, val: string) => {
    setForm(f => ({ ...f, [key]: val }));
    setHasChanges(true);
  };

  const handleSaveAll = async () => {
    // Save each changed key sequentially
    const configs: any[] = configData?.data ?? [];
    for (const [key, value] of Object.entries(form)) {
      const original = configs.find((c: any) => c.key === key);
      if (!original || original.value !== value) {
        await updateMutation.mutateAsync({ key, value });
      }
    }
    setHasChanges(false);
  };

  const BOOLEAN_KEYS = ['MAINTENANCE_MODE', 'ALLOW_NEW_REGISTRATIONS', 'REQUIRE_EMAIL_VERIFICATION'];

  // Group configs from DB
  const allConfigs: any[] = configData?.data ?? [];

  return (
    <div className="space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-900 text-slate-800">System Configuration</h1>
          <p className="text-muted text-sm mt-1">Manage global application flags and parameters</p>
        </div>
        <button
          onClick={handleSaveAll}
          disabled={!hasChanges || updateMutation.isPending}
          className="btn-primary flex items-center gap-2 disabled:opacity-50 self-start sm:self-auto"
        >
          <Save size={16} /> Save All Changes
        </button>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 flex gap-3 text-amber-800">
        <AlertTriangle size={18} className="shrink-0 text-amber-600 mt-0.5" />
        <div>
          <h4 className="font-800 text-sm">Caution</h4>
          <p className="text-xs mt-0.5">Changes affect the production mobile app immediately. Ensure version numbers and flags are correct before saving.</p>
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[1, 2, 3, 4].map(i => <div key={i} className="h-40 bg-slate-100 rounded-2xl animate-pulse" />)}
        </div>
      ) : allConfigs.length === 0 ? (
        <div className="bg-white rounded-2xl p-12 text-center border border-surface-border">
          <Settings size={32} className="text-muted mx-auto mb-3 opacity-40" />
          <div className="font-800 text-slate-700">No config keys found</div>
          <p className="text-muted text-sm mt-1">Seed the <code className="text-primary">AppConfig</code> table in your database to manage settings here.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {allConfigs.map((config: any) => (
            <div key={config.key} className="bg-white rounded-2xl p-5 shadow-card border border-surface-border">
              <div className="flex items-center justify-between mb-3">
                <label className="text-sm font-800 text-slate-700 flex items-center gap-2">
                  <Settings size={14} className="text-muted" />
                  {config.key.replace(/_/g, ' ')}
                </label>
                {savedKey === config.key && (
                  <span className="flex items-center gap-1 text-success text-xs font-700">
                    <CheckCircle size={12} /> Saved
                  </span>
                )}
              </div>
              {config.description && (
                <p className="text-xs text-muted mb-3">{config.description}</p>
              )}
              {BOOLEAN_KEYS.includes(config.key) ? (
                <select
                  value={form[config.key] ?? config.value}
                  onChange={e => handleChange(config.key, e.target.value)}
                  className="w-full px-4 py-2.5 border border-surface-border rounded-xl focus:outline-none focus:border-primary text-sm font-600 bg-surface"
                >
                  <option value="true">✅ Enabled (True)</option>
                  <option value="false">❌ Disabled (False)</option>
                </select>
              ) : (
                <input
                  value={form[config.key] ?? config.value}
                  onChange={e => handleChange(config.key, e.target.value)}
                  className="w-full px-4 py-2.5 border border-surface-border rounded-xl focus:outline-none focus:border-primary text-sm font-600 bg-surface"
                  placeholder={`Enter ${config.key}`}
                />
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
