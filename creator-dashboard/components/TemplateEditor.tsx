'use client';

/**
 * TemplateEditor.tsx
 *
 * Visual drag-and-drop template editor for creators.
 * Renders the uploaded image/video at 9:16 ratio with interactive
 * draggable + resizable zone handles for photo and name zones.
 *
 * All zone positions are stored as normalized values (0.0 to 1.0)
 * which map directly to the Prisma Template schema fields:
 *   photoZoneX, photoZoneY, photoZoneSize, photoZoneShape
 *   nameZoneX, nameZoneY, nameFont, nameColor, nameFontSize
 */

import React, { useRef, useState, useCallback, useEffect } from 'react';
import {
  Move, ZoomIn, Type, Image as ImageIcon,
  AlignCenter, AlignLeft, AlignRight,
  ToggleLeft, ToggleRight, ChevronDown,
} from 'lucide-react';

// ── Types ──────────────────────────────────────────────────────
export interface PhotoZoneConfig {
  enabled: boolean;
  x: number;        // center X (0–1)
  y: number;        // center Y (0–1)
  size: number;     // diameter as fraction of canvas width (0–1)
  shape: 'circle' | 'square' | 'rounded';
}

export interface NameZoneConfig {
  enabled: boolean;
  x: number;        // center X (0–1)
  y: number;        // baseline Y (0–1)
  fontSize: number; // as fraction of canvas height (0–1)
  color: string;
  font: string;
  alignment: 'left' | 'center' | 'right';
  weight: 'normal' | 'bold' | '900';
}

export interface ZoneConfig {
  photo: PhotoZoneConfig;
  name: NameZoneConfig;
}

interface TemplateEditorProps {
  file: File | null;
  gradient: string;
  templateType: 'IMAGE' | 'VIDEO';
  zones: ZoneConfig;
  onZonesChange: (zones: ZoneConfig) => void;
}

// ── Constants ──────────────────────────────────────────────────
const FONTS = [
  { value: 'system-ui', label: 'System Default' },
  { value: 'Georgia, serif', label: 'Georgia (Serif)' },
  { value: '"Noto Sans", sans-serif', label: 'Noto Sans' },
  { value: '"Poppins", sans-serif', label: 'Poppins' },
  { value: '"Baloo 2", cursive', label: 'Baloo 2 (Hindi)' },
];

const COLORS = [
  '#ffffff', '#f8f8f8', '#FFD700', '#FF6B9D',
  '#2563EB', '#0EA5E9', '#2DD4BF', '#FF8C42',
];

// ── Draggable Handle Logic ─────────────────────────────────────
type DragTarget = 'photo' | 'name' | 'photo-resize';

