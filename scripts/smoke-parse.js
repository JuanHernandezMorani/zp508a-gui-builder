#!/usr/bin/env node
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { createRequire } from 'module'

const require = createRequire(import.meta.url)
const { parseSMAEntities } = require('../electron/smaParser.cjs')

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const projectRoot = path.resolve(__dirname, '..')
const inputDir = path.join(projectRoot, 'input')

function walk(dir) {
  const results = []
  if (!fs.existsSync(dir)) return results
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const resolved = path.join(dir, entry.name)
    if (entry.isDirectory()) results.push(...walk(resolved))
    else if (entry.isFile() && entry.name.toLowerCase().endsWith('.sma')) results.push(resolved)
  }
  return results
}

function collectWarnings(entities) {
  const warnings = []
  for (const entity of entities) {
    const metaWarnings = Array.isArray(entity?.meta?.warnings) ? entity.meta.warnings : []
    for (const warning of metaWarnings) {
      const text = String(warning || '').trim()
      if (text) warnings.push(text)
    }
  }
  return warnings
}

const files = walk(inputDir)
const totals = new Map()
const warnings = []
const pseudoExamples = []
const menuExamples = []
const extraCallExamples = []
let unresolvedBaseWarnings = 0

for (const filePath of files) {
  const raw = fs.readFileSync(filePath, 'utf-8')
  const entities = parseSMAEntities(filePath, raw)
  for (const entity of entities) {
    const type = entity?.type || 'unknown'
    totals.set(type, (totals.get(type) || 0) + 1)
    if (entity?.meta?.source === 'pseudo' && pseudoExamples.length < 5) {
      pseudoExamples.push({
        name: entity.name,
        file: path.relative(projectRoot, filePath),
        line: entity?.meta?.registerLine
      })
    }
    if (entity?.meta?.source === 'menu-array' && menuExamples.length < 5) {
      menuExamples.push({
        name: entity.name,
        file: path.relative(projectRoot, filePath),
        base: entity?.meta?.menuBase,
        index: entity?.meta?.menuIndex
      })
    }
    const extraCalls = Array.isArray(entity?.meta?.extraCalls) ? entity.meta.extraCalls : []
    for (const call of extraCalls) {
      if (!call || typeof call !== 'object') continue
      if (!call.fn) continue
      if (extraCallExamples.length >= 5) break
      extraCallExamples.push({
        entity: entity.name,
        type,
        fn: call.fn,
        kind: call.kind,
        resolved: Boolean(call.resolved),
        resolvedFrom: Array.isArray(call.resolvedFrom) ? call.resolvedFrom : [],
        line: call.line
      })
    }
  }
  const entityWarnings = collectWarnings(entities)
  warnings.push(...entityWarnings)
  unresolvedBaseWarnings += entityWarnings.filter(msg => msg.includes('No se encontró entidad base')).length
}

console.log('Resumen de entidades escaneadas:')
for (const [type, count] of totals.entries()) {
  console.log(` - ${type}: ${count}`)
}
console.log('')
console.log(`Warnings totales: ${warnings.length}`)
console.log(`Warnings "sin base": ${unresolvedBaseWarnings}`)
console.log('')

if (pseudoExamples.length) {
  console.log('Ejemplos de pseudo-clases detectadas:')
  for (const example of pseudoExamples) {
    console.log(` - ${example.name} (${example.file}:${example.line ?? '?'})`)
  }
  console.log('')
} else {
  console.log('No se detectaron pseudo-clases.\n')
}

if (menuExamples.length) {
  console.log('Ejemplos de entidades definidas en arrays/menús:')
  for (const example of menuExamples) {
    console.log(` - ${example.name} [${example.base}] (índice ${example.index}) en ${example.file}`)
  }
  console.log('')
} else {
  console.log('No se detectaron entidades de menús basadas en arrays.\n')
}

if (extraCallExamples.length) {
  console.log('Ejemplos de extraCalls enriquecidos:')
  for (const call of extraCallExamples) {
    const resolvedFrom = call.resolvedFrom.length ? call.resolvedFrom.join(', ') : 'sin fuentes'
    console.log(` - ${call.fn} → ${call.kind || 'desconocido'} (${call.resolved ? 'resuelto' : 'fallback'}) en ${call.entity} [${call.type}] :: fuentes=${resolvedFrom}`)
  }
  console.log('')
} else {
  console.log('No se registraron extraCalls enriquecidos.\n')
}
