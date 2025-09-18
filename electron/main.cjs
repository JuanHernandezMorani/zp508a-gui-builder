const { app, BrowserWindow, ipcMain, protocol } = require('electron')
const path = require('path')
const fs = require('fs')
const url = require('url')
const fse = require('fs-extra')
const { spawn, spawnSync } = require('child_process')
const { parseSMAEntities, normalizeName } = require('./smaParser.cjs')

const APP_DIRS = {
  input: path.join(process.cwd(), 'input'),
  build: path.join(process.cwd(), 'build'),
  systems: path.join(process.cwd(), 'systems'),
  db: path.join(process.cwd(), 'zpbuilder.json'),
  cfg: path.join(process.cwd(), 'zpbuilder.config.json'),
  tools: path.join(process.cwd(), 'tools'),
  previews: path.join(process.cwd(), 'previews'),
  scripts: path.join(process.cwd(), 'scripts')
}

const DEFAULT_CFG = {
  csRoot: "",
  amxxpcPath: "",
  includeDirs: [],
  pythonPath: "python"
}

function ensureDirs() {
  for (const d of [APP_DIRS.input, APP_DIRS.build, APP_DIRS.systems, APP_DIRS.tools, APP_DIRS.previews, APP_DIRS.scripts]) {
    fse.ensureDirSync(d)
  }
  fse.ensureDirSync(path.join(APP_DIRS.previews, 'sprites'))
  fse.ensureDirSync(path.join(APP_DIRS.previews, 'models'))
  fse.ensureDirSync(path.join(APP_DIRS.previews, 'sounds'))

  if (!fs.existsSync(APP_DIRS.db)) fs.writeFileSync(APP_DIRS.db, JSON.stringify({ items: [] }, null, 2))
  if (!fs.existsSync(APP_DIRS.cfg)) fs.writeFileSync(APP_DIRS.cfg, JSON.stringify(DEFAULT_CFG, null, 2))
}

function readDB() { ensureDirs(); try { return JSON.parse(fs.readFileSync(APP_DIRS.db, 'utf-8')) } catch { return { items: [] } } }
function writeDB(db) { fs.writeFileSync(APP_DIRS.db, JSON.stringify(db, null, 2)) }
function readCFG() { ensureDirs(); try { return JSON.parse(fs.readFileSync(APP_DIRS.cfg, 'utf-8')) } catch { return DEFAULT_CFG } }
function writeCFG(cfg) { fs.writeFileSync(APP_DIRS.cfg, JSON.stringify(cfg, null, 2)) }

function makeWindow() {
  const win = new BrowserWindow({
    width: 1280, height: 840,
    webPreferences: {
      preload: path.join(process.cwd(), 'preload', 'index.cjs'),
      webSecurity: false
    }
  })
  if (process.env.NODE_ENV === 'development') {
    win.loadURL('http://localhost:5173')
    win.webContents.on('console-message', (event, level, message) => {
      if (message.includes("Autofill")) return
    })
    //win.webContents.openDevTools()
  } else {
    win.loadFile(path.join(process.cwd(), 'dist', 'index.html'))
  }
}

protocol.registerSchemesAsPrivileged([
    {
      scheme: 'zpb',
      privileges: {
        standard: true,
        secure: true,
        supportFetchAPI: true,
        bypassCSP: false
      }
    }
  ])

app.whenReady().then(() => {
  ensureDirs()

  protocol.handle('zpb', (request) => {
    const parsed = new URL(request.url)
    const filePath = path.join(APP_DIRS.previews, parsed.hostname, parsed.pathname)
    const resolved = path.resolve(filePath)
    if (!resolved.startsWith(path.resolve(APP_DIRS.previews))) {
      throw new Error('Access outside previews forbidden')
    }
    return url.pathToFileURL(resolved).toString()
  })

  makeWindow()
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) makeWindow() })
})

app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit() })

// Helpers
function cryptoRandomId() { const a = 'abcdefghijklmnopqrstuvwxyz0123456789'; let s = ''; for (let i = 0; i < 20; i++) s += a[Math.floor(Math.random() * a.length)]; return s }
function mapTypeDir(t) {
  switch (t) {
    case 'zombie_class': return 'scripting/classes/zombies'
    case 'human_class': return 'scripting/classes/humans'
    case 'zombie_special': return 'scripting/classes/special/zombies'
    case 'human_special': return 'scripting/classes/special/humans'
    case 'mode': return 'scripting/modes'
    case 'weapon': return 'scripting/weapons'
    case 'shop_item': return 'scripting/shop'
    case 'system': return 'scripting/systems'
    default: return 'scripting/misc'
  }
}

