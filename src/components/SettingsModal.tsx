import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { discoverFeed } from '../services/feedDiscovery'
import { useTags } from '../context/TagsContext'
import type { AppUpdateState } from '../hooks/useAppUpdate'
import type { Settings, Tag, ReaderTheme, ReaderFont } from '../types/news'
import { parseFeedUrl } from '../utils/url'
import CategoryIcon from './CategoryIcon'
import { XIcon, TrashIcon, PlusIcon, SunIcon, MoonIcon, SepiaIcon, RefreshIcon, TextSizeIcon } from './icons'
import InterestPicker from './InterestPicker'

interface Props {
  open: boolean
  onClose: () => void
  settings: Settings
  onUpdateSettings: (patch: Partial<Settings>) => void
  customSources: Tag[]
  onAddSource: (input: { label: string; feedUrl: string; emoji?: string; scrape?: boolean }) => void
  onRemoveSource: (id: string) => void
  onClearCache: () => void
  interests: string[]
  onToggleInterest: (tagId: string) => void
  appUpdate: AppUpdateState
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
  appUpdate,
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
      setError('Vui lòng nhập tên và đường dẫn.')
      return
    }
    const url = parseFeedUrl(feedUrl)
    if (!url) {
      setError('Đường dẫn không hợp lệ.')
      return
    }

    setValidating(true)
    try {
      const discovered = await discoverFeed(url)
      if (!discovered) {
        setError('Không tìm thấy nguồn tin RSS từ đường dẫn này.')
        setValidating(false)
        return
      }
      onAddSource({
        label: label.trim(),
        feedUrl: discovered.feedUrl,
        emoji: emoji.trim() || undefined,
        scrape: discovered.scrape,
      })
      setLabel('')
      setEmoji('')
      setFeedUrl('')
    } catch {
      setError('Không thể đọc nguồn tin này. Kiểm tra lại đường dẫn.')
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
            className="glass max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-3xl p-6 shadow-[0_30px_80px_rgba(0,0,0,0.7)] lg:max-w-3xl xl:max-w-4xl"
            data-lenis-prevent
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

            <div className="lg:grid lg:grid-cols-2 lg:items-start lg:gap-x-8">
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

              <div className="mt-4 flex gap-2">
                <FontSwatch
                  active={settings.readerFont === 'serif'}
                  label="Chữ có chân"
                  sample="Aa"
                  sampleClassName="font-serif"
                  onClick={() => onUpdateSettings({ readerFont: 'serif' as ReaderFont })}
                />
                <FontSwatch
                  active={settings.readerFont === 'sans'}
                  label="Chữ không chân"
                  sample="Aa"
                  sampleClassName="font-sans"
                  onClick={() => onUpdateSettings({ readerFont: 'sans' as ReaderFont })}
                />
              </div>

              <div className="mt-4 flex items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3">
                <span className="flex items-center gap-2 text-[14px] text-white/85">
                  <TextSizeIcon width={15} height={15} />
                  Cỡ chữ
                </span>
                <div className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() =>
                      onUpdateSettings({ readerFontSize: Math.max(14, settings.readerFontSize - 1) })
                    }
                    disabled={settings.readerFontSize <= 14}
                    aria-label="Giảm cỡ chữ"
                    className="flex h-7 w-7 items-center justify-center rounded-lg bg-white/10 text-white transition hover:bg-white/20 disabled:opacity-30"
                  >
                    −
                  </button>
                  <span className="w-8 text-center text-[13px] tabular-nums text-white/70">
                    {settings.readerFontSize}
                  </span>
                  <button
                    type="button"
                    onClick={() =>
                      onUpdateSettings({ readerFontSize: Math.min(26, settings.readerFontSize + 1) })
                    }
                    disabled={settings.readerFontSize >= 26}
                    aria-label="Tăng cỡ chữ"
                    className="flex h-7 w-7 items-center justify-center rounded-lg bg-white/10 text-white transition hover:bg-white/20 disabled:opacity-30"
                  >
                    +
                  </button>
                </div>
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
                      <CategoryIcon tagId={s.id} emoji={s.emoji} faviconHost={s.source} size={13} chip />
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
                  placeholder="vidu.com/rss.xml"
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

            <UpdateSection settings={settings} onUpdateSettings={onUpdateSettings} appUpdate={appUpdate} />
            </div>

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

