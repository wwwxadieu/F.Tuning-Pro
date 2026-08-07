import { useCallback, useEffect, useState } from 'react'
import { fetchLatestRelease, isNewerVersion, type ReleaseInfo } from '../services/updateService'

type UpdateStatus = 'idle' | 'checking' | 'update-available' | 'up-to-date' | 'error'

export function useAppUpdate(autoCheckEnabled: boolean) {
  const [isElectron, setIsElectron] = useState(false)
  const [currentVersion, setCurrentVersion] = useState<string | null>(null)
  const [status, setStatus] = useState<UpdateStatus>('idle')
  const [latest, setLatest] = useState<ReleaseInfo | null>(null)

  useEffect(() => {
    if (window.electronAPI?.isElectron) {
      setIsElectron(true)
      window.electronAPI
        .getAppVersion()
        .then(setCurrentVersion)
        .catch(() => setCurrentVersion(null))
    }
  }, [])

  const check = useCallback(async () => {
    if (!currentVersion) return
    setStatus('checking')
    try {
      const release = await fetchLatestRelease()
      if (release && isNewerVersion(release.version, currentVersion)) {
        setLatest(release)
        setStatus('update-available')
      } else {
        setLatest(null)
        setStatus('up-to-date')
      }
    } catch {
      setStatus('error')
    }
  }, [currentVersion])

  // Auto-check once, right after we know the real running version — only
  // if the user has automatic checking turned on at that moment.
  useEffect(() => {
    if (isElectron && autoCheckEnabled && currentVersion) {
      check()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isElectron, currentVersion])

  return { isElectron, currentVersion, status, latest, check }
}
