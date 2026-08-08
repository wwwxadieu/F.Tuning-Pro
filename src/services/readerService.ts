import { Readability } from '@mozilla/readability'
import { marked } from 'marked'
import DOMPurify from 'dompurify'

export interface ReaderContent {
  title: string | null
  html: string
}

const CACHE_PREFIX = 'luong:reader:'
const CACHE_TTL_MS = 60 * 60 * 1000 // 1 hour

function readCache(url: string): ReaderContent | null {
  try {
    const raw = sessionStorage.getItem(CACHE_PREFIX + url)
    if (!raw) return null
    const parsed = JSON.parse(raw) as { savedAt: number; content: ReaderContent }
    if (Date.now() - parsed.savedAt > CACHE_TTL_MS) return null
    return parsed.content
  } catch {
    return null
  }
}

function writeCache(url: string, content: ReaderContent) {
  try {
    sessionStorage.setItem(CACHE_PREFIX + url, JSON.stringify({ savedAt: Date.now(), content }))
  } catch {
    // storage full or unavailable — ignore
  }
}

const SANITIZE_CONFIG = {
  ADD_ATTR: ['target'],
  FORBID_TAGS: ['form', 'input', 'button', 'style'],
}

// ---------------------------------------------------------------------------
// Primary path: fetch the publisher's own HTML and extract it locally.
// ---------------------------------------------------------------------------

// Chrome/Firefox/Safari reader modes all run Readability over the live DOM,
// which is exactly what we can do here once the main process hands us the
// HTML. These are the wrappers Readability has no reason to keep and which
// otherwise leak into the article body — deliberately limited to containers
// that are never the story itself, since over-trimming would silently eat
// real content on sites that use these words in unrelated class names.
// Readability already treats "comment" as an unlikely candidate, but its own
// escape hatch un-filters anything whose class also contains "content" — which
// is exactly how a forum's `thread-comment__content` replies survive into the
// article. Removing these up front is what leaves just the original post.
const STRIP_SELECTORS = [
  'script',
  'style',
  'noscript',
  'template',
  'iframe[src*="ads"]',
  'nav',
  'aside',
  'footer',
  '[role="navigation"]',
  '[role="complementary"]',
  '[id*="comment"]',
  '[class*="comment"]',
  '[class*="Comment"]',
  '[class*="message-responses"]',
  '[class*="reactionsBar"]',
  '[class*="socialShare"]',
  '[class*="social-share"]',
  '[class*="relatedNews"]',
  '[class*="related-news"]',
  '[class*="newsletter"]',
  // Bootstrap-style mobile duplicate of the site chrome/footer.
  '[class*="visible-xs"]',
].join(',')

// A substring match could in principle hit a page-level wrapper (a <body
// class="has-comments">), which would throw the article away along with it.
const NEVER_STRIP = new Set(['HTML', 'BODY', 'HEAD', 'MAIN', 'ARTICLE'])

function extractWithReadability(html: string, baseUrl: string): ReaderContent {
  const doc = new DOMParser().parseFromString(html, 'text/html')

  // DOMParser gives the document our own file:// origin as its base, so every
  // relative <img src> and <a href> in the article would resolve against the
  // app bundle instead of the publisher. A <base> tag repoints resolution at
  // the real page, which is what lets Readability emit absolute URLs.
  const base = doc.createElement('base')
  base.setAttribute('href', baseUrl)
  doc.head?.prepend(base)

  doc.querySelectorAll(STRIP_SELECTORS).forEach((el) => {
    if (!NEVER_STRIP.has(el.tagName)) el.remove()
  })

  const article = new Readability(doc, { charThreshold: 250 }).parse()
  if (!article?.content) throw new Error('Không tách được nội dung bài viết')

  const html_ = DOMPurify.sanitize(article.content, SANITIZE_CONFIG)
  if (!html_.trim()) throw new Error('Nội dung rỗng')

  return { title: article.title?.trim() || null, html: stripLeadingTitle(html_, article.title) }
}

