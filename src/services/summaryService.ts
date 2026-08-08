/**
 * Extractive summarisation, done locally.
 *
 * The alternative — sending every opened article to a summarisation API —
 * would need a key the app doesn't have, cost money per article, and add one
 * more remote service that can rate-limit or go down mid-read. Scoring
 * sentences here is instant, works offline, and cannot fail, at the cost of
 * reusing the article's own sentences rather than writing new ones.
 */

const SUMMARY_SENTENCES = 3
const MIN_SENTENCES_TO_SUMMARISE = 5
const MIN_SENTENCE_CHARS = 40
const MAX_SENTENCE_CHARS = 400
// Below this the article is quicker to read than to skim a summary of.
const MIN_TEXT_CHARS = 900
// A "summary" nearly as long as the article saves the reader nothing — that
// happens on short posts, where three sentences can be the whole piece.
const MAX_COMPRESSION_RATIO = 0.55

// High-frequency function words carry no topic signal, so counting them would
// just favour whichever sentence is longest.
const STOPWORDS = new Set([
  'và', 'của', 'có', 'là', 'được', 'trong', 'cho', 'với', 'các', 'những', 'một',
  'người', 'này', 'đó', 'không', 'đã', 'khi', 'ra', 'thì', 'sẽ', 'từ', 'đến',
  'về', 'như', 'nhưng', 'vì', 'nếu', 'tại', 'trên', 'dưới', 'sau', 'trước',
  'cũng', 'còn', 'nên', 'phải', 'bị', 'do', 'mà', 'ở', 'lại', 'rất', 'quá',
  'nhiều', 'ít', 'hơn', 'nhất', 'vẫn', 'đang', 'vừa', 'mới', 'theo', 'để',
  'anh', 'chị', 'em', 'ông', 'bà', 'tôi', 'chúng', 'họ', 'nó', 'mình',
  'the', 'a', 'an', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'at', 'for',
  'with', 'is', 'are', 'was', 'were', 'be', 'been', 'it', 'its', 'this',
  'that', 'these', 'those', 'as', 'by', 'from', 'has', 'have', 'had', 'will',
  'would', 'can', 'could', 'they', 'he', 'she', 'you', 'we', 'i', 'not',
])

const BLOCK_SELECTOR =
  'p, div, li, h1, h2, h3, h4, h5, h6, blockquote, section, article, tr, figure'

/**
 * Flattens article HTML to text, keeping block boundaries as newlines.
 *
 * `textContent` alone concatenates adjacent blocks with nothing between them,
 * which glues a heading onto the paragraph below it and turns "…công ty
 * khác." + "Cùng ngày…" into one unsplittable run.
 */
export function htmlToText(html: string): string {
  const doc = new DOMParser().parseFromString(`<div>${html}</div>`, 'text/html')
  doc.querySelectorAll('script, style, figcaption, code, pre').forEach((el) => el.remove())
  doc.querySelectorAll('br').forEach((el) => el.replaceWith(doc.createTextNode('\n')))
  doc.querySelectorAll(BLOCK_SELECTOR).forEach((el) => el.append(doc.createTextNode('\n')))

  return (doc.body.textContent ?? '')
    .replace(/[ \t ]+/g, ' ')
    .replace(/\s*\n\s*/g, '\n')
    .replace(/\n{2,}/g, '\n')
    .trim()
}

/**
 * Splits on sentence-ending punctuation, but only when followed by whitespace
 * and something that starts a new sentence. That single condition is what
 * keeps "1.578 mã lực" and "TP.HCM" from being torn in half, since neither
 * has a space after the dot.
 */
function splitSentences(text: string): string[] {
  // A block boundary ends a sentence even without punctuation — a heading or
  // a list item usually has none — so split on those first, then on
  // punctuation within each block.
  return text
    .split('\n')
    .flatMap((line) =>
      line.split(
        /(?<=[.!?…])\s+(?=["'“”'(]?[A-ZÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ0-9])/u
      )
    )
    .map((s) => s.trim())
    .filter(Boolean)
}

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter((w) => w.length > 1 && !STOPWORDS.has(w))
}

export interface SummaryResult {
  sentences: string[]
  /** False when the article is too short for a summary to be worth showing. */
  usable: boolean
}

export function summarize(
  html: string,
  title = '',
  count = SUMMARY_SENTENCES
): SummaryResult {
  const text = htmlToText(html)
  if (text.length < MIN_TEXT_CHARS) return { sentences: [], usable: false }

  const all = splitSentences(text)
  const normalizedTitle = title.replace(/\s+/g, ' ').trim().toLowerCase()

  // Very short or very long fragments make poor summary lines — a stray
  // caption on one end, a run-on paragraph on the other. A sentence that just
  // repeats the headline adds nothing, since the headline is right above it.
  const candidates = all
    .map((sentence, index) => ({ sentence, index }))
    .filter(
      ({ sentence }) =>
        sentence.length >= MIN_SENTENCE_CHARS &&
        sentence.length <= MAX_SENTENCE_CHARS &&
        sentence.toLowerCase() !== normalizedTitle
    )

  if (all.length < MIN_SENTENCES_TO_SUMMARISE || candidates.length <= count) {
    return { sentences: [], usable: false }
  }

  const freq = new Map<string, number>()
  for (const word of tokenize(text)) freq.set(word, (freq.get(word) ?? 0) + 1)
  const maxFreq = Math.max(...freq.values(), 1)

  const titleWords = new Set(tokenize(title))

  const scored = candidates.map(({ sentence, index }) => {
    const words = tokenize(sentence)
    if (words.length === 0) return { sentence, index, score: 0 }

    // Dividing by sqrt rather than the raw count keeps a well-packed longer
    // sentence competitive without letting length alone decide.
    const topical = words.reduce((sum, w) => sum + (freq.get(w) ?? 0) / maxFreq, 0)
    let score = topical / Math.sqrt(words.length)

    // News writing front-loads the important facts, so the opening sentences
    // are genuinely more likely to be the summary.
    score *= 1 + Math.max(0, (10 - index) / 10) * 0.6

    // Sentences echoing the headline are usually restating the main point.
    const overlap = words.filter((w) => titleWords.has(w)).length
    if (overlap > 0) score *= 1 + Math.min(overlap, 4) * 0.12

    return { sentence, index, score }
  })

  const picked = scored
    .sort((a, b) => b.score - a.score)
    .slice(0, count)
    // Restoring document order matters: the highest-scoring sentences read as
    // a coherent paragraph only if they appear in the order they were written.
    .sort((a, b) => a.index - b.index)
    .map((s) => s.sentence)

  const summaryLength = picked.reduce((n, s) => n + s.length, 0)
  const worthShowing = picked.length > 0 && summaryLength / text.length <= MAX_COMPRESSION_RATIO

  return { sentences: picked, usable: worthShowing }
}
