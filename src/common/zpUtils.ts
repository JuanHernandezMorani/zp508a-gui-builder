import type {
  ZPItem,
  ZPType,
  ZombieStats,
  HumanStats,
  WeaponStats,
  ShopItemStats
} from './types'

const CLASS_DEFAULTS: Record<'zombie_class' | 'human_class' | 'special_zombie_class' | 'special_human_class', ZombieStats | HumanStats> = {
  zombie_class: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  human_class: { health: 100, speed: 240, armor: 0, base_damage: 1.0 },
  special_zombie_class: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  special_human_class: { health: 100, speed: 240, armor: 0, base_damage: 1.0 }
}

const WEAPON_DEFAULTS: WeaponStats = { damage: 0, clip_capacity: 0, fire_rate: 0, reload_time: 0, cost: 0 }
const SHOP_DEFAULTS: ShopItemStats = { cost: 0, team: 0, unlimited: 0 }

export function getDefaultStats(type: ZPType): ZombieStats | HumanStats | WeaponStats | ShopItemStats | Record<string, any> {
  switch (type) {
    case 'zombie_class':
    case 'special_zombie_class':
      return { ...(CLASS_DEFAULTS[type] as ZombieStats) }
    case 'human_class':
    case 'special_human_class':
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
      claws: [...(item.paths?.claws || [])],
      sounds: [...(item.paths?.sounds || [])],
      sprites: [...(item.paths?.sprites || [])]
    },
    abilities: Array.isArray(item.abilities) ? [...item.abilities] : item.abilities
  } as T
}

export function sanitizePathsForType(
  type: ZPType,
  paths?: { models?: string[]; claws?: string[]; sounds?: string[]; sprites?: string[] }
) {
  const unique = (values?: string[]) =>
    Array.from(new Set((values || []).map((v) => v.trim()).filter(Boolean)))

  const base = {
    models: unique(paths?.models),
    claws: unique(paths?.claws),
    sounds: unique(paths?.sounds),
    sprites: unique(paths?.sprites)
  }

  if (type === 'mode') {
    return { models: [], claws: [], sounds: [], sprites: [] }
  }

  if (['human_class', 'zombie_class', 'special_human_class', 'special_zombie_class'].includes(type)) {
    const filteredModels = base.models.filter((m) => !m.toLowerCase().endsWith('.spr'))
    return { models: filteredModels, claws: base.claws, sounds: base.sounds, sprites: base.sprites }
  }

  return base
}
