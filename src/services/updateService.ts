const REPO = 'wwwxadieu/F.Tuning-Pro'
// The repo hosts releases for more than one app; only look at assets
// carrying this app's installer name so we never pick up an unrelated
// release published by a different pipeline in the same repo.
const ASSET_MARKER = 'F.VNN-Setup-'

export interface ReleaseInfo {
  version: string
  url: string
  publishedAt: string
  /** Direct download URL for the Windows installer, or null if the release has no matching .exe asset. */
  downloadUrl: string | null
}

interface GhRelease {
  tag_name: string
  html_url: string
  published_at: string
  draft: boolean
  prerelease: boolean
  assets?: { name: string; browser_download_url: string }[]
}

export async function fetchLatestRelease(signal?: AbortSignal): Promise<ReleaseInfo | null> {
  const res = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=20`, { signal })
  if (!res.ok) throw new Error(`GitHub API HTTP ${res.status}`)

  const releases = (await res.json()) as GhRelease[]
  const match = releases.find(
    (r) => !r.draft && !r.prerelease && r.assets?.some((a) => a.name.startsWith(ASSET_MARKER))
  )
  if (!match) return null

  const installerAsset = match.assets?.find((a) => a.name.startsWith(ASSET_MARKER) && a.name.endsWith('.exe'))

  return {
    version: match.tag_name.replace(/^v/, ''),
    url: match.html_url,
    publishedAt: match.published_at,
    downloadUrl: installerAsset?.browser_download_url ?? null,
  }
}

export function isNewerVersion(remote: string, current: string): boolean {
  const r = remote.split('.').map((n) => parseInt(n, 10) || 0)
  const c = current.split('.').map((n) => parseInt(n, 10) || 0)
  const len = Math.max(r.length, c.length)
  for (let i = 0; i < len; i++) {
    const rv = r[i] ?? 0
    const cv = c[i] ?? 0
    if (rv > cv) return true
    if (rv < cv) return false
  }
  return false
}
