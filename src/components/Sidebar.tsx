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
  const builtInTags = tags.filter((t) => !t.custom)
  const customTags = tags.filter((t) => t.custom)

  return (
    <AnimatePresence initial={false}>
      {open && (
        <motion.aside
          initial={{ x: -260, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          exit={{ x: -260, opacity: 0 }}
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed bottom-0 left-0 top-0 z-40 flex w-64 shrink-0 flex-col overflow-y-auto border-r border-white/10 bg-black/60 pb-6 pt-24 backdrop-blur-2xl"
        >
          <div className="px-3">
            <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wide text-white/30">
              Loại tin tức
            </p>
            <nav className="flex flex-col gap-0.5">
              <SidebarItem
                active={selected === null}
                emoji="📰"
                label="Tất cả"
                onClick={() => onSelect(null)}
              />
              {builtInTags.map((tag) => (
                <SidebarItem
                  key={tag.id}
                  active={selected === tag.id}
                  emoji={tag.emoji}
                  label={tag.label}
                  onClick={() => onSelect(tag.id)}
                />
              ))}
            </nav>
          </div>

          <div className="my-4 mx-5 h-px shrink-0 bg-white/10" />

          <div className="px-3">
            <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wide text-white/30">
              Nguồn tin tức
            </p>
            <nav className="flex flex-col gap-0.5">
              {customTags.map((tag) => (
                <SidebarItem
                  key={tag.id}
                  active={selected === tag.id}
                  emoji={tag.emoji}
                  label={tag.label}
                  onClick={() => onSelect(tag.id)}
                />
              ))}
            </nav>

            <button
              type="button"
              onClick={onOpenSettings}
              className="mt-1 flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-left text-[13px] font-medium text-white/40 transition hover:bg-white/5 hover:text-white/70"
            >
              <PlusIcon width={15} height={15} />
              Thêm nguồn tin
            </button>
          </div>

          <div className="mt-auto flex items-center gap-2 px-6 pt-4 text-[11px] text-white/25">
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
