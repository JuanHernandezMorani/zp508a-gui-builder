import React, { useCallback, useEffect, useMemo, useState } from 'react'
import type {
  ZPItem,
  ZombieStats,
  HumanStats,
  WeaponStats,
  ShopItemStats
} from '@common/types'
import { cloneZPItem, getDefaultStats, sanitizePathsForType } from '@common/zpUtils'

interface EditModalProps {
  item: ZPItem
  onClose: () => void
  onSave: (item: ZPItem) => void
}

const CLASS_TYPES = new Set(['human_class', 'zombie_class', 'special_human_class', 'special_zombie_class'])

function asStringArray(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((entry) => String(entry))
  if (value instanceof Set) return Array.from(value).map((entry) => String(entry))
  if (typeof value === 'string') return [value]
  return []
}

const ORIGIN_LABEL_DEFAULT = 'Zombie Plague 5.0.8a'

export default function EditModal({ item, onClose, onSave }: EditModalProps) {
  const [draft, setDraft] = useState<ZPItem>(() => cloneZPItem(item))

  useEffect(() => {
    setDraft(cloneZPItem(item))
  }, [item])

  const isClass = useMemo(() => CLASS_TYPES.has(draft.type), [draft.type])
  const isMode = draft.type === 'mode'
  const showModels = !isMode
  const showSounds = !isMode && !isClass
  const showSprites = !isMode && !isClass

  const currentPaths = draft.paths || { models: [], sounds: [], sprites: [] }

  const handleTypeChange = useCallback((nextType: ZPItem['type']) => {
    setDraft((prev) => {
      if (prev.type === nextType) return prev
      const nextStats = getDefaultStats(nextType)
      const nextPaths = sanitizePathsForType(nextType, prev.paths)

      return {
        ...prev,
        type: nextType,
        stats: nextStats as any,
        paths: nextPaths
      } as ZPItem
    })
  }, [])

  const handleStatsChange = useCallback((values: Record<string, any>) => {
    setDraft((prev) => ({
      ...prev,
      stats: values
    }))
  }, [])

  const originVersion = (item.meta && item.meta.originVersion) || 'zp_5_0_8a'
  const originLabelRaw = (item.meta && item.meta.originLabel) || ORIGIN_LABEL_DEFAULT
  const originIsAddon = Boolean(item.meta && item.meta.originIsAddon)
  const originLabel = originIsAddon && !/addon/i.test(originLabelRaw)
    ? `${originLabelRaw} (Addon externo)`
    : originLabelRaw
  const showOriginBadge = originVersion !== 'zp_5_0_8a' || originIsAddon

  const transformationLog = asStringArray(item.meta?.transformations)
  const warnings = asStringArray(item.meta?.warnings)

  const updatePaths = (kind: 'models' | 'sounds' | 'sprites', values: string[]) => {
    setDraft((prev) => {
      const prevPaths = prev.paths || { models: [], sounds: [], sprites: [] }
      return {
        ...prev,
        paths: {
          models: kind === 'models' ? values : [...prevPaths.models],
          sounds: kind === 'sounds' ? values : [...prevPaths.sounds],
          sprites: kind === 'sprites' ? values : [...prevPaths.sprites]
        }
      }
    })
  }

  const handleSave = () => {
    const trimmedName = (draft.name || '').trim()
    if (!trimmedName) {
      window.alert('El nombre es obligatorio')
      return
    }
    const sanitizedPaths = sanitizePathsForType(draft.type, draft.paths)
    const prepared: ZPItem = {
      ...draft,
      name: trimmedName,
      fileName: (draft.fileName || '').trim(),
      paths: sanitizedPaths,
      meta: draft.meta ? { ...draft.meta } : {}
    }
    onSave(prepared)
  }

  const renderSpecificFields = () => {
    switch (draft.type) {
      case 'zombie_class':
      case 'special_zombie_class': {
        const zStats = draft.stats as ZombieStats
        return (
          <>
            <label>
              Vida:
              <input
                type="number"
                value={zStats.health ?? 2000}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...zStats, health: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Velocidad:
              <input
                type="number"
                value={zStats.speed ?? 250}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...zStats, speed: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Gravedad:
              <input
                type="number"
                step="0.1"
                value={zStats.gravity ?? 1.0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...zStats, gravity: Number.parseFloat(e.target.value) || 0 } })
                }
              />
            </label>
            <label>
              Knockback:
              <input
                type="number"
                step="0.1"
                value={zStats.knockback ?? 1.0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...zStats, knockback: Number.parseFloat(e.target.value) || 0 } })
                }
              />
            </label>
          </>
        )
      }
      case 'human_class':
      case 'special_human_class': {
        const hStats = draft.stats as HumanStats
        return (
          <>
            <label>
              Vida:
              <input
                type="number"
                value={hStats.health ?? 100}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...hStats, health: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Velocidad:
              <input
                type="number"
                value={hStats.speed ?? 240}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...hStats, speed: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Chaleco:
              <input
                type="number"
                value={hStats.armor ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...hStats, armor: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Daño base:
              <input
                type="number"
                step="0.1"
                value={hStats.base_damage ?? 1.0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...hStats, base_damage: Number.parseFloat(e.target.value) || 0 } })
                }
              />
            </label>
          </>
        )
      }
      case 'weapon': {
        const wStats = draft.stats as WeaponStats
        return (
          <>
            <label>
              Daño:
              <input
                type="number"
                value={wStats.damage ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...wStats, damage: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Capacidad cargador:
              <input
                type="number"
                value={wStats.clip_capacity ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...wStats, clip_capacity: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Cadencia:
              <input
                type="number"
                step="0.01"
                value={wStats.fire_rate ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...wStats, fire_rate: Number.parseFloat(e.target.value) || 0 } })
                }
              />
            </label>
            <label>
              Tiempo recarga:
              <input
                type="number"
                step="0.1"
                value={wStats.reload_time ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...wStats, reload_time: Number.parseFloat(e.target.value) || 0 } })
                }
              />
            </label>
            <label>
              Costo:
              <input
                type="number"
                value={wStats.cost ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...wStats, cost: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
          </>
        )
      }
      case 'shop_item': {
        const sStats = draft.stats as ShopItemStats
        return (
          <>
            <label>
              Costo:
              <input
                type="number"
                value={sStats.cost ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...sStats, cost: Number.parseInt(e.target.value, 10) || 0 } })
                }
              />
            </label>
            <label>
              Equipo:
              <select
                value={sStats.team ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...sStats, team: (Number.parseInt(e.target.value, 10) as 0 | 1 | 2) || 0 } })
                }
              >
                <option value={0}>Ambos</option>
                <option value={1}>Humano</option>
                <option value={2}>Zombie</option>
              </select>
            </label>
            <label>
              Ilimitado:
              <select
                value={sStats.unlimited ?? 0}
                onChange={(e) =>
                  setDraft({ ...draft, stats: { ...sStats, unlimited: (Number.parseInt(e.target.value, 10) as 0 | 1) || 0 } })
                }
              >
                <option value={0}>No</option>
                <option value={1}>Sí</option>
              </select>
            </label>
          </>
        )
      }
      default:
        return <TextareaKV obj={(draft.stats as Record<string, any>) || {}} onChange={handleStatsChange} />
    }
  }

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}
    >
      <div style={{ background: '#fff', padding: 16, borderRadius: 8, width: 760, maxHeight: '85vh', overflow: 'auto' }}>
        <h3 style={{ marginTop: 0 }}>Editar {draft.type}</h3>

        {(showOriginBadge || transformationLog.length || warnings.length) && (
          <div style={{ background: '#f3f4f6', padding: 12, borderRadius: 8, marginBottom: 12 }}>
            {showOriginBadge && (
              <div style={{ marginBottom: transformationLog.length || warnings.length ? 8 : 0 }}>
                <strong>Origen detectado:</strong> {originLabel}
              </div>
            )}
            {transformationLog.length > 0 && (
              <div style={{ marginBottom: warnings.length ? 8 : 0 }}>
                <strong>Transformaciones aplicadas:</strong>
                <ul style={{ margin: '4px 0 0 16px' }}>
                  {transformationLog.map((entry, index) => (
                    <li key={`transform-${index}`}>{entry}</li>
                  ))}
                </ul>
              </div>
            )}
            {warnings.length > 0 && (
              <div style={{ color: '#b91c1c' }}>
                <strong>Warnings:</strong>
                <ul style={{ margin: '4px 0 0 16px' }}>
                  {warnings.map((entry, index) => (
                    <li key={`warning-${index}`}>{entry}</li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <label>
            Nombre
            <input value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
          </label>
          <label>
            Nombre de archivo (.sma)
            <input
              value={draft.fileName}
              onChange={(e) => setDraft({ ...draft, fileName: e.target.value })}
              placeholder="auto"
            />
          </label>
          <label>
            Descripción
            <textarea
              value={draft.description || ''}
              onChange={(e) => setDraft({ ...draft, description: e.target.value })}
              rows={2}
            />
          </label>
          <label>
            Tipo
            <select value={draft.type} onChange={(e) => handleTypeChange(e.target.value as ZPItem['type'])}>
              <option value="human_class">Human Class</option>
              <option value="zombie_class">Zombie Class</option>
              <option value="special_human_class">Human Special</option>
              <option value="special_zombie_class">Zombie Special</option>
              <option value="mode">Mode</option>
              <option value="weapon">Weapon</option>
              <option value="shop_item">Shop Item</option>
              <option value="system">System</option>
            </select>
          </label>
          <label style={{ alignSelf: 'center' }}>
            Enabled
            <input type="checkbox" checked={draft.enabled} onChange={(e) => setDraft({ ...draft, enabled: e.target.checked })} />
          </label>
        </div>

        <fieldset style={{ marginTop: 12 }}>
          <legend>Atributos específicos</legend>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>{renderSpecificFields()}</div>
        </fieldset>

        {!isMode && (
          <fieldset style={{ marginTop: 12 }}>
            <legend>Paths (models/sounds/sprites)</legend>
            {showModels && (
              <ArrayEdit
                label="Models"
                arr={currentPaths.models}
                onChange={(arr) => updatePaths('models', arr)}
                onAddAttempt={(value) => {
                  if (isClass && value.trim().toLowerCase().endsWith('.spr')) {
                    window.alert('Sprites no aplican a clases en ZP 5.0.8a')
                    return false
                  }
                  return true
                }}
              />
            )}
            {showSounds && (
              <ArrayEdit label="Sounds" arr={currentPaths.sounds} onChange={(arr) => updatePaths('sounds', arr)} />
            )}
            {showSprites && (
              <ArrayEdit
                label="Sprites"
                arr={currentPaths.sprites}
                onChange={(arr) => updatePaths('sprites', arr)}
                onAddAttempt={(value) => {
                  if (isClass) {
                    window.alert('Sprites no aplican a clases en ZP 5.0.8a')
                    return false
                  }
                  return true
                }}
              />
            )}
          </fieldset>
        )}

        <div style={{ marginTop: 12, display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
          <button onClick={onClose}>Cancelar</button>
          <button onClick={handleSave}>Guardar</button>
        </div>
      </div>
    </div>
  )
}

function TextareaKV({ obj, onChange }: { obj: Record<string, any>; onChange: (o: Record<string, any>) => void }) {
  const format = (input: Record<string, any>) =>
    Object.entries(input)
      .map(([k, v]) => `${k}=${v}`)
      .join('\n')

  const [txt, setTxt] = useState(format(obj))

  useEffect(() => {
    const next = format(obj)
    setTxt((current) => (current === next ? current : next))
  }, [obj])

  useEffect(() => {
    const out: Record<string, any> = {}
    txt.split(/\r?\n/).forEach((line) => {
      const trimmed = line.trim()
      if (!trimmed) return
      const m = trimmed.split('=')
      if (m.length >= 2) out[m[0].trim()] = m.slice(1).join('=').trim()
    })
    onChange(out)
  }, [txt, onChange])

  return <textarea value={txt} onChange={(e) => setTxt(e.target.value)} rows={6} style={{ width: '100%' }} />
}

function ArrayEdit({
  label,
  arr,
  onChange,
  onAddAttempt,
  disabled
}: {
  label: string
  arr: string[]
  onChange: (a: string[]) => void
  onAddAttempt?: (value: string) => boolean
  disabled?: boolean
}) {
  const [val, setVal] = useState('')

  return (
    <div style={{ marginBottom: 8 }}>
      <b>{label}</b>
      <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
        <input value={val} onChange={(e) => setVal(e.target.value)} placeholder="ruta/model.mdl" disabled={disabled} />
        <button
          onClick={() => {
            const cleaned = val.trim()
            if (!cleaned) return
            if (onAddAttempt && onAddAttempt(cleaned) === false) {
              setVal('')
              return
            }
            if (arr.includes(cleaned)) {
              setVal('')
              return
            }
            onChange([...arr, cleaned])
            setVal('')
          }}
          disabled={disabled}
        >
          Agregar
        </button>
      </div>
      <ul>
        {arr.map((x, i) => (
          <li key={`${label}-${i}`}>
            {x}{' '}
            <button onClick={() => onChange(arr.filter((_, j) => j !== i))}>x</button>
          </li>
        ))}
      </ul>
    </div>
  )
}
