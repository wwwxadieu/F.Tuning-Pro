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

function candidateFeedUrls(url: URL): string[] {
  const origin = url.origin
  const pathname = url.pathname.replace(/\/+$/, '')
  const lastSegment = pathname.split('/').filter(Boolean).pop()
  const candidates = new Set<string>()

  for (const suffix of [
    '/feed',
    '/feed/',
    '/rss',
    '/rss.xml',
    '/rss/',
    '/rss/index.xml',
    '/feed.xml',
    '/atom.xml',
    '/index.xml',
    '/feeds/posts/default',
    '/?feed=rss2',
  ]) {
    candidates.add(origin + suffix)
  }
  if (pathname) {
    for (const suffix of ['.rss', '/rss.xml', '/rss', '/feed']) {
      candidates.add(origin + pathname + suffix)
    }
  }
  if (lastSegment) {
    candidates.add(`${origin}/rss/${lastSegment}.rss`)
  }
  candidates.delete(url.toString())
  return Array.from(candidates)
}

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
