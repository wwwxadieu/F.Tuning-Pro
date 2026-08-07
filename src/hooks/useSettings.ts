import { useEffect, useState } from 'react'
import type { Settings } from '../types/news'

const KEY = 'luong:settings'

const DEFAULT_SETTINGS: Settings = {
  notificationsEnabled: true,
  readerFontSize: 18,
  readerTheme: 'dark',
  readerFont: 'serif',
  autoUpdateEnabled: true,
}

function readInitial(): Settings {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return DEFAULT_SETTINGS
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) }
  } catch {
    return DEFAULT_SETTINGS
  }
}

export function useSettings() {
  const [settings, setSettings] = useState<Settings>(readInitial)

  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify(settings))
    } catch {
      // storage unavailable — settings just won't persist
    }
  }, [settings])

  function update(patch: Partial<Settings>) {
    setSettings((prev) => ({ ...prev, ...patch }))
  }

  return { settings, update }
}
