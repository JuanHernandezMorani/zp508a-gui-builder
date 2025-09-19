const path = require('path')
const crypto = require('crypto')

const VERSION_INFO = {
  zp_5_0_8a: { label: 'Zombie Plague 5.0.8a' },
  zp_4_3: { label: 'Zombie Plague 4.3' },
  external_addon: { label: 'Addon externo' },
  mixed: { label: 'Sintaxis combinada' },
  unknown: { label: 'Versión desconocida' }
}

const REGISTER_FUNCTION_MAPPINGS = {
  'zp_class_zombie_register': { normalized: 'zp_class_zombie_register', type: 'zombie_class', origin: 'zp_5_0_8a' },
  'zp_register_zombie_class': { normalized: 'zp_class_zombie_register', type: 'zombie_class', origin: 'zp_5_0_8a' },
  'zp_register_class_zombie': { normalized: 'zp_class_zombie_register', type: 'zombie_class', origin: 'zp_4_3', legacy: true },
  'zp_class_human_register': { normalized: 'zp_class_human_register', type: 'human_class', origin: 'zp_5_0_8a' },
  'zp_register_human_class': { normalized: 'zp_class_human_register', type: 'human_class', origin: 'zp_5_0_8a' },
  'zp_register_class_human': { normalized: 'zp_class_human_register', type: 'human_class', origin: 'zp_4_3', legacy: true },
  'zp_register_zombie_special_class': { normalized: 'zp_register_zombie_special_class', type: 'zombie_special', origin: 'zp_5_0_8a' },
  'zp_register_human_special_class': { normalized: 'zp_register_human_special_class', type: 'human_special', origin: 'zp_5_0_8a' },
  'zp_register_extra_item': { normalized: 'zp_register_extra_item', type: 'shop_item', origin: 'zp_5_0_8a' },
  'zp_weapon_register': { normalized: 'zp_weapon_register', type: 'weapon', origin: 'zp_5_0_8a' },
  'zp_register_gamemode': { normalized: 'zp_register_gamemode', type: 'mode', origin: 'zp_5_0_8a' }
}

const REGISTER_FUNCTIONS = Object.keys(REGISTER_FUNCTION_MAPPINGS)
const REGISTER_FUNCTION_SET = new Set(REGISTER_FUNCTIONS.map(name => name.toLowerCase()))

const SUPPLEMENTAL_FUNCTIONS = [
  'zp_class_zombie_register_kb',
  'zp_class_zombie_register_model',
  'zp_class_human_register_model'
]

const ESCAPE_REGEX = /[-/\\^$*+?.()|[\]{}]/g
function esc(s){ return s.replace(ESCAPE_REGEX, '\\$&') }

const TYPE_STAT_FIELDS = {
  zombie_class: ['health', 'speed', 'gravity', 'knockback'],
  human_class: ['health', 'speed', 'gravity', 'armor'],
  zombie_special: ['health', 'speed', 'gravity', 'knockback'],
  human_special: ['health', 'speed', 'gravity', 'armor'],
  weapon: ['damage', 'clip_capacity', 'fire_rate', 'reload_time', 'cost'],
  shop_item: ['cost', 'team', 'unlimited']
}

const TYPE_FIELD_POSITIONS = {
  shop_item: {
    cost: 1,
    team: 2,
    unlimited: 3
  }
}

const STAT_KEYWORDS = {
  health: ['health', 'hp'],
  speed: ['speed', 'velocity'],
  gravity: ['gravity', 'grav'],
  knockback: ['knockback', 'kb'],
  armor: ['armor', 'armour', 'arm'],
  damage: ['damage', 'dmg'],
  clip_capacity: ['clip', 'clipsize', 'clip_capacity', 'clipammo'],
  fire_rate: ['fire_rate', 'firerate', 'rate', 'rof'],
  reload_time: ['reload', 'reload_time'],
  cost: ['cost', 'price'],
  team: ['team'],
  unlimited: ['unlimited', 'limit', 'stock']
}

const RESOURCE_EXTENSIONS = {
  models: ['.mdl'],
  sounds: ['.wav', '.mp3'],
  sprites: ['.spr']
}

const CLASS_TYPES = new Set(['zombie_class', 'human_class', 'zombie_special', 'human_special'])

const ZP508a_DEFAULTS = Object.freeze({
  human_class: { health: 100, speed: 240, gravity: 1.0, armor: 0 },
  human_special: { health: 100, speed: 240, gravity: 1.0, armor: 0 },
  zombie_class: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  zombie_special: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 }
})

const DEFAULT_VALUES = {
  ...ZP508a_DEFAULTS,
  weapon: { damage: 0, clip_capacity: 0, fire_rate: 0, reload_time: 0, cost: 0 },
  shop_item: { cost: 0, team: 0, unlimited: 0 },
  mode: {}
}

const HARDCODED_CONSTANTS = {
  humanclass1_name: 'Classic Human',
  humanclass2_name: 'Raptor',
  zombieclass1_name: 'Classic Zombie',
  zombieclass2_name: 'Raptor Zombie',
  zombieclass3_name: 'Light Zombie',
  zombieclass4_name: 'Fat Zombie',
  zombieclass6_name: 'Rage Zombie',
  ZP_TEAM_ZOMBIE: 1 << 0,
  ZP_TEAM_HUMAN: 1 << 1,
  ZP_TEAM_NEMESIS: 1 << 2,
  ZP_TEAM_SURVIVOR: 1 << 3,
  ZP_TEAM_SNIPER: 1 << 4,
  ZP_TEAM_ASSASSIN: 1 << 5,
  ZP_TEAM_ANY: 0,
  true: 1,
  false: 0,
  TRUE: 1,
  FALSE: 0
  // Extensible: agregar más si fuese necesario según el pack de ZP 5.0.8a
}

class ValueResolver {
  constructor(definitionContainer, warn) {
    this.definitionContainer = definitionContainer || { definitions: new Map(), entries: [] }
    this.warn = typeof warn === 'function' ? warn : () => {}
    this.variables = new Map()
    this.resolutionStack = new Set()
    this.warnedCircular = new Set()
    this.circularWarnings = new Set()
    this.circularHandler = null
  }

  setVariable(name, value) {
    if (!name) return
    this.variables.set(name, value)
  }

  detectCircularDependency(variableName) {
    if (this.resolutionStack.has(variableName)) {
      return true
    }
    this.resolutionStack.add(variableName)
    return false
  }

  onCircular(handler) {
    this.circularHandler = typeof handler === 'function' ? handler : null
  }

  resolveValue(expression, context = 'global') {
    if (expression === undefined || expression === null) return undefined
    const trimmed = typeof expression === 'string' ? expression.trim() : expression
    if (trimmed === '') return undefined
    if (typeof trimmed !== 'string') return trimmed
    if (/^[A-Za-z_]\w*$/.test(trimmed)) {
      if (this.variables.has(trimmed)) return this.variables.get(trimmed)
      const container = this.definitionContainer
      const map = container && container.definitions
      const hasDefinition = map ? map.has(trimmed) : false
      if (!hasDefinition && HARDCODED_CONSTANTS[trimmed] !== undefined) {
        return HARDCODED_CONSTANTS[trimmed]
      }
    }
    return parseExpression(trimmed, this, context)
  }

