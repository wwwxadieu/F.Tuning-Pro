import { motion } from 'framer-motion'
import { MenuIcon, RefreshIcon } from './icons'
import NotificationBell from './NotificationBell'
import LiveClock from './LiveClock'
import { smoothScrollTo } from '../lib/lenisInstance'
import type { Notification } from '../types/news'

interface Props {
  onToggleSidebar: () => void
  notifications: Notification[]
  unreadCount: number
  onReadNotifications: () => void
  onSelectNotification: (tagId: string) => void
  onRefresh: () => void
  refreshing: boolean
}

export default function Header({
  onToggleSidebar,
  notifications,
  unreadCount,
  onReadNotifications,
  onSelectNotification,
  onRefresh,
  refreshing,
}: Props) {
  return (
    <motion.header
      initial={{ y: -40, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
      className="fixed top-0 inset-x-0 z-50"
    >
      <div className="soft-glass mx-3 mt-3 flex max-w-[1600px] items-center justify-between gap-3 rounded-2xl border border-white/15 bg-[#0a0a0c]/90 px-4 py-2.5 shadow-[0_12px_40px_rgba(0,0,0,0.85)] sm:mx-auto">
        <div className="flex items-center gap-2.5">
          <button
            type="button"
            onClick={onToggleSidebar}
            aria-label="Đóng/mở danh mục"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-white/10 text-white transition hover:bg-white/20 active:scale-95"
          >
            <MenuIcon width={18} height={18} />
          </button>
          <button
            type="button"
            onClick={() => smoothScrollTo('#top', 0)}
            className="flex items-center gap-2.5"
          >
            <span className="flex h-7.5 w-7.5 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2] text-sm font-extrabold text-white shadow-md shadow-blue-500/20">
              F
            </span>
            <span className="text-[16px] font-bold tracking-tight text-white drop-shadow-sm">F.VNN</span>
          </button>
        </div>

        <div className="hidden items-center gap-2.5 sm:flex">
          <div className="flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3.5 py-1 text-xs font-semibold text-white/90">
            <LiveClock />
          </div>
          <span
            aria-hidden="true"
            className="lock-select rounded-full border border-blue-500/30 bg-blue-500/15 px-3 py-1 text-[11px] font-semibold text-blue-300"
          >
            Cập nhật trực tiếp
          </span>
        </div>

        <div className="flex items-center gap-1.5">
          <button
            type="button"
            onClick={onRefresh}
            disabled={refreshing}
            aria-label="Làm mới tin tức"
            title="Làm mới tin tức"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-white/10 text-white transition hover:bg-white/20 disabled:opacity-50 active:scale-95"
          >
            <RefreshIcon width={16} height={16} className={refreshing ? 'animate-spin text-blue-400' : ''} />
          </button>
          <NotificationBell
            notifications={notifications}
            unreadCount={unreadCount}
            onOpen={onReadNotifications}
            onSelect={onSelectNotification}
          />
        </div>
      </div>
    </motion.header>
  )
}
