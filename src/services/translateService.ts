const TRANSLATE_ENDPOINT = 'https://translate.googleapis.com/translate_a/single'
const CACHE_PREFIX = 'luong:translate:'

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
    // storage full or unavailable — ignore, caching is a pure optimization
  }
}

/**
 * Translates English text to Vietnamese via Google Translate's public
 * (unofficial, no-key) endpoint. Falls back to returning the original text
 * on any failure — a foreign headline in English is far better UX than a
 * broken/blank card.
 */
export async function translateText(text: string, target = 'vi'): Promise<string> {
  const trimmed = text.trim()
  if (!trimmed) return text

  const cached = readCache(trimmed)
  if (cached !== null) return cached

  try {
    const url = `${TRANSLATE_ENDPOINT}?client=gtx&sl=en&tl=${target}&dt=t&q=${encodeURIComponent(trimmed)}`
    const res = await fetch(url)
    if (!res.ok) throw new Error(`translate HTTP ${res.status}`)
    const data = (await res.json()) as unknown

    const segments = Array.isArray(data) ? (data[0] as unknown) : null
    const translated = Array.isArray(segments)
      ? segments.map((seg) => (Array.isArray(seg) ? String(seg[0] ?? '') : '')).join('')
      : ''

    if (!translated) return text
    writeCache(trimmed, translated)
    return translated
  } catch {
    return text
  }
}