  resolveIdentifier(name, context = 'global') {
    if (!name) return undefined
    if (HARDCODED_CONSTANTS[name] !== undefined) return HARDCODED_CONSTANTS[name]
    if (this.variables.has(name)) return this.variables.get(name)
    const container = this.definitionContainer
    const map = container && container.definitions
    if (!map || !map.has(name)) return undefined
    const entry = map.get(name)
    if (!entry) return undefined
    if (entry.cached !== undefined) return entry.cached

    const isCircular = this.detectCircularDependency(name)
    if (isCircular) {
      const fileKey = `${(container && container.filePath) || 'unknown'}|${name}`
      if (!this.warnedCircular.has(fileKey)) {
        const message = `circular: ${name}`
        this.circularWarnings.add(message)
        if (this.circularHandler) this.circularHandler(message)
        this.warnedCircular.add(fileKey)
      }
      return undefined
    }

    let value
    try {
      if (entry.kind === 'alias' && entry.alias) {
        value = this.resolveIdentifier(entry.alias, context)
      } else if (entry.kind === 'array') {
        value = parseArrayLiteral(entry.expr, this, context)
      } else if (entry.kind === 'string') {
        value = parseStringLiteral(entry.expr)
      } else if (entry.expr) {
        value = parseExpression(entry.expr, this, context)
      }
    } catch (err) {
      this.warn(`Error al resolver ${name}: ${err.message}`)
      value = undefined
    } finally {
      this.resolutionStack.delete(name)
    }

    if (value !== undefined) {
      entry.cached = value
      this.variables.set(name, value)
    }
    return value
  }
}

function parseSMAEntities(filePath, rawText) {
  const context = { definitions: null, resolver: null, warn: null, currentWarnings: null }
  const fileWarnings = new Set()
  const globalWarnings = new Set()

  const warn = (message) => {
    if (!message) return
    const text = String(message)
    fileWarnings.add(text)
    if (context.currentWarnings) context.currentWarnings.add(text)
    else globalWarnings.add(text)
  }

  const commentless = stripComments(rawText)
  const definitions = collectDefinitions(rawText, commentless, warn)
  definitions.filePath = filePath
  const resolver = new ValueResolver(definitions, warn)
  context.definitions = definitions
  context.resolver = resolver
  context.warn = warn
  resolver.onCircular((message) => warn(message))

  const resources = collectResources(rawText, commentless, context)
  const registerCalls = findRegisterCalls(rawText)
  const versionInfo = detectSmaVersion(filePath, rawText, registerCalls)
  detectUnsupportedRegisterFunctions(rawText, registerCalls, warn)
  const transformationSummary = new Set()

  const fileBase = path.basename(filePath, '.sma')
  const originFile = computeOriginFile(filePath)
  const entitiesByKey = new Map()
  const orderedEntities = []

  for (const call of registerCalls) {
    const lowerName = call.name.toLowerCase()
    const mapping = REGISTER_FUNCTION_MAPPINGS[lowerName]
    if (!mapping) continue

    const normalizedFunction = mapping.normalized
    const callTransformations = new Set()
    let transformationMessage = null
    if (mapping.legacy) {
      transformationMessage = `Sintaxis ${call.name} migrada a ${normalizedFunction} (línea ${call.line})`
    } else if (normalizedFunction && normalizedFunction !== call.name) {
      transformationMessage = `Función ${call.name} → ${normalizedFunction} (línea ${call.line})`
    }
    if (transformationMessage) {
      callTransformations.add(transformationMessage)
      transformationSummary.add(transformationMessage)
    }

    const prefixes = collectPrefixes(call.args)
    call._prefixes = prefixes

    const callWarnings = new Set()
    context.currentWarnings = callWarnings

    const nameInfo = resolveEntityName(call, context, fileBase)
    const rawName = nameInfo.value || call.assignedVar || fileBase
    const cleanName = typeof rawName === 'string' ? rawName.trim() : String(rawName || '')
    const normalizedName = normalizeName(cleanName)
    const { stats, defaultsApplied } = extractStatsForEntity(call, mapping.type, context, prefixes)
    const initialPaths = collectPathsFromArgs(call, mapping.type, context)
    const pathSets = createPathSets(mapping.type, initialPaths)

    const entity = {
      id: '',
      type: mapping.type,
      name: cleanName,
      fileName: fileBase,
      enabled: true,
      source: 'scan',
      stats,
      paths: { models: [], sounds: [], sprites: [] },
      meta: {
        originFile,
        originVersion: versionInfo.version,
        originLabel: versionInfo.label,
        originIsAddon: Boolean(versionInfo.isAddon),
        originBaseVersion: versionInfo.baseVersion,
        migrated: versionInfo.version !== 'zp_5_0_8a',
        registerLine: call.line,
        registerFunction: call.name,
        registerFunctionNormalized: normalizedFunction,
        registerVar: call.assignedVar || undefined,
        displayNameToken: nameInfo.token || undefined,
        warnings: callWarnings,
        transformations: Array.from(callTransformations),
        conflicts: [],
        bundle: fileBase,
        normalizedName,
        extraCalls: [],
        defaultedFields: new Set(defaultsApplied || [])
      },
      _registerIndex: call.index,
      _prefixes: prefixes,
      _pathSets: pathSets
    }

    gatherEntityLookupKeys(entity, call, context)

    context.currentWarnings = null

    const key = `${entity.type}|${normalizedName}`
    const existing = entitiesByKey.get(key)
    if (!existing) {
      entitiesByKey.set(key, entity)
      orderedEntities.push(entity)
    } else {
      const preferred = choosePreferredEntity(existing, entity)
      const other = preferred === existing ? entity : existing
      const preferredWarnings = ensureWarningSet(preferred.meta.warnings)
      const otherWarnings = ensureWarningSet(other.meta.warnings)
      otherWarnings.forEach((w) => preferredWarnings.add(w))
      preferred.meta.warnings = preferredWarnings

      const conflicts = Array.isArray(preferred.meta.conflicts) ? preferred.meta.conflicts : []
      conflicts.push({
        originFile: other.meta?.originFile || preferred.meta?.originFile,
        registerLine: other.meta?.registerLine
      })
      preferred.meta.conflicts = conflicts

      mergeDefaultedFields(preferred, other)

      if (preferred !== existing) {
        entitiesByKey.set(key, preferred)
        const idx = orderedEntities.indexOf(existing)
        if (idx !== -1) orderedEntities[idx] = preferred
      }
    }
  }

  context.currentWarnings = null

  if (!orderedEntities.length && /zp_register_(?:zombie|human|extra|weapon|gamemode)/i.test(rawText)) {
    warn('No se pudieron extraer entidades a pesar de encontrar llamadas de registro.')
  }

  const supplementalCalls = findSupplementalCalls(rawText)
  applySupplementalCalls(supplementalCalls, orderedEntities, context)
  recordDefaultApplications(orderedEntities)

  assignResourcesToEntities(orderedEntities, resources)

  const globalWarningArray = Array.from(globalWarnings)
  for (const entity of orderedEntities) {
    const warningSet = ensureWarningSet(entity.meta.warnings)
    for (const msg of globalWarningArray) warningSet.add(msg)
    entity.meta.warnings = Array.from(warningSet)
    const transformationSet = ensureStringSet(entity.meta.transformations)
    entity.meta.transformations = Array.from(transformationSet)
    for (const message of transformationSet) transformationSummary.add(message)
    if (!Array.isArray(entity.meta.conflicts)) entity.meta.conflicts = []
    const normalizedName = entity.meta.normalizedName || normalizeName(entity.name)
    entity.meta.normalizedName = normalizedName
    entity.id = buildDeterministicId(entity.meta.originFile, entity.type, normalizedName)
    finalizeEntityPaths(entity)
  }

  if ((versionInfo.version && versionInfo.version !== 'zp_5_0_8a') || versionInfo.isAddon) {
    console.info(`[SMA Parser] ${path.basename(filePath)} origen detectado: ${versionInfo.label}`)
  }
  if (transformationSummary.size) {
    console.info(`[SMA Parser] ${path.basename(filePath)} transformaciones:`)
    for (const message of transformationSummary) {
      console.info(`  - ${message}`)
    }
  }

  if (fileWarnings.size) {
    const pref = `[SMA Parser] ${path.basename(filePath)}: `
    for (const message of fileWarnings) {
      console.warn(pref + message)
    }
  }

  return orderedEntities
}

