const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('zpb', {
  list: () => ipcRenderer.invoke('db:list'),
  save: (items) => ipcRenderer.invoke('db:save', items),
  scanSMA: () => ipcRenderer.invoke('scan:sma'),
  scanMDL: () => ipcRenderer.invoke('scan:mdl'),
  scanSPR: () => ipcRenderer.invoke('scan:spr'),
  scanWAV: () => ipcRenderer.invoke('scan:wav'),
  deleteMDL: (p) => ipcRenderer.invoke('delete:mdl', p),
  deleteSPR: (p) => ipcRenderer.invoke('delete:spr', p),
  deleteWAV: (p) => ipcRenderer.invoke('delete:wav', p),
  build: (items) => ipcRenderer.invoke('build:generate', items),
  detectZP: () => ipcRenderer.invoke('detect:zp50'),
  detectPython: () => ipcRenderer.invoke('detect:python'),
  setConfig: (cfg) => ipcRenderer.invoke('cfg:set', cfg),
  getConfig: () => ipcRenderer.invoke('cfg:get')
})
