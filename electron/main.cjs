const { app, BrowserWindow, ipcMain, protocol } = require('electron')
const path = require('path')
const fs = require('fs')
const url = require('url')
const fse = require('fs-extra')
const { spawn, spawnSync } = require('child_process')
const { parseSMAEntities, normalizeName, normalizePath } = require('./smaParser.cjs')
const { ZP508a_DEFAULTS } = require('./defaults.cjs')

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
    case 'special_zombie_class': return 'scripting/classes/special/zombies'
    case 'special_human_class': return 'scripting/classes/special/humans'
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

const GROUPED_TYPE_OUTPUTS = {
  zombie_class: { file: 'zp_classes_zombie.sma', label: 'Clases Zombie' },
  human_class: { file: 'zp_classes_human.sma', label: 'Clases Humanas' },
  special_zombie_class: { file: 'zp_classes_special_zombie.sma', label: 'Clases Especiales Zombie' },
  special_human_class: { file: 'zp_classes_special_human.sma', label: 'Clases Especiales Humanas' },
  shop_item: { file: 'zp_items.sma', label: 'Ítems Extra' },
  mode: { file: 'zp_modes.sma', label: 'Modos de Juego' }
}

function emptyStatsForType(type) {
  switch (type) {
    case 'zombie_class':
    case 'special_zombie_class':
      return {
        health: STAT_DEFAULTS.zombie.health,
        speed: STAT_DEFAULTS.zombie.speed,
        gravity: STAT_DEFAULTS.zombie.gravity,
        knockback: STAT_DEFAULTS.zombie.knockback
      }
    case 'human_class':
    case 'special_human_class':
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
  else if (textLower.includes('zp_register_human_special_class') || textLower.includes('zp_register_survivor_class') ||
    textLower.includes('zp_register_sniper_class') || textLower.includes('zp_class_survivor_register') ||
    textLower.includes('zp_class_sniper_register')) type = 'special_human_class'
  else if (textLower.includes('zp_register_zombie_special_class') || textLower.includes('zp_register_nemesis_class') ||
    textLower.includes('zp_register_assassin_class') || textLower.includes('zp_class_nemesis_register') ||
    textLower.includes('zp_class_assassin_register')) type = 'special_zombie_class'
  else if (textLower.includes('zp_register_gamemode')) type = 'mode'
  else if (textLower.includes('zp_register_extra_item')) type = 'shop_item'
  else if (textLower.includes('zp_weapon_register')) type = 'weapon'
  else if (fnameLower.includes('zp50_class_assassin') || fnameLower.includes('zp50_class_nemesis') ||
    fnameLower.includes('zp50_class_dragon') || fnameLower.includes('zp50_class_nightcrawler') ||
    fnameLower.includes('zp50_class_plasma') || fnameLower.includes('zp50_class_knifer')) type = 'special_zombie_class'
  else if (fnameLower.includes('zp50_class_snier') || fnameLower.includes('zp50_class_survivor')) type = 'special_human_class'
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
    case 'special_zombie_class': {
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
    case 'special_human_class': {
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

  const sourceItems = Array.isArray(items) ? items : []

  for (const it of sourceItems) {
    if (!it || !it.enabled) continue
    if (!it.name) problems.push(`Falta nombre en un item (${it.fileName})`)
    if (['zombie_class', 'human_class', 'special_zombie_class', 'special_human_class'].includes(it.type)) {
      const hasModel = it.paths && Array.isArray(it.paths.models) && it.paths.models.length > 0
      if (!hasModel) problems.push(`Faltan models en ${it.name || it.fileName}`)
    }
  }
  if (problems.length) return { ok: false, problems }

  const byType = {}
  for (const it of sourceItems) {
    if (!it || !it.enabled) continue
    ; (byType[it.type] ||= []).push(it)
  }

  const scriptingDir = path.join(APP_DIRS.build, 'scripting')
  fse.ensureDirSync(scriptingDir)

  const groupedBaseNames = {}
  for (const [type, config] of Object.entries(GROUPED_TYPE_OUTPUTS)) {
    const arr = byType[type] || []
    const code = generateGroupedSMA(type, arr)
    const outPath = path.join(scriptingDir, config.file)
    fse.ensureDirSync(path.dirname(outPath))
    fs.writeFileSync(outPath, code, 'utf-8')
    groupedBaseNames[type] = config.file.replace(/\.sma$/i, '')
  }

  for (const [type, arr] of Object.entries(byType)) {
    if (GROUPED_TYPE_OUTPUTS[type]) continue
    const outDir = path.join(APP_DIRS.build, mapTypeDir(type))
    fse.ensureDirSync(outDir)
    for (const it of arr) {
      const code = generateSMA_ZP50(it)
      const outPath = path.join(outDir, `${it.fileName}.sma`)
      fs.writeFileSync(outPath, code, 'utf-8')
    }
  }

  const cfgDir = path.join(APP_DIRS.build, 'configs')
  fse.ensureDirSync(cfgDir)

  const classesIniLines = [
    '; Auto generado por ZP Builder UI',
    '[ZOMBIE_CLASSES]'
  ]
  if ((byType['zombie_class'] || []).length) classesIniLines.push(groupedBaseNames['zombie_class'])
  classesIniLines.push('')
  classesIniLines.push('[HUMAN_CLASSES]')
  if ((byType['human_class'] || []).length) classesIniLines.push(groupedBaseNames['human_class'])
  classesIniLines.push('')
  classesIniLines.push('[SPECIAL_ZOMBIE_CLASSES]')
  if ((byType['special_zombie_class'] || []).length) classesIniLines.push(groupedBaseNames['special_zombie_class'])
  classesIniLines.push('')
  classesIniLines.push('[SPECIAL_HUMAN_CLASSES]')
  if ((byType['special_human_class'] || []).length) classesIniLines.push(groupedBaseNames['special_human_class'])
  const classesIni = classesIniLines.join('\n') + '\n'
  fs.writeFileSync(path.join(cfgDir, 'classes.ini'), classesIni, 'utf-8')

  const humanCfg = (byType['human_class'] || []).length ? `${groupedBaseNames['human_class']}\n` : '; Sin clases humanas\n'
  const zombieCfg = (byType['zombie_class'] || []).length ? `${groupedBaseNames['zombie_class']}\n` : '; Sin clases zombie\n'
  const itemsCfg = (byType['shop_item'] || []).length ? `${groupedBaseNames['shop_item']}\n` : '; Sin ítems extra\n'
  const modesCfg = (byType['mode'] || []).length ? `${groupedBaseNames['mode']}\n` : '; Sin modos registrados\n'
  fs.writeFileSync(path.join(cfgDir, 'zp_humanclasses.ini'), humanCfg, 'utf-8')
  fs.writeFileSync(path.join(cfgDir, 'zp_zombieclasses.ini'), zombieCfg, 'utf-8')
  fs.writeFileSync(path.join(cfgDir, 'zp_extraitems.ini'), itemsCfg, 'utf-8')
  fs.writeFileSync(path.join(cfgDir, 'zp_gamemodes.ini'), modesCfg, 'utf-8')

  seedDefaultSystems(APP_DIRS.systems, APP_DIRS.build)

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
const SHOP_DEFAULTS = { cost: 0, team: 0, unlimited: 0 }

function generateGroupedSMA(type, items) {
  const entries = Array.isArray(items) ? items : []
  const now = new Date().toISOString()
  const warnings = collectWarnings(entries)
  const includes = new Set(['#include <amxmodx>', '#include <zp50_core>'])
  const config = GROUPED_TYPE_OUTPUTS[type] || {}
  const pluginLabel = config.label || type

  let body = ''
  switch (type) {
    case 'zombie_class':
    case 'special_zombie_class':
      includes.add('#include <zp50_class_zombie>')
      if (type === 'special_zombie_class') includes.add('#include <zp50_class_special>')
      body = buildClassBody(type, entries)
      break
    case 'human_class':
    case 'special_human_class':
      includes.add('#include <zp50_class_human>')
      if (type === 'special_human_class') includes.add('#include <zp50_class_special>')
      body = buildClassBody(type, entries)
      break
    case 'shop_item':
      includes.add('#include <zp50_items>')
      body = buildShopItemBody(entries)
      break
    case 'mode':
      includes.add('#include <zp50_gamemodes>')
      body = buildModeBody(entries)
      break
    default:
      body = '// Tipo de agrupación no soportado.\n'
  }

  const headerLines = [
    '// Auto generado por ZP Builder UI (ZP 5.0.8a)',
    `// Fecha: ${now}`,
    `// Entidades: ${entries.length}`
  ]
  if (warnings.length) {
    headerLines.push('// Warnings detectados:')
    for (const warn of warnings) headerLines.push(`// - ${warn}`)
  } else {
    headerLines.push('// Warnings detectados: ninguno')
  }

  const pluginInit = `public plugin_init() { register_plugin("${escapePawnString(`ZPBuilder - ${pluginLabel}`)}", "0.4.0", "ZPBuilder"); }`
  const precacheBlock = buildPrecacheBlock(entries)
  const sections = [
    headerLines.join('\n'),
    Array.from(includes).join('\n'),
    '',
    pluginInit,
    '',
    precacheBlock,
    '',
    body
  ]

  return sections.filter(Boolean).join('\n').replace(/\n{3,}/g, '\n\n') + '\n'
}

function collectWarnings(items) {
  const set = new Set()
  for (const item of items || []) {
    const warnings = Array.isArray(item?.meta?.warnings) ? item.meta.warnings : []
    for (const warn of warnings) {
      const text = String(warn || '').trim()
      if (text) set.add(text)
    }
  }
  return Array.from(set)
}

function collectGroupedResources(items) {
  const models = []
  const sounds = []
  const sprites = []
  const seen = {
    models: new Set(),
    sounds: new Set(),
    sprites: new Set()
  }
  for (const item of items || []) {
    const paths = item?.paths || {}
    for (const model of Array.isArray(paths.models) ? paths.models : []) {
      const normalized = normalizePath(model)
      if (!normalized) continue
      const key = normalized.toLowerCase()
      if (seen.models.has(key)) continue
      seen.models.add(key)
      models.push(normalized)
    }
    for (const sound of Array.isArray(paths.sounds) ? paths.sounds : []) {
      const normalized = normalizePath(sound)
      if (!normalized) continue
      const key = normalized.toLowerCase()
      if (seen.sounds.has(key)) continue
      seen.sounds.add(key)
      sounds.push(normalized)
    }
    for (const sprite of Array.isArray(paths.sprites) ? paths.sprites : []) {
      const normalized = normalizePath(sprite)
      if (!normalized) continue
      const key = normalized.toLowerCase()
      if (seen.sprites.has(key)) continue
      seen.sprites.add(key)
      sprites.push(normalized)
    }
  }
  return { models, sounds, sprites }
}

function buildPrecacheBlock(items) {
  const resources = collectGroupedResources(items)
  const lines = ['public plugin_precache() {']
  if (!resources.models.length && !resources.sounds.length && !resources.sprites.length) {
    lines.push('  // Sin recursos adicionales')
  } else {
    for (const model of resources.models) lines.push(`  precache_model("${escapePawnString(model)}");`)
    for (const sound of resources.sounds) lines.push(`  precache_sound("${escapePawnString(sound)}");`)
    for (const sprite of resources.sprites) lines.push(`  precache_generic("${escapePawnString(sprite)}");`)
  }
  lines.push('}')
  return lines.join('\n')
}

function escapePawnString(value) {
  return String(value ?? '').replace(/\\/g, '\\').replace(/"/g, '\"')
}

function sanitizeIdentifier(value, used) {
  let base = typeof value === 'string' ? value : ''
  base = base.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
  if (!base) base = 'entry'
  if (!/^[a-z_]/.test(base)) base = `id_${base}`
  let candidate = base
  let counter = 2
  while (used.has(candidate)) {
    candidate = `${base}_${counter++}`
  }
  used.add(candidate)
  return candidate
}

function formatFloat(value) {
  const num = Number(value)
  if (!Number.isFinite(num)) return '0.0'
  if (Number.isInteger(num)) return `${num}.0`
  return num.toString()
}

function formatInt(value, fallback = 0) {
  const num = Number(value)
  if (!Number.isFinite(num)) {
    const fb = Number(fallback)
    return String(Number.isFinite(fb) ? Math.round(fb) : 0)
  }
  return String(Math.round(num))
}

function resolveClassStats(type, stats) {
  const defaults = ZP508a_DEFAULTS[type] || {}
  return { ...defaults, ...(stats || {}) }
}

function buildClassBody(type, items) {
  const entries = Array.isArray(items) ? items : []
  const isZombie = type === 'zombie_class' || type === 'special_zombie_class'
  const isSpecial = type === 'special_zombie_class' || type === 'special_human_class'
  const registerFn = isZombie ? 'zp_fw_class_zombie_register' : 'zp_fw_class_human_register'
  const varPrefix = isZombie ? 'g_zc' : 'g_hc'
  const usedIds = new Set()
  const prepared = entries.map((item, index) => ({
    item,
    varId: sanitizeIdentifier(item.fileName || item.name || `entry_${index + 1}`, usedIds)
  }))

  if (!prepared.length) {
    return `public ${registerFn}() {\n  // Sin registros\n}`
  }

  const lines = []
  for (const entry of prepared) lines.push(`new ${varPrefix}_${entry.varId};`)
  lines.push('')
  lines.push(`public ${registerFn}() {`)
  prepared.forEach(({ item, varId }, index) => {
    const stats = resolveClassStats(type, item.stats)
    const defaults = ZP508a_DEFAULTS[type] || {}
    const name = escapePawnString(item.name || `Entrada ${index + 1}`)
    const descDefault = isZombie ? (isSpecial ? 'Clase zombie especial' : 'Clase zombie') : (isSpecial ? 'Clase humana especial' : 'Clase humana')
    const description = escapePawnString(item.description || descDefault)
    const modelFallback = isZombie ? 'zombie_source' : 'terror'
    const model = escapePawnString((item.paths?.models && item.paths.models[0]) || modelFallback)
    const health = formatInt(stats.health, defaults.health)
    const speed = formatFloat(stats.speed ?? defaults.speed)
    const gravity = formatFloat(stats.gravity ?? defaults.gravity ?? 1.0)
    const armor = formatInt(stats.armor, defaults.armor)
    const knockback = formatFloat(stats.knockback ?? defaults.knockback ?? 1.0)

    lines.push(`  // ${item.name || `Entrada ${index + 1}`}`)
    if (isZombie) {
      lines.push(`  ${varPrefix}_${varId} = zp_class_zombie_register("${name}", "${description}", "${model}", "v_knife_zombie.mdl", ${health}, ${speed}, ${gravity});`)
      lines.push(`  zp_class_zombie_register_kb(${varPrefix}_${varId}, ${knockback});`)
    } else {
      lines.push(`  ${varPrefix}_${varId} = zp_class_human_register("${name}", "${description}", "${model}", ${health}, ${speed}, ${armor});`)
    }
    if (isSpecial) {
      lines.push(`  zp_class_special_register(${varPrefix}_${varId});`)
    }
    if (index !== prepared.length - 1) lines.push('')
  })
  lines.push('}')
  return lines.join('\n')
}

function buildShopItemBody(items) {
  const entries = Array.isArray(items) ? items : []
  const usedIds = new Set()
  const prepared = entries.map((item, index) => ({
    item,
    varId: sanitizeIdentifier(item.fileName || item.name || `item_${index + 1}`, usedIds)
  }))

  if (!prepared.length) {
    return 'public zp_fw_items_register() {\n  // Sin registros\n}'
  }

  const lines = []
  for (const entry of prepared) lines.push(`new g_item_${entry.varId};`)
  lines.push('')
  lines.push('public zp_fw_items_register() {')
  prepared.forEach(({ item, varId }, index) => {
    const stats = { ...SHOP_DEFAULTS, ...(item.stats || {}) }
    const name = escapePawnString(item.name || `Ítem ${index + 1}`)
    const cost = formatInt(stats.cost, SHOP_DEFAULTS.cost)
    const team = formatInt(stats.team, SHOP_DEFAULTS.team)
    const unlimited = formatInt(stats.unlimited, SHOP_DEFAULTS.unlimited)
    lines.push(`  // ${item.name || `Ítem ${index + 1}`}`)
    lines.push(`  g_item_${varId} = zp_item_register("${name}", ${cost}, ${team});`)
    if (Number(team)) lines.push(`  // Equipo asignado: ${team}`)
    if (Number(unlimited)) lines.push(`  // Stock ilimitado configurado: ${unlimited}`)
    if (index !== prepared.length - 1) lines.push('')
  })
  lines.push('}')
  return lines.join('\n')
}

function buildModeBody(items) {
  const entries = Array.isArray(items) ? items : []
  const usedIds = new Set()
  const prepared = entries.map((item, index) => ({
    item,
    varId: sanitizeIdentifier(item.fileName || item.name || `mode_${index + 1}`, usedIds)
  }))

  if (!prepared.length) {
    return 'public zp_fw_gamemodes_register() {\n  // Sin registros\n}'
  }

  const lines = []
  for (const entry of prepared) lines.push(`new g_mode_${entry.varId};`)
  lines.push('')
  lines.push('public zp_fw_gamemodes_register() {')
  prepared.forEach(({ item, varId }, index) => {
    const name = escapePawnString(item.name || `Modo ${index + 1}`)
    lines.push(`  // ${item.name || `Modo ${index + 1}`}`)
    lines.push(`  g_mode_${varId} = zp_gamemode_register("${name}", ZP_GAMEMODE_CLASSIC, ZP_GAMEMODE_FLAG_INFECTION);`)
    if (index !== prepared.length - 1) lines.push('')
  })
  lines.push('}')
  return lines.join('\n')
}