import type { Article, Tag } from '../types/news'

const READER_PROXY = 'https://r.jina.ai/'
const MAX_ITEMS = 24
const MIN_TITLE_LENGTH = 12

interface ScrapedLink {
  title: string
  url: string
}

// Pages built around a feed of user avatars/thumbnails (forums, "social"
// homepages like tinhte.vn) nest an image inside the link text itself —
// `[![alt](avatar.jpg)](/profile/x)` — which breaks a naive `[text](url)`
// scan: `[^\]]+` stops at the image's own `]`, so the "title" it captures is
// a mangled `![alt` fragment and the "url" it captures is the avatar image,
// not the link's real destination. Stripping all image markdown first
// collapses those down to `[](url)`, which the title-length filter below
// then correctly discards as noise instead of surfacing as garbage.
const IMAGE_MARKDOWN_RE = /!\[[^\]]*\]\([^)]*\)/g

// Common non-article routes that still carry a long enough "title" (nav
// label, button text) to otherwise pass the length filter.
const NON_ARTICLE_PATH_RE = /\/(login|register|signup|signin|profile|search|contact|terms|privacy)(\/|$)/i

// A homepage's extracted markdown is full of `[text](url)` links — nav,
// footer, social share, ads — mixed in with the actual article links we
// want. Keep only links that point back at the site itself with a
// reasonably long title, which filters out most non-article chrome
// without needing to understand the page's actual HTML structure.
function extractLinks(markdown: string, siteHostname: string): ScrapedLink[] {
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

/**
 * Builds a synthetic article list for a source that has no discoverable
 * RSS/Atom feed by fetching its homepage through the same reader proxy used
 * for full-article extraction, then pulling article-looking links out of
 * the resulting markdown. There's no structured pubDate/description from a
 * homepage scrape, so pubDate is faked as a strictly decreasing sequence to
 * preserve the page's own front-to-back ordering in date-sorted views.
 */
export async function scrapeArticles(tag: Tag, signal?: AbortSignal): Promise<Article[]> {
  const res = await fetch(`${READER_PROXY}${tag.feedUrl}`, { signal })
  if (!res.ok) throw new Error(`jina HTTP ${res.status}`)
  const text = await res.text()

  const markerIdx = text.indexOf('Markdown Content:')
  const markdown = markerIdx >= 0 ? text.slice(markerIdx + 'Markdown Content:'.length) : text

  const hostname = new URL(tag.feedUrl).hostname
  const links = extractLinks(markdown, hostname)

  const now = Date.now()
  return links.map((link, index) => ({
    id: `${tag.id}-scrape-${index}-${link.url}`,
    title: link.title,
    description: '',
    link: link.url,
    image: null,
    pubDate: new Date(now - index * 60_000).toISOString(),
    source: tag.source,
    tagId: tag.id,
  }))
}
