console.log('[parser] SMA parser stubs loaded')

/**
 * Base entity shape for parser results.
 * @returns {{
 *   type: string,
 *   name: string,
 *   stats: Record<string, any>,
 *   paths: { models: string[], claws: string[], sprites: string[], sounds: string[] },
 *   abilities: any[],
 *   meta: { filePath: string, line: number, origin: string, extraCalls: any[], resolvedFrom: any[] }
 * }}
 */
export function createEmptyEntity() {
  // TODO: refine default stats and meta tracking for parsed entities
  return {
    type: '',
    name: '',
    stats: {},
    paths: { models: [], claws: [], sprites: [], sounds: [] },
    abilities: [],
    meta: {
      filePath: '',
      line: 0,
      origin: '',
      extraCalls: [],
      resolvedFrom: []
    }
  }
}

export function parseSprites(line, entity) {
  // TODO: detectar sprites y agregarlos a entity.paths.sprites
}

export function parseSounds(line, entity) {
  // TODO: detectar sonidos y agregarlos a entity.paths.sounds
}

export function parseAbilities(body, entity) {
  // TODO: detectar set_user_health / set_user_armor / set_user_gravity / etc.
  // Guardar en entity.abilities
}