// Readability keeps the headline inside the extracted body on many sites, but
// the reader already renders the title above the content — drop the duplicate.
function stripLeadingTitle(html: string, title: string | null | undefined): string {
  if (!title) return html
  const wrapper = document.createElement('div')
  wrapper.innerHTML = html

  // Readability returns its output inside a <div id="readability-page-1">, and
  // sites often nest another wrapper or two below that, so the headline is
  // never the top-level first child — descend through single-child wrappers
  // until we reach the first element that actually holds content.
  let container: Element = wrapper
  while (
    container.children.length === 1 &&
    container.firstElementChild &&
    /^(div|section|article|main)$/i.test(container.firstElementChild.tagName)
  ) {
    container = container.firstElementChild
  }

  const first = container.firstElementChild
  if (!first) return html

  // Publishers repeat the headline as a heading; forums repeat it as the first
  // line of the post body. Both are duplicates of the title the reader already
  // renders above, and an exact text match makes removal safe either way.
  const normalize = (s: string) => s.replace(/\s+/g, ' ').trim().toLowerCase()
  if (
    /^(h[1-3]|p|div)$/i.test(first.tagName) &&
    normalize(first.textContent ?? '') === normalize(title)
  ) {
    first.remove()
    return wrapper.innerHTML
  }
  return html
}

async function fetchViaElectron(url: string): Promise<ReaderContent> {
  const api = window.electronAPI
  if (!api?.fetchArticleHtml) throw new Error('Không có cầu nối Electron')
  const result = await api.fetchArticleHtml(url)
  if (!result.ok) throw new Error(result.error)
  return extractWithReadability(result.html, result.finalUrl)
}

// ---------------------------------------------------------------------------
// Fallback path: the text-extraction proxy.
//
// Still needed for `npm run dev` in a plain browser (no Electron bridge), and
// as a safety net for the occasional site that refuses a direct fetch. It is
// no longer the primary path because it was measured at 7-21s per article on
// ordinary pages — frequently past any reasonable timeout, which is what left
// the reader stuck on its error screen.
// ---------------------------------------------------------------------------

const AUTHOR_CARD_RE = /\[!\[[^\]]*\]\([^)]*\)\]\((https?:\/\/[^)]*\/(?:profile|user|author|u)\/[^)]*)\)/g

function isolateOriginalPost(markdown: string): string {
  const matches = [...markdown.matchAll(AUTHOR_CARD_RE)]
  if (matches.length < 2) return markdown
  const start = matches[0].index! + matches[0][0].length
  const end = matches[1].index!
  const isolated = markdown.slice(start, end).trim()
  return isolated || markdown
}

const PROXY_TIMEOUT_MS = 30_000

async function fetchViaProxy(
  url: string,
  signal?: AbortSignal,
  priority?: RequestPriority
): Promise<ReaderContent> {
  const timeout = AbortSignal.timeout(PROXY_TIMEOUT_MS)
  const combinedSignal = signal ? AbortSignal.any([signal, timeout]) : timeout
  const res = await fetch(`https://r.jina.ai/${url}`, { signal: combinedSignal, priority })
  if (!res.ok) throw new Error(`jina HTTP ${res.status}`)
  const text = await res.text()

  const titleMatch = text.match(/^Title:\s*(.+)$/m)
  const markerIdx = text.indexOf('Markdown Content:')
  let markdown = markerIdx >= 0 ? text.slice(markerIdx + 'Markdown Content:'.length).trim() : text.trim()
  if (!markdown) throw new Error('Nội dung rỗng')

  markdown = isolateOriginalPost(markdown)
  markdown = markdown.replace(/^#{1,2}[ \t]+.+(?:\r?\n)+/, '')

  const rawHtml = await marked.parse(markdown, { async: true })
  return { title: titleMatch?.[1]?.trim() ?? null, html: DOMPurify.sanitize(rawHtml, SANITIZE_CONFIG) }
}

// ---------------------------------------------------------------------------

export async function fetchReaderContent(
  url: string,
  signal?: AbortSignal,
  priority?: RequestPriority
): Promise<ReaderContent> {
  const cached = readCache(url)
  if (cached) return cached

  const hasBridge = Boolean(window.electronAPI?.fetchArticleHtml)

  if (hasBridge) {
    try {
      const content = await fetchViaElectron(url)
      writeCache(url, content)
      return content
    } catch (err) {
      if (signal?.aborted) throw err
      // Direct fetch failed (site blocked us, or the markup defeated
      // extraction) — fall through to the proxy rather than giving up.
    }
  }

  if (signal?.aborted) throw new Error('aborted')

  const content = await fetchViaProxy(url, signal, priority)
  writeCache(url, content)
  return content
}
