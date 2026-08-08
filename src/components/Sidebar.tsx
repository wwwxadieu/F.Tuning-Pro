import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useState } from 'react'
import { useTags } from '../context/TagsContext'
import { usePinnedTags } from '../hooks/usePinnedTags'
import CategoryIcon from './CategoryIcon'
import { ChevronDownIcon, GearIcon, PinIcon, PlusIcon, TrashIcon } from './icons'

type SectionId = 'pinned' | 'categories' | 'sources'

const COLLAPSE_KEY = 'luong:sidebar-collapsed'

function readCollapsed(): Record<string, boolean> {
  try {
    const raw = localStorage.getItem(COLLAPSE_KEY)
    return raw ? (JSON.parse(raw) as Record<string, boolean>) : {}
  } catch {
    return {}
  }
}

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
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>(readCollapsed)

  // Remembered across launches — a section the user tidied away should stay
  // that way rather than springing back open next time.
  useEffect(() => {
    try {
      localStorage.setItem(COLLAPSE_KEY, JSON.stringify(collapsed))
    } catch {
      // preference only; not worth failing over
    }
  }, [collapsed])

  const toggleSection = (id: SectionId) =>
    setCollapsed((prev) => ({ ...prev, [id]: !prev[id] }))

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
          {/* Kept out of the collapsible sections: this is how you clear a
              filter, so hiding it could strand someone on one category. */}
          <div className="px-3">
            <nav className="flex flex-col gap-0.5">
              <SidebarItem
                active={selected === null}
                icon={<CategoryIcon tagId="all" size={13} chip />}
                label="Tất cả"
                onClick={() => onSelect(null)}
                showPinButton={false}
              />
            </nav>
          </div>

          <div className="my-3 mx-5 h-px shrink-0 bg-[var(--border-1)]" />

          {pinnedTags.length > 0 && (
            <>
              <SidebarSection
                title="Đã ghim"
                count={pinnedTags.length}
                collapsed={!!collapsed.pinned}
                onToggle={() => toggleSection('pinned')}
                hasActive={pinnedTags.some((t) => t.id === selected)}
              >
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
              </SidebarSection>
              <div className="my-3 mx-5 h-px shrink-0 bg-[var(--border-1)]" />
            </>
          )}

          <SidebarSection
            title="Loại tin tức"
            count={builtInTags.length}
            collapsed={!!collapsed.categories}
            onToggle={() => toggleSection('categories')}
            hasActive={builtInTags.some((t) => t.id === selected)}
          >
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
          </SidebarSection>

          <div className="my-3 mx-5 h-px shrink-0 bg-[var(--border-1)]" />

          <SidebarSection
            title="Nguồn tin tức"
            count={customTags.length}
            collapsed={!!collapsed.sources}
            onToggle={() => toggleSection('sources')}
            hasActive={customTags.some((t) => t.id === selected)}
          >
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
            <button
              type="button"
              onClick={onOpenSettings}
              className="mt-1 flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-left text-[13px] font-medium text-[var(--text-3)] transition hover:bg-[var(--surface-1)] hover:text-[var(--text-2)]"
            >
              <PlusIcon width={15} height={15} />
              Thêm nguồn tin
            </button>
          </SidebarSection>

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

function SidebarSection({
  title,
  count,
  collapsed,
  onToggle,
  hasActive,
  children,
}: {
  title: string
  count: number
  collapsed: boolean
  onToggle: () => void
  /** Marks a collapsed section that still holds the current selection. */
  hasActive: boolean
  children: React.ReactNode
}) {
  return (
    <div className="px-3">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={!collapsed}
        className="mb-1.5 flex w-full items-center gap-1.5 rounded-lg px-3 py-1 text-left transition hover:bg-[var(--surface-1)]"
      >
        <ChevronDownIcon
          width={12}
          height={12}
          className={`shrink-0 text-[var(--text-4)] transition-transform duration-200 ${
            collapsed ? '-rotate-90' : ''
          }`}
        />
        <span className="text-[11px] font-semibold uppercase tracking-wide text-[var(--text-4)]">
          {title}
        </span>
        {/* Without this, collapsing the section holding the active filter
            would hide the only sign of what's selected. */}
        {collapsed && hasActive && (
          <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#0A84FF]" />
        )}
        <span className="ml-auto text-[10.5px] font-semibold tabular-nums text-[var(--text-4)] opacity-70">
          {count}
        </span>
      </button>

      <AnimatePresence initial={false}>
        {!collapsed && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
            className="overflow-hidden"
          >
            <nav className="flex flex-col gap-0.5">{children}</nav>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
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
          ? 'bg-[var(--accent)] text-white'
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
