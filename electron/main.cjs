const { app, BrowserWindow, ipcMain, shell, net } = require('electron')
const path = require('node:path')
const fs = require('node:fs')
const os = require('node:os')

ipcMain.handle('app:get-version', () => app.getVersion())

function fetchHtmlDirect(targetUrl) {
  return new Promise((resolve, reject) => {
    let urlObj
    try {
      urlObj = new URL(targetUrl)
    } catch {
      reject(new Error('Invalid URL'))
      return
    }

    const request = net.request({
      url: targetUrl,
      method: 'GET',
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cache-Control': 'no-cache',
      },
    })

    let body = ''
    request.on('response', (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        const redirectUrl = Array.isArray(response.headers.location)
          ? response.headers.location[0]
          : response.headers.location
        const finalUrl = redirectUrl.startsWith('http')
          ? redirectUrl
          : new URL(redirectUrl, targetUrl).toString()
        return fetchHtmlDirect(finalUrl).then(resolve).catch(reject)
      }

      if (response.statusCode !== 200) {
        reject(new Error(`HTTP ${response.statusCode}`))
        return
      }

      response.on('data', (chunk) => {
        body += chunk.toString('utf-8')
      })
      response.on('end', () => resolve(body))
      response.on('error', reject)
    })

    request.on('error', reject)
    request.end()
  })
}

ipcMain.handle('article:fetch-html', async (event, url) => {
  return await fetchHtmlDirect(url)
})

ipcMain.handle('rss:fetch-raw', async (event, url) => {
  return await fetchHtmlDirect(url)
})

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

// Downloads the Windows installer, launches it via shell.openPath, and quits current app
ipcMain.handle('update:download-and-install', async (event, downloadUrl) => {
  const dest = path.join(os.tmpdir(), `FVNN-Setup-${Date.now()}.exe`)
  await downloadFile(downloadUrl, dest, (progressInfo) => {
    event.sender.send('update:progress', progressInfo)
  })

  try {
    await shell.openPath(dest)
  } catch (err) {
    // fallback
  }

  setTimeout(() => {
    app.quit()
  }, 800)
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
