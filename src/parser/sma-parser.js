import parserModule from '../../electron/smaParser.cjs'

const { parseSMAEntities, normalizeName, normalizePath } = parserModule

export { parseSMAEntities, normalizeName, normalizePath }

const SPRITE_REGEX = /"([^"\n]+\.spr)"/gi
const SOUND_REGEX = /"([^"\n]+\.(?:wav|mp3))"/gi

const ABILITY_PATTERNS = [
  { regex: /set_user_health\s*\([^,]+,\s*([^\)]+)\)/gi, effect: 'heal', fn: 'set_user_health' },
  { regex: /cs_set_user_armor\s*\([^,]+,\s*([^,\)]+)[^)]*\)/gi, effect: 'armor_boost', fn: 'cs_set_user_armor' },
  { regex: /set_user_maxspeed\s*\([^,]+,\s*([^\)]+)\)/gi, effect: 'speed_boost', fn: 'set_user_maxspeed' },
  { regex: /set_user_gravity\s*\([^,]+,\s*([^\)]+)\)/gi, effect: 'low_gravity', fn: 'set_user_gravity' },
  { regex: /set_user_rendering\s*\(/gi, effect: 'invisibility', fn: 'set_user_rendering', capture: false },
  { regex: /pev_\s*\(\s*id\s*,\s*pev_rendermode/gi, effect: 'invisibility', fn: 'pev_rendermode', capture: false }
]

function ensureMeta(entity) {
  if (!entity.meta) entity.meta = { extraCalls: [], resolvedFrom: [] }
  if (!Array.isArray(entity.meta.extraCalls)) entity.meta.extraCalls = []
  return entity.meta
}

function ensureAbilities(entity) {
  if (!Array.isArray(entity.abilities)) entity.abilities = []
  return entity.abilities
}

function ensurePathArray(entity, key) {
  if (!entity.paths) entity.paths = { models: [], claws: [], sprites: [], sounds: [] }
  if (!Array.isArray(entity.paths[key])) entity.paths[key] = []
  return entity.paths[key]
}

function pushNormalizedPath(list, value) {
  const normalized = normalizePath ? normalizePath(value) : (value ? String(value).trim().toLowerCase() : '')
  if (!normalized) return
  if (!list.includes(normalized)) list.push(normalized)
}

export function createEmptyEntity() {
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
  if (!line || !entity) return entity
  const target = ensurePathArray(entity, 'sprites')
  let match
  while ((match = SPRITE_REGEX.exec(line)) !== null) {
    pushNormalizedPath(target, match[1])
  }
  return entity
}

export function parseSounds(line, entity) {
  if (!line || !entity) return entity
  const target = ensurePathArray(entity, 'sounds')
  let match
  while ((match = SOUND_REGEX.exec(line)) !== null) {
    pushNormalizedPath(target, match[1])
  }
  return entity
}

export function parseAbilities(body, entity) {
  if (!body || !entity) return entity
  const abilities = ensureAbilities(entity)
  const meta = ensureMeta(entity)

  for (const pattern of ABILITY_PATTERNS) {
    pattern.regex.lastIndex = 0
    let match
    while ((match = pattern.regex.exec(body)) !== null) {
      const value = pattern.capture === false ? null : (match[1] ? match[1].trim() : null)
      const record = {
        type: 'abilityDetected',
        fn: pattern.fn,
        effect: pattern.effect,
        value
      }
      abilities.push({ effect: pattern.effect, fn: pattern.fn, value })
      meta.extraCalls.push({
        ...record,
        kind: 'ability',
        args: value ? [value] : [],
        resolved: Boolean(value),
        dynamic: false,
        resolvedFrom: ['abilityHeuristic']
      })
    }
  }

  return entity
}

export default {
  createEmptyEntity,
  parseSprites,
  parseSounds,
  parseAbilities,
  parseSMAEntities,
  normalizeName,
  normalizePath
}
