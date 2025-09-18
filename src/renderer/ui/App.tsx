import React, { useEffect, useMemo, useState } from 'react'
import type { ZPItem, ZPType, ZombieStats, HumanStats, WeaponStats, ShopItemStats } from '../../common/types'

declare global { interface Window { zpb: any } }

const SECTIONS: { key: ZPType | "model" | "sprite" | "sound", label: string }[] = [
  { key: 'human_class', label: 'Clases Humano' },
  { key: 'zombie_class', label: 'Clases Zombie' },
  { key: 'human_special', label: 'Clases especiales Humano' },
  { key: 'zombie_special', label: 'Clases especiales Zombie' },
  { key: 'mode', label: 'Modos' },
  { key: 'weapon', label: 'Armas' },
  { key: 'shop_item', label: 'Objetos Extras' },
  { key: 'system', label: 'Sistemas extras' },
  { key: 'model', label: 'Modelos (.mdl)' },
  { key: 'sprite', label: 'Sprites (.spr)' },
  { key: 'sound', label: 'Sonidos (.wav)' },
]

function uuid() { return Math.random().toString(36).slice(2, 10) + Math.random().toString(36).slice(2, 10) }
function sanitizeFileName(s: string) { return s.trim().toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-_]/g, '') }

const emptyItem = (type: ZPType): ZPItem => ({ 
  id: uuid(), 
  name: '', 
  fileName: '', 
  type, 
  enabled: true, 
  description: '',
  stats: getDefaultStats(type), 
  meta: {}, 
  paths: { models: [], sounds: [], sprites: [] }, 
  source: 'ui' 
} as any)

function getDefaultStats(type: ZPType): any {
  switch (type) {
    case 'zombie_class':
      return { health: 2000, speed: 260, gravity: 0.8, knockback: 1.0 }
    case 'human_class':
      return { health: 100, speed: 240, armor: 100, base_damage: 1.0 }
    case 'zombie_special':
      return { health: 3000, speed: 280, gravity: 0.7, knockback: 1.2 }
    case 'human_special':
      return { health: 200, speed: 260, armor: 200, base_damage: 1.5 }
    case 'weapon':
      return { damage: 30, clip_capacity: 30, fire_rate: 0.1, reload_time: 2.5, cost: 15 }
    case 'shop_item':
      return { cost: 10, team: 0, unlimited: 0 }
    default:
      return {}
  }
}

