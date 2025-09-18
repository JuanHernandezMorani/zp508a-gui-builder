import React, { useEffect, useMemo, useState } from 'react'
import type { ZPItem, ZPType, ZombieStats, HumanStats, WeaponStats, ShopItemStats } from '../../common/types'
import EditModal from '../../components/EditModal'
import { getDefaultStats } from '@common/zpUtils'

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

const emptyItem = (type: ZPType): ZPItem => {
  const base = {
    id: uuid(),
    name: '',
    fileName: '',
    enabled: true,
    description: '',
    meta: {},
    paths: { models: [], sounds: [], sprites: [] },
    source: 'ui' as const
  }

  switch (type) {
    case 'zombie_class':
      return { ...base, type: 'zombie_class', stats: getDefaultStats('zombie_class') as ZombieStats }
    case 'human_class':
      return { ...base, type: 'human_class', stats: getDefaultStats('human_class') as HumanStats }
    case 'zombie_special':
      return { ...base, type: 'zombie_special', stats: getDefaultStats('zombie_special') as ZombieStats }
    case 'human_special':
      return { ...base, type: 'human_special', stats: getDefaultStats('human_special') as HumanStats }
    case 'weapon':
      return { ...base, type: 'weapon', stats: getDefaultStats('weapon') as WeaponStats }
    case 'shop_item':
      return { ...base, type: 'shop_item', stats: getDefaultStats('shop_item') as ShopItemStats }
    case 'mode':
      return { ...base, type: 'mode', stats: {} }
    case 'system':
    default:
      return { ...base, type: 'system', stats: {} }
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

      {editing && (
        <EditModal
          item={editing}
          onClose={() => setEditing(null)}
          onSave={(it) => onSaveItem(it)}
        />
      )}
    </div>
  )
}
