// Parses a feed URL the user typed, tolerating missing "https://" or TLD
// (e.g. "9to5mac", "9to5mac.com", "vnexpress.net/rss/thoi-su.rss")
export function parseFeedUrl(input: string): URL | null {
  let trimmed = input.trim()
  if (!trimmed) return null

  try {
    return new URL(trimmed)
  } catch {
    // fall through
  }

  // Prepend https://
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    trimmed = `https://${trimmed}`
  }

  try {
    return new URL(trimmed)
  } catch {
    // fall through
  }

  // If missing top-level domain e.g. "https://9to5mac" -> "https://9to5mac.com"
  if (!trimmed.slice(8).includes('.')) {
    try {
      return new URL(`${trimmed}.com`)
    } catch {
      return null
    }
  }

  return null
}