function ensureWarningSet(value) {
  if (value instanceof Set) return value
  return ensureStringSet(value)
}

function ensureStringSet(value) {
  if (value instanceof Set) {
    const cloned = new Set()
    for (const entry of value) {
      if (!entry) continue
      cloned.add(String(entry))
    }
    return cloned
  }
  const set = new Set()
  if (Array.isArray(value)) {
    for (const entry of value) {
      if (!entry) continue
      set.add(String(entry))
    }
  } else if (value) {
    set.add(String(value))
  }
  return set
}

function detectSmaVersion(filePath, rawText, registerCalls) {
  const textLower = typeof rawText === 'string' ? rawText.toLowerCase() : ''
  const fileLower = (filePath ? path.basename(filePath) : '').toLowerCase()
  const looksAddon = /zp_zclass_|zp_hclass_|zp_zombieclass_|zp_zombie_class_|zp_zclass/i.test(fileLower) || /zp_zclass_/i.test(textLower)
  let hasLegacyCall = false
  let hasModernCall = false
  for (const call of registerCalls || []) {
    if (!call || !call.name) continue
    const mapping = REGISTER_FUNCTION_MAPPINGS[call.name.toLowerCase()]
    if (!mapping) continue
    if (mapping.origin === 'zp_4_3') hasLegacyCall = true
    if (mapping.origin === 'zp_5_0_8a') hasModernCall = true
  }
  const includesLegacy = /#include\s*<\s*zombieplague/i.test(textLower)
  const includesModern = /#include\s*<\s*zp50_/i.test(textLower)

  let baseVersion = 'unknown'
  if (hasLegacyCall || includesLegacy) baseVersion = 'zp_4_3'
  else if (hasModernCall || includesModern) baseVersion = 'zp_5_0_8a'

  let version = baseVersion
  if (looksAddon) {
    version = 'external_addon'
  } else if ((hasLegacyCall || includesLegacy) && (hasModernCall || includesModern)) {
    version = 'mixed'
  } else if (version === 'unknown') {
    version = hasModernCall || includesModern ? 'zp_5_0_8a' : (hasLegacyCall || includesLegacy ? 'zp_4_3' : 'unknown')
  }

  const info = VERSION_INFO[version] || VERSION_INFO.unknown
  let label = info.label

  if (version === 'external_addon') {
    const baseLabel = VERSION_INFO[baseVersion]?.label || VERSION_INFO.unknown.label
    label = baseVersion !== 'unknown' ? `${info.label} (${baseLabel})` : info.label
  } else if (version === 'mixed') {
    label = `${info.label} (ZP 4.3 + ZP 5.0.8a)`
  } else if (version === 'unknown' && baseVersion !== 'unknown') {
    label = VERSION_INFO[baseVersion]?.label || label
  }

  if (version === 'unknown') {
    version = 'zp_5_0_8a'
    label = VERSION_INFO[version].label
  }

  const effectiveBase = baseVersion === 'unknown' ? version : baseVersion

  return {
    version,
    baseVersion: effectiveBase,
    label,
    isAddon: looksAddon,
    hasLegacy: hasLegacyCall || includesLegacy,
    hasModern: hasModernCall || includesModern
  }
}

function detectUnsupportedRegisterFunctions(rawText, registerCalls, warn) {
  if (typeof rawText !== 'string') return
  const seen = new Set()
  const recognized = new Set((registerCalls || []).map(c => (c && c.name ? c.name.toLowerCase() : '')))
  const regex = /\bzp_register_(?:class|zombie|human)[A-Za-z0-9_]*/gi
  let match
  while ((match = regex.exec(rawText)) !== null) {
    const lower = match[0].toLowerCase()
    if (REGISTER_FUNCTION_SET.has(lower) || recognized.has(lower) || seen.has(lower)) continue
    warn(`Función de registro no soportada detectada: ${match[0]}`)
    seen.add(lower)
  }
}

function computeOriginFile(filePath) {
  const inputRoot = path.join(process.cwd(), 'input')
  let relative = path.relative(inputRoot, filePath)
  if (!relative || relative.startsWith('..')) {
    relative = path.basename(filePath)
  }
  const normalized = normalizePath(relative)
  return normalized || relative.replace(/\\/g, '/').trim()
}

function normalizeName(name) {
  if (!name) return ''
  const trimmed = String(name).trim().toLowerCase()
  return trimmed.replace(/\s+/g, ' ')
}

function buildDeterministicId(originFile, type, normalizedName) {
  const hash = crypto.createHash('sha1')
  hash.update(`${originFile || ''}|${type || ''}|${normalizedName || ''}`)
  return hash.digest('hex')
}

function stripComments(text) {
  let result = ''
  let inBlock = false
  let inLine = false
  let inString = null
  let escape = false
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    const next = text[i + 1]
    if (inBlock) {
      if (ch === '*' && next === '/') {
        inBlock = false
        i++
      }
      continue
    }
    if (inLine) {
      if (ch === '\n') {
        inLine = false
        result += ch
      }
      continue
    }
    if (inString) {
      result += ch
      if (escape) {
        escape = false
      } else if (ch === '\\') {
        escape = true
      } else if (ch === inString) {
        inString = null
      }
      continue
    }
    if (ch === '/' && next === '*') {
      inBlock = true
      i++
      continue
    }
    if (ch === '/' && next === '/') {
      inLine = true
      i++
      continue
    }
    if (ch === '"' || ch === '\'') {
      inString = ch
      result += ch
      continue
    }
    result += ch
  }
  return result
}

function collectDefinitions(rawText, commentless, warn) {
  const definitions = new Map()
  const defEntries = []

  const defineRegex = /^#define\s+(\w+)\s+(.+)$/
  const lines = commentless.split(/\r?\n/)
  for (const line of lines) {
    const trimmed = line.trim()
    if (!trimmed.startsWith('#define')) continue
    const match = trimmed.match(defineRegex)
    if (!match) continue
    const [, name, expr] = match
    setDefinition(definitions, defEntries, name, expr.trim(), 'define')
  }

  const statements = splitStatements(commentless)
  for (const statement of statements) {
    const trimmed = statement.trim()
    if (!trimmed) continue

    const regMatch = trimmed.match(/(\w+)\s*=\s*register_cvar\s*\(([^)]*)\)/i)
    if (regMatch) {
      const [, name, inside] = regMatch
      const parts = parseArguments(inside)
      const valueExpr = parts[1] || ''
      setDefinition(definitions, defEntries, name, valueExpr.trim(), 'register_cvar')
      continue
    }

    const setPcvarMatch = trimmed.match(/set_pcvar_(?:num|float)\s*\(([^,]+),(.+)\)/i)
    if (setPcvarMatch) {
      const name = extractIdentifier(setPcvarMatch[1])
      const expr = setPcvarMatch[2].replace(/\);?$/, '').trim()
      if (name) setDefinition(definitions, defEntries, name, expr, 'set_pcvar')
      continue
    }

    const eqIndex = trimmed.indexOf('=')
    if (eqIndex === -1) continue
    const lhs = trimmed.slice(0, eqIndex).trim()
    let rhs = trimmed.slice(eqIndex + 1).trim()
    if (rhs.endsWith(';')) rhs = rhs.slice(0, -1)
    const name = extractIdentifier(lhs)
    if (!name) continue

    const pcvarCall = rhs.match(/get_pcvar_(?:num|float)\s*\(([^)]+)\)/i)
    if (pcvarCall) {
      const referenced = extractIdentifier(pcvarCall[1])
      if (referenced && definitions.has(referenced)) {
        setAliasDefinition(definitions, defEntries, name, referenced)
        continue
      }
    }

    setDefinition(definitions, defEntries, name, rhs.trim(), 'assignment')
  }

  return { definitions, entries: defEntries }
}

