import { marked } from 'marked'
import DOMPurify from 'dompurify'

export interface ReaderContent {
  title: string | null
  html: string
}

const CACHE_PREFIX = 'luong:reader:'
const CACHE_TTL_MS = 60 * 60 * 1000 // 1 hour

// Forum/community threads (XenForo, Discourse, WordPress author archives, ...)
// repeat an avatar-photo-wrapped-in-a-profile-link "author card" once for the
// original post and again for every reply beneath it. When that pattern shows
// up more than once, the actual article always sits between the first card
// (the author) and the second (the first reply) — slicing there drops both
// the site's nav/search clutter above the post and the entire comment thread
// below it, without needing any site-specific selectors.
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
    // storage full or unavailable — ignore
  }
}

async function fetchOnce(url: string, signal?: AbortSignal, priority?: RequestPriority): Promise<ReaderContent> {
  const res = await fetch(`https://r.jina.ai/${url}`, { signal, priority })
  if (!res.ok) throw new Error(`jina HTTP ${res.status}`)
  const text = await res.text()

  const titleMatch = text.match(/^Title:\s*(.+)$/m)
  const markerIdx = text.indexOf('Markdown Content:')
  let markdown = markerIdx >= 0 ? text.slice(markerIdx + 'Markdown Content:'.length).trim() : text.trim()
  if (!markdown) throw new Error('Nội dung rỗng')

  markdown = isolateOriginalPost(markdown)

  // jina.ai's extraction almost always repeats the article's own headline as
  // the first line of the markdown (# Headline) — we already render the
  // title separately above the content, so strip it to avoid a duplicate.
  markdown = markdown.replace(/^#{1,2}[ \t]+.+(?:\r?\n)+/, '')

  const rawHtml = await marked.parse(markdown, { async: true })
  const html = DOMPurify.sanitize(rawHtml, { ADD_ATTR: ['target'] })

  const content: ReaderContent = { title: titleMatch?.[1]?.trim() ?? null, html }
  writeCache(url, content)
  return content
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

export async function fetchReaderContent(
  url: string,
  signal?: AbortSignal,
  priority?: RequestPriority
): Promise<ReaderContent> {
  const cached = readCache(url)
  if (cached) return cached

  try {
    return await fetchOnce(url, signal, priority)
  } catch (err) {
    // The reader proxy occasionally fails on the first attempt (transient
    // network blip, momentary rate limiting) — one quick retry clears most
    // of those without the user ever seeing the error state.
    if (signal?.aborted) throw err
    await delay(1200)
    if (signal?.aborted) throw err
    return await fetchOnce(url, signal, priority)
  }
}