// ── Main Component ─────────────────────────────────────────────
export default function TemplateEditor({
  file, gradient, templateType, zones, onZonesChange,
}: TemplateEditorProps) {
  const canvasRef = useRef<HTMLDivElement>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [dragging, setDragging] = useState<DragTarget | null>(null);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [zoneSnapshot, setZoneSnapshot] = useState<ZoneConfig>(zones);
  const [activePanel, setActivePanel] = useState<'photo' | 'name'>('photo');

  // Create/revoke object URL for the uploaded file
  useEffect(() => {
    if (!file) { setPreviewUrl(null); return; }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  // Convert pointer event to normalized canvas coordinates
  const toNormalized = useCallback((e: React.PointerEvent): { nx: number; ny: number } => {
    const canvas = canvasRef.current;
    if (!canvas) return { nx: 0, ny: 0 };
    const rect = canvas.getBoundingClientRect();
    const nx = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    const ny = Math.max(0, Math.min(1, (e.clientY - rect.top) / rect.height));
    return { nx, ny };
  }, []);

  const onPointerDown = useCallback((target: DragTarget, e: React.PointerEvent) => {
    e.preventDefault();
    e.stopPropagation();
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
    setDragging(target);
    setDragStart({ x: e.clientX, y: e.clientY });
    setZoneSnapshot(zones);
  }, [zones]);

  const onPointerMove = useCallback((e: React.PointerEvent) => {
    if (!dragging) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const dx = (e.clientX - dragStart.x) / rect.width;
    const dy = (e.clientY - dragStart.y) / rect.height;

    if (dragging === 'photo') {
      onZonesChange({
        ...zones,
        photo: {
          ...zones.photo,
          x: Math.max(0.05, Math.min(0.95, zoneSnapshot.photo.x + dx)),
          y: Math.max(0.05, Math.min(0.95, zoneSnapshot.photo.y + dy)),
        },
      });
    } else if (dragging === 'name') {
      onZonesChange({
        ...zones,
        name: {
          ...zones.name,
          x: Math.max(0.05, Math.min(0.95, zoneSnapshot.name.x + dx)),
          y: Math.max(0.05, Math.min(0.95, zoneSnapshot.name.y + dy)),
        },
      });
    } else if (dragging === 'photo-resize') {
      // Resize: drag diagonal to change size
      const delta = (dx + dy) / 2;
      onZonesChange({
        ...zones,
        photo: {
          ...zones.photo,
          size: Math.max(0.05, Math.min(0.5, zoneSnapshot.photo.size + delta)),
        },
      });
    }
  }, [dragging, dragStart, zoneSnapshot, zones, onZonesChange]);

  const onPointerUp = useCallback(() => {
    setDragging(null);
  }, []);

  // Helper to update nested zone config
  const updatePhoto = (partial: Partial<PhotoZoneConfig>) =>
    onZonesChange({ ...zones, photo: { ...zones.photo, ...partial } });
  const updateName = (partial: Partial<NameZoneConfig>) =>
    onZonesChange({ ...zones, name: { ...zones.name, ...partial } });

  // Photo zone pixel dimensions
  const photoSizePct = zones.photo.size * 100;
  const photoLeftPct = (zones.photo.x - zones.photo.size / 2) * 100;
  const photoTopPct = (zones.photo.y - zones.photo.size / 2) * 100;

  const photoZoneStyle: React.CSSProperties = {
    position: 'absolute',
    left: `${photoLeftPct}%`,
    top: `${photoTopPct}%`,
    width: `${photoSizePct}%`,
    aspectRatio: '1',
    borderRadius: zones.photo.shape === 'circle' ? '50%'
      : zones.photo.shape === 'rounded' ? '16%' : '4px',
    border: `3px solid ${zones.photo.enabled ? 'rgba(124,92,252,0.9)' : 'rgba(255,255,255,0.3)'}`,
    boxShadow: '0 0 0 1px rgba(0,0,0,0.4)',
    cursor: dragging === 'photo' ? 'grabbing' : 'grab',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'visible',
    opacity: zones.photo.enabled ? 1 : 0.3,
    transition: dragging ? 'none' : 'opacity 0.2s',
    touchAction: 'none',
  };

  const nameZoneStyle: React.CSSProperties = {
    position: 'absolute',
    left: `${zones.name.x * 100}%`,
    top: `${zones.name.y * 100}%`,
    transform: `translate(${zones.name.alignment === 'center' ? '-50%' : zones.name.alignment === 'right' ? '-100%' : '0'}, 0)`,
    color: zones.name.color,
    fontSize: `${zones.name.fontSize * 100}cqh`,
    fontWeight: zones.name.weight as any,
    fontFamily: zones.name.font,
    textShadow: '0 2px 8px rgba(0,0,0,0.7)',
    whiteSpace: 'nowrap',
    cursor: dragging === 'name' ? 'grabbing' : 'grab',
    opacity: zones.name.enabled ? 1 : 0.3,
    border: `2px dashed ${zones.name.enabled ? 'rgba(255,107,157,0.8)' : 'rgba(255,255,255,0.2)'}`,
    padding: '2px 6px',
    borderRadius: '4px',
    userSelect: 'none',
    touchAction: 'none',
    transition: dragging ? 'none' : 'opacity 0.2s',
  };

  return (
    <div className="flex gap-6 h-full">
      {/* Canvas */}
      <div className="flex-1 min-w-0">
        <div className="text-xs text-muted font-600 uppercase tracking-wide mb-2">
          🖱️ Drag zones directly on the canvas — corners resize
        </div>
        <div
          className="relative mx-auto rounded-2xl overflow-hidden shadow-xl select-none"
          style={{
            aspectRatio: '9/16',
            maxHeight: '600px',
            background: previewUrl && templateType === 'IMAGE'
              ? `url(${previewUrl}) center/cover no-repeat`
              : gradient,
            containerType: 'size',
          }}
          ref={canvasRef}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerLeave={onPointerUp}
        >
          {previewUrl && templateType === 'VIDEO' && (
            <video src={previewUrl} autoPlay loop muted playsInline
              className="absolute inset-0 w-full h-full object-cover pointer-events-none" />
          )}

          {/* WhatsApp-style status bar */}
          <div className="absolute top-2 left-2 right-2 flex gap-0.5 pointer-events-none">
            <div className="flex-1 h-0.5 bg-white/50 rounded-full" />
            <div className="flex-1 h-0.5 bg-white/30 rounded-full" />
            <div className="flex-1 h-0.5 bg-white/20 rounded-full" />
          </div>

          {/* Photo Zone */}
          <div
            style={photoZoneStyle}
            onPointerDown={e => onPointerDown('photo', e)}
          >
            {/* Inner content */}
            <div style={{
              width: '100%', height: '100%',
              borderRadius: 'inherit',
              background: 'linear-gradient(135deg, rgba(124,92,252,0.15), rgba(255,107,157,0.15))',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              backdropFilter: 'blur(2px)',
            }}>
              <span style={{ fontSize: '1.5em', opacity: 0.7 }}>👤</span>
            </div>
            {/* Resize handle (bottom-right corner) */}
            {zones.photo.enabled && (
              <div
                style={{
                  position: 'absolute', bottom: -6, right: -6,
                  width: 14, height: 14,
                  background: '#2563EB',
                  borderRadius: '50%',
                  cursor: 'nwse-resize',
                  border: '2px solid white',
                  boxShadow: '0 1px 4px rgba(0,0,0,0.4)',
                  zIndex: 10,
                }}
                onPointerDown={e => { e.stopPropagation(); onPointerDown('photo-resize', e); }}
              />
            )}
            {/* Label */}
            <div style={{
              position: 'absolute', top: '50%', left: '50%',
              transform: 'translate(-50%, -50%)',
              color: 'rgba(255,255,255,0.8)',
              fontSize: '0.4em',
              fontWeight: 700,
              textAlign: 'center',
              lineHeight: 1.2,
              pointerEvents: 'none',
            }}>
              {zones.photo.enabled ? 'Photo' : ''}
            </div>
          </div>

          {/* Name Zone */}
          <div
            style={nameZoneStyle}
            onPointerDown={e => onPointerDown('name', e)}
          >
            Jayesh Jain
          </div>
        </div>
        <div className="text-center text-xs text-muted mt-2">9:16 ratio · 1080×1920px · normalized coordinates</div>
      </div>

      {/* Control Panel */}
      <div className="w-72 flex-shrink-0 space-y-4">
        {/* Tab switcher */}
        <div className="flex gap-1 bg-slate-100 p-1 rounded-xl">
          {(['photo', 'name'] as const).map(tab => (
            <button key={tab} onClick={() => setActivePanel(tab)}
              className={`flex-1 py-2 rounded-lg text-sm font-700 transition-colors ${
                activePanel === tab ? 'bg-white text-slate-800 shadow-sm' : 'text-muted hover:text-slate-600'
              }`}>
              {tab === 'photo' ? '📸 Photo Zone' : '✏️ Name Zone'}
            </button>
          ))}
        </div>

        {/* Photo Zone Controls */}
        {activePanel === 'photo' && (
          <div className="space-y-4 bg-white rounded-2xl p-4 border border-slate-200 shadow-sm">
            <label className="flex items-center justify-between cursor-pointer">
              <span className="text-sm font-700 text-slate-700">Enable Photo Zone</span>
              <div
                className={`w-11 h-6 rounded-full relative transition-colors ${zones.photo.enabled ? 'bg-primary' : 'bg-slate-200'}`}
                onClick={() => updatePhoto({ enabled: !zones.photo.enabled })}
              >
                <div className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${zones.photo.enabled ? 'translate-x-5' : ''}`} />
              </div>
            </label>

            {zones.photo.enabled && (
              <>
                <div>
                  <div className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">Shape</div>
                  <div className="grid grid-cols-3 gap-2">
                    {(['circle', 'square', 'rounded'] as const).map(shape => (
                      <button key={shape}
                        onClick={() => updatePhoto({ shape })}
                        className={`py-2 rounded-lg text-xs font-700 border-2 transition-all ${
                          zones.photo.shape === shape
                            ? 'border-primary bg-primary/10 text-primary'
                            : 'border-slate-200 text-muted'
                        }`}
                      >
                        {shape === 'circle' ? '⬤' : shape === 'square' ? '⬛' : '▢'}{' '}
                        {shape}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="space-y-3">
                  {[
                    { label: 'Center X', key: 'x' as const, min: 0.05, max: 0.95 },
                    { label: 'Center Y', key: 'y' as const, min: 0.05, max: 0.95 },
                    { label: 'Size', key: 'size' as const, min: 0.05, max: 0.5 },
                  ].map(({ label, key, min, max }) => (
                    <div key={key}>
                      <div className="flex justify-between text-xs text-muted mb-1">
                        <span className="font-600">{label}</span>
                        <span>{(zones.photo[key] * 100).toFixed(0)}%</span>
                      </div>
                      <input type="range" min={min} max={max} step={0.01}
                        value={zones.photo[key]}
                        onChange={e => updatePhoto({ [key]: parseFloat(e.target.value) } as any)}
                        className="w-full accent-primary" />
                    </div>
                  ))}
                </div>
                <div className="text-xs text-muted bg-slate-50 rounded-lg p-2">
                  💡 Drag the zone on the canvas or use sliders above
                </div>
              </>
            )}
          </div>
        )}

        {/* Name Zone Controls */}
        {activePanel === 'name' && (
          <div className="space-y-4 bg-white rounded-2xl p-4 border border-slate-200 shadow-sm">
            <label className="flex items-center justify-between cursor-pointer">
              <span className="text-sm font-700 text-slate-700">Enable Name Zone</span>
              <div
                className={`w-11 h-6 rounded-full relative transition-colors ${zones.name.enabled ? 'bg-primary' : 'bg-slate-200'}`}
                onClick={() => updateName({ enabled: !zones.name.enabled })}
              >
                <div className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${zones.name.enabled ? 'translate-x-5' : ''}`} />
              </div>
            </label>

            {zones.name.enabled && (
              <>
                <div className="space-y-3">
                  {[
                    { label: 'Position X', key: 'x' as const, min: 0.05, max: 0.95 },
                    { label: 'Position Y', key: 'y' as const, min: 0.05, max: 0.95 },
                    { label: 'Font Size', key: 'fontSize' as const, min: 0.02, max: 0.12 },
                  ].map(({ label, key, min, max }) => (
                    <div key={key}>
                      <div className="flex justify-between text-xs text-muted mb-1">
                        <span className="font-600">{label}</span>
                        <span>{(zones.name[key] * 100).toFixed(1)}%</span>
                      </div>
                      <input type="range" min={min} max={max} step={0.005}
                        value={zones.name[key]}
                        onChange={e => updateName({ [key]: parseFloat(e.target.value) } as any)}
                        className="w-full accent-primary" />
                    </div>
                  ))}
                </div>

                <div>
                  <div className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">Color</div>
                  <div className="flex gap-2 flex-wrap">
                    {COLORS.map(c => (
                      <button key={c}
                        onClick={() => updateName({ color: c })}
                        className={`w-7 h-7 rounded-full border-2 transition-transform ${
                          zones.name.color === c ? 'border-primary scale-110' : 'border-transparent hover:scale-105'
                        }`}
                        style={{ background: c, boxShadow: '0 0 0 1px rgba(0,0,0,0.2)' }}
                      />
                    ))}
                  </div>
                </div>

                <div>
                  <div className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">Font</div>
                  <select
                    value={zones.name.font}
                    onChange={e => updateName({ font: e.target.value })}
                    className="w-full text-sm border border-slate-200 rounded-lg px-3 py-2 focus:outline-none focus:border-primary"
                  >
                    {FONTS.map(f => (
                      <option key={f.value} value={f.value} style={{ fontFamily: f.value }}>{f.label}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <div className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">Alignment</div>
                  <div className="flex gap-2">
                    {([
                      { value: 'left', icon: <AlignLeft size={14} /> },
                      { value: 'center', icon: <AlignCenter size={14} /> },
                      { value: 'right', icon: <AlignRight size={14} /> },
                    ] as const).map(({ value, icon }) => (
                      <button key={value}
                        onClick={() => updateName({ alignment: value })}
                        className={`flex-1 flex items-center justify-center py-2 rounded-lg border-2 transition-all ${
                          zones.name.alignment === value ? 'border-primary bg-primary/10 text-primary' : 'border-slate-200 text-muted'
                        }`}
                      >
                        {icon}
                      </button>
                    ))}
                  </div>
                </div>

                <div>
                  <div className="text-xs font-700 text-slate-500 uppercase tracking-wide mb-2">Weight</div>
                  <div className="flex gap-2">
                    {(['normal', 'bold', '900'] as const).map(w => (
                      <button key={w}
                        onClick={() => updateName({ weight: w })}
                        className={`flex-1 py-2 rounded-lg border-2 text-xs transition-all ${
                          zones.name.weight === w ? 'border-primary bg-primary/10 text-primary' : 'border-slate-200 text-muted'
                        }`}
                        style={{ fontWeight: w }}
                      >
                        {w === 'normal' ? 'Regular' : w === 'bold' ? 'Bold' : 'Black'}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="text-xs text-muted bg-slate-50 rounded-lg p-2">
                  💡 Drag the pink zone on the canvas or use sliders above. Sample shows "Jayesh Jain".
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
