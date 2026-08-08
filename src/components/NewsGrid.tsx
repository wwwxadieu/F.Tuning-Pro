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
  supplementing: Record<string, boolean>
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
  supplementing,
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
        ? tags.filter((t) => interests.includes(t.id) || t.custom)
        : tags

  return (
    <div id="tin-tuc" className="flex flex-col gap-16">
      {visibleTags.map((tag) => {
        const items = articles
          .filter((a) => a.tagId === tag.id)
          .sort((a, b) => new Date(b.pubDate).getTime() - new Date(a.pubDate).getTime())
        const status = statuses[tag.id]
        const revealCount = revealCounts[tag.id] ?? 18
        const visibleItems = items.slice(0, revealCount)
        const hasMore = items.length > revealCount || supplementing[tag.id] === true

        return (
          <section key={tag.id}>
            <motion.div
              initial={{ opacity: 0, x: -12 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.5 }}
              className="mb-5 flex items-center justify-between border-b border-white/10 pb-3"
            >
              <h2 className="flex items-center gap-2.5 text-xl font-bold tracking-tight sm:text-2xl text-white">
                <CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={18} chip />
                {tag.label}
              </h2>
              <div className="flex items-center gap-3 text-[12px] text-white/60">
                <span>{tag.source}</span>
                {items.length > 0 && (
                  <span className="rounded-full bg-white/10 px-2.5 py-0.5 font-semibold text-white/80">
                    {visibleItems.length} / {items.length} bài
                  </span>
                )}
              </div>
            </motion.div>

            {status === 'error' && items.length === 0 && (
              <div className="glass flex flex-col items-center gap-3 rounded-2xl px-6 py-10 text-center">
                <p className="text-sm text-[var(--text-3)]">Không thể tải tin cho chủ đề này lúc này.</p>
                <button
                  onClick={() => retryTag(tag.id)}
                  className="rounded-full bg-[var(--surface-2)] px-4 py-1.5 text-[13px] font-medium text-[var(--text-1)] transition hover:bg-[var(--surface-3)]"
                >
                  Thử lại
                </button>
              </div>
            )}

            {status === 'loading' && items.length === 0 && (
              <div className={`${MASONRY_COLS} gap-5`}>
                {Array.from({ length: 4 }).map((_, i) => (
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
                {hasMore && (
                  <div className="mt-8 flex flex-col items-center justify-center gap-3 py-4">
                    <button
                      onClick={() => onLoadMore(tag.id)}
                      className="flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-6 py-2.5 text-xs font-bold text-white transition hover:bg-white/20 active:scale-95 shadow-lg backdrop-blur-md"
                    >
                      <span>Xem thêm bài viết</span>
                      <span className="text-white/50">({items.length - visibleItems.length} tin)</span>
                    </button>
                    <LoadMoreSentinel onTrigger={() => onLoadMore(tag.id)} />
                  </div>
                )}
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
      { rootMargin: '200px' }
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [onTrigger])

  return (
    <div ref={ref} className="h-4 w-full flex justify-center items-center opacity-40">
      <div className="h-4 w-4 animate-spin rounded-full border-2 border-white/20 border-t-white" />
    </div>
  )
}
