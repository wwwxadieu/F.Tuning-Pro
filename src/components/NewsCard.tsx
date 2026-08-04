import { motion, useMotionTemplate, useSpring } from 'framer-motion'
import { useRef } from 'react'
import type { Article } from '../types/news'
import { TAG_MAP } from '../data/tags'
import { formatRelativeTime } from '../utils/time'

interface Props {
  article: Article
  index: number
}

const GRADIENTS = [
  'from-[#0A84FF] to-[#5E5CE6]',
  'from-[#BF5AF2] to-[#FF375F]',
  'from-[#FF9F0A] to-[#FF375F]',
  'from-[#30D158] to-[#0A84FF]',
  'from-[#64D2FF] to-[#5E5CE6]',
]

export default function NewsCard({ article, index }: Props) {
  const ref = useRef<HTMLAnchorElement>(null)
  const rotateX = useSpring(0, { stiffness: 300, damping: 25 })
  const rotateY = useSpring(0, { stiffness: 300, damping: 25 })
  const scale = useSpring(1, { stiffness: 300, damping: 25 })

  const transform = useMotionTemplate`perspective(900px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(${scale})`

  const tag = TAG_MAP.get(article.tagId)
  const gradient = GRADIENTS[index % GRADIENTS.length]

  function handleMouseMove(e: React.MouseEvent<HTMLAnchorElement>) {
    const el = ref.current
    if (!el) return
    const rect = el.getBoundingClientRect()
    const px = (e.clientX - rect.left) / rect.width - 0.5
    const py = (e.clientY - rect.top) / rect.height - 0.5
    rotateY.set(px * 14)
    rotateX.set(-py * 14)
  }

  function handleMouseLeave() {
    rotateX.set(0)
    rotateY.set(0)
    scale.set(1)
  }

  return (
    <motion.a
      ref={ref}
      href={article.link}
      target="_blank"
      rel="noopener noreferrer"
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      onMouseEnter={() => scale.set(1.03)}
      style={{ transform, transformStyle: 'preserve-3d' }}
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.5, delay: Math.min(index * 0.04, 0.3), ease: [0.16, 1, 0.3, 1] }}
      className="glass group flex flex-col overflow-hidden rounded-2xl transition-shadow will-change-transform hover:shadow-[0_20px_60px_rgba(0,0,0,0.5)]"
    >
      <div className={`relative aspect-[16/10] w-full overflow-hidden bg-gradient-to-br ${gradient}`}>
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
            className="absolute left-3 top-3 rounded-full bg-black/50 px-2.5 py-1 text-[11px] font-medium text-white backdrop-blur-md"
          >
            {tag.emoji} {tag.label}
          </span>
        )}
      </div>

      <div className="flex flex-1 flex-col gap-2 p-4" style={{ transform: 'translateZ(20px)' }}>
        <h3 className="line-clamp-2 text-[15px] font-semibold leading-snug tracking-tight text-white">
          {article.title}
        </h3>
        <p className="line-clamp-2 flex-1 text-[13px] leading-relaxed text-white/50">
          {article.description}
        </p>
        <div className="mt-1 flex items-center justify-between text-[11px] text-white/35">
          <span>{article.source}</span>
          <span>{formatRelativeTime(article.pubDate)}</span>
        </div>
      </div>
    </motion.a>
  )
}
