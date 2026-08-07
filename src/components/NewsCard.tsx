import { motion, useMotionTemplate, useSpring } from 'framer-motion'
import { useRef } from 'react'
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

// Rotating aspect ratios give the masonry grid organic, Pinterest-like
// staggered heights instead of every card lining up in uniform rows.
const ASPECT_RATIOS = ['aspect-[4/5]', 'aspect-square', 'aspect-[16/10]', 'aspect-[3/4]', 'aspect-[16/9]']

export default function NewsCard({ article, index, onOpen }: Props) {
  const ref = useRef<HTMLButtonElement>(null)
  const rotateX = useSpring(0, { stiffness: 300, damping: 25 })
  const rotateY = useSpring(0, { stiffness: 300, damping: 25 })
  const scale = useSpring(1, { stiffness: 300, damping: 25 })

  const transform = useMotionTemplate`perspective(900px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(${scale})`

  const { tagMap } = useTags()
  const tag = tagMap.get(article.tagId)
  const gradient = GRADIENTS[index % GRADIENTS.length]
  const aspect = ASPECT_RATIOS[index % ASPECT_RATIOS.length]
  const prefetch = useHoverPrefetch(article.link)
  useViewportPrefetch(article.link, ref)

  function handleMouseMove(e: React.MouseEvent<HTMLButtonElement>) {
    const el = ref.current
    if (!el) return
    const rect = el.getBoundingClientRect()
    const px = (e.clientX - rect.left) / rect.width - 0.5
    const py = (e.clientY - rect.top) / rect.height - 0.5
    rotateY.set(px * 14)
    rotateX.set(-py * 14)
  }

  function handleMouseEnter() {
    scale.set(1.03)
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
      className="glass group flex w-full flex-col overflow-hidden rounded-2xl text-left transition-shadow will-change-transform hover:shadow-[0_20px_60px_rgba(0,0,0,0.5)]"
    >
      <div className={`relative w-full overflow-hidden bg-gradient-to-br ${gradient} ${aspect}`}>
        {article.image && (
          <img
            src={article.image}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover opacity-95 transition duration-500 group-hover:scale-105"
            style={{ transform: 'translateZ(30px)' }}
            onError={(e) => {
              ;(e.currentTarget as HTMLImageElement).style.display = 'none'
            }}
          />
        )}
        {tag && (
          <span
            style={{ transform: 'translateZ(40px)' }}
            className="absolute left-3 top-3 flex items-center gap-1.5 rounded-full bg-black/50 py-1 pl-1.5 pr-2.5 text-[11px] font-medium text-white backdrop-blur-md"
          >
            <CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={11} />
            {tag.label}
          </span>
        )}
      </div>

      <div className="flex flex-1 flex-col gap-2 p-4" style={{ transform: 'translateZ(20px)' }}>
        <h3 className="line-clamp-2 text-[15px] font-semibold leading-snug tracking-tight text-[var(--text-1)]">
          {article.title}
        </h3>
        <p className="line-clamp-2 flex-1 text-[13px] leading-relaxed text-[var(--text-3)]">
          {article.description}
        </p>
        <div className="mt-1 flex items-center justify-between text-[11px] text-[var(--text-4)]">
          <span>{article.source}</span>
          <span>{formatRelativeTime(article.pubDate)}</span>
        </div>
      </div>
    </motion.button>
  )
}
