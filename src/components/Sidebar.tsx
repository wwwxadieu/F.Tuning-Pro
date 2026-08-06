import { AnimatePresence, motion } from 'framer-motion'
import { useTags } from '../context/TagsContext'
import { LayersIcon, PlusIcon } from './icons'

interface Props {
  open: boolean
  selected: string | null
  onSelect: (tagId: string | null) => void
  onOpenSettings: () => void
}

export default function Sidebar({ open, selected, onSelect, onOpenSettings }: Props) {
  const { tags } = useTags()

  return (
    <AnimatePresence initial={false}>
      {open && (
        <motion.aside
          initial={{ x: -260, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          exit={{ x: -260, opacity: 0 }}
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed bottom-0 left-0 top-0 z-40 w-64 shrink-0 overflow-y-auto border-r border-white/10 bg-black/60 pb-6 pt-24 backdrop-blur-2xl"
        >
          <nav className="flex flex-col gap-0.5 px-3">
            <SidebarItem
              active={selected === null}
              emoji="📰"
              label="Tất cả"
              onClick={() => onSelect(null)}
            />
            <div className="my-2 h-px bg-white/10" />
            {tags.map((tag) => (
              <SidebarItem
                key={tag.id}
                active={selected === tag.id}
                emoji={tag.emoji}
                label={tag.label}
                onClick={() => onSelect(tag.id)}
              />
            ))}
          </nav>

          <div className="mt-4 px-3">
            <button
              type="button"
              onClick={onOpenSettings}
              className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-left text-[13px] font-medium text-white/40 transition hover:bg-white/5 hover:text-white/70"
            >
              <PlusIcon width={15} height={15} />
              Thêm nguồn tin
            </button>
          </div>

          <div className="mt-6 flex items-center gap-2 px-6 text-[11px] text-white/25">
            <LayersIcon width={13} height={13} />
            {tags.length} chuyên mục
          </div>
        </motion.aside>
      )}
    </AnimatePresence>
  )
}

function SidebarItem({
  active,
  emoji,
  label,
  onClick,
}: {
  active: boolean
  emoji: string
  label: string
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex items-center gap-2.5 rounded-xl px-3 py-2 text-left text-[13.5px] font-medium transition ${
        active ? 'bg-white text-black' : 'text-white/70 hover:bg-white/10 hover:text-white'
      }`}
    >
      <span className="text-base leading-none">{emoji}</span>
      <span className="truncate">{label}</span>
    </button>
  )
}
