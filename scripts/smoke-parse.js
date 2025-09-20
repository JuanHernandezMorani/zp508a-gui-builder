#!/usr/bin/env node

import fs from 'fs/promises'
import path from 'path'
import process from 'process'

import { scanResources } from '../src/utils/file-scanner.js'

const parserModule = await import('../electron/smaParser.cjs')
const { parseSMAEntities } = parserModule

function formatCountTable(counts) {
  const entries = Array.from(counts.entries())
  const maxLabel = entries.reduce((acc, [label]) => Math.max(acc, label.length), 0)
  return entries
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([label, count]) => `${label.padEnd(maxLabel, ' ')} : ${String(count).padStart(3, ' ')}`)
    .join('\n')
}

async function walkSmaFiles(baseDir) {
  const files = []
  async function walk(dir) {
    let entries
    try {
      entries = await fs.readdir(dir, { withFileTypes: true })
    } catch (err) {
      if (err && err.code === 'ENOENT') return
      throw err
    }
    for (const entry of entries) {
      const abs = path.join(dir, entry.name)
      if (entry.isDirectory()) {
        await walk(abs)
        continue
      }
      if (!entry.isFile()) continue
      if (!entry.name.toLowerCase().endsWith('.sma')) continue
      files.push(abs)
    }
  }

  await walk(baseDir)
  return files
}

function collectEntityCounts(entities) {
  const counts = new Map()
  for (const entity of entities) {
    const type = entity?.type || 'unknown'
    counts.set(type, (counts.get(type) || 0) + 1)
  }
  return counts
}

function collectPseudoNames(entities, limit = 10) {
  const names = []
  for (const entity of entities) {
    if (entity?.meta?.source !== 'pseudo') continue
    if (entity?.name) names.push(entity.name)
  }
  names.sort((a, b) => a.localeCompare(b))
  return names.slice(0, limit)
}

function collectSupplementalExamples(entities, limit = 5) {
  const examples = []
  for (const entity of entities) {
    if (!Array.isArray(entity?.meta?.extraCalls)) continue
    for (const call of entity.meta.extraCalls) {
      if (!call || typeof call !== 'object' || !call.fn) continue
      const kind = call.kind || call.fn
      const expanded = Array.isArray(call.expanded) ? call.expanded : call.values || []
      examples.push({
        entity: entity.name || entity.meta?.normalizedName || '(sin nombre)',
        type: entity.type,
        fn: call.fn,
        kind,
        expanded: expanded.slice(0, 3)
      })
      if (examples.length >= limit) return examples
    }
  }
  return examples
}

function collectExtraCallSamples(entities, limit = 5) {
  const samples = []
  for (const entity of entities) {
    if (!Array.isArray(entity?.meta?.extraCalls)) continue
    for (const call of entity.meta.extraCalls) {
      if (!call || typeof call !== 'object' || !call.fn) continue
      samples.push({
        entity: entity.name || entity.meta?.normalizedName || '(sin nombre)',
        fn: call.fn,
        resolved: Boolean(call.resolved),
        dynamic: Boolean(call.dynamic),
        resolvedFrom: Array.isArray(call.resolvedFrom) ? call.resolvedFrom : [],
        args: Array.isArray(call.args) ? call.args.slice(0, 3) : []
      })
      if (samples.length >= limit) return samples
    }
  }
  return samples
}

function gatherResourceReferences(entities) {
  const refs = { models: new Set(), sprites: new Set(), sounds: new Set() }
  for (const entity of entities) {
    const paths = entity?.paths || {}
    for (const model of paths.models || []) refs.models.add(model.toLowerCase())
    for (const claw of paths.claws || []) refs.models.add(claw.toLowerCase())
    for (const sprite of paths.sprites || []) refs.sprites.add(sprite.toLowerCase())
    for (const sound of paths.sounds || []) refs.sounds.add(sound.toLowerCase())
  }
  return refs
}

function computeMissingResources(references, available, limit = 10) {
  const missing = {}
  for (const kind of Object.keys(references)) {
    const refSet = references[kind]
    const availableSet = new Set((available[kind] || []).map((v) => v.toLowerCase()))
    const diff = []
    for (const value of refSet) {
      if (!availableSet.has(value)) diff.push(value)
    }
    diff.sort((a, b) => a.localeCompare(b))
    missing[kind] = diff.slice(0, limit)
  }
  return missing
}

async function main() {
  const inputDir = path.resolve(process.cwd(), 'input')
  const files = await walkSmaFiles(inputDir)
  if (!files.length) {
    console.warn('No se encontraron archivos .sma en input/. Finalizando smoke test.')
    return
  }

  const entities = []
  for (const file of files) {
    const raw = await fs.readFile(file, 'utf8')
    try {
      const parsed = parseSMAEntities(file, raw)
      entities.push(...parsed)
    } catch (err) {
      console.error(`Error al parsear ${path.relative(inputDir, file)}:`, err.message)
    }
  }

  const counts = collectEntityCounts(entities)
  console.log('=== Conteo por tipo ===')
  console.log(formatCountTable(counts))

  const pseudoNames = collectPseudoNames(entities)
  console.log('\n=== Pseudo-clases humanas detectadas ===')
  pseudoNames.forEach((name, idx) => console.log(`${String(idx + 1).padStart(2, '0')}. ${name}`))
  if (!pseudoNames.length) console.log('Sin pseudo-clases detectadas')

  const supplemental = collectSupplementalExamples(entities)
  console.log('\n=== Ejemplos de llamadas suplementarias ===')
  if (!supplemental.length) console.log('Sin llamadas suplementarias detectadas')
  else supplemental.forEach((entry, idx) => {
    console.log(`${idx + 1}. ${entry.fn} -> ${entry.kind} [${entry.type}] ${entry.entity}`)
    if (entry.expanded.length) {
      console.log(`   Recursos: ${entry.expanded.join(', ')}`)
    }
  })

  const extraSamples = collectExtraCallSamples(entities)
  console.log('\n=== extraCalls (auditoría rápida) ===')
  if (!extraSamples.length) console.log('Sin extraCalls registrados')
  else extraSamples.forEach((sample, idx) => {
    const resolvedFrom = sample.resolvedFrom.length ? ` [${sample.resolvedFrom.join(', ')}]` : ''
    console.log(`${idx + 1}. ${sample.fn} (${sample.entity}) -> resolved=${sample.resolved} dynamic=${sample.dynamic}${resolvedFrom}`)
    if (sample.args.length) console.log(`   args: ${sample.args.join(', ')}`)
  })

  const available = await scanResources(inputDir)
  console.log('\n=== Recursos disponibles ===')
  console.log(`Modelos: ${available.models.length}`)
  console.log(`Sprites: ${available.sprites.length}`)
  console.log(`Sonidos: ${available.sounds.length}`)

  const references = gatherResourceReferences(entities)
  const missing = computeMissingResources(references, available)
  console.log('\n=== Referencias ausentes (top 10) ===')
  for (const [kind, list] of Object.entries(missing)) {
    console.log(`- ${kind}: ${list.length ? list.join(', ') : 'completo'}`)
  }
}

main().catch((err) => {
  console.error('Smoke test falló:', err)
  process.exitCode = 1
})
