import type { Article, Tag } from '../types/news'

const RSS2JSON_ENDPOINT = 'https://api.rss2json.com/v1/api.json'
const CACHE_PREFIX = 'luong:feed:'
const CACHE_TTL_MS = 10 * 60 * 1000 // 10 minutes

interface RawFeedItem {
  title?: string
  description?: string
  content?: string
  link?: string
  pubDate?: string
  thumbnail?: string
}

interface RawFeedResponse {
  status: string
  items?: RawFeedItem[]
}

function stripTags(html: string): string {
  return html.replace(/<[^>]*>/g, ' ')
}

/**
 * RSS feeds routinely encode Vietnamese text with HTML entities (named and
 * numeric). A hand-rolled replace list only covers a handful of them and
 * leaves the rest garbled, so decode through a detached <textarea> instead —
 * its content is parsed as text (never as markup), which makes this safe
 * even on untrusted input while still resolving every entity the browser
 * knows about.
 */
function decodeHtmlEntities(text: string): string {
  const el = document.createElement('textarea')
  el.innerHTML = text
  return el.value
}

function cleanText(html: string): string {
  return decodeHtmlEntities(stripTags(html)).replace(/\s+/g, ' ').trim()
}

function extractImage(item: RawFeedItem): string | null {
  if (item.thumbnail) return item.thumbnail
  const html = item.content ?? item.description ?? ''
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i)
  return match ? decodeHtmlEntities(match[1]) : null
}

function readCache(tagId: string): Article[] | null {
  try {
    const raw = localStorage.getItem(CACHE_PREFIX + tagId)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { savedAt: number; articles: Article[] }
    if (Date.now() - parsed.savedAt > CACHE_TTL_MS) return null
    return parsed.articles
  } catch {
    return null
  }
}

function writeCache(tagId: string, articles: Article[]) {
  try {
    localStorage.setItem(
      CACHE_PREFIX + tagId,
      JSON.stringify({ savedAt: Date.now(), articles })
    )
  } catch {
    // storage full or unavailable — ignore, caching is a pure optimization
  }
}

interface FetchOptions {
  forceRefresh?: boolean
}

export async function fetchArticlesForTag(
  tag: Tag,
  signal?: AbortSignal,
  options?: FetchOptions
): Promise<Article[]> {
  if (!options?.forceRefresh) {
    const cached = readCache(tag.id)
    if (cached) return cached
  }

  // rss2json's free tier now rejects the `count` parameter without an API
  // key (HTTP 422) — omit it and take whatever the default page size is.
  const url = `${RSS2JSON_ENDPOINT}?rss_url=${encodeURIComponent(tag.feedUrl)}`
  const res = await fetch(url, { signal })
  if (!res.ok) throw new Error(`rss2json HTTP ${res.status}`)

  const data = (await res.json()) as RawFeedResponse
  if (data.status !== 'ok' || !data.items) {
    throw new Error('rss2json trả về lỗi')
  }

  const articles: Article[] = data.items.map((item, index) => ({
    id: `${tag.id}-${index}-${item.link ?? item.title ?? index}`,
    title: cleanText(item.title ?? '') || '(Không có tiêu đề)',
    description: cleanText(item.description ?? '').slice(0, 220),
    link: item.link ?? '#',
    image: extractImage(item),
    pubDate: item.pubDate ?? '',
    source: tag.source,
    tagId: tag.id,
  }))

  writeCache(tag.id, articles)
  return articles
}
