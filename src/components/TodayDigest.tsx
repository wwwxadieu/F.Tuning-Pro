import { motion } from 'framer-motion'
import { useMemo, useRef } from 'react'
import type { Article, Tag } from '../types/news'
import { useTags } from '../context/TagsContext'
import { useHoverPrefetch } from '../hooks/useHoverPrefetch'
import { useViewportPrefetch } from '../hooks/useViewportPrefetch'
import CategoryIcon from './CategoryIcon'
import { FlameIcon } from './categoryIcons'
import { formatRelativeTime } from '../utils/time'

interface Props {
  articles: Article[]
  recommendedArticles?: Article[]
  loading: boolean
  onOpenArticle: (article: Article, list: Article[]) => void
}

const DIGEST_SIZE = 5
const MAX_AGE_MS = 2 * 24 * 60 * 60 * 1000

function pickDiverse(sortedByRecency: Article[], size: number): Article[] {
  const picked: Article[] = []
  const seenTags = new Set<string>()
  for (const article of sortedByRecency) {
    if (picked.length >= size) break
    if (seenTags.has(article.tagId)) continue
    seenTags.add(article.tagId)
    picked.push(article)
  }
  if (picked.length < size) {
    const pickedIds = new Set(picked.map((a) => a.id))
    for (const article of sortedByRecency) {
      if (picked.length >= size) break
      if (pickedIds.has(article.id)) continue
      picked.push(article)
    }
  }
  return picked
}

export default function TodayDigest({ articles, recommendedArticles = [], loading, onOpenArticle }: Props) {
  const { tagMap } = useTags()

  const topStories = useMemo(() => {
    const sorted = [...articles].sort((a, b) => new Date(b.pubDate).getTime() - new Date(a.pubDate).getTime())
    const recent = sorted.filter((a) => Date.now() - new Date(a.pubDate).getTime() <= MAX_AGE_MS)
    return pickDiverse(recent.length >= DIGEST_SIZE ? recent : sorted, DIGEST_SIZE)
  }, [articles])

  const hasRecommendations = recommendedArticles.length > 0

  if (!loading && topStories.length === 0 && !hasRecommendations) return null

  return (
    <section className="mx-auto max-w-[1900px] px-6 pb-2 pt-10 sm:px-8">
      {/* Side by side once there's room; stacked on narrow windows, where two
          columns would squeeze the headlines to a few words per line. */}
      <div className={`grid gap-8 ${hasRecommendations ? 'lg:grid-cols-2' : 'grid-cols-1'}`}>
        {hasRecommendations && (
          <div>
            <div className="mb-4 flex items-center gap-2.5">
              <h2 className="flex items-center gap-2 text-lg font-semibold tracking-tight sm:text-xl">
                <span className="flex h-6 w-6 items-center justify-center rounded-lg bg-gradient-to-tr from-[#FF375F] to-[#FF9F0A] text-[13px] shadow-sm">
                  ✨
                </span>
                Dành riêng cho bạn
              </h2>
              <span className="text-[12px] text-[var(--text-4)]">Dựa trên thói quen đọc của bạn</span>
            </div>

            <div className="glass flex flex-col divide-y divide-[var(--border-1)] overflow-hidden rounded-2xl">
              {recommendedArticles.slice(0, DIGEST_SIZE).map((article, i) => (
                <DigestRow
                  key={`rec-${article.id}`}
                  article={article}
                  index={i}
                  showIndex={false}
                  tag={tagMap.get(article.tagId)}
                  onOpenArticle={() => onOpenArticle(article, recommendedArticles)}
                />
              ))}
            </div>
          </div>
        )}

        <div>
          <div className="mb-4 flex items-center gap-2.5">
            <h2 className="flex items-center gap-2 text-lg font-semibold tracking-tight sm:text-xl">
              <FlameIcon width={19} height={19} style={{ color: '#FF9F0A' }} />
              Nổi bật hôm nay
            </h2>
            <span className="text-[12px] text-[var(--text-4)]">Tin mới nhất từ mọi chuyên mục</span>
          </div>

          <div className="glass flex flex-col divide-y divide-[var(--border-1)] overflow-hidden rounded-2xl">
            {loading && topStories.length === 0
              ? Array.from({ length: DIGEST_SIZE }).map((_, i) => <DigestSkeleton key={i} />)
              : topStories.map((article, i) => (
                  <DigestRow
                    key={article.id}
                    article={article}
                    index={i}
                    tag={tagMap.get(article.tagId)}
                    onOpenArticle={() => onOpenArticle(article, topStories)}
                  />
                ))}
          </div>
        </div>
      </div>
    </section>
  )
}

function DigestRow({
  article,
  index,
  tag,
  onOpenArticle,
  showIndex = true,
}: {
  article: Article
  index: number
  tag: Tag | undefined
  onOpenArticle: () => void
  /** Off for recommendations — those are suggestions, not a ranked chart. */
  showIndex?: boolean
}) {
  const ref = useRef<HTMLButtonElement>(null)
  const prefetch = useHoverPrefetch(article.link)
  useViewportPrefetch(article.link, ref as any)

  return (
    <motion.button
      type="button"
      ref={ref}
      onClick={onOpenArticle}
      onMouseEnter={prefetch.onMouseEnter}
      onMouseLeave={prefetch.onMouseLeave}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: Math.min(index * 0.06, 0.3) }}
      className="flex w-full items-center gap-4 px-4 py-3 text-left transition hover:bg-[var(--surface-1)]"
    >
      {showIndex && (
        <span className="w-5 shrink-0 text-center text-[15px] font-bold text-[var(--text-4)]">{index + 1}</span>
      )}
      <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-xl bg-gradient-to-br from-[#0A84FF]/40 to-[#BF5AF2]/40">
        {article.image && (
          <img
            src={article.image}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover"
            onError={(e) => {
              ;(e.currentTarget as HTMLImageElement).style.display = 'none'
            }}
          />
        )}
      </div>
      <div className="min-w-0 flex-1">
        <h3 className="line-clamp-1 text-[14px] font-semibold leading-snug text-[var(--text-1)] sm:line-clamp-2">
          {article.title}
        </h3>
        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-[var(--text-3)]">
          {tag && (
            <span className="flex items-center gap-1">
              <CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={11} />
              {tag.label}
            </span>
          )}
          <span className="text-[var(--text-4)]">·</span>
          <span>{formatRelativeTime(article.pubDate)}</span>
        </div>
      </div>
    </motion.button>
  )
}

function DigestSkeleton() {
  return (
    <div className="flex items-center gap-4 px-4 py-3">
      <div className="shimmer-bg h-14 w-14 shrink-0 animate-shimmer rounded-xl" />
      <div className="flex flex-1 flex-col gap-2">
        <div className="shimmer-bg h-3.5 w-4/5 animate-shimmer rounded-full" />
        <div className="shimmer-bg h-3 w-1/3 animate-shimmer rounded-full" />
      </div>
    </div>
  )
}
