import { motion, useMotionTemplate, useSpring } from 'framer-motion'
import { useRef, useState } from 'react'
import type { Article } from '../types/news'
import { useTags } from '../context/TagsContext'
import { useHoverPrefetch } from '../hooks/useHoverPrefetch'
import { useViewportPrefetch } from '../hooks/useViewportPrefetch'
import CategoryIcon from './CategoryIcon'
import { formatRelativeTime } from '../utils/time'

interface Props {
  article: Article
  index: number
  onOpen: (article: Article) => void
}

const GRADIENTS = [
  'from-[#0A84FF] to-[#5E5CE6]',
  'from-[#BF5AF2] to-[#FF375F]',
  'from-[#FF9F0A] to-[#FF375F]',
  'from-[#30D158] to-[#0A84FF]',
  'from-[#64D2FF] to-[#5E5CE6]',
]

const ASPECT_RATIOS = ['aspect-[16/10]', 'aspect-[4/3]', 'aspect-[16/10]', 'aspect-[16/9]']

export default function NewsCard({ article, index, onOpen }: Props) {
  const ref = useRef<HTMLButtonElement>(null)
  const [imageFailed, setImageFailed] = useState(false)

  const rotateX = useSpring(0, { stiffness: 300, damping: 25 })
  const rotateY = useSpring(0, { stiffness: 300, damping: 25 })
  const scale = useSpring(1, { stiffness: 300, damping: 25 })

  const transform = useMotionTemplate`perspective(900px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(${scale})`

  const { tagMap } = useTags()
  const tag = tagMap.get(article.tagId)
  const gradient = GRADIENTS[index % GRADIENTS.length]
  const aspect = ASPECT_RATIOS[index % ASPECT_RATIOS.length]
  const prefetch = useHoverPrefetch(article.link)
  useViewportPrefetch(article.link, ref as any)

  function handleMouseMove(e: React.MouseEvent<HTMLButtonElement>) {
    const el = ref.current
    if (!el) return
    const rect = el.getBoundingClientRect()
    const px = (e.clientX - rect.left) / rect.width - 0.5
    const py = (e.clientY - rect.top) / rect.height - 0.5
    rotateY.set(px * 12)
    rotateX.set(-py * 12)
  }

  function handleMouseEnter() {
    scale.set(1.02)
    prefetch.onMouseEnter()
  }

  function handleMouseLeave() {
    rotateX.set(0)
    rotateY.set(0)
    scale.set(1)
    prefetch.onMouseLeave()
  }

  return (
    <motion.button
      type="button"
      ref={ref}
      onClick={() => onOpen(article)}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      onMouseEnter={handleMouseEnter}
      style={{ transform, transformStyle: 'preserve-3d' }}
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.5, delay: Math.min(index * 0.04, 0.3), ease: [0.16, 1, 0.3, 1] }}
      className="glass group flex w-full flex-col overflow-hidden rounded-2xl text-left transition-shadow will-change-transform hover:shadow-[0_20px_60px_rgba(0,0,0,0.5)] border border-white/10 bg-[#12131a]/80"
    >
      <div className={`relative w-full overflow-hidden bg-gradient-to-br ${gradient} ${aspect}`}>
        {article.image && !imageFailed ? (
          <img
            src={article.image}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover opacity-95 transition duration-500 group-hover:scale-105"
            style={{ transform: 'translateZ(30px)' }}
            onError={() => setImageFailed(true)}
          />
        ) : (
          <div className="flex h-full w-full flex-col items-center justify-center relative overflow-hidden bg-[#121420]/90">
            <div className="absolute inset-0 opacity-20 bg-[radial-gradient(#0A84FF_1px,transparent_1px)] [background-size:16px_16px]" />
            <div className="z-10 flex h-11 w-11 items-center justify-center rounded-2xl border border-white/15 bg-white/10 text-base font-bold text-white shadow-inner backdrop-blur-md">
              {article.source.slice(0, 2).toUpperCase()}
            </div>
            <span className="z-10 mt-2 text-[11px] font-bold tracking-wider text-white/60 uppercase">
              {article.source}
            </span>
          </div>
        )}

        {tag && (
          <span
            style={{ transform: 'translateZ(40px)' }}
            className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-black/60 py-1 pl-2 pr-3 text-[11px] font-semibold text-white backdrop-blur-md border border-white/10"
          >
            <CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={11} />
            {tag.label}
          </span>
        )}
      </div>

      <div className="flex flex-1 flex-col gap-2 p-4" style={{ transform: 'translateZ(20px)' }}>
        <h3 className="line-clamp-2 text-[15px] font-bold leading-snug tracking-tight text-[var(--text-1)] group-hover:text-blue-400 transition-colors">
          {article.title}
        </h3>
        <p className="line-clamp-2 flex-1 text-[13px] leading-relaxed text-[var(--text-3)]">
          {article.description}
        </p>
        <div className="mt-1 flex items-center justify-between border-t border-[var(--border-1)] pt-2 text-[11px] text-[var(--text-4)]">
          <span className="font-semibold text-[var(--text-3)]">{article.source}</span>
          <span>{formatRelativeTime(article.pubDate)}</span>
        </div>
      </div>
    </motion.button>
  )
}
