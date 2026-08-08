import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useState } from 'react'
import { useTags } from '../context/TagsContext'
import { usePinnedTags } from '../hooks/usePinnedTags'
import CategoryIcon from './CategoryIcon'
import { GearIcon, PinIcon, PlusIcon, TrashIcon } from './icons'

interface Props {
  open: boolean
  selected: string | null
  onSelect: (tagId: string | null) => void
  onOpenSettings: () => void
  onRemoveSource: (tagId: string) => void
}

export default function Sidebar({ open, selected, onSelect, onOpenSettings, onRemoveSource }: Props) {
  const { tags } = useTags()
  const { isPinned, togglePin, pinned } = usePinnedTags(tags)
  const [version, setVersion] = useState('v1.0.31')

  useEffect(() => {
    if (window.electronAPI?.getAppVersion) {
      window.electronAPI.getAppVersion().then((v) => {
        if (v) setVersion(`v${v}`)
      })
    }
  }, [])

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
          className="fixed bottom-0 left-0 top-0 z-40 flex w-64 shrink-0 flex-col overflow-y-auto border-r border-[var(--border-1)] bg-[var(--bg)]/85 pb-6 pt-24 backdrop-blur-2xl"
          data-lenis-prevent
        >
          {pinnedTags.length > 0 && (
            <>
              <div className="px-3">
                <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--text-4)]">
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
                      onRemove={tag.custom ? () => onRemoveSource(tag.id) : undefined}
                    />
                  ))}
                </nav>
              </div>
              <div className="my-4 mx-5 h-px shrink-0 bg-[var(--border-1)]" />
            </>
          )}

          <div className="px-3">
            <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--text-4)]">
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

          <div className="my-4 mx-5 h-px shrink-0 bg-[var(--border-1)]" />

          <div className="px-3">
            <p className="mb-1.5 px-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--text-4)]">
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
                  onRemove={() => onRemoveSource(tag.id)}
                />
              ))}
            </nav>

            <button
              type="button"
              onClick={onOpenSettings}
              className="mt-1 flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-left text-[13px] font-medium text-[var(--text-3)] transition hover:bg-[var(--surface-1)] hover:text-[var(--text-2)]"
            >
              <PlusIcon width={15} height={15} />
              Thêm nguồn tin
            </button>
          </div>

          <div className="mt-auto px-3 pt-4">
            <div className="h-px bg-[var(--border-1)]" />
            <button
              type="button"
              onClick={onOpenSettings}
              className="mt-3 flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-left text-[13.5px] font-medium text-[var(--text-2)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)]"
            >
              <GearIcon width={16} height={16} />
              Cài đặt
            </button>
            <div className="mt-2.5 flex items-center justify-between px-3 text-[11px] font-medium text-[var(--text-3)]">
              <span className="flex items-center gap-1.5 font-semibold text-[var(--text-2)]">
                <span className="h-1.5 w-1.5 rounded-full bg-[#30D158]" />
                F.VNN {version}
              </span>
              <span className="text-[10.5px] opacity-70">{tags.length} chuyên mục</span>
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
  onRemove,
}: {
  active: boolean
  icon: React.ReactNode
  label: string
  onClick: () => void
  pinned?: boolean
  onTogglePin?: () => void
  showPinButton?: boolean
  onRemove?: () => void
}) {
  const pinColor = active
    ? pinned
      ? 'text-white'
      : 'text-white/60 hover:text-white'
    : pinned
      ? 'text-[var(--text-1)]'
      : 'text-[var(--text-3)] hover:text-[var(--text-1)]'
  const pinVisibility = pinned ? 'opacity-100' : 'opacity-40 group-hover:opacity-100 focus-visible:opacity-100'

  return (
    <div
      className={`group flex items-center gap-1 rounded-xl pr-1 transition ${
        active
          ? 'bg-[#0A84FF] text-white'
          : 'text-[var(--text-2)] hover:bg-[var(--surface-2)] hover:text-[var(--text-1)]'
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
      {onRemove && (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Xoá ${label}`}
          className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg opacity-40 transition hover:opacity-100 focus-visible:opacity-100 ${
            active
              ? 'text-white/60 hover:bg-white/15 hover:text-[#FF375F]'
              : 'text-[var(--text-3)] hover:bg-[var(--surface-2)] hover:text-[#FF375F]'
          }`}
        >
          <TrashIcon width={13} height={13} />
        </button>
      )}
    </div>
  )
}
