import { motion } from 'framer-motion'
import { TAGS } from '../data/tags'

interface Props {
  selected: Set<string>
  onToggle: (tagId: string) => void
  onClear: () => void
}

export default function TagFilter({ selected, onToggle, onClear }: Props) {
  return (
    <div id="the" className="scrollbar-none -mx-6 flex gap-2.5 overflow-x-auto px-6 pb-2 sm:mx-0 sm:flex-wrap sm:overflow-visible sm:px-0">
      <Pill active={selected.size === 0} onClick={onClear}>
        Tất cả
      </Pill>
      {TAGS.map((tag) => (
        <Pill key={tag.id} active={selected.has(tag.id)} onClick={() => onToggle(tag.id)}>
          <span className="mr-1.5">{tag.emoji}</span>
          {tag.label}
        </Pill>
      ))}
    </div>
  )
}

function Pill({
  active,
  onClick,
  children,
}: {
  active: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <motion.button
      onClick={onClick}
      whileTap={{ scale: 0.94 }}
      className={`relative shrink-0 whitespace-nowrap rounded-full px-4 py-2 text-[13px] font-medium transition-colors ${
        active
          ? 'bg-white text-black'
          : 'border border-white/10 bg-white/5 text-white/70 hover:bg-white/10 hover:text-white'
      }`}
    >
      {children}
    </motion.button>
  )
}
