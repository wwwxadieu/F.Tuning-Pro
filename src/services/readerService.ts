import { Readability } from '@mozilla/readability'
import { marked } from 'marked'
import DOMPurify from 'dompurify'

export interface ReaderContent {
  title: string | null
  html: string
}

const CACHE_PREFIX = 'luong:reader:'
const CACHE_TTL_MS = 60 * 60 * 1000 // 1 hour

const SANITIZE_CONFIG = { ADD_ATTR: ['target', 'src'] }

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
    // ignore
  }
}

// ---------------------------------------------------------------------------
// Shared cleanup
// ---------------------------------------------------------------------------

// Wrappers that are never the story itself. Readability already treats
// "comment" as an unlikely candidate, but its own escape hatch un-filters
// anything whose class also contains "content" — which is how a forum's
// `thread-comment__content` replies survive into the article body. Removing
// them up front is what leaves just the original post.
const STRIP_SELECTORS = [
  'script',
  'style',
  'noscript',
  'template',
  'svg',
  'form',
  'input',
  'button',
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
  '[class*="relate-news"]',
  '[class*="newsletter"]',
  '[class*="recommend"]',
  '[class*="tracking"]',
  '.ads',
  '.ad',
  '.banner',
  '.box-ads',
  '.author-info',
  '.back-to-top',
  // Bootstrap-style mobile duplicate of the site chrome/footer.
  '[class*="visible-xs"]',
].join(',')

// A substring match could in principle hit a page-level wrapper (a <body
// class="has-comments">), which would throw the article away along with it.
const NEVER_STRIP = new Set(['HTML', 'BODY', 'HEAD', 'MAIN', 'ARTICLE'])

// Boilerplate these publishers inline into the article body itself, so it
// survives element-level filtering and has to be matched on its text.
const PROMO_SNIPPETS = [
  'Thêm VnExpress trên Google',
  'Xem hướng dẫn',
  'Chọn VnExpress làm nguồn',
  'Theo dõi channel',
  'Google Search',
]

function stripNoise(root: ParentNode) {
  root.querySelectorAll(STRIP_SELECTORS).forEach((el) => {
    if (!NEVER_STRIP.has(el.tagName)) el.remove()
  })
}

function stripPromoText(root: ParentNode) {
  root.querySelectorAll('p, div, span, a').forEach((el) => {
    const text = el.textContent?.trim() ?? ''
    if (PROMO_SNIPPETS.some((s) => text.includes(s)) || text.startsWith('Trở lại ')) {
      el.remove()
    }
  })
}

// Lazy-loading sites leave the real image in data-src/data-original and ship a
// placeholder in src, so images would otherwise render blank in the reader.
function fixImages(root: ParentNode, origin: string) {
  root.querySelectorAll('img').forEach((img) => {
    const src =
      img.getAttribute('src') ||
      img.getAttribute('data-src') ||
      img.getAttribute('data-original') ||
      ''
    if (!src) return
    if (src.startsWith('//')) img.setAttribute('src', 'https:' + src)
    else if (src.startsWith('/')) img.setAttribute('src', origin + src)
    else img.setAttribute('src', src)
  })
}

function removeEmptyParagraphs(root: ParentNode) {
  root.querySelectorAll('p').forEach((p) => {
    if (!p.textContent?.trim() && p.querySelectorAll('img, video').length === 0) p.remove()
  })
}

