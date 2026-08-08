const { app, BrowserWindow, ipcMain, shell, net } = require('electron')
const path = require('node:path')
const fs = require('node:fs')
const os = require('node:os')

ipcMain.handle('app:get-version', () => app.getVersion())

// Guards so a slow or oversized page can't leave the reader spinning forever
// or balloon memory: a hung request has no natural end, and a few sites serve
// multi-megabyte pages we have no use for.
const ARTICLE_FETCH_TIMEOUT_MS = 15_000
const MAX_ARTICLE_BYTES = 8 * 1024 * 1024
const MAX_REDIRECTS = 5

function fetchHtmlDirect(targetUrl, redirectsLeft = MAX_REDIRECTS) {
  return new Promise((resolve, reject) => {
    try {
      new URL(targetUrl)
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

    const timer = setTimeout(() => {
      request.abort()
      reject(new Error('Hết thời gian tải trang'))
    }, ARTICLE_FETCH_TIMEOUT_MS)
    const settle = (fn) => (value) => {
      clearTimeout(timer)
      fn(value)
    }
    const done = settle(resolve)
    const fail = settle(reject)

    request.on('response', (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        if (redirectsLeft <= 0) {
          fail(new Error('Quá nhiều chuyển hướng'))
          return
        }
        const redirectUrl = Array.isArray(response.headers.location)
          ? response.headers.location[0]
          : response.headers.location
        const finalUrl = new URL(redirectUrl, targetUrl).toString()
        clearTimeout(timer)
        return fetchHtmlDirect(finalUrl, redirectsLeft - 1).then(resolve).catch(reject)
      }

      if (response.statusCode !== 200) {
        fail(new Error(`HTTP ${response.statusCode}`))
        return
      }

      // Decoding each chunk on its own splits any multi-byte character that
      // straddles a chunk boundary into replacement characters — which in
      // Vietnamese text means roughly every accented word is a candidate for
      // corruption. Collect the bytes and decode once, at the end.
      const chunks = []
      let received = 0
      response.on('data', (chunk) => {
        received += chunk.length
        if (received > MAX_ARTICLE_BYTES) {
          request.abort()
          fail(new Error('Trang quá lớn'))
          return
        }
        chunks.push(chunk)
      })
      response.on('end', () => {
        const buffer = Buffer.concat(chunks)
        const charset = /charset=["']?([\w-]+)/i.exec(response.headers['content-type'] ?? '')?.[1]
        let text
        try {
          text = new TextDecoder(charset || 'utf-8').decode(buffer)
        } catch {
          text = buffer.toString('utf-8')
        }
        done(text)
      })
      response.on('error', fail)
    })

    request.on('error', fail)
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
