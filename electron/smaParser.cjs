const path = require('path')

const REGISTER_FUNCTIONS = [
  'zp_class_zombie_register',
  'zp_register_zombie_class',
  'zp_class_human_register',
  'zp_register_human_class',
  'zp_register_zombie_special_class',
  'zp_register_human_special_class',
  'zp_weapon_register',
  'zp_register_extra_item',
  'zp_register_gamemode'
]

const ESCAPE_REGEX = /[-/\\^$*+?.()|[\]{}]/g
function esc(s){ return s.replace(ESCAPE_REGEX, '\\$&') }

const REGISTER_TYPE_RESOLVERS = [
  { match: name => name.toLowerCase() === 'zp_class_zombie_register' || name.toLowerCase() === 'zp_register_zombie_class', type: 'zombie_class' },
  { match: name => name.toLowerCase() === 'zp_class_human_register'  || name.toLowerCase() === 'zp_register_human_class',  type: 'human_class' },
  { match: name => name.toLowerCase() === 'zp_register_zombie_special_class', type: 'zombie_special' },
  { match: name => name.toLowerCase() === 'zp_register_human_special_class', type: 'human_special' },
  { match: name => name.toLowerCase() === 'zp_weapon_register', type: 'weapon' },
  { match: name => name.toLowerCase() === 'zp_register_extra_item', type: 'shop_item' },
  { match: name => name.toLowerCase() === 'zp_register_gamemode', type: 'mode' }
]

