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
    // storage full or unavailable — ignore
  }
}

/**
 * Translates foreign text (English, French, Japanese, etc.) to Vietnamese
 * using Google Translate's auto-detect language endpoint.
 */
export async function translateText(text: string, target = 'vi'): Promise<string> {
  const trimmed = text.trim()
  if (!trimmed || trimmed.length < 3) return text

  const cached = readCache(trimmed)
  if (cached !== null) return cached

  try {
    const url = `${TRANSLATE_ENDPOINT}?client=gtx&sl=auto&tl=${target}&dt=t&q=${encodeURIComponent(trimmed)}`
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