// Publishers repeat the headline as a heading; forums repeat it as the first
// line of the post body. Both duplicate the title the reader renders above.
function stripLeadingTitle(html: string, title: string | null | undefined): string {
  if (!title) return html
  const wrapper = document.createElement('div')
  wrapper.innerHTML = html

  // Readability nests its output in <div id="readability-page-1">, often with
  // another wrapper below it, so the headline is never the top-level first
  // child — descend through single-child wrappers to the real first element.
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

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

const MIN_CONTENT_LENGTH = 50

/**
 * Article containers, most specific first — and they are tried in this order,
 * one at a time.
 *
 * A single comma-joined `querySelector` looks the same but is not: it returns
 * whichever element comes first *in the document*, whatever selector matched.
 * On a page carrying several <article> tags for teasers, a teaser near the top
 * therefore beat the real body further down, and the extraction came back too
 * short to use.
 */
const ARTICLE_SELECTORS = [
  '[itemprop="articleBody"]', // schema.org — precise, and widely used by VN CMSes
  '.knc-content',
  '.detail-content',
  'article.fck_detail',
  '.fck_detail',
  '.maincontent',
  '.content-detail',
  '.singular-content',
  '.post-content',
  '.entry-content',
  'article',
  'main',
]

/**
 * The first selector that matches anything wins, and among its matches the one
 * with the most text — several `<article>` tags on a page are usually teasers
 * around one real body.
 */
function findArticleElement(doc: Document): Element | null {
  for (const selector of ARTICLE_SELECTORS) {
    const matches = Array.from(doc.querySelectorAll(selector))
    if (matches.length === 0) continue
    return matches.reduce((best, el) =>
      (el.textContent?.length ?? 0) > (best.textContent?.length ?? 0) ? el : best
    )
  }
  return null
}

function originOf(targetUrl: string): string {
  try {
    return new URL(targetUrl).origin
  } catch {
    return ''
  }
}

/**
 * Readability is the engine behind Safari/Firefox reader modes: it scores the
 * DOM rather than matching known markup, so it handles arbitrary sites — which
 * is what user-added sources are. A fixed selector list can only ever cover
 * sites someone thought to add, so it runs second, as a safety net.
 */
function extractArticle(rawHtml: string, targetUrl: string): ReaderContent | null {
  const origin = originOf(targetUrl)
  const doc = new DOMParser().parseFromString(rawHtml, 'text/html')

  // DOMParser bases the document on our own file:// origin, so relative URLs
  // would resolve against the app bundle. A <base> tag repoints resolution at
  // the real page, which is what lets Readability emit absolute links.
  const base = doc.createElement('base')
  base.setAttribute('href', targetUrl)
  doc.head?.prepend(base)

  const pageTitle =
    doc.querySelector('h1.title-detail, h1.detail-title, h1, title')?.textContent?.trim() || null

  stripNoise(doc)

  // Readability consumes the document it is given, so hand it a clone and keep
  // the original intact for the selector fallback below.
  const readabilityDoc = doc.cloneNode(true) as Document
  try {
    const parsed = new Readability(readabilityDoc, { charThreshold: 250 }).parse()
    if (parsed?.content) {
      const holder = document.createElement('div')
      holder.innerHTML = parsed.content
      stripPromoText(holder)
      fixImages(holder, origin)
      removeEmptyParagraphs(holder)
      const clean = DOMPurify.sanitize(holder.innerHTML, SANITIZE_CONFIG)
      if (clean.trim().length >= MIN_CONTENT_LENGTH) {
        const title = parsed.title?.trim() || pageTitle
        return { title, html: stripLeadingTitle(clean, title) }
      }
    }
  } catch {
    // fall through to the selector approach
  }

  const articleEl = findArticleElement(doc)
  if (!articleEl) return null

  stripPromoText(articleEl)
  fixImages(articleEl, origin)
  removeEmptyParagraphs(articleEl)

  const clean = DOMPurify.sanitize(articleEl.innerHTML, SANITIZE_CONFIG)
  if (!clean || clean.trim().length < MIN_CONTENT_LENGTH) return null

  return { title: pageTitle, html: stripLeadingTitle(clean, pageTitle) }
}

// ---------------------------------------------------------------------------
// Transports, fastest and most reliable first
// ---------------------------------------------------------------------------

async function fetchViaNativeElectron(url: string): Promise<ReaderContent> {
  if (!window.electronAPI?.fetchHtml) throw new Error('Electron API unavailable')
  const rawHtml = await window.electronAPI.fetchHtml(url)
  const parsed = extractArticle(rawHtml, url)
  if (!parsed) throw new Error('Could not parse article from native fetch')
  return parsed
}

async function fetchViaCorsProxy(url: string, signal?: AbortSignal): Promise<ReaderContent> {
  const proxyUrls = [
    `https://api.allorigins.win/get?url=${encodeURIComponent(url)}`,
    `https://corsproxy.io/?url=${encodeURIComponent(url)}`,
  ]

  for (const proxyUrl of proxyUrls) {
    try {
      const combinedSignal = signal
        ? AbortSignal.any([signal, AbortSignal.timeout(8000)])
        : AbortSignal.timeout(8000)
      const res = await fetch(proxyUrl, { signal: combinedSignal })
      if (!res.ok) continue

      let rawHtml = ''
      if (proxyUrl.includes('allorigins')) {
        const data = await res.json()
        rawHtml = data.contents || ''
      } else {
        rawHtml = await res.text()
      }
      if (!rawHtml || rawHtml.length < 200) continue

      const parsed = extractArticle(rawHtml, url)
      if (parsed) return parsed
    } catch {
      if (signal?.aborted) throw new Error('aborted')
      // try next proxy
    }
  }

  throw new Error('CORS proxy failed')
}

const AUTHOR_CARD_RE = /\[!\[[^\]]*\]\([^)]*\)\]\((https?:\/\/[^)]*\/(?:profile|user|author|u)\/[^)]*)\)/g

function isolateOriginalPost(markdown: string): string {
  const matches = [...markdown.matchAll(AUTHOR_CARD_RE)]
  if (matches.length < 2) return markdown
  const start = matches[0].index! + matches[0][0].length
  const end = matches[1].index!
  const isolated = markdown.slice(start, end).trim()
  return isolated || markdown
}

// Last resort. Measured at 7-21s per article on ordinary pages, which is why
// it is no longer anywhere near the primary path.
async function fetchViaJina(
  url: string,
  signal?: AbortSignal,
  priority?: RequestPriority
): Promise<ReaderContent> {
  const timeout = AbortSignal.timeout(25_000)
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
  return {
    title: titleMatch?.[1]?.trim() ?? null,
    html: DOMPurify.sanitize(rawHtml, SANITIZE_CONFIG),
  }
}

export async function fetchReaderContent(
  url: string,
  signal?: AbortSignal,
  priority?: RequestPriority
): Promise<ReaderContent> {
  const cached = readCache(url)
  if (cached) return cached

  const attempts: Array<() => Promise<ReaderContent>> = [
    () => fetchViaNativeElectron(url),
    () => fetchViaCorsProxy(url, signal),
    () => fetchViaJina(url, signal, priority),
  ]

  let lastError: unknown = new Error('Không thể tải nội dung bài viết')
  for (const attempt of attempts) {
    if (signal?.aborted) throw new Error('aborted')
    try {
      const content = await attempt()
      writeCache(url, content)
      return content
    } catch (err) {
      lastError = err
    }
  }
  throw lastError
}
