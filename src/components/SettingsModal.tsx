import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'
import { discoverFeed } from '../services/feedDiscovery'
import { useTags } from '../context/TagsContext'
import type { AppUpdateState } from '../hooks/useAppUpdate'
import type { Settings, Tag, ReaderTheme, ReaderFont } from '../types/news'
import { parseFeedUrl } from '../utils/url'
import CategoryIcon from './CategoryIcon'
import {
  XIcon,
  TrashIcon,
  PlusIcon,
  SunIcon,
  MoonIcon,
  SepiaIcon,
  RefreshIcon,
  TextSizeIcon,
  ChevronDownIcon,
} from './icons'
import InterestPicker from './InterestPicker'

interface Props {
  open: boolean
  onClose: () => void
  settings: Settings
  onUpdateSettings: (patch: Partial<Settings>) => void
  customSources: Tag[]
  onAddSource: (input: { label: string; feedUrl: string; emoji?: string; scrape?: boolean; translate?: boolean }) => void
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
  const [autoTranslate, setAutoTranslate] = useState(false)
  const [validating, setValidating] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [interestsOpen, setInterestsOpen] = useState(false)

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    const trimmedUrl = feedUrl.trim()
    if (!trimmedUrl) {
      setError('Vui lòng nhập đường dẫn trang tin hoặc RSS.')
      return
    }
    const url = parseFeedUrl(trimmedUrl)
    if (!url) {
      setError('Đường dẫn không hợp lệ. Hãy thử nhập tên miền (ví dụ: 9to5mac.com).')
      return
    }

