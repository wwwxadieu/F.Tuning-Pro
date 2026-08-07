import { fetchReaderContent } from './readerService'

// Reader extraction (via r.jina.ai) is the slowest step in opening an
// article, so we warm its cache in the background before the user clicks —
// but running every prefetch at once would flood the network and slow down
// the fetches the user is actually waiting on, so only a couple run
// concurrently and the rest wait their turn.
const MAX_CONCURRENT = 2

const scheduled = new Set<string>()
const queue: string[] = []
let active = 0

function runNext() {
  if (active >= MAX_CONCURRENT) return
  const url = queue.shift()
  if (!url) return
  active++
  fetchReaderContent(url, undefined, 'low')
    .catch(() => {})
    .finally(() => {
      active--
      runNext()
    })
}

export function schedulePrefetch(url: string) {
  if (scheduled.has(url)) return
  scheduled.add(url)
  queue.push(url)
  runNext()
}
