// Parses a feed URL the user typed, tolerating a missing "https://" prefix
// (e.g. "vnexpress.net/rss/thoi-su.rss") by retrying with it prepended.
export function parseFeedUrl(input: string): URL | null {
  const trimmed = input.trim()
  if (!trimmed) return null

  try {
    return new URL(trimmed)
  } catch {
    // fall through to the https:// retry below
  }

  try {
    return new URL(`https://${trimmed}`)
  } catch {
    return null
  }
}