function collectResources(rawText, commentless, context) {
  const resources = []
  const resolver = context && context.resolver
  const warn = context && typeof context.warn === 'function' ? context.warn : () => {}
  const regex = /precache_(model|sound|generic)\s*\(/gi
  let match
  while ((match = regex.exec(commentless)) !== null) {
    const func = match[1].toLowerCase()
    const start = regex.lastIndex - 1
    const extracted = extractCall(commentless, start)
    if (!extracted) {
      warn(`No se pudieron leer los argumentos de precache_${func}`)
      continue
    }
    const args = parseArguments(extracted.args)
    if (!args.length) continue
    const value = resolver ? resolver.resolveValue(args[0], 'resource') : undefined
    const strings = flattenStringValues(value)
    for (const s of strings) {
      if (!s) continue
      resources.push({
        type: func,
        value: s,
        index: match.index
      })
    }
  }
  return resources
}

function findRegisterCalls(rawText) {
  return findCalls(rawText, REGISTER_FUNCTIONS)
}

function findCalls(rawText, functionNames) {
  if (!Array.isArray(functionNames) || functionNames.length === 0) return []
  const pat = '\\b(' + functionNames.map(esc).join('|') + ')\\s*\\('
  const regex = new RegExp(pat, 'gi')
  const calls = []
  let match
  while ((match = regex.exec(rawText)) !== null) {
    const name = match[1]
    const start = regex.lastIndex - 1
    const extracted = extractCall(rawText, start)
    if (!extracted) continue
    const args = parseArguments(extracted.args)
    const line = rawText.slice(0, match.index).split(/\r?\n/).length
    const assignedVar = detectAssignedVariable(rawText, match.index)
    calls.push({ name, args, index: match.index, line, assignedVar })
  }
  return calls
}

function detectAssignedVariable(text, callIndex) {
  const before = text.slice(0, callIndex)
  const lastSemicolon = before.lastIndexOf(';')
  const lastNewline = before.lastIndexOf('\n')
  const start = Math.max(lastSemicolon, lastNewline)
  const snippet = before.slice(start + 1).trim()
  if (!snippet) return null
  const match = snippet.match(/([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*=\s*$/)
  return match ? match[1] : null
}

const SUPPLEMENTAL_HANDLERS = {
  zp_class_zombie_register_kb: { kind: 'stat', field: 'knockback' },
  zp_class_zombie_register_model: { kind: 'models' },
  zp_class_human_register_model: { kind: 'models' }
}

function findSupplementalCalls(rawText) {
  return findCalls(rawText, SUPPLEMENTAL_FUNCTIONS)
}

function applySupplementalCalls(calls, entities, context) {
  if (!Array.isArray(calls) || !calls.length) return
  if (!Array.isArray(entities) || !entities.length) return

  const resolver = context && context.resolver
  const warn = context && typeof context.warn === 'function' ? context.warn : () => {}
  const registryByVar = new Map()
  const registryByName = new Map()
  const registryByKey = new Map()

  for (const entity of entities) {
    if (!entity || !entity.meta) continue
    const varName = entity.meta.registerVar
    if (varName) registryByVar.set(varName.toLowerCase(), entity)
    const normalizedName = entity.meta.normalizedName || normalizeName(entity.name)
    if (normalizedName) registryByName.set(normalizedName.toLowerCase(), entity)
    const keys = Array.isArray(entity.meta.lookupKeys) ? entity.meta.lookupKeys : []
    for (const key of keys) {
      if (!key) continue
      const lower = key.toLowerCase()
      if (!registryByKey.has(lower)) registryByKey.set(lower, [])
      const list = registryByKey.get(lower)
      if (!list.includes(entity)) list.push(entity)
    }
  }

  for (const call of calls) {
    const handler = SUPPLEMENTAL_HANDLERS[call.name.toLowerCase()]
    if (!handler || !call.args.length) continue

    const firstArg = call.args[0]
    const ident = extractIdentifier(firstArg)
    const candidateKeys = []
    const seenCandidates = new Set()
    const addCandidate = (value) => {
      const normalized = normalizeLookupKey(value)
      if (normalized && !seenCandidates.has(normalized)) {
        candidateKeys.push(normalized)
        seenCandidates.add(normalized)
      }
      const normalizedName = normalizeLookupName(value)
      if (normalizedName && !seenCandidates.has(normalizedName)) {
        candidateKeys.push(normalizedName)
        seenCandidates.add(normalizedName)
      }
    }

    if (ident) addCandidate(ident)
    if (firstArg !== undefined) addCandidate(firstArg)
    if (resolver && firstArg !== undefined) {
      const resolved = resolver.resolveValue(firstArg, 'supplemental.lookup')
      const resolvedCandidates = flattenStringValues(resolved)
      for (const candidate of resolvedCandidates) addCandidate(candidate)
    }

    let entity = null

    if (ident) {
      const lowerIdent = ident.toLowerCase()
      if (registryByVar.has(lowerIdent)) entity = registryByVar.get(lowerIdent)
    }

    if (!entity) {
      for (const key of candidateKeys) {
        const matches = registryByKey.get(key)
        if (matches && matches.length) {
          entity = matches[0]
          break
        }
      }
    }

    if (!entity) {
      for (const key of candidateKeys) {
        if (registryByName.has(key)) {
          entity = registryByName.get(key)
          break
        }
      }
    }

    if (!entity) {
      const lineInfo = call.line !== undefined ? call.line : '?'
      const warningMessage = `No se encontró entidad base para ${call.name} en línea ${lineInfo}.`
      warn(warningMessage)
      logSupplementalWarning(warningMessage)
      continue
    }

    if (!entity.stats) entity.stats = {}
    const warningSet = ensureWarningSet(entity.meta.warnings)
    entity.meta.warnings = warningSet
    context.currentWarnings = warningSet

    if (!Array.isArray(entity.meta.extraCalls)) entity.meta.extraCalls = []
    const record = { name: call.name, params: {} }

    if (handler.kind === 'stat') {
      const expr = call.args[1]
      let resolved = expr && resolver ? resolver.resolveValue(expr, `${entity.type}.${handler.field}`) : undefined
      let numeric = toNumber(resolved)
      if (numeric === undefined && expr !== undefined) {
        const literal = resolveLiteralValue(expr, resolver, `${entity.type}.${handler.field}`)
        if (literal !== undefined) {
          resolved = literal
          numeric = toNumber(literal)
        }
      }
      let associated = false
      if (numeric === undefined) {
        warn(`No se pudo resolver ${handler.field} adicional (${call.name} línea ${call.line})`)
        const fallback = entity.stats && entity.stats[handler.field] !== undefined ? entity.stats[handler.field] : DEFAULT_VALUES[entity.type]?.[handler.field]
        if (fallback !== undefined && entity.stats) {
          entity.stats[handler.field] = fallback
          record.params[handler.field] = fallback
        }
      } else {
        entity.stats[handler.field] = numeric
        record.params[handler.field] = numeric
        associated = true
        if (entity.meta && entity.meta.defaultedFields instanceof Set) {
          entity.meta.defaultedFields.delete(handler.field)
        }
      }
      if (associated) {
        const displayName = formatEntityDisplayName(entity)
        logSupplementalInfo(`Asociado ${handler.field} adicional a ${entity.type} '${displayName}'.`)
      }
    } else if (handler.kind === 'models') {
      const expr = call.args[1]
      const addedModels = createResourceCollector()
      if (!expr) {
        warn(`No se pudo resolver modelo adicional (${call.name} línea ${call.line})`)
      } else {
        const resolved = resolver ? resolver.resolveValue(expr, 'paths') : undefined
        const strings = flattenStringValues(resolved)
        if (!strings.length) {
          warn(`No se pudo resolver modelo adicional (${call.name} línea ${call.line})`)
        }
        for (const value of strings) {
          addResourceToEntity(entity, 'models', value)
          addResourceValue(addedModels, value)
        }
      }
      record.params.models = addedModels.values.slice()
      if (addedModels.values.length) {
        const displayName = formatEntityDisplayName(entity)
        logSupplementalInfo(`Asociado modelo adicional a ${entity.type} '${displayName}'.`)
      }
    }

    entity.meta.extraCalls.push(record)
    context.currentWarnings = null
  }
  context.currentWarnings = null
}

function recordDefaultApplications(entities) {
  if (!Array.isArray(entities)) return
  for (const entity of entities) {
    if (!entity || !entity.meta) continue
    const defaults = entity.meta.defaultedFields
    if (!(defaults instanceof Set)) {
      if (defaults !== undefined) delete entity.meta.defaultedFields
      continue
    }
    if (defaults.size === 0) {
      delete entity.meta.defaultedFields
      continue
    }
    const fields = Array.from(defaults)
    if (!Array.isArray(entity.meta.extraCalls)) entity.meta.extraCalls = []
    const alreadyRecorded = entity.meta.extraCalls.some(call => call && call.name === 'zp_5_0_8a_defaults')
    if (!alreadyRecorded) {
      entity.meta.extraCalls.push({ name: 'zp_5_0_8a_defaults', params: { fields } })
    }
    delete entity.meta.defaultedFields
  }
}

function mergeDefaultedFields(target, source) {
  if (!target || !target.meta) return
  if (!(target.meta.defaultedFields instanceof Set)) {
    target.meta.defaultedFields = new Set()
  }
  if (!source || !source.meta || !(source.meta.defaultedFields instanceof Set)) return
  for (const field of source.meta.defaultedFields) {
    target.meta.defaultedFields.add(field)
  }
}

function logSupplementalInfo(message) {
  if (!message) return
  console.info(message)
}

function logSupplementalWarning(message) {
  if (!message) return
  console.warn(message)
}

function extractCall(text, startIndex) {
  let depth = 1
  let i = startIndex + 1
  let inString = null
  let escape = false
  for (; i < text.length; i++) {
    const ch = text[i]
    if (inString) {
      if (escape) {
        escape = false
      } else if (ch === '\\') {
        escape = true
      } else if (ch === inString) {
        inString = null
      }
      continue
    }
    if (ch === '"' || ch === '\'') {
      inString = ch
      continue
    }
    if (ch === '(') depth++
    else if (ch === ')') {
      depth--
      if (depth === 0) {
        const args = text.slice(startIndex + 1, i)
        return { args, end: i + 1 }
      }
    }
  }
  return null
}

function parseArguments(argsText) {
  const args = []
  let current = ''
  let depthParen = 0
  let depthBrace = 0
  let depthBracket = 0
  let inString = null
  let escape = false
  for (let i = 0; i < argsText.length; i++) {
    const ch = argsText[i]
    if (inString) {
      current += ch
      if (escape) {
        escape = false
      } else if (ch === '\\') {
        escape = true
      } else if (ch === inString) {
        inString = null
      }
      continue
    }
    if (ch === '"' || ch === '\'') {
      inString = ch
      current += ch
      continue
    }
    if (ch === '(') depthParen++
    else if (ch === ')') depthParen--
    else if (ch === '{') depthBrace++
    else if (ch === '}') depthBrace--
    else if (ch === '[') depthBracket++
    else if (ch === ']') depthBracket--
    if (ch === ',' && depthParen === 0 && depthBrace === 0 && depthBracket === 0) {
      args.push(current.trim())
      current = ''
      continue
    }
    current += ch
  }
  if (current.trim()) args.push(current.trim())
  return args
}

function splitStatements(text) {
  const statements = []
  let current = ''
  let depthParen = 0
  let depthBrace = 0
  let depthBracket = 0
  let inString = null
  let escape = false
  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    current += ch
    if (inString) {
      if (escape) {
        escape = false
      } else if (ch === '\\') {
        escape = true
      } else if (ch === inString) {
        inString = null
      }
      continue
    }
    if (ch === '"' || ch === '\'') {
      inString = ch
      continue
    }
    if (ch === '(') depthParen++
    else if (ch === ')') depthParen--
    else if (ch === '{') depthBrace++
    else if (ch === '}') depthBrace--
    else if (ch === '[') depthBracket++
    else if (ch === ']') depthBracket--
    if (ch === ';' && depthParen === 0 && depthBrace === 0 && depthBracket === 0) {
      statements.push(current)
      current = ''
    }
  }
  if (current.trim()) statements.push(current)
  return statements
}

function extractIdentifier(text) {
  if (!text) return null
  let cleaned = text.replace(/\b(?:new|static|stock|const|enum|Float|bool|char|String|Handle)\b/gi, ' ')
  cleaned = cleaned.replace(/\b(?:Float|bool|char|String|Handle|any|Task|Array|_:)[A-Za-z0-9_]*:/g, ' ')
  cleaned = cleaned.replace(/\[[^\]]*\]/g, ' ')
  cleaned = cleaned.replace(/[*&]/g, ' ')
  const parts = cleaned.trim().split(/\s+/)
  return parts.length ? parts[parts.length - 1] : null
}

function setDefinition(map, entries, name, expr, source) {
  const entry = {
    name,
    expr: expr.trim(),
    source,
    kind: detectKind(expr),
    cached: undefined,
    alias: undefined,
    tokens: identifierTokens(name)
  }
  map.set(name, entry)
  entries.push(entry)
}

function setAliasDefinition(map, entries, name, target) {
  const entry = {
    name,
    expr: target,
    source: 'alias',
    kind: 'alias',
    cached: undefined,
    alias: target,
    tokens: identifierTokens(name)
  }
  map.set(name, entry)
  entries.push(entry)
}

function detectKind(expr) {
  const trimmed = expr.trim()
  if (trimmed.startsWith('{')) return 'array'
  if (/^".*"$/.test(trimmed) || /^'.*'$/.test(trimmed)) return 'string'
  if (/^[+-]?(?:0x[0-9a-f]+|\d+\.\d+|\d+)$/.test(trimmed)) return 'number'
  return 'expr'
}

function parseExpression(expression, resolver, context) {
  if (!expression || typeof expression !== 'string') return undefined
  const trimmed = expression.trim()
  if (!trimmed) return undefined

  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    return parseArrayLiteral(trimmed, resolver, context)
  }

  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith('\'') && trimmed.endsWith('\''))) {
    const parsed = parseStringLiteral(trimmed)
    if (trimmed.startsWith('\'') && trimmed.endsWith('\'') && parsed.length === 1) {
      return parsed.charCodeAt(0)
    }
    return parsed
  }

  const tagMatch = trimmed.match(/^(?:Float|_:Float|_:float|float|bool|Bool|_:bool|_:Bool):(.+)$/)
  if (tagMatch) {
    return parseExpression(tagMatch[1], resolver, context)
  }

  if (/^[-+]?0x[0-9a-f]+$/i.test(trimmed)) return parseInt(trimmed, 16)
  if (/^[-+]?\d+\.\d+(?:e[-+]?\d+)?$/i.test(trimmed)) return parseFloat(trimmed)
  if (/^[-+]?\d+$/.test(trimmed)) return parseInt(trimmed, 10)

  if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
    const inner = trimmed.slice(1, -1)
    const innerResolved = parseExpression(inner, resolver, context)
    if (innerResolved !== undefined) return innerResolved
  }

  const newMatch = trimmed.match(/^new\s+[A-Za-z_]\w*\s*\((.*)\)$/i)
  if (newMatch) {
    const argsText = newMatch[1]
    const args = parseArguments(argsText)
    if (args.length) {
      const firstArg = args[0]
      if (resolver) {
        const resolved = resolver.resolveValue(firstArg, context)
        const numeric = toNumber(resolved)
        if (numeric !== undefined) return numeric
      }
      const literal = resolveLiteralValue(firstArg, resolver, context)
      if (literal !== undefined) return literal
      return parseExpression(firstArg, resolver, context)
    }
    return undefined
  }

  const numericWrapMatch = trimmed.match(/^(float|_:float)\s*\((.*)\)$/i)
  if (numericWrapMatch) {
    const inner = parseExpression(numericWrapMatch[2], resolver, context)
    return inner !== undefined ? Number(inner) : undefined
  }

  const viewAsMatch = trimmed.match(/^view_as<[^>]+>\s*\((.+)\)$/i)
  if (viewAsMatch) {
    return parseExpression(viewAsMatch[1], resolver, context)
  }

  const pcvarMatch = trimmed.match(/^get_pcvar_(?:num|float)\s*\((.+)\)$/i)
  if (pcvarMatch) {
    const args = parseArguments(pcvarMatch[1])
    const firstArg = args.length ? args[0] : null
    const ident = firstArg ? extractIdentifier(firstArg) : null
    if (ident && resolver) {
      const value = resolver.resolveIdentifier(ident, context)
      if (value !== undefined) return value
    }
    return undefined
  }

  const accessMatch = trimmed.match(/^([A-Za-z_]\w*)(\[[^\]]+\])+$/)
  if (accessMatch) {
    const baseName = accessMatch[1]
    const indexRegex = /\[([^\]]+)\]/g
    let baseValue = resolver ? resolver.resolveIdentifier(baseName, context) : undefined
    if (baseValue === undefined) return undefined
    let match
    while ((match = indexRegex.exec(trimmed)) !== null) {
      if (!Array.isArray(baseValue)) return undefined
      const idx = parseExpression(match[1], resolver, context)
      if (idx === undefined) return undefined
      baseValue = baseValue[idx]
    }
    return baseValue
  }

  if (/^[A-Za-z_]\w*$/.test(trimmed)) {
    return resolver ? resolver.resolveIdentifier(trimmed, context) : undefined
  }

  const sanitized = trimmed.replace(/\b([A-Za-z_]\w*)\b/g, (match) => {
    if (!resolver) return match
    const val = resolver.resolveIdentifier(match, context)
    if (val === undefined) return match
    const num = Number(val)
    return Number.isNaN(num) ? match : num
  })

  if (/^[0-9+\-*/%().<>=!&|^~\s]+$/.test(sanitized)) {
    try {
      // eslint-disable-next-line no-new-func
      const fn = new Function(`return (${sanitized})`)
      return fn()
    } catch (err) {
      if (resolver && resolver.warn) resolver.warn(`No se pudo evaluar la expresión: ${trimmed}`)
      return undefined
    }
  }

  return undefined
}

