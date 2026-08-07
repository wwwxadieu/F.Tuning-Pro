import { useRef } from 'react'
import { fetchReaderContent } from '../services/readerService'

// Warms the reader-content cache slightly before a click actually happens,
// so opening the article usually finds it already cached and skips the
// loading skeleton entirely. Guarded by a short hover-intent delay so
// briefly passing the cursor over a card while scrolling doesn't fire a
// fetch for every card underneath it.
export function useHoverPrefetch(url: string, delayMs = 150) {
  const timerRef = useRef<number | null>(null)

  function onMouseEnter() {
    if (timerRef.current) return
    timerRef.current = window.setTimeout(() => {
      fetchReaderContent(url, undefined, 'high').catch(() => {})
      timerRef.current = null
    }, delayMs)
  }

  function onMouseLeave() {
    if (timerRef.current) {
      window.clearTimeout(timerRef.current)
      timerRef.current = null
    }
  }

  return { onMouseEnter, onMouseLeave }
}
