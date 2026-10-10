'use client';

import { useEffect, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Settings, Save, AlertTriangle, CheckCircle } from 'lucide-react';
import { adminApi } from '@/lib/api';
import { toast } from '@/lib/toast';
import { getErrorMessage } from '@/lib/utils';
import { QueryError } from '@/components/QueryError';

export default function ConfigPage() {
  const queryClient = useQueryClient();
  const [form, setForm] = useState<Record<string, string>>({});
  const [hasChanges, setHasChanges] = useState(false);
  const [savedKey, setSavedKey] = useState<string | null>(null);

  const { data: configData, isLoading, isError, error, refetch } = useQuery({
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
    onError: (err, { key }) => toast.error(`Failed to save ${key}: ${getErrorMessage(err)}`),
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
    let saved = 0;
    for (const [key, value] of Object.entries(form)) {
      const original = configs.find((c: any) => c.key === key);
      if (!original || original.value !== value) {
        try {
          await updateMutation.mutateAsync({ key, value });
          saved++;
        } catch {
          // onError already surfaced the message; keep unsaved changes so the user can retry
          return;
        }
      }
    }
    setHasChanges(false);
    if (saved > 0) toast.success(`Saved ${saved} setting${saved === 1 ? '' : 's'}`);
  };

  const BOOLEAN_KEYS = ['MAINTENANCE_MODE', 'ALLOW_NEW_REGISTRATIONS', 'REQUIRE_EMAIL_VERIFICATION'];

  // Group configs from DB
  const allConfigs: any[] = configData?.data ?? [];

  return (
    <div className="space-y-5">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900">System Configuration</h1>
          <p className="text-slate-500 text-xs mt-1">Manage global application runtime flags, feature switches, and endpoints</p>
        </div>
        <button
          onClick={handleSaveAll}
          disabled={!hasChanges || updateMutation.isPending}
          className="btn-primary text-xs flex items-center gap-1.5 disabled:opacity-50 self-start sm:self-auto"
        >
          <Save size={14} /> Save All Changes
        </button>
      </div>

      <div className="bg-amber-50/70 border border-amber-200/80 rounded-xl p-3.5 flex gap-3 text-amber-900">
        <AlertTriangle size={16} className="shrink-0 text-amber-600 mt-0.5" />
        <div className="text-xs">
          <span className="font-semibold text-amber-900">Caution: </span>
          <span className="text-amber-800">
            Changes propagate to production mobile clients immediately upon save. Ensure version strings and flag states are accurate before committing.
          </span>
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[1, 2, 3, 4].map(i => <div key={i} className="h-32 bg-slate-100 rounded-xl animate-pulse border border-slate-200" />)}
        </div>
      ) : isError ? (
        <QueryError error={error} onRetry={() => refetch()} />
      ) : allConfigs.length === 0 ? (
        <div className="bg-white rounded-xl p-12 text-center border border-slate-200/80 shadow-sm">
          <Settings size={28} className="text-slate-300 mx-auto mb-2.5" />
          <div className="font-bold text-slate-800 text-sm">No configuration keys found</div>
          <p className="text-slate-500 text-xs mt-1">Seed the <code className="text-primary font-mono">AppConfig</code> table in your database to manage settings here.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {allConfigs.map((config: any) => (
            <div key={config.key} className="bg-white rounded-xl p-4 md:p-5 border border-slate-200/80 shadow-sm space-y-2.5">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-slate-800 flex items-center gap-2 uppercase tracking-wide">
                  <Settings size={13} className="text-slate-400" />
                  {config.key.replace(/_/g, ' ')}
                </label>
                {savedKey === config.key && (
                  <span className="flex items-center gap-1 text-emerald-600 text-[11px] font-semibold bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
                    <CheckCircle size={11} /> Saved
                  </span>
                )}
              </div>
              {config.description && (
                <p className="text-[11px] text-slate-500">{config.description}</p>
              )}
              {BOOLEAN_KEYS.includes(config.key) ? (
                <select
                  value={form[config.key] ?? config.value}
                  onChange={e => handleChange(config.key, e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-xs font-medium bg-slate-50/50 text-slate-800"
                >
                  <option value="true">✅ Enabled (True)</option>
                  <option value="false">❌ Disabled (False)</option>
                </select>
              ) : (
                <input
                  value={form[config.key] ?? config.value}
                  onChange={e => handleChange(config.key, e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-xs font-medium bg-slate-50/50 text-slate-800 font-mono"
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
