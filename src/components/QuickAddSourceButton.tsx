import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { discoverFeed } from '../services/feedDiscovery'
import { parseFeedUrl } from '../utils/url'
import { PlusIcon, XIcon } from './icons'

interface Props {
  onAddSource: (input: { label: string; feedUrl: string; emoji?: string }) => void
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
    if (!feedUrl.trim()) {
      setError('Vui lòng nhập đường dẫn trang tin hoặc RSS.')
      return
    }
    const url = parseFeedUrl(feedUrl)
    if (!url) {
      setError('Đường dẫn không hợp lệ.')
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
      onAddSource({ label: name, feedUrl: discovered.feedUrl })
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
            className="glass w-80 rounded-2xl p-4 shadow-[0_20px_60px_rgba(0,0,0,0.6)]"
          >
            <div className="mb-3 flex items-center justify-between">
              <h3 className="text-[14px] font-semibold text-white">Thêm nguồn tin nhanh</h3>
              <button
                type="button"
                onClick={() => setOpen(false)}
                aria-label="Đóng"
                className="flex h-6 w-6 items-center justify-center rounded-lg text-white/40 transition hover:bg-white/10 hover:text-white"
              >
                <XIcon width={13} height={13} />
              </button>
            </div>

            {success ? (
              <p className="py-4 text-center text-[13px] text-[#30D158]">Đã thêm nguồn tin!</p>
            ) : (
              <form onSubmit={handleAdd} className="flex flex-col gap-2">
                <input
                  value={feedUrl}
                  onChange={(e) => setFeedUrl(e.target.value)}
                  placeholder="vidu.com/rss.xml"
                  autoFocus
                  className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm outline-none focus:border-white/30"
                />
                <input
                  value={label}
                  onChange={(e) => setLabel(e.target.value)}
                  placeholder="Tên chuyên mục (tuỳ chọn)"
                  className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm outline-none focus:border-white/30"
                />
                {error && <p className="text-[12px] text-[#FF375F]">{error}</p>}
                <button
                  type="submit"
                  disabled={validating}
                  className="flex items-center justify-center gap-1.5 rounded-xl bg-white px-4 py-2.5 text-[13px] font-semibold text-black transition hover:bg-white/90 disabled:opacity-50"
                >
                  <PlusIcon width={14} height={14} />
                  {validating ? 'Đang kiểm tra...' : 'Thêm nguồn'}
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
