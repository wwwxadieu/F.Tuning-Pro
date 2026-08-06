import { motion } from 'framer-motion'
import { useMemo } from 'react'
import type { Article } from '../types/news'
import { useTags } from '../context/TagsContext'
import { formatRelativeTime } from '../utils/time'

interface Props {
  articles: Article[]
  loading: boolean
  onOpenArticle: (article: Article, list: Article[]) => void
}

const DIGEST_SIZE = 10

export default function TodayDigest({ articles, loading, onOpenArticle }: Props) {
  const { tagMap } = useTags()

  const topStories = useMemo(() => {
    return [...articles]
      .sort((a, b) => new Date(b.pubDate).getTime() - new Date(a.pubDate).getTime())
      .slice(0, DIGEST_SIZE)
  }, [articles])

  if (!loading && topStories.length === 0) return null

  return (
    <section className="mx-auto max-w-[1600px] px-6 pb-2 pt-10 sm:px-8">
      <div className="mb-4 flex items-baseline gap-2.5">
        <h2 className="text-lg font-semibold tracking-tight sm:text-xl">🔥 Nổi bật hôm nay</h2>
        <span className="text-[12px] text-white/35">Tổng hợp tin mới nhất từ mọi chuyên mục</span>
      </div>

      <div className="scrollbar-none -mx-6 flex gap-4 overflow-x-auto px-6 pb-3 sm:mx-0 sm:px-0">
        {loading && topStories.length === 0
          ? Array.from({ length: 5 }).map((_, i) => <DigestSkeleton key={i} />)
          : topStories.map((article, i) => {
              const tag = tagMap.get(article.tagId)
              return (
                <motion.button
                  key={article.id}
                  type="button"
                  onClick={() => onOpenArticle(article, topStories)}
                  initial={{ opacity: 0, x: 16 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ duration: 0.4, delay: Math.min(i * 0.05, 0.3) }}
                  className="glass flex w-[260px] shrink-0 flex-col overflow-hidden rounded-2xl text-left transition hover:shadow-[0_12px_40px_rgba(0,0,0,0.5)]"
                >
                  <div className="relative aspect-[16/9] w-full shrink-0 overflow-hidden bg-gradient-to-br from-[#0A84FF]/40 to-[#BF5AF2]/40">
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
                    <span className="absolute left-2 top-2 flex h-5 w-5 items-center justify-center rounded-full bg-black/60 text-[10px] font-bold text-white">
                      {i + 1}
                    </span>
                  </div>
                  <div className="flex flex-1 flex-col gap-1.5 p-3">
                    <h3 className="line-clamp-2 text-[13px] font-semibold leading-snug text-white">
                      {article.title}
                    </h3>
                    <div className="mt-auto flex items-center justify-between text-[10.5px] text-white/40">
                      <span>
                        {tag?.emoji} {tag?.label}
                      </span>
                      <span>{formatRelativeTime(article.pubDate)}</span>
                    </div>
                  </div>
                </motion.button>
              )
            })}
      </div>
    </section>
  )
}

function DigestSkeleton() {
  return (
    <div className="glass flex w-[260px] shrink-0 flex-col overflow-hidden rounded-2xl">
      <div className="shimmer-bg aspect-[16/9] w-full animate-shimmer" />
      <div className="flex flex-col gap-2 p-3">
        <div className="shimmer-bg h-3.5 w-full animate-shimmer rounded-full" />
        <div className="shimmer-bg h-3.5 w-2/3 animate-shimmer rounded-full" />
      </div>
    </div>
  )
}
