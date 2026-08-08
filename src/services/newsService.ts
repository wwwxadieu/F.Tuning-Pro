import type { Article, Tag } from '../types/news'
import { scrapeArticles } from './scrapeService'
import { translateText } from './translateService'

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
  enclosure?: { link?: string }
}

interface RawFeedResponse {
  status: string
  items?: RawFeedItem[]
}

function stripTags(html: string): string {
  return html.replace(/<script\b[^<]*>([\s\S]*?)<\/script>/gi, '')
    .replace(/<style\b[^<]*>([\s\S]*?)<\/style>/gi, '')
    .replace(/<[^>]*>/g, ' ')
}

function decodeHtmlEntities(text: string): string {
  const el = document.createElement('textarea')
  el.innerHTML = text
  return el.value
}

function cleanText(html: string): string {
  return decodeHtmlEntities(stripTags(html)).replace(/\s+/g, ' ').trim()
}

function extractImage(item: RawFeedItem): string | null {
  if (item.thumbnail && item.thumbnail.startsWith('http')) return item.thumbnail
  if (item.enclosure?.link && item.enclosure.link.startsWith('http')) return item.enclosure.link
  const html = item.content ?? item.description ?? ''
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i)
  if (match && match[1]) {
    const src = decodeHtmlEntities(match[1])
    if (src.startsWith('http')) return src
  }
  return null
}

function parsePubDateMs(pubDateStr?: string): number {
  if (!pubDateStr) return Date.now()
  const parsed = new Date(pubDateStr).getTime()
  return isNaN(parsed) ? Date.now() : parsed
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
    // ignore
  }
}

interface FetchOptions {
  forceRefresh?: boolean
}

async function fetchViaRss(tag: Tag, signal?: AbortSignal): Promise<Article[]> {
  try {
    const url = `${RSS2JSON_ENDPOINT}?rss_url=${encodeURIComponent(tag.feedUrl)}`
    const res = await fetch(url, { signal, priority: 'high' })
    if (res.ok) {
      const data = (await res.json()) as RawFeedResponse
      if (data.status === 'ok' && data.items && data.items.length > 0) {
        return data.items.map((item, index) => ({
          id: `${tag.id}-${index}-${item.link ?? item.title ?? index}`,
          title: cleanText(item.title ?? '') || '(Không có tiêu đề)',
          description: cleanText(item.description ?? ''),
          link: item.link ?? '#',
          image: extractImage(item),
          pubDate: item.pubDate ?? new Date().toISOString(),
          source: tag.source,
          tagId: tag.id,
        }))
      }
    }
  } catch {
    // fallback to proxy
  }

  // Fallback RSS proxy using allorigins
  try {
    const proxyUrl = `https://api.allorigins.win/get?url=${encodeURIComponent(tag.feedUrl)}`
    const res = await fetch(proxyUrl, { signal })
    if (!res.ok) throw new Error(`proxy HTTP ${res.status}`)
    const data = await res.json()
    const xmlText = data.contents
    if (!xmlText) throw new Error('Proxy returned empty content')

    const parser = new DOMParser()
    const doc = parser.parseFromString(xmlText, 'text/xml')
    const items = Array.from(doc.querySelectorAll('item, entry'))

    return items.slice(0, 30).map((item, index) => {
      const title = item.querySelector('title')?.textContent ?? '(Không có tiêu đề)'
      const description = item.querySelector('description, summary, content')?.textContent ?? ''
      const link = item.querySelector('link')?.getAttribute('href') || item.querySelector('link')?.textContent || '#'
      const pubDate = item.querySelector('pubDate, updated, date')?.textContent || new Date().toISOString()
      const thumb = item.querySelector('thumbnail, content, enclosure')?.getAttribute('url') || null

      return {
        id: `${tag.id}-${index}-${link}`,
        title: cleanText(title),
        description: cleanText(description),
        link,
        image: thumb || extractImage({ description }),
        pubDate,
        source: tag.source,
        tagId: tag.id,
      }
    })
  } catch (err) {
    throw new Error(`Không thể nạp RSS từ ${tag.source}`)
  }
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

  let articles = tag.scrape ? await scrapeArticles(tag, signal) : await fetchViaRss(tag, signal)

  // Filter out articles older than 14 days (14 * 24 * 60 * 60 * 1000)
  const nowMs = Date.now()
  const fourteenDaysMs = 14 * 24 * 60 * 60 * 1000
  const freshArticles = articles.filter((a) => {
    const pubMs = parsePubDateMs(a.pubDate)
    return nowMs - pubMs <= fourteenDaysMs
  })

  // Fallback to original articles if filter returned too few
  if (freshArticles.length >= 3) {
    articles = freshArticles
  }

  // Sort strictly by publication date descending (newest first)
  articles.sort((a, b) => parsePubDateMs(b.pubDate) - parsePubDateMs(a.pubDate))

  if (tag.translate) {
    await Promise.all(
      articles.map(async (a) => {
        const [title, description] = await Promise.all([translateText(a.title), translateText(a.description)])
        a.title = title
        a.description = description
      })
    )
  }

  for (const a of articles) {
    a.description = a.description.slice(0, 260)
  }

  writeCache(tag.id, articles)
  return articles
}