function parseStringLiteral(lit) {
  if (!lit) return ''
  const quote = lit[0]
  let str = ''
  for (let i = 1; i < lit.length - 1; i++) {
    const ch = lit[i]
    if (ch === '\\' && i + 1 < lit.length - 1) {
      const next = lit[i + 1]
      if (next === 'n') str += '\n'
      else if (next === 't') str += '\t'
      else str += next
      i++
    } else {
      str += ch
    }
  }
  return str
}

function parseArrayLiteral(expr, resolver, context) {
  const content = expr.slice(1, -1)
  const parts = parseArguments(content)
  const values = []
  for (const part of parts) {
    if (!resolver) values.push(undefined)
    else values.push(resolver.resolveValue(part, context))
  }
  return values
}

function flattenStringValues(value) {
  if (value === undefined || value === null) return []
  if (Array.isArray(value)) {
    const result = []
    for (const v of value) result.push(...flattenStringValues(v))
    return result
  }
  if (typeof value === 'string') return [value]
  if (typeof value === 'number') return [String(value)]
  return []
}

function collectPrefixes(args) {
  const prefixes = new Set()
  for (const arg of args) {
    const ident = extractIdentifier(arg)
    if (!ident) continue
    const parts = ident.split('_')
    if (parts.length > 1) prefixes.add(parts[0].toLowerCase())
    prefixes.add(ident.toLowerCase())
  }
  return prefixes
}

