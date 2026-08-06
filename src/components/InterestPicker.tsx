import { motion } from 'framer-motion'
import type { Tag } from '../types/news'

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
                ? 'border-white bg-white text-black'
                : 'border-white/10 bg-white/5 text-white/80 hover:bg-white/10'
            }`}
          >
            <span className="text-2xl">{tag.emoji}</span>
            <span className="text-[13px] font-medium leading-tight">{tag.label}</span>
          </motion.button>
        )
      })}
    </div>
  )
}
