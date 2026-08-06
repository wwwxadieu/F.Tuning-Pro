import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { fetchArticlesForTag } from '../services/newsService'
import { useTags } from '../context/TagsContext'
import type { Settings, Tag, ReaderTheme } from '../types/news'
import { XIcon, TrashIcon, PlusIcon, SunIcon, MoonIcon, SepiaIcon } from './icons'
import InterestPicker from './InterestPicker'

interface Props {
  open: boolean
  onClose: () => void
  settings: Settings
  onUpdateSettings: (patch: Partial<Settings>) => void
  customSources: Tag[]
  onAddSource: (input: { label: string; feedUrl: string; emoji?: string }) => void
  onRemoveSource: (id: string) => void
  onClearCache: () => void
  interests: string[]
  onToggleInterest: (tagId: string) => void
}

export default function SettingsModal({
  open,
  onClose,
  settings,
  onUpdateSettings,
  customSources,
  onAddSource,
  onRemoveSource,
  onClearCache,
  interests,
  onToggleInterest,
}: Props) {
  const { tags } = useTags()
  const [label, setLabel] = useState('')
  const [emoji, setEmoji] = useState('')
  const [feedUrl, setFeedUrl] = useState('')
  const [validating, setValidating] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    if (!label.trim() || !feedUrl.trim()) {
      setError('Vui lòng nhập tên và đường dẫn RSS.')
      return
    }
    let url: URL
    try {
      url = new URL(feedUrl.trim())
    } catch {
      setError('Đường dẫn RSS không hợp lệ.')
      return
    }

    setValidating(true)
    try {
      const tempTag: Tag = {
        id: 'validate-temp',
        label: label.trim(),
        emoji: emoji.trim() || '📰',
        feedUrl: url.toString(),
        source: url.hostname,
      }
      const items = await fetchArticlesForTag(tempTag, undefined, { forceRefresh: true })
      if (items.length === 0) {
        setError('Nguồn này không có bài viết nào, hoặc không phải RSS hợp lệ.')
        setValidating(false)
        return
      }
      onAddSource({ label: label.trim(), feedUrl: url.toString(), emoji: emoji.trim() || undefined })
      setLabel('')
      setEmoji('')
      setFeedUrl('')
    } catch {
      setError('Không thể đọc nguồn RSS này. Kiểm tra lại đường dẫn.')
    } finally {
      setValidating(false)
    }
  }

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[70] flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
          onClick={onClose}
        >
          <motion.div
            initial={{ opacity: 0, y: 20, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 20, scale: 0.97 }}
            transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
            onClick={(e) => e.stopPropagation()}
            className="glass max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-3xl p-6 shadow-[0_30px_80px_rgba(0,0,0,0.7)]"
          >
            <div className="mb-6 flex items-center justify-between">
              <h2 className="text-lg font-semibold tracking-tight">Cài đặt</h2>
              <button
                type="button"
                onClick={onClose}
                aria-label="Đóng cài đặt"
                className="flex h-8 w-8 items-center justify-center rounded-lg text-white/50 transition hover:bg-white/10 hover:text-white"
              >
                <XIcon width={16} height={16} />
              </button>
            </div>

            <section className="mb-7">
              <h3 className="mb-3 text-[12px] font-semibold uppercase tracking-wide text-white/40">
                Sở thích của bạn
              </h3>
              <p className="mb-3 text-[12px] text-white/40">
                Trang chủ sẽ ưu tiên hiển thị các chủ đề bạn chọn ở đây. Bỏ chọn hết để xem tất cả.
              </p>
              <InterestPicker
                tags={tags}
                selected={new Set(interests)}
                onToggle={onToggleInterest}
              />
            </section>

            <section className="mb-7">
              <h3 className="mb-3 text-[12px] font-semibold uppercase tracking-wide text-white/40">
                Thông báo
              </h3>
              <label className="flex cursor-pointer items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3">
                <span className="text-[14px] text-white/85">Báo khi có tin mới</span>
                <input
                  type="checkbox"
                  checked={settings.notificationsEnabled}
                  onChange={(e) => onUpdateSettings({ notificationsEnabled: e.target.checked })}
                  className="h-5 w-5 accent-[#0A84FF]"
                />
              </label>
            </section>

            <section className="mb-7">
              <h3 className="mb-3 text-[12px] font-semibold uppercase tracking-wide text-white/40">
                Chế độ đọc mặc định
              </h3>
              <div className="flex gap-2">
                <ThemeSwatch
                  active={settings.readerTheme === 'light'}
                  label="Sáng"
                  icon={<SunIcon width={15} height={15} />}
                  onClick={() => onUpdateSettings({ readerTheme: 'light' as ReaderTheme })}
                />
                <ThemeSwatch
                  active={settings.readerTheme === 'sepia'}
                  label="Sepia"
                  icon={<SepiaIcon width={15} height={15} />}
                  onClick={() => onUpdateSettings({ readerTheme: 'sepia' as ReaderTheme })}
                />
                <ThemeSwatch
                  active={settings.readerTheme === 'dark'}
                  label="Tối"
                  icon={<MoonIcon width={15} height={15} />}
                  onClick={() => onUpdateSettings({ readerTheme: 'dark' as ReaderTheme })}
                />
              </div>
            </section>

            <section className="mb-7">
              <h3 className="mb-3 text-[12px] font-semibold uppercase tracking-wide text-white/40">
                Nguồn tin của bạn
              </h3>

              {customSources.length > 0 && (
                <ul className="mb-3 flex flex-col gap-1.5">
                  {customSources.map((s) => (
                    <li
                      key={s.id}
                      className="flex items-center gap-2.5 rounded-xl border border-white/10 bg-white/5 px-3 py-2"
                    >
                      <span className="text-base">{s.emoji}</span>
                      <span className="flex-1 truncate text-[13px] text-white/85">{s.label}</span>
                      <button
                        type="button"
                        onClick={() => onRemoveSource(s.id)}
                        aria-label={`Xoá ${s.label}`}
                        className="flex h-7 w-7 items-center justify-center rounded-lg text-white/40 transition hover:bg-white/10 hover:text-[#FF375F]"
                      >
                        <TrashIcon width={14} height={14} />
                      </button>
                    </li>
                  ))}
                </ul>
              )}

              <form onSubmit={handleAdd} className="flex flex-col gap-2">
                <div className="flex gap-2">
                  <input
                    value={emoji}
                    onChange={(e) => setEmoji(e.target.value)}
                    placeholder="📰"
                    maxLength={4}
                    className="w-14 rounded-xl border border-white/10 bg-white/5 px-2 py-2 text-center text-sm outline-none focus:border-white/30"
                  />
                  <input
                    value={label}
                    onChange={(e) => setLabel(e.target.value)}
                    placeholder="Tên chuyên mục"
                    className="flex-1 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm outline-none focus:border-white/30"
                  />
                </div>
                <input
                  value={feedUrl}
                  onChange={(e) => setFeedUrl(e.target.value)}
                  placeholder="https://vidu.com/rss.xml"
                  className="rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm outline-none focus:border-white/30"
                />
                {error && <p className="text-[12px] text-[#FF375F]">{error}</p>}
                <button
                  type="submit"
                  disabled={validating}
                  className="flex items-center justify-center gap-1.5 rounded-xl bg-white px-4 py-2.5 text-[13px] font-semibold text-black transition hover:bg-white/90 disabled:opacity-50"
                >
                  <PlusIcon width={14} height={14} />
                  {validating ? 'Đang kiểm tra...' : 'Thêm nguồn RSS'}
                </button>
              </form>
            </section>

            <section>
              <h3 className="mb-3 text-[12px] font-semibold uppercase tracking-wide text-white/40">
                Khác
              </h3>
              <button
                type="button"
                onClick={onClearCache}
                className="w-full rounded-xl border border-white/10 bg-white/5 px-4 py-2.5 text-[13px] font-medium text-white/70 transition hover:bg-white/10 hover:text-white"
              >
                Xoá bộ nhớ đệm tin tức
              </button>
            </section>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

function ThemeSwatch({
  active,
  label,
  icon,
  onClick,
}: {
  active: boolean
  label: string
  icon: React.ReactNode
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex flex-1 flex-col items-center gap-1.5 rounded-xl border px-3 py-3 text-[12px] font-medium transition ${
        active ? 'border-white bg-white text-black' : 'border-white/10 bg-white/5 text-white/60 hover:bg-white/10'
      }`}
    >
      {icon}
      {label}
    </button>
  )
}
