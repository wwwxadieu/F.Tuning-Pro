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

async function fetchViaCorsProxy(url: string, signal?: AbortSignal): Promise<ReaderContent> {
  const proxyUrls = [
    `https://api.allorigins.win/get?url=${encodeURIComponent(url)}`,
    `https://corsproxy.io/?url=${encodeURIComponent(url)}`,
  ]

  let targetUrlObj: URL
  try {
    targetUrlObj = new URL(url)
  } catch {
    targetUrlObj = new URL('https://' + url)
  }

  for (const proxyUrl of proxyUrls) {
    try {
      const combinedSignal = signal ? AbortSignal.any([signal, AbortSignal.timeout(4500)]) : AbortSignal.timeout(4500)
      const res = await fetch(proxyUrl, { signal: combinedSignal })
      if (!res.ok) continue

      let rawHtmlStr = ''
      if (proxyUrl.includes('allorigins')) {
        const data = await res.json()
        rawHtmlStr = data.contents || ''
      } else {
        rawHtmlStr = await res.text()
      }

      if (!rawHtmlStr || rawHtmlStr.length < 200) continue

      const parser = new DOMParser()
      const doc = parser.parseFromString(rawHtmlStr, 'text/html')

      const title = doc.querySelector('h1.title-detail, h1.detail-title, h1, title')?.textContent?.trim() || null
      const articleEl = doc.querySelector(
        '.knc-content, .detail-content, article, .fck_detail, .maincontent, .content-detail, .singular-content, .post-content, .entry-content, main'
      )

      let html = ''
      if (articleEl) {
        // Strip scripts, styles, iframe, ads, comments, share buttons
        articleEl
          .querySelectorAll(
            'script, style, iframe, nav, header, footer, .ads, .ad, .comment, .social-share, .author-info, .relate-news'
          )
          .forEach((el) => el.remove())

        // Fix relative image URLs
        articleEl.querySelectorAll('img').forEach((img) => {
          const src = img.getAttribute('src') || img.getAttribute('data-src')
          if (src) {
            if (src.startsWith('http://') || src.startsWith('https://')) {
              img.setAttribute('src', src)
            } else if (src.startsWith('//')) {
              img.setAttribute('src', 'https:' + src)
            } else if (src.startsWith('/')) {
              img.setAttribute('src', targetUrlObj.origin + src)
            }
          }
        })

        html = articleEl.innerHTML
      } else {
        const ps = Array.from(doc.querySelectorAll('p')).slice(0, 20)
        html = ps.map((p) => p.outerHTML).join('')
      }

      const cleanHtml = DOMPurify.sanitize(html, { ADD_ATTR: ['target', 'src'] })
      if (!cleanHtml || cleanHtml.trim().length < 80) continue

      const content: ReaderContent = { title, html: cleanHtml }
      writeCache(url, content)
      return content
    } catch {
      // try next proxy
    }
  }

  throw new Error('Direct CORS proxy extraction failed')
}

async function fetchViaJina(url: string, signal?: AbortSignal, priority?: RequestPriority): Promise<ReaderContent> {
  const combinedSignal = signal ? AbortSignal.any([signal, AbortSignal.timeout(6000)]) : AbortSignal.timeout(6000)
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
  const html = DOMPurify.sanitize(rawHtml, { ADD_ATTR: ['target', 'src'] })

  const content: ReaderContent = { title: titleMatch?.[1]?.trim() ?? null, html }
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

  // Try FAST direct CORS HTML extraction first (0.8s load time!)
  try {
    return await fetchViaCorsProxy(url, signal)
  } catch {
    // Fallback to Jina reader proxy
    try {
      return await fetchViaJina(url, signal, priority)
    } catch (err) {
      throw err
    }
  }
}
