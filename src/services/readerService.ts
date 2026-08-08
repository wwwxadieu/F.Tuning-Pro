import { marked } from 'marked'
import DOMPurify from 'dompurify'

export interface ReaderContent {
  title: string | null
  html: string
}

const CACHE_PREFIX = 'luong:reader:'
const CACHE_TTL_MS = 60 * 60 * 1000 // 1 hour

const AUTHOR_CARD_RE = /\[!\[[^\]]*\]\([^)]*\)\]\((https?:\/\/[^)]*\/(?:profile|user|author|u)\/[^)]*)\)/g

function isolateOriginalPost(markdown: string): string {
  const matches = [...markdown.matchAll(AUTHOR_CARD_RE)]
  if (matches.length < 2) return markdown
  const start = matches[0].index! + matches[0][0].length
  const end = matches[1].index!
  const isolated = markdown.slice(start, end).trim()
  return isolated || markdown
}

function readCache(url: string): ReaderContent | null {
  try {
    const raw = sessionStorage.getItem(CACHE_PREFIX + url)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { savedAt: number; content: ReaderContent }
    if (Date.now() - parsed.savedAt > CACHE_TTL_MS) return null
    return parsed.content
  } catch {
    return null
  }
}

function writeCache(url: string, content: ReaderContent) {
  try {
    sessionStorage.setItem(CACHE_PREFIX + url, JSON.stringify({ savedAt: Date.now(), content }))
  } catch {
    // ignore
  }
}

const FETCH_TIMEOUT_MS = 12_000

async function fetchViaJina(url: string, signal?: AbortSignal, priority?: RequestPriority): Promise<ReaderContent> {
  const combinedSignal = signal ? AbortSignal.any([signal, AbortSignal.timeout(FETCH_TIMEOUT_MS)]) : AbortSignal.timeout(FETCH_TIMEOUT_MS)
  const res = await fetch(`https://r.jina.ai/${url}`, { signal: combinedSignal, priority })
  if (!res.ok) throw new Error(`jina HTTP ${res.status}`)
  const text = await res.text()

  const titleMatch = text.match(/^Title:\s*(.+)$/m)
  const markerIdx = text.indexOf('Markdown Content:')
  let markdown = markerIdx >= 0 ? text.slice(markerIdx + 'Markdown Content:'.length).trim() : text.trim()
  if (!markdown) throw new Error('Nội dung rỗng')

  markdown = isolateOriginalPost(markdown)
  markdown = markdown.replace(/^#{1,2}[ \t]+.+(?:\r?\n)+/, '')

  const rawHtml = await marked.parse(markdown, { async: true })
  const html = DOMPurify.sanitize(rawHtml, { ADD_ATTR: ['target'] })

  const content: ReaderContent = { title: titleMatch?.[1]?.trim() ?? null, html }
  writeCache(url, content)
  return content
}

async function fetchViaCorsProxy(url: string, signal?: AbortSignal): Promise<ReaderContent> {
  const proxyUrl = `https://api.allorigins.win/get?url=${encodeURIComponent(url)}`
  const res = await fetch(proxyUrl, { signal: signal || AbortSignal.timeout(10_000) })
  if (!res.ok) throw new Error(`proxy HTTP ${res.status}`)
  const data = await res.json()
  const rawHtmlStr = data.contents
  if (!rawHtmlStr) throw new Error('Proxy empty')

  const parser = new DOMParser()
  const doc = parser.parseFromString(rawHtmlStr, 'text/html')

  const title = doc.querySelector('h1, title')?.textContent?.trim() || null
  const articleEl = doc.querySelector('article, .fck_detail, .detail-content, .entry-content, .post-content, main')
  
  let html = ''
  if (articleEl) {
    // Strip scripts & styles
    articleEl.querySelectorAll('script, style, iframe, nav, header, footer, .ads, .comment').forEach((el) => el.remove())
    html = articleEl.innerHTML
  } else {
    const ps = Array.from(doc.querySelectorAll('p')).slice(0, 15)
    html = ps.map((p) => p.outerHTML).join('')
  }

  const cleanHtml = DOMPurify.sanitize(html, { ADD_ATTR: ['target'] })
  if (!cleanHtml || cleanHtml.trim().length < 50) {
    throw new Error('Không trích xuất được bài viết')
  }

  const content: ReaderContent = { title, html: cleanHtml }
  writeCache(url, content)
  return content
}

export async function fetchReaderContent(
  url: string,
  signal?: AbortSignal,
  priority?: RequestPriority
): Promise<ReaderContent> {
  const cached = readCache(url)
  if (cached) return cached

  try {
    return await fetchViaJina(url, signal, priority)
  } catch {
    try {
      return await fetchViaCorsProxy(url, signal)
    } catch (err) {
      throw err
    }
  }
}
