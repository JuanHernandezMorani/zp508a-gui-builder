import fs from 'fs/promises'
import path from 'path'

const MODEL_EXTENSIONS = new Set(['.mdl'])
const SPRITE_EXTENSIONS = new Set(['.spr'])
const SOUND_EXTENSIONS = new Set(['.wav', '.mp3'])

function shouldCollect(filePath) {
  const ext = path.extname(filePath).toLowerCase()
  if (MODEL_EXTENSIONS.has(ext)) return 'models'
  if (SPRITE_EXTENSIONS.has(ext)) return 'sprites'
  if (SOUND_EXTENSIONS.has(ext)) return 'sounds'
  return null
}

async function walkDir(dir, base, results) {
  let entries
  try {
    entries = await fs.readdir(dir, { withFileTypes: true })
  } catch (err) {
    if (err && err.code === 'ENOENT') return
    throw err
  }

  for (const entry of entries) {
    const absPath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      await walkDir(absPath, base, results)
      continue
    }

    const kind = shouldCollect(absPath)
    if (!kind) continue

    const relPath = path.relative(base, absPath).replace(/\\/g, '/').toLowerCase()
    if (!results[kind].includes(relPath)) {
      results[kind].push(relPath)
    }
  }
}

export async function scanResources(baseDir) {
  const normalizedBase = baseDir ? path.resolve(baseDir) : path.resolve(process.cwd(), 'input')
  const results = { models: [], sprites: [], sounds: [] }
  await walkDir(normalizedBase, normalizedBase, results)
  results.models.sort()
  results.sprites.sort()
  results.sounds.sort()
  return results
}

export default { scanResources }
