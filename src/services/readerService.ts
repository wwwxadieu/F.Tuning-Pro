import { marked } from 'marked'
import DOMPurify from 'dompurify'

export interface ReaderContent {
  title: string | null
  html: string
}

const CACHE_PREFIX = 'luong:reader:'
const CACHE_TTL_MS = 60 * 60 * 1000 // 1 hour

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
    // storage full or unavailable — ignore
  }
}

export async function fetchReaderContent(url: string, signal?: AbortSignal): Promise<ReaderContent> {
  const cached = readCache(url)
  if (cached) return cached

  const res = await fetch(`https://r.jina.ai/${url}`, { signal })
  if (!res.ok) throw new Error(`jina HTTP ${res.status}`)
  const text = await res.text()

  const titleMatch = text.match(/^Title:\s*(.+)$/m)
  const markerIdx = text.indexOf('Markdown Content:')
  const markdown = markerIdx >= 0 ? text.slice(markerIdx + 'Markdown Content:'.length).trim() : text.trim()
  if (!markdown) throw new Error('Nội dung rỗng')

  const rawHtml = await marked.parse(markdown, { async: true })
  const html = DOMPurify.sanitize(rawHtml, { ADD_ATTR: ['target'] })

  const content: ReaderContent = { title: titleMatch?.[1]?.trim() ?? null, html }
  writeCache(url, content)
  return content
}
