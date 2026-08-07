import { motion } from 'framer-motion'
import type { Tag } from '../types/news'
import CategoryIcon from './CategoryIcon'

interface Props {
  tags: Tag[]
  selected: Set<string>
  onToggle: (tagId: string) => void
}

export default function InterestPicker({ tags, selected, onToggle }: Props) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
      {tags.map((tag) => {
        const active = selected.has(tag.id)
        return (
          <motion.button
            key={tag.id}
            type="button"
            onClick={() => onToggle(tag.id)}
            whileTap={{ scale: 0.96 }}
            className={`flex flex-col items-center gap-2 rounded-2xl border px-4 py-5 text-center transition ${
              active
                ? 'border-[var(--text-1)] bg-[var(--text-1)] text-[var(--bg)]'
                : 'border-[var(--border-1)] bg-[var(--surface-1)] text-[var(--text-2)] hover:bg-[var(--surface-2)]'
            }`}
          >
            <CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={20} chip className="!h-11 !w-11" />
            <span className="text-[13px] font-medium leading-tight">{tag.label}</span>
          </motion.button>
        )
      })}
    </div>
  )
}