function normalizeLookupKey(value) {
  if (value === undefined || value === null) return null
  let str = String(value).trim()
  if (!str) return null
  if ((str.startsWith('"') && str.endsWith('"')) || (str.startsWith('\'') && str.endsWith('\''))) {
    str = str.slice(1, -1).trim()
    if (!str) return null
  }
  return str.toLowerCase()
}

function normalizeLookupName(value) {
  if (value === undefined || value === null) return null
  let str = String(value).trim()
  if (!str) return null
  if ((str.startsWith('"') && str.endsWith('"')) || (str.startsWith('\'') && str.endsWith('\''))) {
    str = str.slice(1, -1).trim()
    if (!str) return null
  }
  const normalized = normalizeName(str)
  return normalized ? normalized.toLowerCase() : null
}

function gatherEntityLookupKeys(entity, call, context) {
  if (!entity || !entity.meta) return
  const keys = new Set(Array.isArray(entity.meta.lookupKeys) ? entity.meta.lookupKeys : [])
  const pushKey = (value) => {
    const normalized = normalizeLookupKey(value)
    if (normalized) keys.add(normalized)
    const normalizedName = normalizeLookupName(value)
    if (normalizedName) keys.add(normalizedName)
  }

  pushKey(entity.meta.registerVar)
  pushKey(entity.meta.displayNameToken)
  pushKey(entity.meta.normalizedName || entity.name)
  pushKey(entity.name)

  const args = call && Array.isArray(call.args) ? call.args : []
  if (args.length) {
    const firstArg = args[0]
    const ident = extractIdentifier(firstArg)
    if (ident) pushKey(ident)
    if (firstArg !== undefined) pushKey(firstArg)
    if (context && context.resolver && firstArg !== undefined) {
      const resolved = context.resolver.resolveValue(firstArg, 'register.identifier')
      const values = flattenStringValues(resolved)
      for (const value of values) pushKey(value)
    }
  }

  entity.meta.lookupKeys = Array.from(keys)
}

