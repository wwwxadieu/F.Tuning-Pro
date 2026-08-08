const { app, BrowserWindow, ipcMain, shell, net } = require('electron')
const path = require('node:path')
const fs = require('node:fs')
const os = require('node:os')

ipcMain.handle('app:get-version', () => app.getVersion())

// The renderer can't fetch article pages itself — it runs on a file:// origin,
// so every news site's response is blocked by CORS. That's the only reason the
// reader ever went through a third-party text-extraction proxy. The main
// process has no such restriction, so it can pull the page straight from the
// publisher: measured at ~2-3s versus 7-21s (frequently timing out) through
// the proxy, with no shared rate limit to get stuck behind.
const ARTICLE_FETCH_TIMEOUT_MS = 15_000
const MAX_ARTICLE_BYTES = 8 * 1024 * 1024

ipcMain.handle('article:fetch-html', async (_event, url) => {
  let parsed
  try {
    parsed = new URL(url)
  } catch {
    return { ok: false, error: 'URL không hợp lệ' }
  }
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
    return { ok: false, error: 'Giao thức không được hỗ trợ' }
  }

  try {
    const res = await net.fetch(parsed.href, {
      method: 'GET',
      redirect: 'follow',
      headers: {
        // Some publishers serve a stripped or blocked page to non-browser
        // clients, so present as the browser this actually is.
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.8',
      },
      signal: AbortSignal.timeout(ARTICLE_FETCH_TIMEOUT_MS),
    })
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}` }

    const contentType = res.headers.get('content-type') ?? ''
    if (contentType && !/(text\/html|application\/xhtml|text\/plain|xml)/i.test(contentType)) {
      return { ok: false, error: `Loại nội dung không đọc được: ${contentType}` }
    }

    const buffer = await res.arrayBuffer()
    if (buffer.byteLength > MAX_ARTICLE_BYTES) {
      return { ok: false, error: 'Trang quá lớn' }
    }

    // Vietnamese news sites are overwhelmingly UTF-8, but a few older ones
    // still serve windows-1258/latin1 — honour the declared charset so
    // accented characters don't come through mangled.
    const charsetMatch = contentType.match(/charset=([^;\s]+)/i)
    let html
    try {
      html = new TextDecoder(charsetMatch?.[1] ?? 'utf-8').decode(buffer)
    } catch {
      html = new TextDecoder('utf-8').decode(buffer)
    }

    return { ok: true, html, finalUrl: res.url || parsed.href }
  } catch (err) {
    return { ok: false, error: err?.message ?? 'Không thể tải trang' }
  }
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