    setValidating(true)
    try {
      const name = label.trim() || url.hostname.replace(/^www\./, '')
      const discovered = await discoverFeed(url)
      
      onAddSource({
        label: name,
        feedUrl: discovered ? discovered.feedUrl : url.toString(),
        emoji: emoji.trim() || undefined,
        scrape: discovered ? discovered.scrape : true,
        translate: autoTranslate,
      })
      setLabel('')
      setEmoji('')
      setFeedUrl('')
      setAutoTranslate(false)
    } catch {
      // Automatic fallback to web HTML scraping mode seamlessly
      const name = label.trim() || url.hostname.replace(/^www\./, '')
      onAddSource({
        label: name,
        feedUrl: url.toString(),
        emoji: emoji.trim() || undefined,
        scrape: true,
        translate: autoTranslate,
      })
      setLabel('')
      setEmoji('')
      setFeedUrl('')
      setAutoTranslate(false)
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
          className="fixed inset-0 z-[70] flex items-center justify-center bg-black/75 p-4 sm:p-6 backdrop-blur-md"
          onClick={onClose}
        >
          <motion.div
            initial={{ opacity: 0, y: 24, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 24, scale: 0.97 }}
            transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
            onClick={(e) => e.stopPropagation()}
            className="max-h-[88vh] w-full max-w-2xl overflow-y-auto rounded-3xl p-7 sm:p-9 shadow-[0_30px_90px_rgba(0,0,0,0.5)] border border-[var(--border-1)] bg-[var(--modal-bg)] text-[var(--text-1)] backdrop-blur-2xl lg:max-w-4xl xl:max-w-5xl"
            data-lenis-prevent
          >
            {/* Modal Header */}
            <div className="mb-8 flex items-center justify-between border-b border-[var(--border-1)] pb-5">
              <div>
                <h2 className="text-xl font-bold tracking-tight text-[var(--text-1)]">Cài đặt ứng dụng</h2>
                <p className="mt-1 text-[13px] text-[var(--text-3)]">
                  Tùy chỉnh giao diện, trải nghiệm đọc báo và quản lý nguồn tin cá nhân.
                </p>
              </div>
              <button
                type="button"
                onClick={onClose}
                aria-label="Đóng cài đặt"
                className="flex h-9 w-9 items-center justify-center rounded-xl bg-[var(--surface-1)] text-[var(--text-3)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)]"
              >
                <XIcon width={17} height={17} />
              </button>
            </div>

            {/* Spacious Grid Sections */}
            <div className="space-y-8 lg:grid lg:grid-cols-2 lg:gap-8 lg:space-y-0">
              {/* Left Column: Theme & Reader Defaults */}
              <div className="space-y-8">
                {/* Giao diện ứng dụng */}
                <section className="rounded-2xl border border-[var(--border-1)] bg-[var(--surface-1)] p-5 sm:p-6">
                  <h3 className="mb-4 text-[13px] font-bold uppercase tracking-wider text-[var(--text-3)]">
                    Giao diện ứng dụng
                  </h3>
                  <div className="flex gap-3">
                    <ThemeSwatch
                      active={settings.appTheme === 'dark'}
                      label="Giao diện Tối"
                      icon={<MoonIcon width={16} height={16} />}
                      onClick={() => onUpdateSettings({ appTheme: 'dark' })}
                    />
                    <ThemeSwatch
                      active={settings.appTheme === 'light'}
                      label="Giao diện Sáng"
                      icon={<SunIcon width={16} height={16} />}
                      onClick={() => onUpdateSettings({ appTheme: 'light' })}
                    />
                  </div>
                </section>

                {/* Chế độ đọc mặc định */}
                <section className="rounded-2xl border border-[var(--border-1)] bg-[var(--surface-1)] p-5 sm:p-6">
                  <h3 className="mb-4 text-[13px] font-bold uppercase tracking-wider text-[var(--text-3)]">
                    Chế độ đọc báo
                  </h3>
                  <div className="flex gap-2.5">
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

                  <div className="mt-4 flex gap-2.5">
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

                  <div className="mt-4 flex items-center justify-between rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-4 py-3.5">
                    <span className="flex items-center gap-2.5 text-[14px] font-medium text-[var(--text-1)]">
                      <TextSizeIcon width={16} height={16} />
                      Cỡ chữ bài viết
                    </span>
                    <div className="flex items-center gap-3">
                      <button
                        type="button"
                        onClick={() =>
                          onUpdateSettings({ readerFontSize: Math.max(14, settings.readerFontSize - 1) })
                        }
                        disabled={settings.readerFontSize <= 14}
                        aria-label="Giảm cỡ chữ"
                        className="flex h-8 w-8 items-center justify-center rounded-lg bg-[var(--surface-2)] text-[var(--text-1)] transition hover:bg-[var(--surface-3)] disabled:opacity-30"
                      >
                        −
                      </button>
                      <span className="w-8 text-center text-[14px] font-bold tabular-nums text-[var(--text-1)]">
                        {settings.readerFontSize}
                      </span>
                      <button
                        type="button"
                        onClick={() =>
                          onUpdateSettings({ readerFontSize: Math.min(26, settings.readerFontSize + 1) })
                        }
                        disabled={settings.readerFontSize >= 26}
                        aria-label="Tăng cỡ chữ"
                        className="flex h-8 w-8 items-center justify-center rounded-lg bg-[var(--surface-2)] text-[var(--text-1)] transition hover:bg-[var(--surface-3)] disabled:opacity-30"
                      >
                        +
                      </button>
                    </div>
                  </div>
                </section>

                {/* Sở thích */}
                <section className="rounded-2xl border border-[var(--border-1)] bg-[var(--surface-1)] p-5 sm:p-6">
                  <h3 className="mb-3 text-[13px] font-bold uppercase tracking-wider text-[var(--text-3)]">
                    Sở thích tin tức
                  </h3>
                  <button
                    type="button"
                    onClick={() => setInterestsOpen((v) => !v)}
                    aria-expanded={interestsOpen}
                    className="flex w-full items-center justify-between rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-4 py-3.5 text-left transition hover:bg-[var(--surface-2)]"
                  >
                    <span className="text-[14px] font-medium text-[var(--text-1)]">
                      {interests.length > 0 ? `${interests.length} chủ đề ưu tiên` : 'Hiển thị tất cả chủ đề'}
                    </span>
                    <ChevronDownIcon
                      width={16}
                      height={16}
                      className={`shrink-0 text-[var(--text-3)] transition-transform ${interestsOpen ? 'rotate-180' : ''}`}
                    />
                  </button>
                  {interestsOpen && (
                    <div className="mt-4">
                      <p className="mb-3 text-[12px] text-[var(--text-3)]">
                        Trang chủ sẽ ưu tiên hiển thị các chủ đề bạn chọn ở đây. Bỏ chọn hết để xem tất cả.
                      </p>
                      <InterestPicker tags={tags} selected={new Set(interests)} onToggle={onToggleInterest} />
                    </div>
                  )}
                </section>
              </div>

              {/* Right Column: Custom Sources, Auto-Update & Misc */}
              <div className="space-y-8">
                {/* Nguồn tin cá nhân */}
                <section className="rounded-2xl border border-[var(--border-1)] bg-[var(--surface-1)] p-5 sm:p-6">
                  <h3 className="mb-3 text-[13px] font-bold uppercase tracking-wider text-[var(--text-3)]">
                    Thêm nguồn tin tức cá nhân
                  </h3>

                  {customSources.length > 0 && (
                    <ul className="mb-4 flex flex-col gap-2">
                      {customSources.map((s) => (
                        <li
                          key={s.id}
                          className="flex items-center gap-3 rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-3.5 py-2.5"
                        >
                          <CategoryIcon tagId={s.id} emoji={s.emoji} faviconHost={s.source} size={14} chip />
                          <span className="flex-1 truncate text-[13.5px] font-medium text-[var(--text-1)]">{s.label}</span>
                          {s.scrape && (
                            <span className="rounded bg-[#0A84FF]/15 px-2 py-0.5 text-[10.5px] font-semibold text-[#0A84FF]">
                              Web HTML
                            </span>
                          )}
                          <button
                            type="button"
                            onClick={() => onRemoveSource(s.id)}
                            aria-label={`Xoá ${s.label}`}
                            className="flex h-7 w-7 items-center justify-center rounded-lg text-[var(--text-3)] transition hover:bg-[var(--surface-2)] hover:text-[#FF375F]"
                          >
                            <TrashIcon width={14} height={14} />
                          </button>
                        </li>
                      ))}
                    </ul>
                  )}

                  <form onSubmit={handleAdd} className="flex flex-col gap-3">
                    <div className="flex gap-2.5">
                      <input
                        value={emoji}
                        onChange={(e) => setEmoji(e.target.value)}
                        placeholder="📰"
                        maxLength={4}
                        className="w-14 rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-2 py-2.5 text-center text-base text-[var(--text-1)] outline-none focus:border-[#0A84FF]"
                      />
                      <input
                        value={label}
                        onChange={(e) => setLabel(e.target.value)}
                        placeholder="Tên chuyên mục (Ví dụ: Tech Blog)"
                        className="flex-1 rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-3.5 py-2.5 text-sm text-[var(--text-1)] outline-none focus:border-[#0A84FF]"
                      />
                    </div>
                    <input
                      value={feedUrl}
                      onChange={(e) => setFeedUrl(e.target.value)}
                      placeholder="Dán link RSS hoặc URL bất kỳ (vd: 9to5mac.com)"
                      className="rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-3.5 py-2.5 text-sm text-[var(--text-1)] outline-none focus:border-[#0A84FF]"
                    />

                    <label className="flex cursor-pointer items-center gap-2 px-1 text-[12.5px] font-medium text-[var(--text-2)]">
                      <input
                        type="checkbox"
                        checked={autoTranslate}
                        onChange={(e) => setAutoTranslate(e.target.checked)}
                        className="h-4.5 w-4.5 accent-[#0A84FF]"
                      />
                      <span>Tự động dịch nội dung sang Tiếng Việt</span>
                    </label>

                    {error && <p className="text-[12px] font-medium text-[#FF375F]">{error}</p>}
                    <button
                      type="submit"
                      disabled={validating}
                      className="flex items-center justify-center gap-2 rounded-xl bg-[#0A84FF] px-4 py-3 text-[13.5px] font-bold text-white shadow-md shadow-blue-500/20 transition hover:bg-[#0A84FF]/90 active:scale-95 disabled:opacity-50"
                    >
                      <PlusIcon width={15} height={15} />
                      {validating ? 'Đang tự động phân tích trang...' : 'Thêm nguồn tin mới'}
                    </button>
                  </form>
                </section>

                {/* Cập nhật ứng dụng */}
                <UpdateSection settings={settings} onUpdateSettings={onUpdateSettings} appUpdate={appUpdate} />

                {/* Khác */}
                <section className="rounded-2xl border border-[var(--border-1)] bg-[var(--surface-1)] p-5 sm:p-6">
                  <h3 className="mb-3 text-[13px] font-bold uppercase tracking-wider text-[var(--text-3)]">
                    Quản lý bộ nhớ đệm
                  </h3>
                  <button
                    type="button"
                    onClick={onClearCache}
                    className="w-full rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-4 py-3 text-[13px] font-semibold text-[var(--text-2)] transition hover:bg-[var(--surface-2)] hover:text-[var(--text-1)] active:scale-95"
                  >
                    Xoá bộ nhớ đệm tin tức
                  </button>
                </section>
              </div>
            </div>
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
      className={`flex flex-1 flex-col items-center justify-center gap-2 rounded-xl border px-3 py-3.5 text-[12.5px] font-semibold transition active:scale-95 ${
        active
          ? 'border-[#0A84FF] bg-[#0A84FF] text-white shadow-md'
          : 'border-[var(--border-1)] bg-[var(--modal-bg)] text-[var(--text-2)] hover:bg-[var(--surface-2)]'
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
      className={`flex flex-1 items-center gap-3 rounded-xl border px-3.5 py-3 text-[12.5px] font-semibold transition active:scale-95 ${
        active
          ? 'border-[#0A84FF] bg-[#0A84FF] text-white shadow-md'
          : 'border-[var(--border-1)] bg-[var(--modal-bg)] text-[var(--text-2)] hover:bg-[var(--surface-2)]'
      }`}
    >
      <span className={`text-xl leading-none ${sampleClassName}`}>{sample}</span>
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
    <section className="rounded-2xl border border-[var(--border-1)] bg-[var(--surface-1)] p-5 sm:p-6">
      <h3 className="mb-4 text-[13px] font-bold uppercase tracking-wider text-[var(--text-3)]">
        Cập nhật ứng dụng
      </h3>

      {!isElectron && (
        <p className="mb-3 text-[12.5px] font-medium text-[var(--text-3)]">
          Kiểm tra cập nhật tự động chỉ khả dụng trên bản ứng dụng Desktop.
        </p>
      )}

      <label className="mb-3 flex cursor-pointer items-center justify-between rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-4 py-3.5">
        <span className="text-[14px] font-medium text-[var(--text-1)]">Tự động kiểm tra khi mở ứng dụng</span>
        <input
          type="checkbox"
          checked={settings.autoUpdateEnabled}
          onChange={(e) => onUpdateSettings({ autoUpdateEnabled: e.target.checked })}
          className="h-5 w-5 accent-[#0A84FF]"
        />
      </label>

      <div className="flex items-center justify-between gap-3 rounded-xl border border-[var(--border-1)] bg-[var(--modal-bg)] px-4 py-3.5">
        <div className="text-[13px] text-[var(--text-2)]">
          {currentVersion ? (
            <>
              Phiên bản hiện tại: <span className="font-bold text-[var(--text-1)]">{currentVersion}</span>
            </>
          ) : (
            'Không xác định phiên bản'
          )}
          {status === 'update-available' && latest && (
            <p className="mt-1 font-bold text-[#30D158]">Có bản mới: v{latest.version}</p>
          )}
          {status === 'up-to-date' && <p className="mt-1 text-[var(--text-3)]">Bạn đang dùng bản mới nhất.</p>}
          {status === 'error' && <p className="mt-1 text-[#FF375F]">Không thể kiểm tra lúc này.</p>}
        </div>
        <button
          type="button"
          onClick={check}
          disabled={!isElectron || status === 'checking'}
          className="flex shrink-0 items-center gap-1.5 rounded-full bg-[#0A84FF]/15 px-4 py-2 text-[12.5px] font-bold text-[#0A84FF] transition hover:bg-[#0A84FF]/25 disabled:opacity-40"
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
          className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-[#0A84FF] px-4 py-3 text-[13.5px] font-bold text-white shadow-md transition hover:bg-[#0A84FF]/90 disabled:opacity-40 active:scale-95"
        >
          {latest.downloadUrl ? 'Nâng cấp lên bản mới ngay' : 'Không tìm thấy tệp cài đặt'}
        </button>
      )}

      {installStatus === 'downloading' && (
        <div className="mt-3">
          <div className="mb-2 flex items-center justify-between text-[12px] font-medium text-[var(--text-2)]">
            <span>Đang tải bản cập nhật...</span>
            <span className="tabular-nums font-bold text-[#0A84FF]">
              {typeof installProgress === 'number' ? installProgress : installProgress.percent}%
            </span>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-[var(--surface-2)]">
            <div
              className="h-full rounded-full bg-gradient-to-r from-[#0A84FF] to-[#BF5AF2] transition-[width] duration-200"
              style={{
                width: `${typeof installProgress === 'number' ? installProgress : installProgress.percent}%`,
              }}
            />
          </div>
        </div>
      )}

      {installStatus === 'error' && (
        <p className="mt-2 text-[12px] font-medium text-[#FF375F]">Không thể tải hoặc mở trình cài đặt. Thử lại sau.</p>
      )}
    </section>
  )
}
