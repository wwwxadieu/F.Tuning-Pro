export interface UpdateProgress {
  percent: number
  transferred: number
  total: number
  bytesPerSecond: number
}

export interface ElectronAPI {
  isElectron: true
  getAppVersion: () => Promise<string>
  downloadAndInstallUpdate: (url: string) => Promise<void>
  /** Fetches a page's HTML from the main process, bypassing renderer CORS. Rejects on failure. */
  fetchHtml: (url: string) => Promise<string>
  /** Same transport, used for feeds so they don't need a third-party converter. */
  fetchRawRss: (url: string) => Promise<string>
  /** Translates a block of text. POSTs from the main process, so long paragraphs are fine. */
  translateText: (text: string, target?: string) => Promise<string>
  onUpdateProgress: (callback: (data: UpdateProgress | number) => void) => () => void
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI
  }
}