const STAT_DEFAULTS = {
  zombie: { health: 2000, speed: 250, gravity: 1.0, knockback: 1.0 },
  human: { health: 100, speed: 240, gravity: 1.0, armor: 0 }
}

function emptyStatsForType(type) {
  switch (type) {
    case 'zombie_class':
    case 'zombie_special':
      return {
        health: STAT_DEFAULTS.zombie.health,
        speed: STAT_DEFAULTS.zombie.speed,
        gravity: STAT_DEFAULTS.zombie.gravity,
        knockback: STAT_DEFAULTS.zombie.knockback
      }
    case 'human_class':
    case 'human_special':
      return {
        health: STAT_DEFAULTS.human.health,
        speed: STAT_DEFAULTS.human.speed,
        gravity: STAT_DEFAULTS.human.gravity,
        armor: STAT_DEFAULTS.human.armor
      }
    case 'weapon':
      return { damage: undefined, clip_capacity: undefined, fire_rate: undefined, reload_time: undefined, cost: undefined }
    case 'shop_item':
      return { cost: undefined, team: undefined, unlimited: undefined }
    default:
      return {}
  }
}

function normalizeEntityPaths(paths) {
  const ensureArray = (value) => Array.isArray(value) ? value.filter(Boolean) : []
  const unique = (arr) => Array.from(new Set(arr))
  if (!paths || typeof paths !== 'object') {
    return { models: [], sounds: [], sprites: [] }
  }
  return {
    models: unique(ensureArray(paths.models)),
    sounds: unique(ensureArray(paths.sounds)),
    sprites: unique(ensureArray(paths.sprites))
  }
}

function detectFallbackType(textLower, fnameLower) {
  let type = null
  if (textLower.includes('zp_register_zombie_class') || textLower.includes('zp_class_zombie_register')) type = 'zombie_class'
  else if (textLower.includes('zp_register_human_class') || textLower.includes('zp_class_human_register')) type = 'human_class'
  else if (textLower.includes('zp_register_human_special_class')) type = 'human_special'
  else if (textLower.includes('zp_register_zombie_special_class')) type = 'zombie_special'
  else if (textLower.includes('zp_register_gamemode')) type = 'mode'
  else if (textLower.includes('zp_register_extra_item')) type = 'shop_item'
  else if (textLower.includes('zp_weapon_register')) type = 'weapon'
  else if (fnameLower.includes('zp50_class_assassin') || fnameLower.includes('zp50_class_nemesis') ||
    fnameLower.includes('zp50_class_dragon') || fnameLower.includes('zp50_class_nightcrawler') ||
    fnameLower.includes('zp50_class_plasma') || fnameLower.includes('zp50_class_knifer')) type = 'zombie_special'
  else if (fnameLower.includes('zp50_class_snier') || fnameLower.includes('zp50_class_survivor')) type = 'human_special'
  else if (fnameLower.startsWith('zp50_class_zombie')) type = 'zombie_class'
  else if (fnameLower.startsWith('zp50_class_human')) type = 'human_class'
  else if (fnameLower.startsWith('zp50_gamemode')) type = 'mode'
  else if (fnameLower.startsWith('zp50_item_') || fnameLower.startsWith('zp50_grenade')) type = 'shop_item'
  else if (fnameLower.startsWith('zp50_weapon_')) type = 'weapon'
  else if (fnameLower.startsWith('zp50_')) type = 'system'
  return type
}

// ------------------- Python Helpers --------------------
function checkPythonAvailable(pythonPath) {
  try {
    const result = spawnSync(pythonPath, ['--version'])
    return result.status === 0
  } catch (error) {
    return false
  }
}

