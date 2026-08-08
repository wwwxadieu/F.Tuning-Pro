export type ArticleFetchResult =
  | { ok: true; html: string; finalUrl: string }
  | { ok: false; error: string }

export interface ElectronAPI {
  isElectron: true
  getAppVersion: () => Promise<string>
  fetchArticleHtml: (url: string) => Promise<ArticleFetchResult>
  downloadAndInstallUpdate: (url: string) => Promise<void>
  onUpdateProgress: (callback: (percent: number) => void) => () => void
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI
  }
}
