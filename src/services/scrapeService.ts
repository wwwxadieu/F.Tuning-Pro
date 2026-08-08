import type { Article, Tag } from '../types/news'

const READER_PROXY = 'https://r.jina.ai/'
const MAX_ITEMS = 30
const MIN_TITLE_LENGTH = 12

interface ScrapedLink {
  title: string
  url: string
  image?: string | null
}

const IMAGE_MARKDOWN_RE = /!\[[^\]]*\]\([^)]*\)/g
const NON_ARTICLE_PATH_RE = /\/(login|register|signup|signin|profile|search|contact|terms|privacy|about)(\/|$)/i

function extractLinksFromMarkdown(markdown: string, siteHostname: string): ScrapedLink[] {
  const bareHost = siteHostname.replace(/^www\./, '')
  const withoutImages = markdown.replace(IMAGE_MARKDOWN_RE, '')
  const linkPattern = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g
  const seen = new Set<string>()
  const links: ScrapedLink[] = []
  let match: RegExpExecArray | null

  while ((match = linkPattern.exec(withoutImages))) {
    const title = match[1].trim()
    if (title.length < MIN_TITLE_LENGTH) continue

    let linkUrl: URL
    try {
      linkUrl = new URL(match[2])
    } catch {
      continue
    }
    if (!linkUrl.hostname.replace(/^www\./, '').endsWith(bareHost)) continue
    if (!linkUrl.pathname || linkUrl.pathname === '/') continue
    if (NON_ARTICLE_PATH_RE.test(linkUrl.pathname)) continue

    const normalized = linkUrl.toString()
    if (seen.has(normalized)) continue
    seen.add(normalized)

    links.push({ title, url: normalized })
    if (links.length >= MAX_ITEMS) break
  }

  return links
}

async function scrapeViaNativeElectron(tag: Tag): Promise<Article[]> {
  if (!window.electronAPI?.fetchHtml) throw new Error('Native Electron API unavailable')
  const rawHtmlStr = await window.electronAPI.fetchHtml(tag.feedUrl)

  const parser = new DOMParser()
  const doc = parser.parseFromString(rawHtmlStr, 'text/html')

  let baseOrigin = 'https://' + tag.source
  try {
    baseOrigin = new URL(tag.feedUrl).origin
  } catch {
    // fallback
  }

  const seen = new Set<string>()
  const articles: Article[] = []

  const articleNodes = doc.querySelectorAll('article, .news-item, .post-item, .item, .story, h2 a, h3 a, h1 a, .title a')
  articleNodes.forEach((node, index) => {
    const a = node.tagName === 'A' ? (node as HTMLAnchorElement) : node.querySelector('a')
    if (!a) return
    const title = a.textContent?.trim() || ''
    if (title.length < MIN_TITLE_LENGTH) return

    let href = a.getAttribute('href') || ''
    if (!href || href.startsWith('#') || href.startsWith('javascript:')) return
    if (href.startsWith('/')) href = baseOrigin + href
    else if (!href.startsWith('http')) href = baseOrigin + '/' + href

    if (seen.has(href)) return
    seen.add(href)

    const img = node.querySelector('img')
    let thumb = img?.getAttribute('src') || img?.getAttribute('data-src') || img?.getAttribute('data-original') || null
    if (thumb) {
      if (thumb.startsWith('//')) thumb = 'https:' + thumb
      else if (thumb.startsWith('/')) thumb = baseOrigin + thumb
    }

    articles.push({
      id: `${tag.id}-native-scrape-${index}-${href}`,
      title,
      description: '',
      link: href,
      image: thumb,
      pubDate: new Date(Date.now() - index * 60_000).toISOString(),
      source: tag.source,
      tagId: tag.id,
    })
  })

  if (articles.length === 0) throw new Error('Native scrape found 0 articles')
  return articles.slice(0, MAX_ITEMS)
}

export async function scrapeArticles(tag: Tag, signal?: AbortSignal): Promise<Article[]> {
  // 1. Try Native Electron HTML Scrape FIRST (0.2s ultra fast, no proxies!)
  try {
    return await scrapeViaNativeElectron(tag)
  } catch {
    // 2. Fallback to Jina Reader Scrape
    const res = await fetch(`${READER_PROXY}${tag.feedUrl}`, { signal })
    if (!res.ok) throw new Error(`jina HTTP ${res.status}`)
    const text = await res.text()

    const markerIdx = text.indexOf('Markdown Content:')
    const markdown = markerIdx >= 0 ? text.slice(markerIdx + 'Markdown Content:'.length) : text

    const hostname = new URL(tag.feedUrl).hostname
    const links = extractLinksFromMarkdown(markdown, hostname)

    const now = Date.now()
    return links.map((link, index) => ({
      id: `${tag.id}-scrape-${index}-${link.url}`,
      title: link.title,
      description: '',
      link: link.url,
      image: link.image || null,
      pubDate: new Date(now - index * 60_000).toISOString(),
      source: tag.source,
      tagId: tag.id,
    }))
  }
}