function runPythonScript(pythonPath, scriptPath, args) {
  return new Promise((resolve, reject) => {
    const allArgs = [scriptPath, ...args]
    const child = spawn(pythonPath, allArgs)

    let stdout = ''
    let stderr = ''

    child.stdout.on('data', (data) => {
      stdout += data.toString()
    })

    child.stderr.on('data', (data) => {
      stderr += data.toString()
    })

    child.on('close', (code) => {
      if (code === 0) {
        resolve({ stdout, stderr })
      } else {
        reject(new Error(`Python script exited with code ${code}: ${stderr}`))
      }
    })

    child.on('error', (error) => {
      reject(error)
    })
  })
}

// ------------------- Python Script Paths --------------------
const PYTHON_SCRIPTS = {
  spr2png: path.join(APP_DIRS.scripts, 'spr2png.py'),
  mdl2png: path.join(APP_DIRS.scripts, 'mdl2png.py'),
  wav2waveform: path.join(APP_DIRS.scripts, 'wav2waveform.py')
}

// ------------------- Preview Generators --------------------
async function generateSpritePreview(sprPath, outputPath) {
  try {
    const cfg = readCFG()
    const pythonPath = cfg.pythonPath || 'python'

    // Verificar que el script existe
    if (!fs.existsSync(PYTHON_SCRIPTS.spr2png)) {
      throw new Error(`Script no encontrado: ${PYTHON_SCRIPTS.spr2png}`)
    }

    await runPythonScript(pythonPath, PYTHON_SCRIPTS.spr2png, [sprPath, outputPath])
    return true
  } catch (error) {
    console.error('Error generating sprite preview:', error)
    // Crear un placeholder de error
    createErrorPlaceholder(outputPath, 'SPR')
    return false
  }
}

async function generateModelPreview(mdlPath, outputPath) {
  try {
    const cfg = readCFG()
    const pythonPath = cfg.pythonPath || 'python'

    if (!fs.existsSync(PYTHON_SCRIPTS.mdl2png)) {
      throw new Error(`Script no encontrado: ${PYTHON_SCRIPTS.mdl2png}`)
    }

    await runPythonScript(pythonPath, PYTHON_SCRIPTS.mdl2png, [mdlPath, outputPath])
    return true
  } catch (error) {
    console.error('Error generating model preview:', error)
    createErrorPlaceholder(outputPath, 'MDL')
    return false
  }
}

async function generateSoundPreview(wavPath, outputPath) {
  try {
    const cfg = readCFG()
    const pythonPath = cfg.pythonPath || 'python'

    if (!fs.existsSync(PYTHON_SCRIPTS.wav2waveform)) {
      throw new Error(`Script no encontrado: ${PYTHON_SCRIPTS.wav2waveform}`)
    }

    await runPythonScript(pythonPath, PYTHON_SCRIPTS.wav2waveform, [wavPath, outputPath])

    // Copiar el archivo WAV original para reproducción
    const soundOutputPath = path.join(APP_DIRS.previews, 'sounds', path.basename(wavPath))
    fs.copyFileSync(wavPath, soundOutputPath)

    return true
  } catch (error) {
    console.error('Error generating sound preview:', error)
    createErrorPlaceholder(outputPath, 'WAV')
    return false
  }
}

function createErrorPlaceholder(outputPath, type) {
  const svgContent = `
    <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
      <rect width="100%" height="100%" fill="#ff0000"/>
      <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" 
            fill="white" font-family="Arial" font-size="10">${type} Error</text>
    </svg>
  `
  fs.writeFileSync(outputPath, svgContent)
}

// ------------------- Walk Recursivo --------------------
function walkAll(dir) {
  let results = []
  if (!fs.existsSync(dir)) return results
  for (const f of fse.readdirSync(dir)) {
    const p = path.join(dir, f)
    const st = fse.statSync(p)
    if (st.isDirectory()) results = results.concat(walkAll(p))
    else results.push(p)
  }
  return results
}

// ------------------- IPC ------------------------
ipcMain.handle('cfg:get', async () => readCFG())
ipcMain.handle('cfg:set', async (_evt, cfg) => { writeCFG(cfg); return true })
ipcMain.handle('db:list', async () => readDB().items)
ipcMain.handle('db:save', async (_evt, items) => { writeDB({ items }); return true })

