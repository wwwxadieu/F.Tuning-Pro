import type { Tag } from '../types/news'

export const TAGS: Tag[] = [
  {
    id: 'thoi-su',
    label: 'Thời sự',
    emoji: '🏛️',
    feedUrl: 'https://vnexpress.net/rss/thoi-su.rss',
    source: 'VnExpress',
  },
  {
    id: 'the-gioi',
    label: 'Thế giới',
    emoji: '🌍',
    feedUrl: 'https://vnexpress.net/rss/the-gioi.rss',
    source: 'VnExpress',
  },
  {
    id: 'kinh-doanh',
    label: 'Kinh doanh',
    emoji: '💼',
    feedUrl: 'https://vnexpress.net/rss/kinh-doanh.rss',
    source: 'VnExpress',
  },
  {
    id: 'khoa-hoc-cong-nghe',
    label: 'Khoa học - Công nghệ',
    emoji: '🚀',
    feedUrl: 'https://vnexpress.net/rss/khoa-hoc-cong-nghe.rss',
    source: 'VnExpress',
  },
  {
    id: 'the-thao',
    label: 'Thể thao',
    emoji: '⚽',
    feedUrl: 'https://vnexpress.net/rss/the-thao.rss',
    source: 'VnExpress',
  },
  {
    id: 'giai-tri',
    label: 'Giải trí',
    emoji: '🎬',
    feedUrl: 'https://vnexpress.net/rss/giai-tri.rss',
    source: 'VnExpress',
  },
  {
    id: 'giao-duc',
    label: 'Giáo dục',
    emoji: '🎓',
    feedUrl: 'https://vnexpress.net/rss/giao-duc.rss',
    source: 'VnExpress',
  },
  {
    id: 'suc-khoe',
    label: 'Sức khỏe',
    emoji: '❤️',
    feedUrl: 'https://vnexpress.net/rss/suc-khoe.rss',
    source: 'VnExpress',
  },
  {
    id: 'du-lich',
    label: 'Du lịch',
    emoji: '✈️',
    feedUrl: 'https://vnexpress.net/rss/du-lich.rss',
    source: 'VnExpress',
  },
]

export const TAG_MAP = new Map(TAGS.map((t) => [t.id, t]))