function formatEntityDisplayName(entity) {
  if (!entity) return '?'
  if (entity.name !== undefined && entity.name !== null) {
    const raw = String(entity.name).trim()
    if (raw) return raw
  }
  const normalized = entity.meta && entity.meta.normalizedName ? String(entity.meta.normalizedName).trim() : ''
  if (normalized) return normalized
  const varName = entity.meta && entity.meta.registerVar ? String(entity.meta.registerVar).trim() : ''
  if (varName) return varName
  return '?'
}

function resolveEntityName(call, context, fallback) {
  const resolver = context && context.resolver
  for (const arg of call.args) {
    const ident = extractIdentifier(arg)
    if (ident && HARDCODED_CONSTANTS[ident] !== undefined) {
      return { value: HARDCODED_CONSTANTS[ident], token: ident }
    }
  }
  for (const arg of call.args) {
    const trimmed = typeof arg === 'string' ? arg.trim() : ''
    if (/^[A-Za-z_]\w*$/.test(trimmed)) {
      const resolved = resolver ? resolver.resolveValue(trimmed, 'name') : undefined
      const strings = flattenStringValues(resolved)
      const str = strings.find(Boolean)
      if (typeof str === 'string' && str.length) return { value: str, token: trimmed }
    }
    const value = resolver ? resolver.resolveValue(arg, 'name') : undefined
    const strings = flattenStringValues(value)
    const str = strings.find(Boolean)
    if (typeof str === 'string' && str.length) return { value: str, token: undefined }
  }
  return { value: fallback, token: undefined }
}

function collectPathsFromArgs(call, type, context) {
  const models = createResourceCollector()
  const sounds = createResourceCollector()
  const sprites = createResourceCollector()
  const resolver = context && context.resolver
  for (const arg of call.args) {
    const value = resolver ? resolver.resolveValue(arg, 'paths') : undefined
    const strings = flattenStringValues(value)
    for (const s of strings) {
      categorizeResourcePath(type, s, models, sounds, sprites)
    }
  }
  return {
    models: models.values.slice(),
    sounds: sounds.values.slice(),
    sprites: sprites.values.slice()
  }
}

function categorizeResourcePath(type, value, models, sounds, sprites) {
  if (!value || typeof value !== 'string') return
  if (type === 'mode') return
  const normalized = normalizePath(value)
  if (!normalized) return
  const lower = normalized.toLowerCase()
  const ext = path.extname(lower)
  if (!ext) return
  if (RESOURCE_EXTENSIONS.models.includes(ext)) {
    if (isResourceAllowedForType(type, 'models')) addResourceValue(models, normalized)
  } else if (RESOURCE_EXTENSIONS.sounds.includes(ext)) {
    if (!CLASS_TYPES.has(type) && isResourceAllowedForType(type, 'sounds')) addResourceValue(sounds, normalized)
  } else if (RESOURCE_EXTENSIONS.sprites.includes(ext)) {
    if (!CLASS_TYPES.has(type) && isResourceAllowedForType(type, 'sprites')) addResourceValue(sprites, normalized)
  }
}

function createResourceCollector() {
  return { values: [], seen: new Set() }
}

function addResourceValue(collector, value) {
  if (!collector) return
  const normalized = normalizePath(value)
  if (!normalized) return
  const key = normalized.toLowerCase()
  if (collector.seen.has(key)) return
  collector.seen.add(key)
  collector.values.push(normalized)
}

function assignResourcesToEntities(entities, resources) {
  if (!entities.length) return
  for (const res of resources) {
    const normalizedValue = normalizePath(res.value)
    if (!normalizedValue) continue
    const ext = path.extname(normalizedValue.toLowerCase())
    if (!ext) continue

    let chosen = null
    let bestScore = -Infinity
    let bestDistance = Infinity

    for (const entity of entities) {
      const kind = extensionToKind(ext)
      if (!kind || !isResourceAllowedForType(entity.type, kind)) continue

      const prefixes = entity._prefixes || new Set()
      const lowerValue = normalizedValue.toLowerCase()
      let score = 0
      for (const prefix of prefixes) {
        if (!prefix) continue
        if (lowerValue.includes(prefix)) score += 2
      }
      let distance = Infinity
      if (res.index >= entity._registerIndex) {
        distance = res.index - entity._registerIndex
      }
      if (score > bestScore || (score === bestScore && distance < bestDistance)) {
        chosen = entity
        bestScore = score
        bestDistance = distance
      }
    }

    if (!chosen) {
      chosen = entities.reduce((acc, entity) => {
        const distance = res.index >= entity._registerIndex ? res.index - entity._registerIndex : Infinity
        if (!acc) return entity
        const accDistance = res.index >= acc._registerIndex ? res.index - acc._registerIndex : Infinity
        return distance < accDistance ? entity : acc
      }, null) || entities[0]
    }

    const kind = extensionToKind(ext)
    if (!kind) continue
    addResourceToEntity(chosen, kind, normalizedValue)
  }

  for (const entity of entities) {
    delete entity._registerIndex
    delete entity._prefixes
  }
}

function extensionToKind(ext) {
  const lower = ext.toLowerCase()
  if (RESOURCE_EXTENSIONS.models.includes(lower)) return 'models'
  if (RESOURCE_EXTENSIONS.sounds.includes(lower)) return 'sounds'
  if (RESOURCE_EXTENSIONS.sprites.includes(lower)) return 'sprites'
  return null
}

function isResourceAllowedForType(type, kind) {
  if (type === 'mode') return false
  if (CLASS_TYPES.has(type)) return kind === 'models'
  return true
}

function createPathSets(type, initial) {
  const sets = {
    models: createResourceCollector(),
    sounds: createResourceCollector(),
    sprites: createResourceCollector()
  }
  if (initial) {
    if (Array.isArray(initial.models) && isResourceAllowedForType(type, 'models')) {
      for (const value of initial.models) addResourceValue(sets.models, value)
    }
    if (Array.isArray(initial.sounds) && isResourceAllowedForType(type, 'sounds')) {
      for (const value of initial.sounds) addResourceValue(sets.sounds, value)
    }
    if (Array.isArray(initial.sprites) && isResourceAllowedForType(type, 'sprites')) {
      for (const value of initial.sprites) addResourceValue(sets.sprites, value)
    }
  }
  return sets
}

function addResourceToEntity(entity, kind, value) {
  if (!isResourceAllowedForType(entity.type, kind)) return
  if (!entity._pathSets) {
    entity._pathSets = createPathSets(entity.type, entity.paths || { models: [], sounds: [], sprites: [] })
  }
  addResourceValue(entity._pathSets[kind], value)
}

function finalizeEntityPaths(entity) {
  const sets = entity._pathSets || createPathSets(entity.type, entity.paths)
  const paths = { models: [], sounds: [], sprites: [] }
  if (isResourceAllowedForType(entity.type, 'models')) paths.models = sets.models.values.slice()
  if (isResourceAllowedForType(entity.type, 'sounds')) paths.sounds = sets.sounds.values.slice()
  if (isResourceAllowedForType(entity.type, 'sprites')) paths.sprites = sets.sprites.values.slice()
  entity.paths = paths
  delete entity._pathSets
}

function choosePreferredEntity(a, b) {
  const scoreA = scoreEntity(a)
  const scoreB = scoreEntity(b)
  if (scoreB > scoreA) return b
  return a
}

