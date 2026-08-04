import { useCallback, useEffect, useRef, useState } from 'react'
import { TAGS } from '../data/tags'
import { fetchArticlesForTag } from '../services/newsService'
import type { Article } from '../types/news'

type TagStatus = 'loading' | 'ok' | 'error'

export function useNews() {
  const [articles, setArticles] = useState<Article[]>([])
  const [statuses, setStatuses] = useState<Record<string, TagStatus>>(() =>
    Object.fromEntries(TAGS.map((t) => [t.id, 'loading']))
  )
  const controllerRef = useRef<AbortController | null>(null)

  const loadTag = useCallback(async (tagId: string, signal?: AbortSignal) => {
    const tag = TAGS.find((t) => t.id === tagId)
    if (!tag) return

    setStatuses((prev) => ({ ...prev, [tagId]: 'loading' }))
    try {
      const items = await fetchArticlesForTag(tag, signal)
      setArticles((prev) => [
        ...prev.filter((a) => a.tagId !== tagId),
        ...items,
      ])
      setStatuses((prev) => ({ ...prev, [tagId]: 'ok' }))
    } catch {
      if (signal?.aborted) return
      setStatuses((prev) => ({ ...prev, [tagId]: 'error' }))
    }
  }, [])

  useEffect(() => {
    const controller = new AbortController()
    controllerRef.current = controller
    TAGS.forEach((tag) => loadTag(tag.id, controller.signal))
    return () => controller.abort()
  }, [loadTag])

  const retryTag = useCallback(
    (tagId: string) => {
      loadTag(tagId, controllerRef.current?.signal)
    },
    [loadTag]
  )

  const isInitialLoading = Object.values(statuses).every((s) => s === 'loading')

  return { articles, statuses, retryTag, isInitialLoading }
}
