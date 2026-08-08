const { app, BrowserWindow, ipcMain, shell, net } = require('electron')
const path = require('node:path')
const fs = require('node:fs')
const os = require('node:os')
const { spawn } = require('node:child_process')

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

// Translation runs here rather than in the renderer for two reasons: a POST
// body has no practical length limit, where the GET form the renderer used for
// short titles would truncate an article paragraph into an over-long URL; and
// requests carry a normal browser User-Agent, which the endpoint is far less
// likely to turn away.
const TRANSLATE_TIMEOUT_MS = 20_000
const MYMEMORY_MAX_CHARS = 500

const delay = (ms) => new Promise((r) => setTimeout(r, ms))
const GOOGLE_RETRIES = 2

// Translating a whole article is several requests in a row, which is enough to
// trip the endpoint's rate limit — it then answers 429 with an HTML challenge
// page rather than JSON. That is why translating one article could work and
// the very next one fail outright. A short backoff clears it most of the time.
// GET is the form this endpoint is actually known to serve — it is what the
// app has always used for headlines. POST is kept only for text too long to
// sit in a URL; it is unverified, so it must never be the default path.
const MAX_GET_URL_CHARS = 7000
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

async function translateViaGoogle(text, target, attempt = 0) {
  const base = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${encodeURIComponent(target)}&dt=t`
  const encoded = encodeURIComponent(text)
  const useGet = base.length + encoded.length + 3 <= MAX_GET_URL_CHARS

  const res = useGet
    ? await net.fetch(`${base}&q=${encoded}`, {
        headers: { 'User-Agent': UA },
        signal: AbortSignal.timeout(TRANSLATE_TIMEOUT_MS),
      })
    : await net.fetch(base, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
          'User-Agent': UA,
        },
        body: new URLSearchParams({ q: text }).toString(),
        signal: AbortSignal.timeout(TRANSLATE_TIMEOUT_MS),
      })

  if ((res.status === 429 || res.status === 503) && attempt < GOOGLE_RETRIES) {
    await delay(900 * (attempt + 1))
    return translateViaGoogle(text, target, attempt + 1)
  }
  if (!res.ok) throw new Error(`translate HTTP ${res.status}`)

  // A rate-limited or challenged response can still arrive as 200 HTML, so
  // don't let a raw JSON.parse failure surface as an unrelated syntax error.
  const raw = await res.text()
  let data
  try {
    data = JSON.parse(raw)
  } catch {
    throw new Error('Dịch vụ dịch tạm thời từ chối yêu cầu')
  }

  const segments = Array.isArray(data) ? data[0] : null
  if (!Array.isArray(segments)) throw new Error('Phản hồi dịch không hợp lệ')
  // Segments are per-sentence and carry their own line breaks, so joining
  // with no separator reproduces the paragraph structure that was sent in.
  const out = segments.map((s) => (Array.isArray(s) ? String(s[0] ?? '') : '')).join('')
  if (!out.trim()) throw new Error('Kết quả dịch rỗng')
  return out
}

function splitToLength(line, limit) {
  if (line.length <= limit) return [line]
  const pieces = []
  let rest = line
  while (rest.length > limit) {
    // Break at the last space inside the limit so a word isn't cut in half.
    let cut = rest.lastIndexOf(' ', limit)
    if (cut <= 0) cut = limit
    pieces.push(rest.slice(0, cut))
    rest = rest.slice(cut).trimStart()
  }
  if (rest) pieces.push(rest)
  return pieces
}

async function myMemoryOnce(text, target) {
  const url =
    'https://api.mymemory.translated.net/get?q=' +
    encodeURIComponent(text) +
    `&langpair=${encodeURIComponent('en|' + target)}`
  const res = await net.fetch(url, { signal: AbortSignal.timeout(TRANSLATE_TIMEOUT_MS) })
  if (!res.ok) throw new Error(`mymemory HTTP ${res.status}`)
  const data = JSON.parse(await res.text())
  if (data?.responseStatus !== 200) throw new Error(String(data?.responseDetails ?? 'lỗi dịch'))
  const out = String(data?.responseData?.translatedText ?? '')
  if (!out.trim()) throw new Error('Kết quả dịch rỗng')
  return out
}

// Hard cap per request on this service, so anything article-sized has to be
// broken up. Previously it simply refused, which made the fallback useless for
// exactly the case it existed to cover.
const MYMEMORY_MAX_PIECES = 16

async function translateViaMyMemory(text, target) {
  // The caller joins paragraphs with newlines and splits the result back on
  // them, so the line count has to survive exactly — translate line by line.
  const lines = text.split('\n')
  const pieceCount = lines.reduce(
    (n, l) => n + (l.trim() ? splitToLength(l, MYMEMORY_MAX_CHARS).length : 0),
    0
  )
  if (pieceCount > MYMEMORY_MAX_PIECES) {
    throw new Error('Đoạn văn quá dài cho nguồn dự phòng')
  }

  const out = []
  for (const line of lines) {
    if (!line.trim()) {
      out.push(line)
      continue
    }
    const parts = []
    for (const piece of splitToLength(line, MYMEMORY_MAX_CHARS)) {
      parts.push(await myMemoryOnce(piece, target))
    }
    out.push(parts.join(' '))
  }
  return out.join('\n')
}

ipcMain.handle('translate:text', async (_event, text, target = 'vi') => {
  if (typeof text !== 'string' || !text.trim()) return text
  try {
    return await translateViaGoogle(text, target)
  } catch (err) {
    // MyMemory only accepts 500 characters at a time and needs an explicit
    // source language, so it cannot cover every case — but for a short
    // paragraph it is better than showing the reader nothing.
    try {
      return await translateViaMyMemory(text, target)
    } catch {
      throw err
    }
  }
})

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

// Flags the electron-builder NSIS installer understands (see its
// installSection.nsh / allowOnlyOneInstallerInstance.nsh templates):
//
//   --updated    Tells the installer this is an update. Without it, finding
//                the app still running makes it show a modal "app is running"
//                prompt and then `Quit` — aborting the install outright. That
//                is why launching it with no arguments left the old version in
//                place: the app exited, the installer gave up, nothing changed.
//                With the flag it waits for the app to exit, then taskkills.
//   /S           Install silently, with no installer window.
//   --force-run  Relaunch the app afterwards. A one-click installer only
//                auto-starts the app when NOT silent, so going silent without
//                this is what left the app closed after updating.
const INSTALLER_ARGS = ['--updated', '/S', '--force-run']

// shell.openPath can't pass arguments, so the installer has to be spawned
// directly — detached, so it outlives the app it is about to replace.
function launchInstaller(installerPath) {
  return new Promise((resolve) => {
    let settled = false
    const finish = (ok) => {
      if (!settled) {
        settled = true
        resolve(ok)
      }
    }
    try {
      const child = spawn(installerPath, INSTALLER_ARGS, {
        detached: true,
        stdio: 'ignore',
        windowsHide: true,
      })
      child.once('error', () => finish(false))
      child.unref()
      // No error almost immediately means the process is up; the installer
      // itself runs long after this resolves.
      setTimeout(() => finish(true), 600)
    } catch {
      finish(false)
    }
  })
}

// Downloading the whole 78MB installer for every update is almost all wasted
// bytes: the Electron runtime inside it is byte-identical between releases and
// only the app code actually changed. electron-builder already publishes a
// .blockmap alongside each installer describing its blocks, and
// electron-updater uses it to fetch only the blocks that differ — so a
// code-only update transfers a few MB instead of the full package.
async function installViaUpdater(event) {
  const { autoUpdater } = require('electron-updater')
  autoUpdater.autoDownload = false
  autoUpdater.autoInstallOnAppQuit = false
  autoUpdater.allowDowngrade = false
  // The whole point: reuse the installed package's blocks.
  autoUpdater.disableDifferentialDownload = false

  const onProgress = (info) => {
    event.sender.send('update:progress', {
      percent: Math.round(info.percent ?? 0),
      transferred: info.transferred ?? 0,
      total: info.total ?? 0,
      bytesPerSecond: Math.round(info.bytesPerSecond ?? 0),
    })
  }
  autoUpdater.on('download-progress', onProgress)

  try {
    const result = await autoUpdater.checkForUpdates()
    if (!result?.updateInfo) throw new Error('Không tìm thấy thông tin bản cập nhật')
    await autoUpdater.downloadUpdate(result.cancellationToken)
    // isSilent=true, isForceRunAfter=true — install without a wizard and
    // relaunch afterwards. quitAndInstall handles quitting this process.
    setTimeout(() => autoUpdater.quitAndInstall(true, true), 300)
  } finally {
    autoUpdater.removeListener('download-progress', onProgress)
  }
}

// The original path: download the full installer and run it. Kept as a
// fallback so a problem in the differential path can't strand anyone on an
// old version — which has already happened once.
async function installViaFullDownload(event, downloadUrl) {
  const dest = path.join(os.tmpdir(), `FVNN-Setup-${Date.now()}.exe`)
  await downloadFile(downloadUrl, dest, (progressInfo) => {
    event.sender.send('update:progress', progressInfo)
  })

  const launched = await launchInstaller(dest)
  if (!launched) {
    // Couldn't spawn it — open the installer visibly so the user can finish by
    // hand rather than being left on the old version with no explanation.
    await shell.openPath(dest)
  }

  // Exit promptly: the installer is already waiting on this process to release
  // its files, and every extra moment is time it spends stuck in that loop.
  setTimeout(() => app.quit(), 300)
}

ipcMain.handle('update:download-and-install', async (event, downloadUrl) => {
  try {
    await installViaUpdater(event)
  } catch (err) {
    if (!downloadUrl) throw err
    await installViaFullDownload(event, downloadUrl)
  }
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