function scoreEntity(entity) {
  let score = 0
  const stats = entity.stats || {}
  for (const value of Object.values(stats)) {
    if (value !== undefined && value !== null) score += 1
  }
  const sets = entity._pathSets || createPathSets(entity.type, entity.paths)
  score += sets.models.values.length + sets.sounds.values.length + sets.sprites.values.length
  return score
}

function extractStatsForEntity(call, type, context, prefixes) {
  const stats = {}
  const defaultsApplied = new Set()
  const fields = TYPE_STAT_FIELDS[type] || []
  for (const field of fields) stats[field] = undefined

  const positional = TYPE_FIELD_POSITIONS[type] || {}
  const definitionEntries = context.definitions.entries
  const resolver = context.resolver
  const warn = context.warn
  for (const field of fields) {
    const keywords = STAT_KEYWORDS[field] || [field]
    const contextKey = `${type}.${field}`
    let resolved
    let positionalArgValue

    const positionIndex = positional[field]
    if (positionIndex !== undefined) {
      positionalArgValue = call.args[positionIndex]
      if (positionalArgValue !== undefined) {
        resolved = resolver ? resolver.resolveValue(positionalArgValue, contextKey) : positionalArgValue
      }
    }

    if (resolved === undefined && positionalArgValue !== undefined) {
      const literal = resolveLiteralValue(positionalArgValue, resolver, contextKey)
      if (literal !== undefined) resolved = literal
    }

    // Search within call arguments first
    if (resolved === undefined) {
      for (const arg of call.args) {
        const ident = extractIdentifier(arg)
        if (!ident) continue
        const tokens = identifierTokens(ident)
        if (tokens.some(t => keywords.includes(t))) {
          resolved = resolver ? resolver.resolveValue(arg, contextKey) : undefined
          if (resolved === undefined) {
            const literal = resolveLiteralValue(arg, resolver, contextKey)
            if (literal !== undefined) resolved = literal
          }
          if (resolved !== undefined) break
        }
      }
    }

    if (resolved === undefined) {
      resolved = findValueInDefinitions(definitionEntries, keywords, prefixes, context)
    }

    if (resolved === undefined) {
      const hasDefault = DEFAULT_VALUES[type] && DEFAULT_VALUES[type][field] !== undefined
      if (!hasDefault && warn) {
        warn(`No se pudo resolver el valor de ${field} en ${call.name} (línea ${call.line})`)
      }
    }

    let numeric = toNumber(resolved)
    if (numeric === undefined && resolved !== undefined && typeof resolved === 'string') {
      const literal = resolveLiteralValue(resolved, resolver, contextKey)
      numeric = toNumber(literal)
    }

    if (numeric === undefined && DEFAULT_VALUES[type] && DEFAULT_VALUES[type][field] !== undefined) {
      numeric = DEFAULT_VALUES[type][field]
      defaultsApplied.add(field)
    }

    stats[field] = numeric
  }
  return { stats, defaultsApplied: Array.from(defaultsApplied) }
}

function findValueInDefinitions(entries, keywords, prefixes, context) {
  const prefixList = Array.from(prefixes || [])
  const lowerPrefixes = prefixList.map(p => p.toLowerCase())

  const resolver = context && context.resolver
  const tryResolve = (entry) => resolver ? resolver.resolveIdentifier(entry.name) : undefined

  for (const prefix of lowerPrefixes) {
    for (const keyword of keywords) {
      const lowerKeyword = keyword.toLowerCase()
      for (const entry of entries) {
        if (!entry.tokens.includes(lowerKeyword)) continue
        if (prefix && !entry.tokens.some(t => t === prefix || t.startsWith(prefix))) continue
        const value = tryResolve(entry)
        if (value !== undefined) return value
      }
    }
  }

  for (const keyword of keywords) {
    const lowerKeyword = keyword.toLowerCase()
    for (const entry of entries) {
      if (!entry.tokens.includes(lowerKeyword)) continue
      const value = tryResolve(entry)
      if (value !== undefined) return value
    }
  }

  return undefined
}

function identifierTokens(name) {
  if (!name) return []
  const withUnderscore = name.replace(/([a-z])([A-Z])/g, '$1_$2')
  return withUnderscore.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean)
}

function toNumber(value) {
  if (value === undefined || value === null) return undefined
  if (typeof value === 'number') return value
  if (typeof value === 'boolean') return value ? 1 : 0
  if (typeof value === 'string' && value.trim() !== '') {
    const num = Number(value)
    return Number.isNaN(num) ? undefined : num
  }
  return undefined
}

function resolveLiteralValue(expr, resolver, context) {
  if (expr === undefined || expr === null) return undefined
  if (typeof expr !== 'string') return toNumber(expr)
  let trimmed = expr.trim()
  if (!trimmed) return undefined

  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith('\'') && trimmed.endsWith('\''))) {
    return undefined
  }

  if (resolver) {
    const resolved = resolver.resolveValue(trimmed, context)
    const numericResolved = toNumber(resolved)
    if (numericResolved !== undefined) return numericResolved
    if (typeof resolved === 'string' && resolved !== trimmed) {
      const nested = resolveLiteralValue(resolved, resolver, context)
      if (nested !== undefined) return nested
    }
  }

  const newMatch = trimmed.match(/^new\s+[A-Za-z_]\w*\s*\((.*)\)$/i)
  if (newMatch) {
    const args = parseArguments(newMatch[1])
    if (args.length) {
      const firstArg = args[0]
      if (resolver) {
        const resolved = resolver.resolveValue(firstArg, context)
        const numeric = toNumber(resolved)
        if (numeric !== undefined) return numeric
      }
      return resolveLiteralValue(firstArg, resolver, context)
    }
  }

  trimmed = trimmed.replace(/\b(?:new|const|stock|static)\b/gi, ' ')
  trimmed = trimmed.replace(/\b(?:Float|float|_:float|_:Float|bool|Bool|_:bool|_:Bool|char|Char|_:char|_:Char|Handle)\s*:/g, ' ')
  trimmed = trimmed.replace(/;+$/g, '').trim()
  if (!trimmed) return undefined

  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith('\'') && trimmed.endsWith('\''))) {
    return undefined
  }

  if (/^[-+]?0x[0-9a-f]+$/i.test(trimmed)) return parseInt(trimmed, 16)
  if (/^[-+]?\d+\.\d+(?:e[-+]?\d+)?$/i.test(trimmed)) return parseFloat(trimmed)
  if (/^[-+]?\d+$/.test(trimmed)) return parseInt(trimmed, 10)

  if (/^[A-Za-z_]\w*$/.test(trimmed) && resolver) {
    const resolved = resolver.resolveValue(trimmed, context)
    const numeric = toNumber(resolved)
    if (numeric !== undefined) return numeric
  }

  if (/^[0-9+\-*/%().<>=!&|^~\s]+$/.test(trimmed)) {
    try {
      // eslint-disable-next-line no-new-func
      const fn = new Function(`return (${trimmed})`)
      const result = fn()
      const numeric = toNumber(result)
      if (numeric !== undefined) return numeric
    } catch (err) {
      return undefined
    }
  }

  return undefined
}

function normalizePath(p) {
  if (p === undefined || p === null) return null
  let str = String(p).trim()
  if (!str) return null
  if ((str.startsWith('"') && str.endsWith('"')) || (str.startsWith('\'') && str.endsWith('\''))) {
    str = str.slice(1, -1)
  }
  str = str.trim()
  if (!str) return null
  str = str.replace(/\\/g, '/').replace(/\/{2,}/g, '/').trim()
  if (!str) return null
  return str
}

module.exports = {
  parseSMAEntities,
  normalizeName
}
