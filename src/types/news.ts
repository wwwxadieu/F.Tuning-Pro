export interface Tag {
  id: string
  label: string
  emoji: string
  feedUrl: string
  source: string
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
