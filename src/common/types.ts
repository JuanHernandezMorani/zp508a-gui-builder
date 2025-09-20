export type ZPType = 
  | 'human_class'
  | 'zombie_class'
  | 'special_human_class'
  | 'special_zombie_class'
  | 'mode'
  | 'weapon'
  | 'shop_item'
  | 'system'

export interface BaseItem {
  id: string
  name: string
  fileName: string
  type: ZPType
  enabled: boolean
  description?: string
  source: 'ui' | 'scan'
  meta: Record<string, any>
  paths: { models: string[]; sounds: string[]; sprites: string[] }
}

export interface ZombieStats {
  health?: number
  speed?: number
  gravity?: number
  knockback?: number
}
export interface HumanStats {
  health?: number
  speed?: number
  armor?: number
  base_damage?: number
}
export interface WeaponStats {
  damage?: number
  clip_capacity?: number
  fire_rate?: number
  reload_time?: number
  cost?: number
}
export interface ShopItemStats {
  cost?: number
  team?: 0 | 1 | 2
  unlimited?: 0 | 1
}

export type ZPItem =
  | (BaseItem & { type: 'zombie_class'; stats: ZombieStats })
  | (BaseItem & { type: 'human_class'; stats: HumanStats })
  | (BaseItem & { type: 'special_zombie_class'; stats: ZombieStats })
  | (BaseItem & { type: 'special_human_class'; stats: HumanStats })
  | (BaseItem & { type: 'weapon'; stats: WeaponStats })
  | (BaseItem & { type: 'shop_item'; stats: ShopItemStats })
  | (BaseItem & { type: 'mode' | 'system'; stats: Record<string, any> })
