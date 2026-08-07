import { motion } from 'framer-motion'
import { useMemo } from 'react'
import type { Article, Tag } from '../types/news'
import { useTags } from '../context/TagsContext'
import { useHoverPrefetch } from '../hooks/useHoverPrefetch'
import CategoryIcon from './CategoryIcon'
import { FlameIcon } from './categoryIcons'
import { formatRelativeTime } from '../utils/time'

interface Props {
  articles: Article[]
  loading: boolean
  onOpenArticle: (article: Article, list: Article[]) => void
}

const DIGEST_SIZE = 5

export default function TodayDigest({ articles, loading, onOpenArticle }: Props) {
  const { tagMap } = useTags()

  const topStories = useMemo(() => {
    return [...articles]
      .sort((a, b) => new Date(b.pubDate).getTime() - new Date(a.pubDate).getTime())
      .slice(0, DIGEST_SIZE)
  }, [articles])

  if (!loading && topStories.length === 0) return null

  return (
    <section className="mx-auto max-w-[1900px] px-6 pb-2 pt-10 sm:px-8">
      <div className="mb-4 flex items-center gap-2.5">
        <h2 className="flex items-center gap-2 text-lg font-semibold tracking-tight sm:text-xl">
          <FlameIcon width={19} height={19} style={{ color: '#FF9F0A' }} />
          Nổi bật hôm nay
        </h2>
        <span className="text-[12px] text-white/35">Tổng hợp tin mới nhất từ mọi chuyên mục</span>
      </div>

      <div className="glass flex flex-col divide-y divide-white/8 overflow-hidden rounded-2xl">
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
    </section>
  )
}

function DigestRow({
  article,
  index,
  tag,
  onOpenArticle,
}: {
  article: Article
  index: number
  tag: Tag | undefined
  onOpenArticle: () => void
}) {
  const prefetch = useHoverPrefetch(article.link)

  return (
    <motion.button
      type="button"
      onClick={onOpenArticle}
      onMouseEnter={prefetch.onMouseEnter}
      onMouseLeave={prefetch.onMouseLeave}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, delay: Math.min(index * 0.06, 0.3) }}
      className="flex w-full items-center gap-4 px-4 py-3 text-left transition hover:bg-white/5"
    >
      <span className="w-5 shrink-0 text-center text-[15px] font-bold text-white/20">{index + 1}</span>
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
        <h3 className="line-clamp-1 text-[14px] font-semibold leading-snug text-white sm:line-clamp-2">
          {article.title}
        </h3>
        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-white/40">
          {tag && (
            <span className="flex items-center gap-1">
              <CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={11} />
              {tag.label}
            </span>
          )}
          <span className="text-white/20">·</span>
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
