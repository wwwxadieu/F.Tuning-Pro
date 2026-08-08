import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { discoverFeed } from '../services/feedDiscovery'
import { parseFeedUrl } from '../utils/url'
import { PlusIcon, XIcon } from './icons'

interface Props {
  onAddSource: (input: { label: string; feedUrl: string; emoji?: string; scrape?: boolean }) => void
}

export default function QuickAddSourceButton({ onAddSource }: Props) {
  const [open, setOpen] = useState(false)
  const [label, setLabel] = useState('')
  const [feedUrl, setFeedUrl] = useState('')
  const [validating, setValidating] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState(false)

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    const trimmedInput = feedUrl.trim()
    if (!trimmedInput) {
      setError('Vui lòng nhập đường dẫn trang tin hoặc RSS.')
      return
    }
    const url = parseFeedUrl(trimmedInput)
    if (!url) {
      setError('Đường dẫn không hợp lệ. Hãy thử nhập tên miền (ví dụ: 9to5mac.com).')
      return
    }

    setValidating(true)
    try {
      const name = label.trim() || url.hostname.replace(/^www\./, '')
      const discovered = await discoverFeed(url)
      if (!discovered) {
        setError('Không tìm thấy nguồn tin RSS từ đường dẫn này.')
        setValidating(false)
        return
      }
      onAddSource({ label: name, feedUrl: discovered.feedUrl, scrape: discovered.scrape })
      setLabel('')
      setFeedUrl('')
      setSuccess(true)
      setTimeout(() => {
        setOpen(false)
        setSuccess(false)
      }, 1200)
    } catch {
      setError('Không thể đọc nguồn tin này. Kiểm tra lại đường dẫn.')
    } finally {
      setValidating(false)
    }
  }

  return (
    <div className="fixed bottom-6 right-6 z-40 flex flex-col items-end gap-3">
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: 12, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 12, scale: 0.95 }}
            transition={{ duration: 0.2, ease: [0.16, 1, 0.3, 1] }}
            className="soft-glass w-84 rounded-2xl p-5 shadow-[0_25px_60px_rgba(0,0,0,0.8)] border border-white/15 bg-[#12141a]/95 text-white"
          >
            <div className="mb-3 flex items-center justify-between border-b border-white/10 pb-2.5">
              <h3 className="text-[15px] font-bold text-white">Thêm nguồn tin nhanh</h3>
              <button
                type="button"
                onClick={() => setOpen(false)}
                aria-label="Đóng"
                className="flex h-6 w-6 items-center justify-center rounded-lg bg-white/10 text-white/70 transition hover:bg-white/20 hover:text-white"
              >
                <XIcon width={13} height={13} />
              </button>
            </div>

            {success ? (
              <p className="py-4 text-center text-[13px] font-semibold text-[#30D158]">Đã thêm nguồn tin!</p>
            ) : (
              <form onSubmit={handleAdd} className="flex flex-col gap-3">
                <div>
                  <label className="mb-1 block text-[11px] font-semibold text-white/70">
                    Tên miền hoặc RSS (Ví dụ: 9to5mac.com)
                  </label>
                  <input
                    value={feedUrl}
                    onChange={(e) => setFeedUrl(e.target.value)}
                    placeholder="9to5mac.com hoặc vnexpress.net"
                    autoFocus
                    className="w-full rounded-xl border border-white/20 bg-black/70 px-3.5 py-2.5 text-sm text-white placeholder-white/40 outline-none transition focus:border-blue-500 focus:ring-2 focus:ring-blue-500/30"
                  />
                </div>

                <div>
                  <label className="mb-1 block text-[11px] font-semibold text-white/70">
                    Tên hiển thị (Tùy chọn)
                  </label>
                  <input
                    value={label}
                    onChange={(e) => setLabel(e.target.value)}
                    placeholder="Tên nguồn (tuỳ chọn)"
                    className="w-full rounded-xl border border-white/20 bg-black/70 px-3.5 py-2.5 text-sm text-white placeholder-white/40 outline-none transition focus:border-blue-500 focus:ring-2 focus:ring-blue-500/30"
                  />
                </div>

                {error && (
                  <div className="flex items-center gap-2 rounded-xl border border-red-500/40 bg-red-500/20 p-3 text-xs font-semibold text-red-200">
                    <span className="shrink-0 text-base">⚠️</span>
                    <span>{error}</span>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={validating}
                  className="mt-1 flex items-center justify-center gap-1.5 rounded-xl bg-white px-4 py-2.5 text-[13px] font-bold text-black transition hover:bg-white/90 active:scale-95 disabled:opacity-50"
                >
                  <PlusIcon width={14} height={14} />
                  {validating ? 'Đang kiểm tra RSS...' : 'Thêm nguồn'}
                </button>
              </form>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      <motion.button
        type="button"
        onClick={() => setOpen((v) => !v)}
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        aria-label="Thêm nguồn tin nhanh"
        className="flex h-14 w-14 items-center justify-center rounded-full bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2] text-white shadow-[0_10px_30px_rgba(10,132,255,0.4)]"
      >
        <motion.span animate={{ rotate: open ? 45 : 0 }} transition={{ duration: 0.2 }}>
          <PlusIcon width={22} height={22} />
        </motion.span>
      </motion.button>
    </div>
  )
}
