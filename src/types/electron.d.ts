export interface ElectronAPI {
  isElectron: true
  getAppVersion: () => Promise<string>
  downloadAndInstallUpdate: (url: string) => Promise<void>
  onUpdateProgress: (callback: (percent: number) => void) => () => void
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI
  }
}
