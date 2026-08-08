const { app, BrowserWindow, ipcMain, shell, net } = require('electron')
const { spawn } = require('node:child_process')
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
      let lastTime = Date.now()
      let lastReceived = 0
      let currentSpeed = 0

      response.on('data', (chunk) => {
        received += chunk.length
        file.write(chunk)

        const now = Date.now()
        const timeDiff = (now - lastTime) / 1000
        if (timeDiff >= 0.3) {
          currentSpeed = Math.round((received - lastReceived) / timeDiff)
          lastTime = now
          lastReceived = received
        }

        const percent = total ? Math.min(100, Math.round((received / total) * 100)) : 0
        onProgress({
          percent,
          transferred: received,
          total,
          bytesPerSecond: currentSpeed,
        })
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

// Downloads the Windows installer, passes progress/size/speed info,
// runs silent background update (/S), detaches process and restarts the app into the new version.
ipcMain.handle('update:download-and-install', async (event, downloadUrl) => {
  const dest = path.join(os.tmpdir(), `FVNN-Update-${Date.now()}.exe`)
  await downloadFile(downloadUrl, dest, (progressInfo) => {
    event.sender.send('update:progress', progressInfo)
  })

  try {
    const child = spawn(dest, ['/S', '--updated'], {
      detached: true,
      stdio: 'ignore',
    })
    child.unref()
  } catch (err) {
    await shell.openPath(dest)
  }

  setTimeout(() => {
    app.quit()
  }, 600)
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