export default function App() {
  const [items, setItems] = useState<ZPItem[]>([])
  const [sel, setSel] = useState<ZPType | "model" | "sprite" | "sound">('human_class')
  const [editing, setEditing] = useState<ZPItem | null>(null)
  const [problems, setProblems] = useState<string[]>([])
  const [compiled, setCompiled] = useState<string[]>([])
  const [cfg, setCfg] = useState<any>(null)
  const [models, setModels] = useState<string[]>([])
  const [sprites, setSprites] = useState<string[]>([])
  const [sounds, setSounds] = useState<string[]>([])

  const sectionItems = useMemo(() => items.filter(i => i.type === sel), [items, sel])

  useEffect(() => {
    window.zpb.list().then(setItems)
    window.zpb.getConfig().then(setCfg)
  }, [])

  function addNew() { if (typeof sel === "string" && !["model","sprite","sound"].includes(sel)) setEditing(emptyItem(sel as ZPType)) }
  function onSaveItem(it: ZPItem) {
    if (!it.fileName) it.fileName = sanitizeFileName(it.name || 'item')
    const updated = items.some(x => x.id === it.id) ? items.map(x => x.id === it.id ? it : x) : [...items, it]
    setItems(updated); window.zpb.save(updated); setEditing(null)
  }
  function onDelete(it: ZPItem) { const updated = items.filter(x => x.id !== it.id); setItems(updated); window.zpb.save(updated) }
  async function onScan() { const merged = await window.zpb.scanSMA(); setItems(merged) }
  async function onBuild() {
    const res = await window.zpb.build(items)
    if (!res.ok) { setProblems(res.problems || []); setCompiled([]) }
    else { setProblems([]); setCompiled(res.compiled || []); setCfg(res.cfg) }
  }
  async function onDetect() { const r = await window.zpb.detectZP(); if (r.ok) setCfg(r.cfg) }

  async function updateCfgField(k: string, v: string) {
    const n = { ...(cfg||{}), [k]: v }
    await window.zpb.setConfig(n)
    setCfg(n)
  }

  // --- funciones recursos ---
  async function refreshModels() { setModels(await window.zpb.scanMDL()) }
  async function refreshSprites() { setSprites(await window.zpb.scanSPR()) }
  async function refreshSounds() { setSounds(await window.zpb.scanWAV()) }

  async function deleteModel(m: string) { await window.zpb.deleteMDL(m); refreshModels() }
  async function deleteSprite(s: string) { await window.zpb.deleteSPR(s); refreshSprites() }
  async function deleteSound(s: string) { await window.zpb.deleteWAV(s); refreshSounds() }

  return (
    <div style={{fontFamily:'ui-sans-serif', display:'grid', gridTemplateColumns:'260px 1fr', height:'100vh'}}>
      <aside style={{padding:12, background:'#1f2937', color:'#fff'}}>
        <h2 style={{marginTop:0}}>ZP Builder UI 5.0</h2>
        {SECTIONS.map(s => (
          <button key={s.key} onClick={()=>setSel(s.key)}
            style={{display:'block', width:'100%', textAlign:'left', padding:8, marginBottom:6, background: sel===s.key?'#111827':'#374151', color:'#fff', border:'none', borderRadius:8}}>
            {s.label} {(["model","sprite","sound"].includes(s.key) ? 
              (s.key==="model"?models.length:s.key==="sprite"?sprites.length:sounds.length) 
              : `(${items.filter(i=>i.type===s.key).length})`)}
          </button>
        ))}

        <div style={{marginTop:16, display:'flex', flexDirection:'column', gap:8}}>
          <button onClick={addNew} disabled={["model","sprite","sound"].includes(sel)}>Añadir nuevo</button>
          <button onClick={onScan}>Revisar sma en input/</button>
          <button onClick={refreshModels}>Revisar mdl en input/</button>
          <button onClick={refreshSprites}>Revisar spr en input/</button>
          <button onClick={refreshSounds}>Revisar wav en input/</button>
          <button onClick={onBuild}>Guardar / Compilar</button>
        </div>

        <div style={{marginTop:16, background:'#111827', padding:8, borderRadius:8}}>
          <b>Config (ZP 5.0)</b>
          <div style={{marginTop:6}}>
            <label>amxxpcPath<br/>
              <input style={{width:'100%'}} value={cfg?.amxxpcPath||''} onChange={e=>updateCfgField('amxxpcPath', e.target.value)} placeholder="C:\...\amxxpc.exe"/>
            </label>
            <label style={{display:'block', marginTop:6}}>includeDirs (separar con ;)<br/>
              <input style={{width:'100%'}} value={(cfg?.includeDirs||[]).join(';')} onChange={e=>updateCfgField('includeDirs', e.target.value.split(';').map((s:string)=>s.trim()).filter(Boolean))} placeholder="C:\...\scripting\include"/>
            </label>
            <button style={{marginTop:6}} onClick={onDetect}>Detectar en input/</button>
          </div>
        </div>

        {problems.length>0 && (
          <div style={{marginTop:12, background:'#fee', color:'#111', padding:8, borderRadius:8}}>
            <b>Problemas</b>
            <ul>{problems.map((p: string, i:number)=><li key={i}>{p}</li>)}</ul>
          </div>
        )}

        {compiled.length>0 && (
          <div style={{marginTop:12, background:'#ecfdf5', color:'#065f46', padding:8, borderRadius:8}}>
            <b>Compilados</b>
            <ul>{compiled.map((p: string, i:number)=><li key={i}>{p}</li>)}</ul>
          </div>
        )}
      </aside>

      <main style={{padding:16, overflow:'auto'}}>
        {sel==="model" && (
          <div style={{display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px'}}>
            {models.map(m => (
              <div key={m} style={{border: '1px solid #444', borderRadius: '8px', padding: '8px', 
                                  background: '#2a2a2a', textAlign: 'center'}}>
                <img 
                  src={`zpb://models/${m.replace('.mdl', '.png')}?t=${Date.now()}`} 
                  alt={m}
                  style={{width: '100%', height: '120px', objectFit: 'contain', backgroundColor: '#1a1a1a',
                         border: '1px solid #333', borderRadius: '4px'}}
                  onError={(e) => {
                    e.currentTarget.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgZmlsbD0iIzMzMyIvPjx0ZXh0IHg9IjUwIiB5PSI1MCIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0iI2ZmZiIgZm9udC1zaXplPSIxMiI+TUQMLlBORzwvdGV4dD48L3N2Zz4=';
                  }}
                />
                <div style={{marginTop: '8px', fontSize: '12px', wordBreak: 'break-all', color: '#ccc'}}>{m}</div>
                <button onClick={() => deleteModel(m)} style={{marginTop: '8px', padding: '4px 8px', fontSize: '12px'}}>
                  Eliminar
                </button>
              </div>
            ))}
            {models.length===0 && <div style={{opacity:0.7, gridColumn: '1/-1', textAlign: 'center'}}>Sin modelos</div>}
          </div>
        )}
        
        {sel==="sprite" && (
          <div style={{display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px'}}>
            {sprites.map(s => (
              <div key={s} style={{border: '1px solid #444', borderRadius: '8px', padding: '8px', 
                                  background: '#2a2a2a', textAlign: 'center'}}>
                <img 
                  src={`zpb://sprites/${s.replace('.spr', '.png')}?t=${Date.now()}`} 
                  alt={s}
                  style={{width: '100%', height: '120px', objectFit: 'contain', backgroundColor: '#1a1a1a',
                         border: '1px solid #333', borderRadius: '4px'}}
                  onError={(e) => {
                    e.currentTarget.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgZmlsbD0iIzMzMyIvPjx0ZXh0IHg9IjUwIiB5PSI1MCIgZG9taW5hbnQtYmFzZWxpbmE9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0iI2ZmZiIgZm9udC1zaXplPSIxMiI+U1BSLlBORzwvdGV4dD48L3N2Zz4=';
                  }}
                />
                <div style={{marginTop: '8px', fontSize: '12px', wordBreak: 'break-all', color: '#ccc'}}>{s}</div>
                <button onClick={() => deleteSprite(s)} style={{marginTop: '8px', padding: '4px 8px', fontSize: '12px'}}>
                  Eliminar
                </button>
              </div>
            ))}
            {sprites.length===0 && <div style={{opacity:0.7, gridColumn: '1/-1', textAlign: 'center'}}>Sin sprites</div>}
          </div>
        )}
        
        {sel==="sound" && (
          <div style={{display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: '12px'}}>
            {sounds.map(s => (
              <div key={s} style={{border: '1px solid #444', borderRadius: '8px', padding: '8px', 
                                  background: '#2a2a2a', textAlign: 'center'}}>
                <img 
                  src={`zpb://sounds/${s.replace('.wav', '.png')}?t=${Date.now()}`} 
                  alt={s}
                  style={{width: '100%', height: '120px', objectFit: 'contain', backgroundColor: '#1a1a1a',
                         border: '1px solid #333', borderRadius: '4px'}}
                  onError={(e) => {
                    e.currentTarget.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgZmlsbD0iIzMzMyIvPjx0ZXh0IHg9IjUwIiB5PSI1MCIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZmlsbD0iI2ZmZiIgZm9udC1zaXplPSIxMiI+V0FWLlBORzwvdGV4dD48L3N2Zz4=';
                  }}
                />
                <div style={{marginTop: '8px', fontSize: '12px', wordBreak: 'break-all', color: '#ccc'}}>{s}</div>
                <button onClick={() => deleteSound(s)} style={{marginTop: '8px', padding: '4px 8px', fontSize: '12px'}}>
                  Eliminar
                </button>
              </div>
            ))}
            {sounds.length===0 && <div style={{opacity:0.7, gridColumn: '1/-1', textAlign: 'center'}}>Sin sonidos</div>}
          </div>
        )}

        {["model","sprite","sound"].includes(sel) ? null : (
          <table width="100%" cellPadding={6} style={{borderCollapse:'collapse'}}>
            <thead><tr style={{background:'#eee'}}><th>Habilitado</th><th>Nombre</th><th>Archivo</th><th>Acciones</th></tr></thead>
            <tbody>
              {items.filter(i=>i.type===sel).map(it => (
                <tr key={it.id} style={{borderBottom:'1px solid #ddd'}}>
                  <td><input type="checkbox" checked={it.enabled} onChange={e => {
                    const upd = {...it, enabled: e.target.checked}
                    const arr = items.map(x=>x.id===it.id?upd:x); setItems(arr); window.zpb.save(arr)
                  }} /></td>
                  <td>{it.name}</td>
                  <td>{it.fileName}.sma</td>
                  <td>
                    <button onClick={()=>setEditing(it)}>Editar</button>
                    <button onClick={()=>{ const arr=items.filter(x=>x.id!==it.id); setItems(arr); window.zpb.save(arr) }} style={{marginLeft:8}}>Eliminar</button>
                  </td>
                </tr>
              ))}
              {sectionItems.length===0 && <tr><td colSpan={4} style={{opacity:0.7}}>Sin elementos</td></tr>}
            </tbody>
          </table>
        )}
      </main>

      {editing && <Editor item={editing} onClose={()=>setEditing(null)} onSave={(it)=>onSaveItem(it)} />}
    </div>
  )
}

function Editor({ item, onClose, onSave }:{ item: ZPItem, onClose: ()=>void, onSave: (it: ZPItem)=>void }) {
  const [draft, setDraft] = useState<ZPItem>({...item})

  const renderSpecificFields = () => {
    switch (draft.type) {
      case 'zombie_class': {
        const zStats = draft.stats as ZombieStats
        return (
          <>
            <label>Vida: <input type="number" value={zStats.health || 2000} onChange={e => setDraft({...draft, stats: {...zStats, health: parseInt(e.target.value)}})} /></label>
            <label>Velocidad: <input type="number" value={zStats.speed || 260} onChange={e => setDraft({...draft, stats: {...zStats, speed: parseInt(e.target.value)}})} /></label>
            <label>Gravedad: <input type="number" step="0.1" value={zStats.gravity || 0.8} onChange={e => setDraft({...draft, stats: {...zStats, gravity: parseFloat(e.target.value)}})} /></label>
            <label>Knockback: <input type="number" step="0.1" value={zStats.knockback || 1.0} onChange={e => setDraft({...draft, stats: {...zStats, knockback: parseFloat(e.target.value)}})} /></label>
          </>
        )
      }
      case 'human_class': {
        const hStats = draft.stats as HumanStats
        return (
          <>
            <label>Vida: <input type="number" value={hStats.health || 100} onChange={e => setDraft({...draft, stats: {...hStats, health: parseInt(e.target.value)}})} /></label>
            <label>Velocidad: <input type="number" value={hStats.speed || 240} onChange={e => setDraft({...draft, stats: {...hStats, speed: parseInt(e.target.value)}})} /></label>
            <label>Chaleco: <input type="number" value={hStats.armor || 100} onChange={e => setDraft({...draft, stats: {...hStats, armor: parseInt(e.target.value)}})} /></label>
            <label>Daño base: <input type="number" step="0.1" value={hStats.base_damage || 1.0} onChange={e => setDraft({...draft, stats: {...hStats, base_damage: parseFloat(e.target.value)}})} /></label>
          </>
        )
      }
      case 'weapon': {
        const wStats = draft.stats as WeaponStats
        return (
          <>
            <label>Daño: <input type="number" value={wStats.damage || 30} onChange={e => setDraft({...draft, stats: {...wStats, damage: parseInt(e.target.value)}})} /></label>
            <label>Capacidad cargador: <input type="number" value={wStats.clip_capacity || 30} onChange={e => setDraft({...draft, stats: {...wStats, clip_capacity: parseInt(e.target.value)}})} /></label>
            <label>Cadencia: <input type="number" step="0.01" value={wStats.fire_rate || 0.1} onChange={e => setDraft({...draft, stats: {...wStats, fire_rate: parseFloat(e.target.value)}})} /></label>
            <label>Tiempo recarga: <input type="number" step="0.1" value={wStats.reload_time || 2.5} onChange={e => setDraft({...draft, stats: {...wStats, reload_time: parseFloat(e.target.value)}})} /></label>
            <label>Costo: <input type="number" value={wStats.cost || 15} onChange={e => setDraft({...draft, stats: {...wStats, cost: parseInt(e.target.value)}})} /></label>
          </>
        )
      }
      case 'shop_item': {
        const sStats = draft.stats as ShopItemStats
        return (
          <>
            <label>Costo: <input type="number" value={sStats.cost || 10} onChange={e => setDraft({...draft, stats: {...sStats, cost: parseInt(e.target.value)}})} /></label>
            <label>Equipo: 
              <select value={sStats.team || 0} onChange={e => setDraft({...draft, stats: {...sStats, team: parseInt(e.target.value)}})}>
                <option value={0}>Ambos</option>
                <option value={1}>Humano</option>
                <option value={2}>Zombie</option>
              </select>
            </label>
            <label>Ilimitado: 
              <select value={sStats.unlimited || 0} onChange={e => setDraft({...draft, stats: {...sStats, unlimited: parseInt(e.target.value)}})}>
                <option value={0}>No</option>
                <option value={1}>Sí</option>
              </select>
            </label>
          </>
        )
      }
      default:
        return <TextareaKV obj={draft.stats || {}} onChange={(o) => setDraft({ ...draft, stats: o })} />
    }
  }

  return (
    <div style={{position:'fixed', inset:0, background:'rgba(0,0,0,0.4)', display:'flex', alignItems:'center', justifyContent:'center'}}>
      <div style={{background:'#fff', padding:16, borderRadius:8, width:720, maxHeight: '80vh', overflow: 'auto'}}>
        <h3>Editar {draft.type}</h3>
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:12}}>
          <label>Nombre<input value={draft.name} onChange={e=>setDraft({...draft, name:e.target.value})} /></label>
          <label>Nombre de archivo (.sma)<input value={draft.fileName} onChange={e=>setDraft({...draft, fileName:e.target.value})} placeholder="auto" /></label>
          <label>Descripción<textarea value={draft.description || ''} onChange={e=>setDraft({...draft, description:e.target.value})} rows={2} /></label>
          <label>Tipo
            <select value={draft.type} onChange={e=>setDraft({...draft, type:e.target.value as any})}>
              <option value="human_class">Human Class</option>
              <option value="zombie_class">Zombie Class</option>
              <option value="human_special">Human Special</option>
              <option value="zombie_special">Zombie Special</option>
              <option value="mode">Mode</option>
              <option value="weapon">Weapon</option>
              <option value="shop_item">Shop Item</option>
              <option value="system">System</option>
            </select>
          </label>
          <label>Enabled<input type="checkbox" checked={draft.enabled} onChange={e=>setDraft({...draft, enabled:e.target.checked})} /></label>
        </div>

        <fieldset style={{marginTop:12}}>
          <legend>Atributos específicos</legend>
          <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:12}}>
            {renderSpecificFields()}
          </div>
        </fieldset>

        <fieldset style={{marginTop:12}}>
          <legend>Paths (models/sounds/sprites)</legend>
          <ArrayEdit label="Models" arr={draft.paths?.models||[]} onChange={(a)=>setDraft({...draft, paths:{...(draft.paths||{}), models:a}})} />
          <ArrayEdit label="Sounds" arr={draft.paths?.sounds||[]} onChange={(a)=>setDraft({...draft, paths:{...(draft.paths||{}), sounds:a}})} />
          <ArrayEdit label="Sprites" arr={draft.paths?.sprites||[]} onChange={(a)=>setDraft({...draft, paths:{...(draft.paths||{}), sprites:a}})} />
        </fieldset>

        <div style={{marginTop:12, display:'flex', justifyContent:'flex-end', gap:8}}>
          <button onClick={onClose}>Cancelar</button>
          <button onClick={()=>onSave(draft)}>Guardar</button>
        </div>
      </div>
    </div>
  )
}