const TYPE_STAT_FIELDS = {
  zombie_class: ['health', 'speed', 'gravity', 'knockback'],
  human_class: ['health', 'speed', 'gravity', 'armor'],
  zombie_special: ['health', 'speed', 'gravity', 'knockback'],
  human_special: ['health', 'speed', 'gravity', 'armor'],
  weapon: ['damage', 'clip_capacity', 'fire_rate', 'reload_time', 'cost'],
  shop_item: ['cost', 'team', 'unlimited']
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

const DEFAULT_VALUES = {
  human_class: { health: 100, speed: 240, gravity: 1.0, armor: 0 },
  human_special: { health: 100, speed: 240, gravity: 1.0, armor: 0 },
  zombie_class: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  zombie_special: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  weapon: { damage: 0, clip_capacity: 0, fire_rate: 0, reload_time: 0, cost: 0 },
  shop_item: { cost: 0, team: 0, unlimited: 0 }
}

const HARDCODED_CONSTANTS = {
  humanclass1_name: 'Classic Human',
  humanclass2_name: 'Raptor',
  zombieclass1_name: 'Classic Zombie',
  zombieclass2_name: 'Raptor Zombie',
  zombieclass3_name: 'Light Zombie',
  zombieclass4_name: 'Fat Zombie',
  zombieclass6_name: 'Rage Zombie'
  // Extensible: agregar más si fuese necesario según el pack de ZP 5.0.8a
}

class ValueResolver {
  constructor(definitionContainer, warn) {
    this.definitionContainer = definitionContainer || { definitions: new Map(), entries: [] }
    this.warn = typeof warn === 'function' ? warn : () => {}
    this.variables = new Map()
    this.resolutionStack = new Set()
    this.warnedCircular = new Set()
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
        this.warn(`Dependencia circular detectada: ${name}`)
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

function parseSMAFile(filePath, rawText) {
  const warnings = new Set()
  const warn = msg => warnings.add(msg)

  const commentless = stripComments(rawText)
  const definitions = collectDefinitions(rawText, commentless, warn)
  definitions.filePath = filePath
  const resolver = new ValueResolver(definitions, warn)
  const context = { definitions, warn, resolver }
  const resources = collectResources(rawText, commentless, context)
  const registerCalls = findRegisterCalls(rawText)

  const fileBase = path.basename(filePath, '.sma')

  const entities = []
  for (const call of registerCalls) {
    const lowerName = call.name.toLowerCase()
    const config = REGISTER_TYPE_RESOLVERS.find(r => r.match(lowerName))
    if (!config) continue

    const type = config.type
    const prefixes = collectPrefixes(call.args)

    const name = resolveEntityName(call, context, fileBase)
    const stats = extractStatsForEntity(call, type, context, prefixes)
    const paths = collectPathsFromArgs(call, type, context)

    entities.push({
      type,
      name,
      fileName: fileBase,
      stats,
      paths,
      meta: {
        registerFunction: call.name,
        registerArgs: call.args
      },
      _registerIndex: call.index
    })
  }

  assignResourcesToEntities(entities, resources)

  for (const entity of entities) {
    entity.paths.models = Array.from(new Set(entity.paths.models))
    entity.paths.sounds = Array.from(new Set(entity.paths.sounds))
    entity.paths.sprites = Array.from(new Set(entity.paths.sprites))
  }

  if (entities.length === 0 && /zp_register_(?:zombie|human|extra|weapon|gamemode)/i.test(rawText)) {
    warn('No se pudieron extraer entidades a pesar de encontrar llamadas de registro.')
  }

  if (warnings.size) {
    const pref = `[SMA Parser] ${path.basename(filePath)}: `
    warnings.forEach(msg => console.warn(pref + msg))
  }

  // ...después de asignar resources y normalizar:
  const seen = new Set()
  const deduped = []
  for (const e of entities) {
    const key = `${e.type}|${(e.name || '').toLowerCase()}|${(e.fileName || '').toLowerCase()}`
    if (!seen.has(key)) {
      seen.add(key)
      deduped.push(e)
    }
  }
  return deduped
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
  const pat = '\\b(' + REGISTER_FUNCTIONS.map(esc).join('|') + ')\\s*\\('
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
    calls.push({ name, args, index: match.index, line })
  }
  return calls
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

  const numericWrapMatch = trimmed.match(/^(float|_:float)\s*\((.*)\)$/i)
  if (numericWrapMatch) {
    const inner = parseExpression(numericWrapMatch[2], resolver, context)
    return inner !== undefined ? Number(inner) : undefined
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

function resolveEntityName(call, context, fallback) {
  const resolver = context && context.resolver
  for (const arg of call.args) {
    const ident = extractIdentifier(arg)
    if (ident && HARDCODED_CONSTANTS[ident] !== undefined) {
      return HARDCODED_CONSTANTS[ident]
    }
  }
  for (const arg of call.args) {
    const value = resolver ? resolver.resolveValue(arg, 'name') : undefined
    const strings = flattenStringValues(value)
    const str = strings.find(Boolean)
    if (typeof str === 'string' && str.length) return str
  }
  return fallback
}

function collectPathsFromArgs(call, type, context) {
  const models = new Set()
  const sounds = new Set()
  const sprites = new Set()
  const resolver = context && context.resolver
  for (const arg of call.args) {
    const value = resolver ? resolver.resolveValue(arg, 'paths') : undefined
    const strings = flattenStringValues(value)
    for (const s of strings) {
      categorizeResourcePath(type, s, models, sounds, sprites)
    }
  }
  return {
    models: Array.from(models),
    sounds: Array.from(sounds),
    sprites: Array.from(sprites)
  }
}

function categorizeResourcePath(type, value, models, sounds, sprites) {
  if (!value || typeof value !== 'string') return
  const lower = value.toLowerCase()
  const ext = path.extname(lower)
  if (!ext) return
  if (RESOURCE_EXTENSIONS.models.includes(ext)) models.add(value)
  else if (RESOURCE_EXTENSIONS.sounds.includes(ext)) {
    if (!CLASS_TYPES.has(type)) sounds.add(value)
  } else if (RESOURCE_EXTENSIONS.sprites.includes(ext)) {
    if (!CLASS_TYPES.has(type)) sprites.add(value)
  }
}

function assignResourcesToEntities(entities, resources) {
  if (!entities.length) return
  for (const res of resources) {
    const ext = path.extname(res.value.toLowerCase())
    if (!ext) continue
    let target = null
    let minDistance = Infinity
    for (const entity of entities) {
      if (res.index >= entity._registerIndex) {
        const dist = res.index - entity._registerIndex
        if (dist < minDistance) {
          target = entity
          minDistance = dist
        }
      }
    }
    if (!target) target = entities[0]
    if (CLASS_TYPES.has(target.type) && ext !== '.mdl') continue
    if (RESOURCE_EXTENSIONS.models.includes(ext)) target.paths.models.push(res.value)
    else if (RESOURCE_EXTENSIONS.sounds.includes(ext)) target.paths.sounds.push(res.value)
    else if (RESOURCE_EXTENSIONS.sprites.includes(ext)) target.paths.sprites.push(res.value)
  }
  for (const entity of entities) delete entity._registerIndex
}

function extractStatsForEntity(call, type, context, prefixes) {
  const stats = {}
  const fields = TYPE_STAT_FIELDS[type] || []
  for (const field of fields) stats[field] = undefined

  const definitionEntries = context.definitions.entries
  const resolver = context.resolver
  const warn = context.warn
  for (const field of fields) {
    const keywords = STAT_KEYWORDS[field] || [field]
    let resolved

    // Search within call arguments first
    for (const arg of call.args) {
      const ident = extractIdentifier(arg)
      if (!ident) continue
      const tokens = identifierTokens(ident)
      if (tokens.some(t => keywords.includes(t))) {
        resolved = resolver ? resolver.resolveValue(arg, `${type}.${field}`) : undefined
        if (resolved !== undefined) break
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

    const numeric = toNumber(resolved)
    stats[field] = numeric ?? DEFAULT_VALUES[type]?.[field] ?? undefined
  }
  return stats
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
  if (typeof value === 'string' && value.trim() !== '') {
    const num = Number(value)
    return Number.isNaN(num) ? undefined : num
  }
  return undefined
}

module.exports = {
  parseSMAFile
}
