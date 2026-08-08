import { AnimatePresence, motion } from 'framer-motion'
import type { AppUpdateState } from '../hooks/useAppUpdate'
import { RefreshIcon, XIcon } from './icons'

interface Props {
  appUpdate: AppUpdateState
  dismissed: boolean
  onDismiss: () => void
}

function formatBytes(bytes: number, decimals = 1): string {
  if (!bytes || bytes <= 0) return '0 B'
  const k = 1024
  const dm = decimals < 0 ? 0 : decimals
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`
}

export default function AppUpdateToast({ appUpdate, dismissed, onDismiss }: Props) {
  const { status, latest, installStatus, installProgress, install } = appUpdate
  const visible = status === 'update-available' && latest !== null && !dismissed

  const percent = typeof installProgress === 'number' ? installProgress : installProgress.percent
  const transferred = typeof installProgress === 'object' ? installProgress.transferred : 0
  const total = typeof installProgress === 'object' ? installProgress.total : 0
  const bytesPerSecond = typeof installProgress === 'object' ? installProgress.bytesPerSecond : 0

  let statusText = 'Đang tải bản cập nhật...'
  if (percent >= 100) {
    statusText = 'Đang khởi động trình cài đặt...'
  } else if (transferred > 0 && total > 0) {
    const speedStr = bytesPerSecond > 0 ? ` · ${formatBytes(bytesPerSecond)}/s` : ''
    statusText = `${formatBytes(transferred)} / ${formatBytes(total)}${speedStr}`
  }

  return (
    <div className="pointer-events-none fixed bottom-24 right-6 z-[65] w-full max-w-sm">
      <AnimatePresence>
        {visible && (
          <motion.div
            initial={{ opacity: 0, y: 16, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 16, scale: 0.95, transition: { duration: 0.2 } }}
            transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
            className="pointer-events-auto flex flex-col gap-4 rounded-2xl p-5 shadow-[0_25px_60px_rgba(0,0,0,0.35)] border border-[var(--border-1)] bg-[var(--modal-bg)] text-[var(--text-1)] backdrop-blur-2xl"
          >
            <div className="flex items-start gap-3">
              <span className="mt-0.5 flex h-8.5 w-8.5 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2] shadow-md shadow-blue-500/20">
                <RefreshIcon width={15} height={15} style={{ color: '#fff' }} />
              </span>
              <div className="flex-1">
                <p className="text-[14px] font-bold text-[var(--text-1)]">Có bản cập nhật mới</p>
                <p className="mt-0.5 text-[12px] font-medium text-[var(--text-2)]">
                  F.VNN v{latest?.version} đã sẵn sàng để cài đặt.
                </p>
              </div>
              {installStatus !== 'downloading' && (
                <button
                  type="button"
                  onClick={onDismiss}
                  aria-label="Để sau"
                  className="flex h-6.5 w-6.5 shrink-0 items-center justify-center rounded-lg bg-[var(--surface-1)] text-[var(--text-3)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)]"
                >
                  <XIcon width={13} height={13} />
                </button>
              )}
            </div>

            {installStatus === 'downloading' ? (
              <div className="flex flex-col gap-2 pt-1 pb-1">
                <div className="flex items-center justify-between text-[11.5px] font-semibold text-[var(--text-1)]">
                  <span className="truncate pr-2 text-[var(--text-2)]">{statusText}</span>
                  <span className="tabular-nums font-bold text-[#0A84FF]">{percent}%</span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-[var(--surface-2)] border border-[var(--border-1)]">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-[#0A84FF] to-[#BF5AF2] transition-[width] duration-200"
                    style={{ width: `${percent}%` }}
                  />
                </div>
              </div>
            ) : (
              <div className="flex gap-2.5 pt-1">
                <button
                  type="button"
                  onClick={onDismiss}
                  className="flex-1 rounded-xl border border-[var(--border-1)] bg-[var(--surface-1)] px-3 py-2.5 text-[12px] font-semibold text-[var(--text-2)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)] active:scale-95"
                >
                  Để sau
                </button>
                <button
                  type="button"
                  onClick={install}
                  disabled={!latest?.downloadUrl}
                  className="flex-1 rounded-xl bg-[var(--accent)] px-3 py-2.5 text-[12px] font-bold text-white shadow-md shadow-blue-500/20 transition hover:bg-[var(--accent)]/90 active:scale-95 disabled:opacity-40"
                >
                  Cập nhật ngay
                </button>
              </div>
            )}

            {installStatus === 'error' && (
              <p className="text-[11px] font-semibold text-[#FF375F]">Không thể tải bản cập nhật. Vui lòng thử lại sau.</p>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