function TextareaKV({ obj, onChange }:{ obj: Record<string, any>, onChange: (o: Record<string, any>)=>void }){
  const [txt, setTxt] = useState(Object.entries(obj).map(([k,v])=>`${k}=${v}`).join('\n'))
  useEffect(()=>{
    const out: Record<string, any> = {}
    txt.split(/\r?\n/).forEach(line=>{ const m = line.split('='); if (m.length>=2) out[m[0].trim()] = m.slice(1).join('=').trim() })
    onChange(out)
  }, [txt])
  return <textarea value={txt} onChange={e=>setTxt(e.target.value)} rows={6} style={{width:'100%'}}/>
}

function ArrayEdit({ label, arr, onChange }:{ label: string, arr: string[], onChange:(a:string[])=>void }){
  const [val, setVal] = useState('')
  return (
    <div style={{marginBottom:8}}>
      <b>{label}</b>
      <div style={{display:'flex', gap:8, marginTop:4}}>
        <input value={val} onChange={e=>setVal(e.target.value)} placeholder="ruta/model.mdl"/>
        <button onClick={()=>{ if(val.trim()){ onChange([...arr, val.trim()]); setVal('') } }}>Agregar</button>
      </div>
      <ul>{arr.map((x,i)=>(<li key={i}>{x} <button onClick={()=>onChange(arr.filter((_,j)=>j!==i))}>x</button></li>))}</ul>
    </div>
  )
}
