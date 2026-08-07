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
      <div className="glass mx-4 mt-3 flex max-w-[1600px] items-center justify-between gap-3 rounded-2xl px-4 py-2.5 shadow-[0_8px_32px_rgba(0,0,0,0.4)] sm:mx-auto">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onToggleSidebar}
            aria-label="Đóng/mở danh mục"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-[var(--text-2)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)]"
          >
            <MenuIcon width={18} height={18} />
          </button>
          <button
            type="button"
            onClick={() => smoothScrollTo('#top', 0)}
            className="flex items-center gap-2.5"
          >
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2] text-sm font-bold shadow-lg shadow-blue-500/20">
              F
            </span>
            <span className="hidden text-[15px] font-semibold tracking-tight sm:inline">F.VNN</span>
          </button>
        </div>

        <div className="hidden items-center gap-2 sm:flex">
          <LiveClock />
          <span
            aria-hidden="true"
            className="lock-select rounded-full border border-[var(--border-1)] bg-[var(--surface-1)] px-3 py-1 text-[11px] font-medium text-[var(--text-3)]"
          >
            Cập nhật trực tiếp
          </span>
        </div>

        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={onRefresh}
            disabled={refreshing}
            aria-label="Làm mới tin tức"
            title="Làm mới tin tức"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-[var(--text-2)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)] disabled:opacity-50"
          >
            <RefreshIcon width={16} height={16} className={refreshing ? 'animate-spin' : ''} />
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
