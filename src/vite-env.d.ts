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
      fetchHtml: (url: string) => Promise<string>
      fetchRawRss: (url: string) => Promise<string>
      onUpdateProgress: (callback: (data: number | UpdateProgressData) => void) => () => void
    }
  }
}
