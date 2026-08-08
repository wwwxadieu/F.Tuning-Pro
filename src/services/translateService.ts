const TRANSLATE_ENDPOINT = 'https://translate.googleapis.com/translate_a/single'
const CACHE_PREFIX = 'luong:translate:'
const ARTICLE_CACHE_PREFIX = 'luong:translate:article:'

function readCache(text: string): string | null {
  try {
    return sessionStorage.getItem(CACHE_PREFIX + text)
  } catch {
    return null
  }
}

function writeCache(text: string, translated: string) {
  try {
    sessionStorage.setItem(CACHE_PREFIX + text, translated)
  } catch {
    // storage full or unavailable — ignore
  }
}

/**
 * Translates one block of text, throwing if it cannot.
 *
 * Prefers the Electron bridge: it POSTs, so a long paragraph isn't squeezed
 * into a URL, and it can fall back to a second provider. The direct GET below
 * is what `npm run dev` in a browser gets, and is only safe for short strings.
 */
// The main process bounds every request it makes, but this side must not
// depend on that: if a reply were ever lost, an un-timed await would hang the
// translation forever and leave the reader frozen on a percentage. Racing a
// timer here makes that impossible no matter how the bridge behaves.
const CHUNK_TIMEOUT_MS = 15_000

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Dịch quá thời gian chờ')), ms)
    promise.then(
      (value) => {
        clearTimeout(timer)
        resolve(value)
      },
      (err) => {
        clearTimeout(timer)
        reject(err)
      }
    )
  })
}

async function translateChunk(text: string, target: string): Promise<string> {
  const bridge = window.electronAPI?.translateText
  if (bridge) return await withTimeout(bridge(text, target), CHUNK_TIMEOUT_MS)

  const url = `${TRANSLATE_ENDPOINT}?client=gtx&sl=auto&tl=${target}&dt=t&q=${encodeURIComponent(text)}`
  const res = await fetch(url)
  if (!res.ok) throw new Error(`translate HTTP ${res.status}`)
  const data = (await res.json()) as unknown

  const segments = Array.isArray(data) ? (data[0] as unknown) : null
  const translated = Array.isArray(segments)
    ? segments.map((seg) => (Array.isArray(seg) ? String(seg[0] ?? '') : '')).join('')
    : ''
  if (!translated) throw new Error('Kết quả dịch rỗng')
  return translated
}

// Letters that only Vietnamese uses among the languages we see. Foreign
// headlines are already translated once at the feed layer for sources marked
// as foreign, so without this check the reader would translate them a second
// time — a wasted request, and a chance to mangle text that was already right.
const VIETNAMESE_LETTERS =
  /[ăâđêôơưĂÂĐÊÔƠƯàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]/

export function looksVietnamese(text: string): boolean {
  return VIETNAMESE_LETTERS.test(text)
}

/**
 * Translates foreign text (English, French, Japanese, etc.) to Vietnamese.
 * Returns the original text unchanged if translation fails — callers use this
 * for headlines, where showing the source language beats showing nothing.
 */
export async function translateText(text: string, target = 'vi'): Promise<string> {
  const trimmed = text.trim()
  if (!trimmed || trimmed.length < 3) return text

  const cached = readCache(trimmed)
  if (cached !== null) return cached

  try {
    const translated = await translateChunk(trimmed, target)
    writeCache(trimmed, translated)
    return translated
  } catch {
    return text
  }
}

// ---------------------------------------------------------------------------
// Whole-article translation
// ---------------------------------------------------------------------------

// Big enough that a normal article is only a handful of round trips, small
// enough to stay well inside what the endpoint will accept in one go. The
// browser fallback puts the text in a URL, where percent-encoding inflates it
// several times over, so it has to aim much lower.
// A whole article has to finish in a time a person will actually wait. Past
// this we stop and show what we have, instead of sitting on a percentage.
const TOTAL_BUDGET_MS = 45_000
const MAX_CONSECUTIVE_FAILURES = 2

const BATCH_CHARS_VIA_BRIDGE = 1400
const BATCH_CHARS_VIA_URL = 400

function batchBudget(): number {
  return window.electronAPI?.translateText ? BATCH_CHARS_VIA_BRIDGE : BATCH_CHARS_VIA_URL
}
// Nodes inside these carry code or markup, where a translation would be wrong.
const SKIP_ANCESTORS = new Set(['SCRIPT', 'STYLE', 'CODE', 'PRE', 'KBD', 'SAMP'])
const SEPARATOR = '\n'

function readArticleCache(key: string): string | null {
  try {
    return sessionStorage.getItem(ARTICLE_CACHE_PREFIX + key)
  } catch {
    return null
  }
}

function writeArticleCache(key: string, html: string) {
  try {
    sessionStorage.setItem(ARTICLE_CACHE_PREFIX + key, html)
  } catch {
    // article translations are large; a full cache is not worth failing over
  }
}

function collectTextNodes(root: ParentNode): Text[] {
  const walker = document.createTreeWalker(root as Node, NodeFilter.SHOW_TEXT)
  const nodes: Text[] = []
  let current = walker.nextNode()
  while (current) {
    const node = current as Text
    const value = node.nodeValue ?? ''
    // Pure whitespace and stray punctuation carry no meaning to translate,
    // and sending them would waste the character budget.
    if (value.trim().length > 1 && /\p{L}/u.test(value)) {
      let skip = false
      for (let el = node.parentElement; el; el = el.parentElement) {
        if (SKIP_ANCESTORS.has(el.tagName)) {
          skip = true
          break
        }
      }
      if (!skip) nodes.push(node)
    }
    current = walker.nextNode()
  }
  return nodes
}

