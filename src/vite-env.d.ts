/// <reference types="vite/client" />

export interface UpdateProgressData {
  percent: number
  transferred: number
  total: number
  bytesPerSecond: number
}

declare global {
  interface Window {
    electronAPI?: {
      isElectron: boolean
      getAppVersion: () => Promise<string>
      downloadAndInstallUpdate: (url: string) => Promise<void>
      onUpdateProgress: (callback: (data: number | UpdateProgressData) => void) => () => void
    }
  }
}
