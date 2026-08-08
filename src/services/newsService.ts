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

const VIETNAMESE_DIACRITICS_RE = /[àáảãạăắằẳẵặâấầẩẫậđèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵ]/i

function isForeignText(text: string): boolean {
  const trimmed = text.trim()
  if (trimmed.length < 15) return false
  const wordCount = trimmed.split(/\s+/).length
  if (wordCount < 4) return false
  return !VIETNAMESE_DIACRITICS_RE.test(trimmed)
}

function stripTags(html: string): string {
  return html
    .replace(/<script\b[^<]*>([\s\S]*?)<\/script>/gi, '')
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

function extractImageFromHtml(html: string): string | null {
  if (!html) return null
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

function parseXmlFeed(xmlText: string, tag: Tag): Article[] {
  const parser = new DOMParser()
  const doc = parser.parseFromString(xmlText, 'text/xml')
  const items = Array.from(doc.querySelectorAll('item, entry'))
  if (items.length === 0) return []

  return items.slice(0, 40).map((item, index) => {
    const title = item.querySelector('title')?.textContent ?? '(Không có tiêu đề)'
    const description =
      item.querySelector('content\\:encoded, encoded, description, summary, content')?.textContent ?? ''

    let link = item.querySelector('link')?.getAttribute('href') || item.querySelector('link')?.textContent || '#'
    const pubDate = item.querySelector('pubDate, updated, date, published')?.textContent || new Date().toISOString()

    let thumb = item.querySelector('media\\:thumbnail, thumbnail')?.getAttribute('url') ||
      item.querySelector('media\\:content, content')?.getAttribute('url') ||
      item.querySelector('enclosure')?.getAttribute('url') ||
      item.querySelector('og\\:image, image url')?.textContent || null

    if (!thumb || !thumb.startsWith('http')) {
      thumb = extractImageFromHtml(description) || extractImageFromHtml(item.innerHTML)
    }

    return {
      id: `${tag.id}-${index}-${link}`,
      title: cleanText(title),
      description: cleanText(description),
      link,
      image: thumb,
      pubDate,
      source: tag.source,
      tagId: tag.id,
    }
  })
}

async function fetchViaNativeElectronRss(tag: Tag): Promise<Article[]> {
  if (!window.electronAPI?.fetchRawRss) throw new Error('Native Electron API unavailable')
  const xmlText = await window.electronAPI.fetchRawRss(tag.feedUrl)
  const articles = parseXmlFeed(xmlText, tag)
  if (articles.length === 0) throw new Error('Parsed 0 articles from native RSS')
  return articles
}

async function fetchViaXmlProxy(tag: Tag, signal?: AbortSignal): Promise<Article[]> {
  const proxyUrls = [
    `https://api.allorigins.win/get?url=${encodeURIComponent(tag.feedUrl)}`,
    `https://corsproxy.io/?url=${encodeURIComponent(tag.feedUrl)}`,
  ]

  for (const proxyUrl of proxyUrls) {
    try {
      const res = await fetch(proxyUrl, { signal: signal || AbortSignal.timeout(8000) })
      if (!res.ok) continue

      let xmlText = ''
      if (proxyUrl.includes('allorigins')) {
        const data = await res.json()
        xmlText = data.contents || ''
      } else {
        xmlText = await res.text()
      }

      if (!xmlText || (!xmlText.includes('<rss') && !xmlText.includes('<feed') && !xmlText.includes('<xml'))) {
        continue
      }

      const articles = parseXmlFeed(xmlText, tag)
      if (articles.length > 0) return articles
    } catch {
      // try next
    }
  }

  throw new Error('Proxy XML fetch failed')
}

async function fetchViaRss2Json(tag: Tag, signal?: AbortSignal): Promise<Article[]> {
  const url = `${RSS2JSON_ENDPOINT}?rss_url=${encodeURIComponent(tag.feedUrl)}`
  const res = await fetch(url, { signal: signal || AbortSignal.timeout(7000), priority: 'high' })
  if (!res.ok) throw new Error(`rss2json HTTP ${res.status}`)

  const data = (await res.json()) as RawFeedResponse
  if (data.status !== 'ok' || !data.items || data.items.length === 0) {
    throw new Error('rss2json returned empty or error')
  }

  return data.items.map((item, index) => ({
    id: `${tag.id}-${index}-${item.link ?? item.title ?? index}`,
    title: cleanText(item.title ?? '') || '(Không có tiêu đề)',
    description: cleanText(item.description ?? ''),
    link: item.link ?? '#',
    image: item.thumbnail || item.enclosure?.link || extractImageFromHtml(item.content || item.description || ''),
    pubDate: item.pubDate ?? new Date().toISOString(),
    source: tag.source,
    tagId: tag.id,
  }))
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

  let articles: Article[] = []

  if (tag.scrape) {
    articles = await scrapeArticles(tag, signal)
  } else {
    // 1. Try Native Electron Direct RSS Fetch FIRST (instant, no CORS, no 3rd party!)
    try {
      articles = await fetchViaNativeElectronRss(tag)
    } catch {
      // 2. Try XML Proxy
      try {
        articles = await fetchViaXmlProxy(tag, signal)
      } catch {
        // 3. Fallback to rss2json
        try {
          articles = await fetchViaRss2Json(tag, signal)
        } catch {
          // 4. Fallback to scrape if available
          try {
            articles = await scrapeArticles(tag, signal)
          } catch {
            articles = []
          }
        }
      }
    }
  }

  // Filter out articles older than 14 days
  const nowMs = Date.now()
  const fourteenDaysMs = 14 * 24 * 60 * 60 * 1000
  const freshArticles = articles.filter((a) => {
    const pubMs = parsePubDateMs(a.pubDate)
    return nowMs - pubMs <= fourteenDaysMs
  })

  if (freshArticles.length >= 3) {
    articles = freshArticles
  }

  // Sort strictly by publication date descending (newest first)
  articles.sort((a, b) => parsePubDateMs(b.pubDate) - parsePubDateMs(a.pubDate))

  // Auto-translate foreign language headlines to Vietnamese
  const shouldTranslate = tag.translate || articles.some((a) => isForeignText(a.title))
  if (shouldTranslate) {
    await Promise.all(
      articles.map(async (a) => {
        if (tag.translate || isForeignText(a.title)) {
          const [title, description] = await Promise.all([
            translateText(a.title),
            a.description ? translateText(a.description) : Promise.resolve(''),
          ])
          a.title = title
          a.description = description
        }
      })
    )
  }

  for (const a of articles) {
    a.description = a.description.slice(0, 260)
  }

  writeCache(tag.id, articles)
  return articles
}
