import { motion } from 'framer-motion'
import { MenuIcon, GearIcon } from './icons'
import NotificationBell from './NotificationBell'
import LiveClock from './LiveClock'
import { smoothScrollTo } from '../lib/lenisInstance'
import type { Notification } from '../types/news'

interface Props {
  onToggleSidebar: () => void
  onOpenSettings: () => void
  notifications: Notification[]
  unreadCount: number
  onReadNotifications: () => void
  onSelectNotification: (tagId: string) => void
}

export default function Header({
  onToggleSidebar,
  onOpenSettings,
  notifications,
  unreadCount,
  onReadNotifications,
  onSelectNotification,
}: Props) {
  return (
    <motion.header
      initial={{ y: -40, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
      className="fixed top-0 inset-x-0 z-50"
    >
      <div className="glass mx-auto mt-3 flex max-w-[1600px] items-center justify-between gap-3 rounded-2xl px-4 py-2.5 shadow-[0_8px_32px_rgba(0,0,0,0.4)] sm:mx-4">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={onToggleSidebar}
            aria-label="Đóng/mở danh mục"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-white/60 transition hover:bg-white/10 hover:text-white"
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
            className="lock-select rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-medium text-white/50"
          >
            Cập nhật trực tiếp
          </span>
        </div>

        <div className="flex items-center gap-1">
          <NotificationBell
            notifications={notifications}
            unreadCount={unreadCount}
            onOpen={onReadNotifications}
            onSelect={onSelectNotification}
          />
          <button
            type="button"
            onClick={onOpenSettings}
            aria-label="Cài đặt"
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-white/60 transition hover:bg-white/10 hover:text-white"
          >
            <GearIcon width={18} height={18} />
          </button>
        </div>
      </div>
    </motion.header>
  )
}
