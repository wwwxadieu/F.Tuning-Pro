const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  isElectron: true,
  getAppVersion: () => ipcRenderer.invoke('app:get-version'),
  downloadAndInstallUpdate: (url) => ipcRenderer.invoke('update:download-and-install', url),
  fetchHtml: (url) => ipcRenderer.invoke('article:fetch-html', url),
  fetchRawRss: (url) => ipcRenderer.invoke('rss:fetch-raw', url),
  onUpdateProgress: (callback) => {
    const handler = (_event, data) => callback(data)
    ipcRenderer.on('update:progress', handler)
    return () => ipcRenderer.removeListener('update:progress', handler)
  },
})