// Detectar ZP 5.0
ipcMain.handle('detect:zp50', async () => {
  ensureDirs()
  let foundCore = ""
  fse.readdirSync(APP_DIRS.input, { withFileTypes: true }).forEach(d => {
    const p = path.join(APP_DIRS.input, d.name)
    if (d.isDirectory()) {
      const inc = path.join(p, 'cstrike', 'addons', 'amxmodx', 'scripting', 'include', 'zp50_core.inc')
      if (fs.existsSync(inc)) foundCore = inc
    }
  })
  const cfg = readCFG()
  if (foundCore) {
    const includeDir = path.dirname(foundCore)
    cfg.includeDirs = [includeDir]
    const amxxpc1 = path.join(includeDir, '..', 'amxxpc.exe')
    const amxxpc2 = path.join(includeDir, '..', 'amxxpc')
    if (fs.existsSync(amxxpc1)) cfg.amxxpcPath = path.resolve(amxxpc1)
    else if (fs.existsSync(amxxpc2)) cfg.amxxpcPath = path.resolve(amxxpc2)
    writeCFG(cfg)
    return { ok: true, cfg }
  }
  return { ok: false, message: 'No se encontró zp50_core.inc en input/' }
})

// Detectar Python
ipcMain.handle('detect:python', async () => {
  const cfg = readCFG()
  const pythonAvailable = checkPythonAvailable(cfg.pythonPath)

  // Check if Python scripts are available
  const scriptsAvailable = {
    spr2png: fs.existsSync(PYTHON_SCRIPTS.spr2png),
    mdl2png: fs.existsSync(PYTHON_SCRIPTS.mdl2png),
    wav2waveform: fs.existsSync(PYTHON_SCRIPTS.wav2waveform)
  }

  return {
    pythonAvailable,
    scriptsAvailable,
    pythonPath: cfg.pythonPath
  }
})

ipcMain.handle('scan:sma', async () => {
  ensureDirs()
  const files = walkAll(APP_DIRS.input).filter(f => f.toLowerCase().endsWith('.sma'))
  const scanned = []

  for (const p of files) {
    const raw = fs.readFileSync(p, 'utf-8')
    const fname = path.basename(p)
    if (/_api\.sma$/i.test(fname) || /^amx_/i.test(fname) || /^cs_/i.test(fname)) continue

    const parsedEntities = parseSMAEntities(p, raw)
    scanned.push(...parsedEntities)
  }

  const dedupedByKey = new Map()
  for (const item of scanned) {
    const normalized = normalizeName(item.meta?.normalizedName || item.name)
    const key = `${item.type}|${normalized}`
    if (!dedupedByKey.has(key)) {
      dedupedByKey.set(key, item)
    } else {
      const existing = dedupedByKey.get(key)
      const conflicts = Array.isArray(existing.meta?.conflicts) ? [...existing.meta.conflicts] : []
      conflicts.push({ originFile: item.meta?.originFile, registerLine: item.meta?.registerLine })
      const existingWarnings = Array.isArray(existing.meta?.warnings) ? existing.meta.warnings : []
      const newWarnings = Array.isArray(item.meta?.warnings) ? item.meta.warnings : []
      const warnings = Array.from(new Set([...existingWarnings, ...newWarnings]))
      existing.meta = {
        ...(existing.meta || {}),
        conflicts,
        warnings,
        normalizedName: existing.meta?.normalizedName || normalized
      }
    }
  }

  const deduped = Array.from(dedupedByKey.values())
  const db = readDB()

  // 1) Limpieza suave: quita duplicados existentes por la misma clave (por si ya había ruido previo)
  const byKey = new Map()
  for (const it of db.items) {
    const normalized = normalizeName((it.meta && it.meta.normalizedName) || it.name)
    const k = `${it.type}|${normalized}`
    if (!byKey.has(k)) byKey.set(k, it) // conserva el primero (y su "enabled")
  }
  db.items = Array.from(byKey.values())

  // 2) Merge: si la entidad ya existe, conserva "enabled" anterior
  for (const it of deduped) {
    const normalized = normalizeName(it.meta?.normalizedName || it.name)
    const k = `${it.type}|${normalized}`
    if (byKey.has(k)) {
      const prev = byKey.get(k)
      it.enabled = prev.enabled // preserva estado
    }
    byKey.set(k, it)
  }

  // 3) Persistir
  db.items = Array.from(byKey.values())
  writeDB(db)
  return db.items
})

