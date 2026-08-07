import { AnimatePresence, motion } from 'framer-motion'
import { useTags } from '../context/TagsContext'
import { usePinnedTags } from '../hooks/usePinnedTags'
import CategoryIcon from './CategoryIcon'
import { GearIcon, LayersIcon, PinIcon, PlusIcon } from './icons'

interface Props {
  open: boolean
  selected: string | null
  onSelect: (tagId: string | null) => void
  onOpenSettings: () => void
}

export default function Sidebar({ open, selected, onSelect, onOpenSettings }: Props) {
  const { tags } = useTags()
  const { isPinned, togglePin, pinned } = usePinnedTags(tags)
  const builtInTags = tags.filter((t) => !t.custom)
  const customTags = tags.filter((t) => t.custom)
  const pinnedTags = tags
    .filter((t) => pinned.includes(t.id))
    .sort((a, b) => pinned.indexOf(a.id) - pinned.indexOf(b.id))

  return (
    <AnimatePresence initial={false}>
      {open && (
        <motion.aside
          initial={{ x: -260, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          exit={{ x: -260, opacity: 0 }}
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed bottom-0 left-0 top-0 z-40 flex w-64 shrink-0 flex-col overflow-y-auto border-r border-white/10 bg-black/60 pb-6 pt-24 backdrop-blur-2xl"
          data-lenis-prevent
        >
          {pinnedTags.length > 0 && (
            <>
              <div className="px-3">
                <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wide text-white/30">
                  Đã ghim
                </p>
                <nav className="flex flex-col gap-0.5">
                  {pinnedTags.map((tag) => (
                    <SidebarItem
                      key={`pinned-${tag.id}`}
                      active={selected === tag.id}
                      icon={<CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={13} chip />}
                      label={tag.label}
                      onClick={() => onSelect(tag.id)}
                      pinned
                      onTogglePin={() => togglePin(tag.id)}
                    />
                  ))}
                </nav>
              </div>
              <div className="my-4 mx-5 h-px shrink-0 bg-white/10" />
            </>
          )}

          <div className="px-3">
            <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wide text-white/30">
              Loại tin tức
            </p>
            <nav className="flex flex-col gap-0.5">
              <SidebarItem
                active={selected === null}
                icon={<CategoryIcon tagId="all" size={13} chip />}
                label="Tất cả"
                onClick={() => onSelect(null)}
                showPinButton={false}
              />
              {builtInTags.map((tag) => (
                <SidebarItem
                  key={tag.id}
                  active={selected === tag.id}
                  icon={<CategoryIcon tagId={tag.id} size={13} chip />}
                  label={tag.label}
                  onClick={() => onSelect(tag.id)}
                  pinned={isPinned(tag.id)}
                  onTogglePin={() => togglePin(tag.id)}
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
                  icon={<CategoryIcon tagId={tag.id} emoji={tag.emoji} faviconHost={tag.source} size={13} chip />}
                  label={tag.label}
                  onClick={() => onSelect(tag.id)}
                  pinned={isPinned(tag.id)}
                  onTogglePin={() => togglePin(tag.id)}
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

          <div className="mt-auto px-3 pt-4">
            <div className="h-px bg-white/10" />
            <button
              type="button"
              onClick={onOpenSettings}
              className="mt-3 flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-left text-[13.5px] font-medium text-white/70 transition hover:bg-white/10 hover:text-white"
            >
              <GearIcon width={16} height={16} />
              Cài đặt
            </button>
            <div className="mt-2 flex items-center gap-2 px-3 text-[11px] text-white/25">
              <LayersIcon width={13} height={13} />
              {tags.length} chuyên mục
            </div>
          </div>
        </motion.aside>
      )}
    </AnimatePresence>
  )
}

function SidebarItem({
  active,
  icon,
  label,
  onClick,
  pinned,
  onTogglePin,
  showPinButton = true,
}: {
  active: boolean
  icon: React.ReactNode
  label: string
  onClick: () => void
  pinned?: boolean
  onTogglePin?: () => void
  showPinButton?: boolean
}) {
  const pinColor = active
    ? pinned
      ? 'text-black'
      : 'text-black/40 hover:text-black'
    : pinned
      ? 'text-white'
      : 'text-white/40 hover:text-white'
  const pinVisibility = pinned ? 'opacity-100' : 'opacity-40 group-hover:opacity-100 focus-visible:opacity-100'

  return (
    <div
      className={`group flex items-center gap-1 rounded-xl pr-1 transition ${
        active ? 'bg-white text-black' : 'text-white/70 hover:bg-white/10 hover:text-white'
      }`}
    >
      <button
        type="button"
        onClick={onClick}
        className="flex min-w-0 flex-1 items-center gap-2.5 px-3 py-2 text-left text-[13.5px] font-medium"
      >
        {icon}
        <span className="truncate">{label}</span>
      </button>
      {showPinButton && onTogglePin && (
        <button
          type="button"
          onClick={onTogglePin}
          aria-label={pinned ? `Bỏ ghim ${label}` : `Ghim ${label}`}
          aria-pressed={pinned}
          className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg transition ${pinColor} ${pinVisibility}`}
        >
          <PinIcon width={13} height={13} fill={pinned ? 'currentColor' : 'none'} />
        </button>
      )}
    </div>
  )
}
