import { AnimatePresence, motion } from 'framer-motion'
import type { AppUpdateState } from '../hooks/useAppUpdate'
import { RefreshIcon, XIcon } from './icons'

interface Props {
  appUpdate: AppUpdateState
  dismissed: boolean
  onDismiss: () => void
}

export default function AppUpdateToast({ appUpdate, dismissed, onDismiss }: Props) {
  const { status, latest, installStatus, installProgress, install } = appUpdate
  const visible = status === 'update-available' && latest !== null && !dismissed

  return (
    <div className="pointer-events-none fixed bottom-24 right-6 z-[65] w-full max-w-xs">
      <AnimatePresence>
        {visible && (
          <motion.div
            initial={{ opacity: 0, y: 16, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 16, scale: 0.95, transition: { duration: 0.2 } }}
            transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
            className="glass pointer-events-auto flex flex-col gap-3 rounded-2xl p-4 shadow-[0_20px_60px_rgba(0,0,0,0.6)]"
          >
            <div className="flex items-start gap-3">
              <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2]">
                <RefreshIcon width={14} height={14} style={{ color: '#fff' }} />
              </span>
              <div className="flex-1">
                <p className="text-[13px] font-semibold text-[var(--text-1)]">Có bản cập nhật mới</p>
                <p className="mt-0.5 text-[12px] text-[var(--text-2)]">
                  F.VNN v{latest?.version} đã sẵn sàng để cài đặt.
                </p>
              </div>
              {installStatus !== 'downloading' && (
                <button
                  type="button"
                  onClick={onDismiss}
                  aria-label="Để sau"
                  className="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg text-[var(--text-3)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)]"
                >
                  <XIcon width={12} height={12} />
                </button>
              )}
            </div>

            {installStatus === 'downloading' ? (
              <div>
                <div className="mb-1.5 flex items-center justify-between text-[11px] text-[var(--text-3)]">
                  <span>{installProgress >= 100 ? 'Đang tự động cập nhật & khởi động lại...' : 'Đang tải bản cập nhật...'}</span>
                  <span className="tabular-nums font-bold">{installProgress}%</span>
                </div>
                <div className="h-1.5 overflow-hidden rounded-full bg-[var(--surface-2)]">
                  <div
                    className="h-full rounded-full bg-[#0A84FF] transition-[width] duration-200"
                    style={{ width: `${installProgress}%` }}
                  />
                </div>
              </div>
            ) : (
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={onDismiss}
                  className="flex-1 rounded-xl bg-[var(--surface-2)] px-3 py-2 text-[12px] font-medium text-[var(--text-1)] transition hover:bg-[var(--surface-3)]"
                >
                  Để sau
                </button>
                <button
                  type="button"
                  onClick={install}
                  disabled={!latest?.downloadUrl}
                  className="flex-1 rounded-xl bg-[var(--text-1)] px-3 py-2 text-[12px] font-semibold text-[var(--bg)] transition hover:opacity-90 disabled:opacity-40"
                >
                  Cập nhật ngay
                </button>
              </div>
            )}

            {installStatus === 'error' && (
              <p className="text-[11px] text-[#FF375F]">Không thể tải hoặc mở trình cài đặt. Thử lại sau.</p>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
