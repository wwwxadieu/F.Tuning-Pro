export interface Tag {
  id: string
  label: string
  emoji: string
  feedUrl: string
  source: string
  custom?: boolean
  /** Foreign-language source — translate article titles/descriptions to Vietnamese after fetching. */
  translate?: boolean
  /** No RSS/Atom feed could be found for this source — feedUrl is a plain page to scrape instead. */
  scrape?: boolean
}

export interface Article {
  id: string
  title: string
  description: string
  link: string
  image: string | null
  pubDate: string
  source: string
  tagId: string
}

export interface Notification {
  id: string
  tagId: string
  tagLabel: string
  count: number
  timestamp: number
  read: boolean
}

export type ReaderTheme = 'light' | 'sepia' | 'dark'
export type ReaderFont = 'serif' | 'sans'

export interface Settings {
  notificationsEnabled: boolean
  readerFontSize: number
  readerTheme: ReaderTheme
  readerFont: ReaderFont
  autoUpdateEnabled: boolean
}
