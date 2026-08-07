import { motion } from 'framer-motion'
import { useEffect, useRef } from 'react'
import { useTags } from '../context/TagsContext'
import type { Article } from '../types/news'
import CategoryIcon from './CategoryIcon'
import NewsCard from './NewsCard'
import CardSkeleton from './CardSkeleton'

interface Props {
  articles: Article[]
  statuses: Record<string, 'loading' | 'ok' | 'error'>
  revealCounts: Record<string, number>
  selected: string | null
  interests: string[]
  retryTag: (tagId: string) => void
  onLoadMore: (tagId: string) => void
  onOpenArticle: (article: Article, list: Article[]) => void
}

const MASONRY_COLS = 'columns-1 sm:columns-2 lg:columns-3 xl:columns-4 3xl:columns-5'

export default function NewsGrid({
  articles,
  statuses,
  revealCounts,
  selected,
  interests,
  retryTag,
  onLoadMore,
  onOpenArticle,
}: Props) {
  const { tags } = useTags()
  const visibleTags =
    selected !== null
      ? tags.filter((t) => t.id === selected)
      : interests.length > 0
        ? tags.filter((t) => interests.includes(t.id))
        : tags

  return (
    <div id="tin-tuc" className="flex flex-col gap-16">
      {visibleTags.map((tag) => {
        const items = articles
          .filter((a) => a.tagId === tag.id)
          .sort((a, b) => new Date(b.pubDate).getTime() - new Date(a.pubDate).getTime())
        const status = statuses[tag.id]
        const revealCount = revealCounts[tag.id] ?? 6
        const visibleItems = items.slice(0, revealCount)
        const hasMore = items.length > revealCount

        return (
          <section key={tag.id}>
            <motion.div
              initial={{ opacity: 0, x: -12 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.5 }}
              className="mb-5 flex items-center justify-between"
            >
              <h2 className="flex items-center gap-2.5 text-xl font-semibold tracking-tight sm:text-2xl">
                <CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={18} chip />
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
              <div className={`${MASONRY_COLS} gap-5`}>
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="mb-5 break-inside-avoid">
                    <CardSkeleton />
                  </div>
                ))}
              </div>
            )}

            {items.length > 0 && (
              <>
                <div className={`perspective-container ${MASONRY_COLS} gap-5`}>
                  {visibleItems.map((article, i) => (
                    <div key={article.id} className="mb-5 break-inside-avoid">
                      <NewsCard
                        article={article}
                        index={i}
                        onOpen={(a) => onOpenArticle(a, items)}
                      />
                    </div>
                  ))}
                </div>
                {hasMore && <LoadMoreSentinel onTrigger={() => onLoadMore(tag.id)} />}
              </>
            )}
          </section>
        )
      })}
    </div>
  )
}

function LoadMoreSentinel({ onTrigger }: { onTrigger: () => void }) {
  const ref = useRef<HTMLDivElement>(null)
  const firedRef = useRef(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && !firedRef.current) {
          firedRef.current = true
          onTrigger()
          setTimeout(() => {
            firedRef.current = false
          }, 600)
        }
      },
      { rootMargin: '0px' }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [onTrigger])

  return (
    <div ref={ref} className="mt-6 flex justify-center py-6">
      <div className="h-5 w-5 animate-spin rounded-full border-2 border-white/15 border-t-white/50" />
    </div>
  )
}
