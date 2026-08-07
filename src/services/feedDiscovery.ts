import type { Article, Tag } from '../types/news'
import { fetchArticlesForTag } from './newsService'

export interface DiscoveredFeed {
  feedUrl: string
  items: Article[]
}

function probeTag(feedUrl: string, hostname: string): Tag {
  return {
    id: 'discover-temp',
    label: '',
    emoji: '📰',
    feedUrl,
    source: hostname,
  }
}

async function probe(feedUrl: string, hostname: string): Promise<DiscoveredFeed> {
  const items = await fetchArticlesForTag(probeTag(feedUrl, hostname), undefined, { forceRefresh: true })
  if (items.length === 0) throw new Error('empty feed')
  return { feedUrl, items }
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
 * (e.g. /rss.xml, /feed) and returns the first one that actually resolves
 * to a non-empty feed.
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
  return success ? success.value : null
}
