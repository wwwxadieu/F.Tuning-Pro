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
  onNotificationsOpenChange?: (open: boolean) => void
  onSelectNotification: (tagId: string) => void
  onRefresh: () => void
  refreshing: boolean
}

export default function Header({
  onToggleSidebar,
  notifications,
  unreadCount,
  onReadNotifications,
  onNotificationsOpenChange,
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
      <div className="mx-3 mt-3 flex max-w-[1600px] items-center justify-between gap-3 rounded-2xl border border-[var(--border-1)] bg-[var(--glass-bg-modal)] px-4 py-2.5 shadow-[0_12px_40px_rgba(0,0,0,0.25)] backdrop-blur-2xl text-[var(--text-1)] sm:mx-auto">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onToggleSidebar}
            aria-label="Đóng/mở danh mục"
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-[var(--surface-1)] border border-[var(--border-1)] text-[var(--text-1)] transition hover:bg-[var(--surface-2)] active:scale-95"
          >
            <MenuIcon width={18} height={18} />
          </button>

          {/* Premium Large Brand Logo */}
          <button
            type="button"
            onClick={() => smoothScrollTo('#top', 0)}
            className="group flex items-center gap-3 select-none"
          >
            <div className="relative flex h-[38px] w-[38px] shrink-0 items-center justify-center rounded-2xl bg-gradient-to-tr from-[#0A84FF] via-[#5E5CE6] to-[#BF5AF2] text-lg font-black text-white shadow-[0_4px_18px_rgba(10,132,255,0.45)] transition-transform duration-300 group-hover:scale-105">
              <div className="absolute inset-0 rounded-2xl bg-gradient-to-tr from-[#0A84FF] to-[#BF5AF2] opacity-40 blur-md transition-opacity group-hover:opacity-75" />
              <span className="relative z-10 font-black tracking-tighter drop-shadow-md">F</span>
            </div>
            <div className="flex flex-col text-left">
              <span className="text-[17.5px] font-black tracking-tight text-[var(--text-1)] leading-none transition-colors group-hover:text-[#0A84FF]">
                F.VNN
              </span>
              <span className="mt-0.5 text-[9.5px] font-extrabold uppercase tracking-widest text-[#0A84FF]">
                Vietnamese News
              </span>
            </div>
          </button>
        </div>

        <div className="hidden items-center gap-2.5 sm:flex">
          <LiveClock />
          <span
            aria-hidden="true"
            className="lock-select rounded-full border border-blue-500/30 bg-blue-500/15 px-3 py-1 text-[11px] font-bold text-[#0A84FF]"
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
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-[var(--surface-1)] border border-[var(--border-1)] text-[var(--text-1)] transition hover:bg-[var(--surface-2)] disabled:opacity-50 active:scale-95"
          >
            <RefreshIcon width={16} height={16} className={refreshing ? 'animate-spin text-[#0A84FF]' : ''} />
          </button>
          <NotificationBell
            notifications={notifications}
            unreadCount={unreadCount}
            onOpen={onReadNotifications}
            onOpenChange={onNotificationsOpenChange}
            onSelect={onSelectNotification}
          />
        </div>
      </div>
    </motion.header>
  )
}