function batchNodes(nodes: Text[]): Text[][] {
  const budget = batchBudget()
  const batches: Text[][] = []
  let batch: Text[] = []
  let size = 0
  for (const node of nodes) {
    const len = (node.nodeValue ?? '').length
    if (batch.length > 0 && size + len > budget) {
      batches.push(batch)
      batch = []
      size = 0
    }
    batch.push(node)
    size += len + SEPARATOR.length
  }
  if (batch.length > 0) batches.push(batch)
  return batches
}

interface Budget {
  /** Wall-clock cutoff for the whole article; past it we stop and keep what we have. */
  deadline: number
}

const outOfTime = (budget: Budget) => Date.now() > budget.deadline

async function translateBatch(batch: Text[], target: string, budget: Budget): Promise<boolean> {
  // Newlines are the delimiter, so any that a node already contains — HTML
  // source is routinely indented across lines — would inflate the split count
  // and force the whole batch down the one-request-per-node path. Collapsing
  // runs of whitespace costs nothing, since HTML renders them as one space.
  const originals = batch.map((n) => (n.nodeValue ?? '').replace(/\s+/g, ' ').trim())
  const joined = originals.join(SEPARATOR)
  const result = await translateChunk(joined, target)
  const parts = result.split(SEPARATOR)

  // The endpoint is not contractually obliged to give back the same number of
  // lines it was handed, and a silent misalignment would attach each
  // paragraph's text to the wrong element. Verify, and if it doesn't line up,
  // translate this batch one node at a time instead of shipping scrambled text.
  if (parts.length === batch.length) {
    batch.forEach((node, i) => {
      const next = parts[i]?.trim()
      if (next) node.nodeValue = next
    })
    return true
  }

  // Falling back to one request per node multiplies the provider's whole
  // retry-and-fallback chain by the number of nodes, which is how a single
  // stalled batch could hold the reader at the same percentage indefinitely.
  // The deadline is what stops that.
  let any = false
  for (let i = 0; i < batch.length; i++) {
    if (outOfTime(budget)) break
    try {
      const single = await translateChunk(originals[i], target)
      if (single.trim()) {
        batch[i].nodeValue = single.trim()
        any = true
      }
    } catch {
      // leave this node in its original language rather than dropping it
    }
  }
  return any
}

export interface TranslatedArticle {
  html: string
  /** False when some paragraphs were left in the original language. */
  complete: boolean
}

export interface TranslateArticleOptions {
  target?: string
  signal?: AbortSignal
  onProgress?: (fraction: number) => void
  cacheKey?: string
}

/**
 * Translates an article's HTML in place, preserving its structure — only text
 * nodes are rewritten, so paragraphs, images, and links survive untouched.
 */
export async function translateArticleHtml(
  html: string,
  { target = 'vi', signal, onProgress, cacheKey }: TranslateArticleOptions = {}
): Promise<TranslatedArticle> {
  if (cacheKey) {
    const cached = readArticleCache(cacheKey)
    if (cached) {
      onProgress?.(1)
      return { html: cached, complete: true }
    }
  }

  const doc = new DOMParser().parseFromString(`<div id="root">${html}</div>`, 'text/html')
  const root = doc.getElementById('root')
  if (!root) throw new Error('Không đọc được nội dung để dịch')

  const nodes = collectTextNodes(root)
  if (nodes.length === 0) return { html, complete: true }

  const batches = batchNodes(nodes)
  const budget: Budget = { deadline: Date.now() + TOTAL_BUDGET_MS }
  let done = 0
  let succeeded = 0
  let consecutiveFailures = 0
  let stopped = false

  for (const batch of batches) {
    if (signal?.aborted) throw new Error('aborted')

    // Rate limiting doesn't clear within one article, so once the provider has
    // refused twice in a row the remaining batches would only burn through the
    // same timeouts to fail the same way. Stop and keep what's translated
    // rather than leaving the reader watching a frozen percentage.
    if (outOfTime(budget) || consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
      stopped = true
      break
    }

    // Back-to-back requests are what trips the rate limit in the first place.
    if (done > 0) await new Promise((r) => setTimeout(r, 250))

    let ok = false
    try {
      ok = await translateBatch(batch, target, budget)
    } catch {
      // One failed batch shouldn't discard the paragraphs that did translate.
    }
    if (ok) {
      succeeded++
      consecutiveFailures = 0
    } else {
      consecutiveFailures++
    }
    done++
    onProgress?.(done / batches.length)
  }

  // Never leave the caller on a partial number — whether we finished the last
  // batch or gave up early, the work is over.
  onProgress?.(1)

  // Only a total washout is worth an error — a partial translation is still
  // more useful to the reader than being sent back to the original.
  if (succeeded === 0) throw new Error('Không thể dịch bài viết này')

  const html_ = root.innerHTML
  const complete = !stopped && succeeded === batches.length
  // A partial result is deliberately not cached: reopening the article should
  // get another go at the paragraphs that were left untranslated.
  if (cacheKey && complete) writeArticleCache(cacheKey, html_)
  return { html: html_, complete }
}
