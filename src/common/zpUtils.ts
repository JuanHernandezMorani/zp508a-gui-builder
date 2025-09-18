import type {
  ZPItem,
  ZPType,
  ZombieStats,
  HumanStats,
  WeaponStats,
  ShopItemStats
} from './types'

const CLASS_DEFAULTS: Record<'zombie_class' | 'human_class' | 'zombie_special' | 'human_special', ZombieStats | HumanStats> = {
  zombie_class: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  human_class: { health: 100, speed: 240, armor: 0, base_damage: 1.0 },
  zombie_special: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  human_special: { health: 100, speed: 240, armor: 0, base_damage: 1.0 }
}

const WEAPON_DEFAULTS: WeaponStats = { damage: 0, clip_capacity: 0, fire_rate: 0, reload_time: 0, cost: 0 }
const SHOP_DEFAULTS: ShopItemStats = { cost: 0, team: 0, unlimited: 0 }

export function getDefaultStats(type: ZPType): ZombieStats | HumanStats | WeaponStats | ShopItemStats | Record<string, any> {
  switch (type) {
    case 'zombie_class':
    case 'zombie_special':
      return { ...(CLASS_DEFAULTS[type] as ZombieStats) }
    case 'human_class':
    case 'human_special':
      return { ...(CLASS_DEFAULTS[type] as HumanStats) }
    case 'weapon':
      return { ...WEAPON_DEFAULTS }
    case 'shop_item':
      return { ...SHOP_DEFAULTS }
    default:
      return {}
  }
}

export function cloneZPItem<T extends ZPItem>(item: T): T {
  return {
    ...item,
    stats: item.stats ? { ...item.stats } : {},
    meta: item.meta ? { ...item.meta } : {},
    paths: {
      models: [...(item.paths?.models || [])],
      sounds: [...(item.paths?.sounds || [])],
      sprites: [...(item.paths?.sprites || [])]
    }
  } as T
}

export function sanitizePathsForType(
  type: ZPType,
  paths?: { models?: string[]; sounds?: string[]; sprites?: string[] }
) {
  const unique = (values?: string[]) =>
    Array.from(new Set((values || []).map((v) => v.trim()).filter(Boolean)))

  const base = {
    models: unique(paths?.models),
    sounds: unique(paths?.sounds),
    sprites: unique(paths?.sprites)
  }

  if (type === 'mode') {
    return { models: [], sounds: [], sprites: [] }
  }

  if (['human_class', 'zombie_class', 'human_special', 'zombie_special'].includes(type)) {
    const filteredModels = base.models.filter((m) => !m.toLowerCase().endsWith('.spr'))
    return { models: filteredModels, sounds: [], sprites: [] }
  }

  return base
}
