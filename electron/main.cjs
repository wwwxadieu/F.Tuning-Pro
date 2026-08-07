const { app, BrowserWindow, ipcMain, shell, net } = require('electron')
const path = require('node:path')
const fs = require('node:fs')
const os = require('node:os')

ipcMain.handle('app:get-version', () => app.getVersion())

function downloadFile(url, dest, onProgress) {
  return new Promise((resolve, reject) => {
    const request = net.request(url)
    const file = fs.createWriteStream(dest)
    request.on('response', (response) => {
      if (response.statusCode !== 200) {
        file.close()
        fs.unlink(dest, () => {})
        reject(new Error(`Download HTTP ${response.statusCode}`))
        return
      }
      const total = parseInt(response.headers['content-length'] ?? '0', 10)
      let received = 0
      response.on('data', (chunk) => {
        received += chunk.length
        file.write(chunk)
        if (total) onProgress(Math.round((received / total) * 100))
      })
      response.on('end', () => file.end(resolve))
      response.on('error', reject)
    })
    request.on('error', (err) => {
      file.close()
      fs.unlink(dest, () => reject(err))
    })
    request.end()
  })
}

// Downloads the Windows installer straight into the app (no browser hop),
// launches it like a double-click, then quits so the installer can
// overwrite this running instance's files without a lock conflict.
ipcMain.handle('update:download-and-install', async (event, downloadUrl) => {
  const dest = path.join(os.tmpdir(), `FVNN-Update-${Date.now()}.exe`)
  await downloadFile(downloadUrl, dest, (percent) => {
    event.sender.send('update:progress', percent)
  })
  const openError = await shell.openPath(dest)
  if (openError) throw new Error(openError)
  setTimeout(() => app.quit(), 800)
})

function createWindow() {
  const win = new BrowserWindow({
    width: 1360,
    height: 900,
    minWidth: 720,
    minHeight: 480,
    backgroundColor: '#000000',
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, 'preload.cjs'),
    },
  })

  // Article links (target="_blank") should open in the user's real browser,
  // not spawn another Electron window.
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'))
}

app.whenReady().then(() => {
  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})