function FontSwatch({
  active,
  label,
  sample,
  sampleClassName,
  onClick,
}: {
  active: boolean
  label: string
  sample: string
  sampleClassName: string
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex flex-1 items-center gap-2.5 rounded-xl border px-3 py-2.5 text-[12px] font-medium transition ${
        active ? 'border-white bg-white text-black' : 'border-white/10 bg-white/5 text-white/60 hover:bg-white/10'
      }`}
    >
      <span className={`text-lg leading-none ${sampleClassName}`}>{sample}</span>
      {label}
    </button>
  )
}

function UpdateSection({
  settings,
  onUpdateSettings,
  appUpdate,
}: {
  settings: Settings
  onUpdateSettings: (patch: Partial<Settings>) => void
  appUpdate: AppUpdateState
}) {
  const { isElectron, currentVersion, status, latest, check, installStatus, installProgress, install } = appUpdate

  return (
    <section className="mb-7">
      <h3 className="mb-3 text-[12px] font-semibold uppercase tracking-wide text-white/40">
        Cập nhật ứng dụng
      </h3>

      {!isElectron && (
        <p className="mb-3 text-[12px] text-white/40">
          Kiểm tra cập nhật chỉ khả dụng trên bản cài đặt desktop.
        </p>
      )}

      <label className="mb-2 flex cursor-pointer items-center justify-between rounded-xl border border-white/10 bg-white/5 px-4 py-3">
        <span className="text-[14px] text-white/85">Tự động kiểm tra khi mở ứng dụng</span>
        <input
          type="checkbox"
          checked={settings.autoUpdateEnabled}
          onChange={(e) => onUpdateSettings({ autoUpdateEnabled: e.target.checked })}
          className="h-5 w-5 accent-[#0A84FF]"
        />
      </label>

      <div className="flex items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3">
        <div className="text-[13px] text-white/60">
          {currentVersion ? (
            <>
              Phiên bản hiện tại: <span className="text-white/85">{currentVersion}</span>
            </>
          ) : (
            'Không xác định phiên bản'
          )}
          {status === 'update-available' && latest && (
            <p className="mt-1 text-[#30D158]">Có bản mới: v{latest.version}</p>
          )}
          {status === 'up-to-date' && <p className="mt-1 text-white/40">Bạn đang dùng bản mới nhất.</p>}
          {status === 'error' && <p className="mt-1 text-[#FF375F]">Không thể kiểm tra lúc này.</p>}
        </div>
        <button
          type="button"
          onClick={check}
          disabled={!isElectron || status === 'checking'}
          className="flex shrink-0 items-center gap-1.5 rounded-full bg-white/10 px-3.5 py-2 text-[12px] font-medium text-white transition hover:bg-white/20 disabled:opacity-40"
        >
          <RefreshIcon width={13} height={13} />
          {status === 'checking' ? 'Đang kiểm tra...' : 'Kiểm tra ngay'}
        </button>
      </div>

      {status === 'update-available' && latest && installStatus !== 'downloading' && (
        <button
          type="button"
          onClick={install}
          disabled={!latest.downloadUrl}
          className="mt-2 flex items-center justify-center gap-1.5 rounded-xl bg-white px-4 py-2.5 text-[13px] font-semibold text-black transition hover:bg-white/90 disabled:opacity-40"
        >
          {latest.downloadUrl ? 'Cập nhật ngay' : 'Không tìm thấy tệp cài đặt'}
        </button>
      )}

      {installStatus === 'downloading' && (
        <div className="mt-2">
          <div className="mb-1.5 flex items-center justify-between text-[12px] text-white/60">
            <span>Đang tải bản cập nhật...</span>
            <span className="tabular-nums">{installProgress}%</span>
          </div>
          <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
            <div
              className="h-full rounded-full bg-[#0A84FF] transition-[width] duration-200"
              style={{ width: `${installProgress}%` }}
            />
          </div>
        </div>
      )}

      {installStatus === 'error' && (
        <p className="mt-2 text-[12px] text-[#FF375F]">Không thể tải hoặc mở trình cài đặt. Thử lại sau.</p>
      )}
    </section>
  )
}
