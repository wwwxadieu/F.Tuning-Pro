import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
import { useTags } from '../context/TagsContext'
import CategoryIcon from './CategoryIcon'
import { BellIcon } from './icons'
import type { Notification } from '../types/news'

interface Props {
  notifications: Notification[]
  unreadCount: number
  onOpen: () => void
  onSelect: (tagId: string) => void
}

export default function NotificationBell({ notifications, unreadCount, onOpen, onSelect }: Props) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const { tagMap } = useTags()

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  function toggle() {
    const next = !open
    setOpen(next)
    if (next && unreadCount > 0) onOpen()
  }

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={toggle}
        aria-label="Thông báo"
        className="relative flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-white/60 transition hover:bg-white/10 hover:text-white"
      >
        <BellIcon width={18} height={18} />
        {unreadCount > 0 && (
          <span className="absolute right-1 top-1 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-[#FF375F] px-1 text-[9px] font-bold leading-none text-white">
            {unreadCount > 9 ? '9+' : unreadCount}
          </span>
        )}
      </button>

      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: -8, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8, scale: 0.97 }}
            transition={{ duration: 0.15, ease: [0.16, 1, 0.3, 1] }}
            className="glass absolute right-0 top-11 z-50 max-h-[70vh] w-80 overflow-y-auto rounded-2xl p-2 shadow-[0_20px_60px_rgba(0,0,0,0.6)]"
          >
            <div className="px-2 py-1.5 text-[13px] font-semibold text-white">Thông báo</div>
            {notifications.length === 0 ? (
              <p className="px-2 py-6 text-center text-[13px] text-white/40">
                Chưa có thông báo nào.
              </p>
            ) : (
              <ul className="flex flex-col gap-0.5">
                {notifications.map((n) => (
                  <li key={n.id}>
                    <button
                      type="button"
                      onClick={() => {
                        onSelect(n.tagId)
                        setOpen(false)
                      }}
                      className="flex w-full items-start gap-2.5 rounded-xl px-2 py-2 text-left transition hover:bg-white/10"
                    >
                      <CategoryIcon
                        tagId={n.tagId}
                        emoji={tagMap.get(n.tagId)?.emoji}
                        faviconHost={tagMap.get(n.tagId)?.source}
                        size={13}
                        chip
                        className="mt-0.5"
                      />
                      <span className="flex-1">
                        <span className="block text-[13px] text-white/90">
                          <strong className="font-semibold">{n.count}</strong> tin mới trong{' '}
                          <strong className="font-semibold">{n.tagLabel}</strong>
                        </span>
                        <span className="mt-0.5 block text-[11px] text-white/40">
                          {formatTime(n.timestamp)}
                        </span>
                      </span>
                      {!n.read && <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-[#0A84FF]" />}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

function formatTime(ts: number): string {
  const diffMin = Math.round((Date.now() - ts) / 60000)
  if (diffMin < 1) return 'Vừa xong'
  if (diffMin < 60) return `${diffMin} phút trước`
  const diffHr = Math.round(diffMin / 60)
  return `${diffHr} giờ trước`
}
