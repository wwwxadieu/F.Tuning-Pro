import { motion } from 'framer-motion'
import { TAGS } from '../data/tags'
import type { Article } from '../types/news'
import NewsCard from './NewsCard'
import CardSkeleton from './CardSkeleton'

interface Props {
  articles: Article[]
  statuses: Record<string, 'loading' | 'ok' | 'error'>
  selected: Set<string>
  retryTag: (tagId: string) => void
}

export default function NewsGrid({ articles, statuses, selected, retryTag }: Props) {
  const visibleTags = TAGS.filter((t) => selected.size === 0 || selected.has(t.id))

  return (
    <div id="tin-tuc" className="flex flex-col gap-16">
      {visibleTags.map((tag) => {
        const items = articles
          .filter((a) => a.tagId === tag.id)
          .sort((a, b) => new Date(b.pubDate).getTime() - new Date(a.pubDate).getTime())
        const status = statuses[tag.id]

        return (
          <section key={tag.id}>
            <motion.div
              initial={{ opacity: 0, x: -12 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.5 }}
              className="mb-5 flex items-center justify-between"
            >
              <h2 className="flex items-center gap-2 text-xl font-semibold tracking-tight sm:text-2xl">
                <span>{tag.emoji}</span>
                {tag.label}
              </h2>
              <span className="text-[12px] text-white/35">{tag.source}</span>
            </motion.div>

            {status === 'error' && items.length === 0 && (
              <div className="glass flex flex-col items-center gap-3 rounded-2xl px-6 py-10 text-center">
                <p className="text-sm text-white/50">Không thể tải tin cho chủ đề này lúc này.</p>
                <button
                  onClick={() => retryTag(tag.id)}
                  className="rounded-full bg-white/10 px-4 py-1.5 text-[13px] font-medium text-white transition hover:bg-white/20"
                >
                  Thử lại
                </button>
              </div>
            )}

            {status === 'loading' && items.length === 0 && (
              <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <CardSkeleton key={i} />
                ))}
              </div>
            )}

            {items.length > 0 && (
              <div className="perspective-container grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
                {items.slice(0, 6).map((article, i) => (
                  <NewsCard key={article.id} article={article} index={i} />
                ))}
              </div>
            )}
          </section>
        )
      })}
    </div>
  )
}
