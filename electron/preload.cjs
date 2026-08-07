const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  isElectron: true,
  getAppVersion: () => ipcRenderer.invoke('app:get-version'),
  downloadAndInstallUpdate: (url) => ipcRenderer.invoke('update:download-and-install', url),
  onUpdateProgress: (callback) => {
    const handler = (_event, percent) => callback(percent)
    ipcRenderer.on('update:progress', handler)
    return () => ipcRenderer.removeListener('update:progress', handler)
  },
})