ipcMain.handle('scan:mdl', async () => {
  ensureDirs()
  const models = walkAll(APP_DIRS.input).filter(f => f.toLowerCase().endsWith('.mdl')).map(m => path.relative(APP_DIRS.input, m))

  // Generate previews for models
  for (const model of models) {
    const absPath = path.join(APP_DIRS.input, model)
    const previewPath = path.join(APP_DIRS.previews, 'models', model.replace('.mdl', '.png'))
    fse.ensureDirSync(path.dirname(previewPath))

    if (!fs.existsSync(previewPath)) {
      await generateModelPreview(absPath, previewPath)
    }
  }

  return models
})

ipcMain.handle('scan:spr', async () => {
  ensureDirs()
  const sprites = walkAll(APP_DIRS.input).filter(f => f.toLowerCase().endsWith('.spr')).map(s => path.relative(APP_DIRS.input, s))

  // Generate previews for sprites
  for (const sprite of sprites) {
    const absPath = path.join(APP_DIRS.input, sprite)
    const previewPath = path.join(APP_DIRS.previews, 'sprites', sprite.replace('.spr', '.png'))
    fse.ensureDirSync(path.dirname(previewPath))

    if (!fs.existsSync(previewPath)) {
      await generateSpritePreview(absPath, previewPath)
    }
  }

  return sprites
})

ipcMain.handle('scan:wav', async () => {
  ensureDirs()
  const sounds = walkAll(APP_DIRS.input).filter(f => f.toLowerCase().endsWith('.wav')).map(s => path.relative(APP_DIRS.input, s))

  // Generate previews for sounds
  for (const sound of sounds) {
    const absPath = path.join(APP_DIRS.input, sound)
    const previewPath = path.join(APP_DIRS.previews, 'sounds', sound.replace('.wav', '.png'))
    fse.ensureDirSync(path.dirname(previewPath))

    if (!fs.existsSync(previewPath)) {
      await generateSoundPreview(absPath, previewPath)
    }
  }

  return sounds
})

ipcMain.handle('delete:mdl', async (_evt, relPath) => {
  const abs = path.join(APP_DIRS.input, relPath)
  const preview = path.join(APP_DIRS.previews, 'models', relPath.replace('.mdl', '.png'))
  if (fs.existsSync(abs)) fs.unlinkSync(abs)
  if (fs.existsSync(preview)) fs.unlinkSync(preview)
  return true
})

ipcMain.handle('delete:spr', async (_evt, relPath) => {
  const abs = path.join(APP_DIRS.input, relPath)
  const preview = path.join(APP_DIRS.previews, 'sprites', relPath.replace('.spr', '.png'))
  if (fs.existsSync(abs)) fs.unlinkSync(abs)
  if (fs.existsSync(preview)) fs.unlinkSync(preview)
  return true
})

ipcMain.handle('delete:wav', async (_evt, relPath) => {
  const abs = path.join(APP_DIRS.input, relPath)
  const preview = path.join(APP_DIRS.previews, 'sounds', relPath.replace('.wav', '.png'))
  const soundCopy = path.join(APP_DIRS.previews, 'sounds', relPath)
  if (fs.existsSync(abs)) fs.unlinkSync(abs)
  if (fs.existsSync(preview)) fs.unlinkSync(preview)
  if (fs.existsSync(soundCopy)) fs.unlinkSync(soundCopy)
  return true
})

