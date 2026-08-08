import { useCallback, useEffect, useState } from 'react'
import { fetchLatestRelease, isNewerVersion, type ReleaseInfo } from '../services/updateService'

type UpdateStatus = 'idle' | 'checking' | 'update-available' | 'up-to-date' | 'error'
type InstallStatus = 'idle' | 'downloading' | 'error'

export interface UpdateProgressState {
  percent: number
  transferred: number
  total: number
  bytesPerSecond: number
}

const INITIAL_PROGRESS: UpdateProgressState = {
  percent: 0,
  transferred: 0,
  total: 0,
  bytesPerSecond: 0,
}

export function useAppUpdate(autoCheckEnabled: boolean) {
  const [isElectron, setIsElectron] = useState(false)
  const [currentVersion, setCurrentVersion] = useState<string | null>(null)
  const [status, setStatus] = useState<UpdateStatus>('idle')
  const [latest, setLatest] = useState<ReleaseInfo | null>(null)
  const [installStatus, setInstallStatus] = useState<InstallStatus>('idle')
  const [installProgress, setInstallProgress] = useState<UpdateProgressState>(INITIAL_PROGRESS)

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

  useEffect(() => {
    if (isElectron && autoCheckEnabled && currentVersion) {
      check()
    }
  }, [isElectron, currentVersion, autoCheckEnabled, check])

  const install = useCallback(async () => {
    if (!latest?.downloadUrl || !window.electronAPI) return
    setInstallStatus('downloading')
    setInstallProgress(INITIAL_PROGRESS)

    const unsubscribe = window.electronAPI.onUpdateProgress((data) => {
      if (typeof data === 'number') {
        setInstallProgress({ percent: data, transferred: 0, total: 0, bytesPerSecond: 0 })
      } else {
        setInstallProgress(data)
      }
    })

    try {
      await window.electronAPI.downloadAndInstallUpdate(latest.downloadUrl)
    } catch {
      setInstallStatus('error')
    } finally {
      unsubscribe()
    }
  }, [latest])

  return { isElectron, currentVersion, status, latest, check, installStatus, installProgress, install }
}

export type AppUpdateState = ReturnType<typeof useAppUpdate>
