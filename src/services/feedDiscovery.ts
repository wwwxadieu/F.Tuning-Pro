import type { Article, Tag } from '../types/news'
import { fetchArticlesForTag } from './newsService'

export interface DiscoveredFeed {
  feedUrl: string
  items: Article[]
  /** No feed was found — feedUrl is a plain page being scraped instead of an RSS URL. */
  scrape?: boolean
}

function probeTag(feedUrl: string, hostname: string, scrape?: boolean): Tag {
  return {
    id: 'discover-temp',
    label: '',
    emoji: '📰',
    feedUrl,
    source: hostname,
    scrape,
  }
}

async function probe(feedUrl: string, hostname: string): Promise<DiscoveredFeed> {
  const items = await fetchArticlesForTag(probeTag(feedUrl, hostname), undefined, { forceRefresh: true })
  if (items.length === 0) throw new Error('empty feed')
  return { feedUrl, items }
}

async function probeScrape(feedUrl: string, hostname: string): Promise<DiscoveredFeed> {
  const items = await fetchArticlesForTag(probeTag(feedUrl, hostname, true), undefined, { forceRefresh: true })
  if (items.length === 0) throw new Error('nothing scraped')
  return { feedUrl, items, scrape: true }
}

// A plain site URL isn't a feed — guess the paths most CMSes, blog
// platforms, and Vietnamese news sites actually publish their feed at.
function candidateFeedUrls(url: URL): string[] {
  const origin = url.origin
  const pathname = url.pathname.replace(/\/+$/, '')
  const lastSegment = pathname.split('/').filter(Boolean).pop()
  const candidates = new Set<string>()

  for (const suffix of [
    '/rss.xml',
    '/rss',
    '/rss/',
    '/rss/index.xml',
    '/feed.xml',
    '/feed',
    '/feed/',
    '/atom.xml',
    '/index.xml',
    '/feeds/posts/default', // Blogger
    '/?feed=rss2', // WordPress
  ]) {
    candidates.add(origin + suffix)
  }
  if (pathname) {
    for (const suffix of ['.rss', '/rss.xml', '/rss', '/feed']) {
      candidates.add(origin + pathname + suffix)
    }
  }
  if (lastSegment) {
    // Common Vietnamese news site convention: a category page's feed lives
    // under a shared /rss/ folder, e.g. vnexpress.net/thoi-su -> /rss/thoi-su.rss
    candidates.add(`${origin}/rss/${lastSegment}.rss`)
  }
  candidates.delete(url.toString())
  return Array.from(candidates)
}

/**
 * Accepts either a direct RSS/Atom feed URL or a plain website link. Tries
 * the URL as-is first, then races a set of common feed-path conventions
 * (e.g. /rss.xml, /feed), and if nothing there looks like a feed at all,
 * falls back to scraping article links straight out of the page itself
 * (e.g. tinhte.vn has no discoverable RSS) so the user isn't forced to
 * find and paste an exact feed URL.
 */
export async function discoverFeed(url: URL): Promise<DiscoveredFeed | null> {
  try {
    return await probe(url.toString(), url.hostname)
  } catch {
    // not a feed as typed — fall through to guessing common feed paths
  }

  const results = await Promise.allSettled(
    candidateFeedUrls(url).map((feedUrl) => probe(feedUrl, url.hostname))
  )
  const success = results.find(
    (r): r is PromiseFulfilledResult<DiscoveredFeed> => r.status === 'fulfilled'
  )
  if (success) return success.value

  try {
    return await probeScrape(url.toString(), url.hostname)
  } catch {
    return null
  }
}
