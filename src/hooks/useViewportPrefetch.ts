import { useEffect } from 'react'
import type { RefObject } from 'react'
import { schedulePrefetch } from '../services/prefetchQueue'

// Warms the reader cache as soon as a card scrolls near the viewport —
// well before the user hovers or clicks it — so the article is usually
// already cached by the time they open it.
export function useViewportPrefetch(url: string, ref: RefObject<HTMLElement>) {
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          schedulePrefetch(url)
          observer.disconnect()
        }
      },
      { rootMargin: '600px 0px' }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [url, ref])
}
