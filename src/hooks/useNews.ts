import { useCallback, useEffect, useRef, useState } from 'react'
import { fetchArticlesForTag } from '../services/newsService'
import { scrapeArticles } from '../services/scrapeService'
import type { Article, Tag } from '../types/news'

type TagStatus = 'loading' | 'ok' | 'error'

const REVEAL_STEP = 6
const POLL_INTERVAL_MS = 3 * 60 * 1000
// RSS2JSON's free tier caps a single feed fetch at ~10 items, which runs out
// after one or two "load more" steps — nowhere near enough for scrolling to
// feel infinite. A tag with this few items on hand is almost certainly
// sitting at that cap rather than the source genuinely having no more.
const SUPPLEMENT_THRESHOLD = 10

export function useNews(
  tags: Tag[],
  onNewArticles?: (tag: Tag, newItems: Article[]) => void,
  priorityTagIds?: string[]
) {
  const [articles, setArticles] = useState<Article[]>([])
  const [statuses, setStatuses] = useState<Record<string, TagStatus>>({})
  const [revealCounts, setRevealCounts] = useState<Record<string, number>>({})
  const [supplementing, setSupplementing] = useState<Record<string, boolean>>({})

  const tagsRef = useRef<Tag[]>(tags)
  tagsRef.current = tags
  const articlesRef = useRef<Article[]>(articles)
  articlesRef.current = articles
  const seenIdsRef = useRef<Record<string, Set<string>>>({})
  const loadedOnceRef = useRef<Set<string>>(new Set())
  const supplementedRef = useRef<Set<string>>(new Set())
  const onNewArticlesRef = useRef(onNewArticles)
  onNewArticlesRef.current = onNewArticles

  const loadTag = useCallback(
    async (tag: Tag, signal?: AbortSignal, opts?: { forceRefresh?: boolean; silent?: boolean }) => {
      if (!opts?.silent) setStatuses((prev) => ({ ...prev, [tag.id]: 'loading' }))
      try {
        const items = await fetchArticlesForTag(tag, signal, {
          forceRefresh: opts?.forceRefresh,
        })
        // Merge rather than replace: a background/manual refresh only ever
        // sees the source's current top items (~10 for RSS2JSON), so
        // replacing would silently discard everything the user already
        // scrolled past. Keeping the union means the available pool only
        // grows over a session instead of resetting every few minutes.
        setArticles((prev) => {
          const existingIds = new Set(prev.filter((a) => a.tagId === tag.id).map((a) => a.id))
          const fresh = items.filter((a) => !existingIds.has(a.id))
          return fresh.length > 0 ? [...prev, ...fresh] : prev
        })
        setStatuses((prev) => ({ ...prev, [tag.id]: 'ok' }))
        setRevealCounts((prev) => (prev[tag.id] ? prev : { ...prev, [tag.id]: REVEAL_STEP }))

        const prevSeen = seenIdsRef.current[tag.id]
        const nextSeen = new Set(items.map((i) => i.id))
        if (prevSeen && loadedOnceRef.current.has(tag.id)) {
          const newly = items.filter((i) => !prevSeen.has(i.id))
          if (newly.length > 0) onNewArticlesRef.current?.(tag, newly)
        }
        seenIdsRef.current[tag.id] = nextSeen
        loadedOnceRef.current.add(tag.id)
      } catch {
        if (signal?.aborted) return
        if (!opts?.silent) setStatuses((prev) => ({ ...prev, [tag.id]: 'error' }))
      }
    },
    []
  )

  const controllerRef = useRef<AbortController | null>(null)
  useEffect(() => {
    const controller = new AbortController()
    controllerRef.current = controller
    return () => controller.abort()
  }, [])

  // Load any tag we haven't fetched yet (initial load, or a newly added custom source).
  // Tags the user actually cares about (their selected interests) are issued
  // first so those requests grab available per-origin connection slots
  // ahead of the rest, instead of loading in arbitrary array order.
  useEffect(() => {
    const priority = priorityTagIds && priorityTagIds.length > 0 ? new Set(priorityTagIds) : null
    const ordered = priority
      ? [...tags].sort((a, b) => Number(priority.has(b.id)) - Number(priority.has(a.id)))
      : tags
    ordered.forEach((tag) => {
      if (!(tag.id in statuses)) {
        loadTag(tag, controllerRef.current?.signal)
      }
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tags, loadTag, priorityTagIds])

  // Background poll for new articles on already-loaded tags.
  useEffect(() => {
    const interval = setInterval(() => {
      tagsRef.current.forEach((tag) => {
        if (loadedOnceRef.current.has(tag.id)) {
          loadTag(tag, undefined, { forceRefresh: true, silent: true })
        }
      })
    }, POLL_INTERVAL_MS)
    return () => clearInterval(interval)
  }, [loadTag])

  const retryTag = useCallback(
    (tagId: string) => {
      const tag = tagsRef.current.find((t) => t.id === tagId)
      if (tag) loadTag(tag, controllerRef.current?.signal, { forceRefresh: true })
    },
    [loadTag]
  )

  const loadMore = useCallback((tagId: string) => {
    setRevealCounts((prev) => ({ ...prev, [tagId]: (prev[tagId] ?? REVEAL_STEP) + REVEAL_STEP }))

    const tag = tagsRef.current.find((t) => t.id === tagId)
    if (!tag || tag.scrape || supplementedRef.current.has(tagId)) return
    const currentCount = articlesRef.current.filter((a) => a.tagId === tagId).length
    if (currentCount > SUPPLEMENT_THRESHOLD) return

    supplementedRef.current.add(tagId)
    setSupplementing((prev) => ({ ...prev, [tagId]: true }))
    scrapeArticles(tag, controllerRef.current?.signal)
      .then((extra) => {
        setArticles((prev) => {
          const existingLinks = new Set(prev.filter((a) => a.tagId === tagId).map((a) => a.link))
          const fresh = extra.filter((a) => !existingLinks.has(a.link))
          return fresh.length > 0 ? [...prev, ...fresh] : prev
        })
      })
      .catch(() => {})
      .finally(() => {
        setSupplementing((prev) => ({ ...prev, [tagId]: false }))
      })
  }, [])

  const refreshAll = useCallback(() => {
    tagsRef.current.forEach((tag) => {
      if (loadedOnceRef.current.has(tag.id)) {
        loadTag(tag, controllerRef.current?.signal, { forceRefresh: true })
      }
    })
  }, [loadTag])

  const refreshing = articles.length > 0 && Object.values(statuses).some((s) => s === 'loading')

  return { articles, statuses, revealCounts, retryTag, loadMore, refreshAll, refreshing, supplementing }
}