// ------------------- Generador SMA unitario --------------------
function generateSMA_ZP50(item) {
  let header = `// Auto generado por ZP Builder UI (ZP 5.0.8a)\n#include <amxmodx>\n#include <zp50_core>\n`;
  let code = '';
  const precacheBlocks = `
public plugin_precache() {
  ${item.paths?.models?.map(m => `precache_model("${m}")`).join('\n  ') || ''}
  ${item.paths?.sounds?.map(s => `precache_sound("${s}")`).join('\n  ') || ''}
  ${item.paths?.sprites?.map(s => `precache_generic("${s}")`).join('\n  ') || ''}
}
`

  switch (item.type) {
    case 'zombie_class': {
      header += '#include <zp50_class_zombie>\n';
      const health = item.stats?.health ?? 2000;
      const speed = item.stats?.speed ?? 260;
      const gravity = item.stats?.gravity ?? 0.8;
      const knockback = item.stats?.knockback ?? 1.0;
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
${precacheBlocks}
new g_zclass_id;
public zp_fw_class_zombie_register() {
  g_zclass_id = zp_class_zombie_register("${item.name}", "${item.description || 'Clase zombie'}", "${item.paths?.models?.[0] || 'zombie_source'}", "v_knife_zombie.mdl", ${health}, ${speed}.0, ${gravity});
  zp_class_zombie_register_kb(g_zclass_id, ${knockback});
}
`;
      break;
    }
    case 'human_class': {
      header += '#include <zp50_class_human>\n';
      const health = item.stats?.health ?? 100;
      const speed = item.stats?.speed ?? 240;
      const armor = item.stats?.armor ?? 100;
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
${precacheBlocks}
new g_hclass_id;
public zp_fw_class_human_register() {
  g_hclass_id = zp_class_human_register("${item.name}", "${item.description || 'Clase humana'}", "${item.paths?.models?.[0] || 'terror'}", ${health}, ${speed}.0, ${armor});
}
`;
      break;
    }
    case 'zombie_special': {
      header += '#include <zp50_class_zombie>\n#include <zp50_class_special>\n';
      const health = item.stats?.health ?? 3000;
      const speed = item.stats?.speed ?? 280;
      const gravity = item.stats?.gravity ?? 0.7;
      const knockback = item.stats?.knockback ?? 1.2;
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
${precacheBlocks}
new g_zspec_id;
public zp_fw_class_zombie_register() {
  g_zspec_id = zp_class_zombie_register("${item.name}", "${item.description || 'Clase zombie especial'}", "${item.paths?.models?.[0] || 'zombie_source'}", "v_knife_zombie.mdl", ${health}, ${speed}.0, ${gravity});
  zp_class_zombie_register_kb(g_zspec_id, ${knockback});
  zp_class_special_register(g_zspec_id);
}
`;
      break;
    }
    case 'human_special': {
      header += '#include <zp50_class_human>\n#include <zp50_class_special>\n';
      const health = item.stats?.health ?? 200;
      const speed = item.stats?.speed ?? 260;
      const armor = item.stats?.armor ?? 200;
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
${precacheBlocks}
new g_hspec_id;
public zp_fw_class_human_register() {
  g_hspec_id = zp_class_human_register("${item.name}", "${item.description || 'Clase humana especial'}", "${item.paths?.models?.[0] || 'terror'}", ${health}, ${speed}.0, ${armor});
  zp_class_special_register(g_hspec_id);
}
`;
      break;
    }
    case 'mode': {
      header += '#include <zp50_gamemodes>\n';
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
${precacheBlocks}
new g_gamemode_id;
public zp_fw_gamemodes_register() {
  g_gamemode_id = zp_gamemode_register("${item.name}", ZP_GAMEMODE_CLassic, ZP_GAMEMODE_FLAG_INFECTION);
}
`;
      break;
    }
    case 'weapon': {
      header += '#include <zp50_weapons>\n';
      const damage = item.stats?.damage ?? 30;
      const clip = item.stats?.clip_capacity ?? 30;
      const fire_rate = item.stats?.fire_rate ?? 0.1;
      const reload = item.stats?.reload_time ?? 2.5;
      const cost = item.stats?.cost ?? 15;
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
${precacheBlocks}
new g_weapon_id;
public zp_fw_weapons_register() {
  g_weapon_id = zp_weapon_register("${item.name}", WEAPON_${(item.meta && item.meta.weapon_type) || 'RIFLE'}, ${cost}, ${damage}, ${clip}, ${fire_rate}, ${reload});
}
`;
      break;
    }
    case 'shop_item': {
      header += '#include <zp50_items>\n';
      const cost = item.stats?.cost ?? 10;
      const team = item.stats?.team ?? 0;
      const unlimited = item.stats?.unlimited ?? 0;
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
${precacheBlocks}
new g_item_id;
public zp_fw_items_register() {
  g_item_id = zp_item_register("${item.name}", ${cost}, ${team});
}
`;
      break;
    }
    case 'system':
    default: {
      code = `
public plugin_init() { register_plugin("${item.name}", "0.3.0", "ZPBuilder"); }
// Sistema personalizado
`;
    }
  }
  return header + code;
}

// ------------------- Sistemas por defecto --------------------
function seedDefaultSystems(systemsDir, buildDir) {
  const sysFiles = [
    ['system_levels.sma', `#include <amxmodx>\n#include <zp50_core>\n// Niveles persistentes\n`],
    ['system_resets.sma', `#include <amxmodx>\n#include <zp50_core>\n// Reset / Grand Reset\n`],
    ['system_login.sma', `#include <amxmodx>\n#include <zp50_core>\n// Login/Register\n`],
    ['system_combos.sma', `#include <amxmodx>\n#include <zp50_core>\n// Combos estilo Zombie Carnage\n`],
    ['system_points.sma', `#include <amxmodx>\n#include <zp50_core>\n// Puntos Z/H\n`],
    ['system_ammopacks.sma', `#include <amxmodx>\n#include <zp50_core>\n// Ammopacks\n`],
    ['system_goldpoints.sma', `#include <amxmodx>\n#include <zp50_core>\n// Gold Points\n`],
  ]
  for (const [fname, code] of sysFiles) {
    const src = path.join(systemsDir, fname)
    if (!fs.existsSync(src)) fs.writeFileSync(src, code, 'utf-8')
    const dst = path.join(buildDir, 'scripting', 'systems', fname)
    fse.ensureDirSync(path.dirname(dst))
    fs.copyFileSync(src, dst)
  }
}

// ------------------- Build/Compile ------------------------
ipcMain.handle('build:generate', async (_evt, items) => {
  ensureDirs()
  const cfg = readCFG()
  const problems = []

  // Basic validations
  for (const it of items) {
    if (!it.enabled) continue
    if (!it.name) problems.push(`Falta nombre en un item (${it.fileName})`)
    if (['zombie_class', 'human_class', 'zombie_special', 'human_special'].includes(it.type)) {
      const hasModel = it.paths && Array.isArray(it.paths.models) && it.paths.models.length > 0
      if (!hasModel) problems.push(`Faltan models en ${it.name}`)
    }
  }
  if (problems.length) return { ok: false, problems }

  // Group items by type
  const byType = {}
  for (const it of items) {
    if (!it.enabled) continue
      ; (byType[it.type] ||= []).push(it)
  }

  // Generate files
  for (const [type, arr] of Object.entries(byType)) {
    const outDir = path.join(APP_DIRS.build, mapTypeDir(type))
    fse.ensureDirSync(outDir)
    if (['zombie_class', 'human_class', 'zombie_special', 'human_special'].includes(type)) {
      const code = generateGroupedSMA(type, arr)
      const outPath = path.join(outDir, `zp50_${type}.sma`)
      fs.writeFileSync(outPath, code, 'utf-8')
    } else {
      for (const it of arr) {
        const code = generateSMA_ZP50(it)
        const outPath = path.join(outDir, `${it.fileName}.sma`)
        fs.writeFileSync(outPath, code, 'utf-8')
      }
    }
  }

  // Configs
  const cfgDir = path.join(APP_DIRS.build, 'configs')
  fse.ensureDirSync(cfgDir)
  const classesIni = [
    '; Auto generado por ZP Builder UI',
    '[ZOMBIE_CLASSES]',
    ...(byType['zombie_class'] || []).map(i => i.fileName),
    '',
    '[HUMAN_CLASSES]',
    ...(byType['human_class'] || []).map(i => i.fileName),
  ].join('\n')
  fs.writeFileSync(path.join(cfgDir, 'classes.ini'), classesIni, 'utf-8')
  fs.writeFileSync(path.join(cfgDir, 'zp_humanclasses.ini'), (byType['human_class'] || []).map(i => i.fileName).join('\n') + '\n', 'utf-8')
  fs.writeFileSync(path.join(cfgDir, 'zp_zombieclasses.ini'), (byType['zombie_class'] || []).map(i => i.fileName).join('\n') + '\n', 'utf-8')
  fs.writeFileSync(path.join(cfgDir, 'zp_extraitems.ini'), (byType['shop_item'] || []).map(i => i.fileName).join('\n') + '\n', 'utf-8')

  // Seed default systems
  seedDefaultSystems(APP_DIRS.systems, APP_DIRS.build)

  // Compile
  const compiled = []
  if (cfg.amxxpcPath && fs.existsSync(cfg.amxxpcPath)) {
    const includeFlags = (cfg.includeDirs || []).flatMap(d => ['-i', d])
    const smaFiles = []
    function pushDir(d) {
      if (!fs.existsSync(d)) return
      for (const f of fse.readdirSync(d)) {
        const p = path.join(d, f)
        const st = fse.statSync(p)
        if (st.isDirectory()) pushDir(p)
        else if (f.toLowerCase().endsWith('.sma')) smaFiles.push(p)
      }
    }
    pushDir(path.join(APP_DIRS.build, 'scripting'))
    const pluginsDir = path.join(APP_DIRS.build, 'plugins')
    fse.ensureDirSync(pluginsDir)
    for (const sma of smaFiles) {
      const out = path.join(pluginsDir, path.basename(sma, '.sma') + '.amxx')
      const args = [sma, '-o', out, ...includeFlags]
      try {
        const child = spawn(cfg.amxxpcPath, args, { shell: false })
        await new Promise((resolve) => child.on('close', resolve))
        if (fs.existsSync(out)) compiled.push(out)
      } catch (e) { /* ignore */ }
    }
  }

  return { ok: true, problems: [], compiled, cfg: readCFG() }
})

// ------------------- Grouped SMA ------------------------
function generateGroupedSMA(type, items) {
  let header = `// Auto generado por ZP Builder UI (ZP 5.0.8a)\n#include <amxmodx>\n#include <zp50_core>\n`
  let body = `public plugin_init(){ register_plugin("${type.replace('_', ' ').toUpperCase()}", "0.3.0", "ZPBuilder"); }\n\n`

  if (type === 'zombie_class' || type === 'zombie_special') header += '#include <zp50_class_zombie>\n'
  if (type === 'human_class' || type === 'human_special') header += '#include <zp50_class_human>\n'
  if (type === 'zombie_special' || type === 'human_special') header += '#include <zp50_class_special>\n'

  // Single precache that covers all listed paths
  const allModels = [].concat(...items.map(it => it.paths?.models || []))
  const allSounds = [].concat(...items.map(it => it.paths?.sounds || []))
  const allSprites = [].concat(...items.map(it => it.paths?.sprites || []))

  body += 'public plugin_precache() {\n'
  for (const m of allModels) body += `  precache_model("${m}");\n`
  for (const s of allSounds) body += `  precache_sound("${s}");\n`
  for (const sp of allSprites) body += `  precache_generic("${sp}");\n`
  body += '}\n\n'

  items.forEach((it) => {
    const mdl = (it.paths?.models && it.paths.models[0]) || (type.includes('zombie') ? 'zombie_source' : 'terror')
    const health = it.stats?.health ?? (type.includes('zombie') ? 2000 : 120)
    const speed = it.stats?.speed ?? (type.includes('zombie') ? 260 : 250)
    const gravity = it.stats?.gravity ?? 0.8
    const armor = it.stats?.armor ?? 100
    const knockback = it.stats?.knockback ?? 1.0
    const desc = it.description || (type.includes('zombie') ? 'Clase zombie' : 'Clase humana')
    const varid = it.fileName.replace(/[^a-z0-9_]/ig, '_')

    if (type === 'zombie_class' || type === 'zombie_special') {
      body += `// ${it.name}\nnew g_zc_${varid};\npublic zp_fw_class_zombie_register_${varid}(){\n  g_zc_${varid} = zp_class_zombie_register("${it.name}", "${desc}", "${mdl}", "v_knife_zombie.mdl", ${health}, ${speed}.0, ${gravity});\n  zp_class_zombie_register_kb(g_zc_${varid}, ${knockback});\n`
      if (type === 'zombie_special') body += `  zp_class_special_register(g_zc_${varid});\n`
      body += `}\n\n`
    } else if (type === 'human_class' || type === 'human_special') {
      body += `// ${it.name}\nnew g_hc_${varid};\npublic zp_fw_class_human_register_${varid}(){\n  g_hc_${varid} = zp_class_human_register("${it.name}", "${desc}", "${mdl}", ${health}, ${speed}.0, ${armor});\n`
      if (type === 'human_special') body += `  zp_class_special_register(g_hc_${varid});\n`
      body += `}\n\n`
    }
  })

  return header + body
}