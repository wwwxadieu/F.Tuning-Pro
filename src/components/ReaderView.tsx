import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useRef, useState } from 'react'
import type { Article, ReaderTheme, Settings } from '../types/news'
import { getLenisInstance } from '../lib/lenisInstance'
import { fetchReaderContent } from '../services/readerService'
import { pausePrefetch, resumePrefetch } from '../services/prefetchQueue'
import { formatRelativeTime } from '../utils/time'
import { PlaneIcon } from './categoryIcons'
import ImageLightbox from './ImageLightbox'
import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ExternalLinkIcon,
  LinkIcon,
  MaximizeIcon,
  MinimizeIcon,
  MoonIcon,
  RefreshIcon,
  SepiaIcon,
  ShareIcon,
  SunIcon,
  TextSizeIcon,
  XIcon,
} from './icons'

interface Props {
  article: Article | null
  hasPrev: boolean
  hasNext: boolean
  onPrev: () => void
  onNext: () => void
  onClose: () => void
  settings: Settings
  onUpdateSettings: (patch: Partial<Settings>) => void
}

const THEME_STYLES: Record<ReaderTheme, { bg: string; text: string; subtle: string; card: string }> = {
  light: { bg: '#ffffff', text: '#1d1d1f', subtle: '#6e6e73', card: '#f5f5f7' },
  sepia: { bg: '#f4ecd8', text: '#3a2f22', subtle: '#7a6a52', card: '#ece1c8' },
  dark: { bg: '#12141a', text: '#f2f2f2', subtle: '#9a9a9e', card: '#1c1c24' },
}

type LoadState = 'loading' | 'ok' | 'error'

export default function ReaderView({
  article,
  hasPrev,
  hasNext,
  onPrev,
  onNext,
  onClose,
  settings,
  onUpdateSettings,
}: Props) {
  const [state, setState] = useState<LoadState>('loading')
  const [html, setHtml] = useState<string>('')
  const [zoomedImage, setZoomedImage] = useState<string | null>(null)
  const [shareState, setShareState] = useState<'idle' | 'copied' | 'error'>('idle')
  const [shareMenuOpen, setShareMenuOpen] = useState(false)
  const [retryToken, setRetryToken] = useState(0)
  const [isExpanded, setIsExpanded] = useState(false)
  const shareMenuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!article) return
    setState('loading')
    setHtml('')
    setZoomedImage(null)
    const controller = new AbortController()

    fetchReaderContent(article.link, controller.signal, 'high')
      .then((content) => {
        setHtml(content.html)
        setState('ok')
      })
      .catch(() => {
        if (controller.signal.aborted) return
        setState('error')
      })

    return () => controller.abort()
  }, [article, retryToken])

  useEffect(() => {
    if (article) pausePrefetch()
    else resumePrefetch()
    return () => resumePrefetch()
  }, [article])

  useEffect(() => {
    const lenis = getLenisInstance()
    if (article) lenis?.stop()
    else lenis?.start()
  }, [article])

  useEffect(() => {
    return () => {
      getLenisInstance()?.start()
    }
  }, [])

  useEffect(() => {
    if (!article) return
    function onKeyDown(e: KeyboardEvent) {
      if (zoomedImage) return
      if (e.key === 'Escape') {
        if (shareMenuOpen) setShareMenuOpen(false)
        else onClose()
      } else if (e.key === 'ArrowLeft' && hasPrev) onPrev()
      else if (e.key === 'ArrowRight' && hasNext) onNext()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [article, hasPrev, hasNext, onPrev, onNext, onClose, zoomedImage, shareMenuOpen])

  useEffect(() => {
    if (!shareMenuOpen) return
    function onClickOutside(e: MouseEvent) {
      if (shareMenuRef.current && !shareMenuRef.current.contains(e.target as Node)) setShareMenuOpen(false)
    }
    document.addEventListener('mousedown', onClickOutside)
    return () => document.removeEventListener('mousedown', onClickOutside)
  }, [shareMenuOpen])

  function flashShareState(next: 'copied' | 'error') {
    setShareState(next)
    setTimeout(() => setShareState('idle'), 2000)
  }

  async function copyText(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      flashShareState('copied')
    } catch {
      flashShareState('error')
    }
  }

  function openSharePopup(url: string) {
    window.open(url, '_blank', 'noopener,noreferrer,width=600,height=520')
    setShareMenuOpen(false)
  }

  function shareToFacebook() {
    if (!article) return
    openSharePopup(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(article.link)}`)
  }

  function shareToX() {
    if (!article) return
    openSharePopup(
      `https://twitter.com/intent/tweet?text=${encodeURIComponent(article.title)}&url=${encodeURIComponent(article.link)}`
    )
  }

  function shareToTelegram() {
    if (!article) return
    openSharePopup(
      `https://t.me/share/url?url=${encodeURIComponent(article.link)}&text=${encodeURIComponent(article.title)}`
    )
  }

  async function shareToDiscord() {
    if (!article) return
    setShareMenuOpen(false)
    await copyText(`${article.title}\n${article.link}`)
  }

  async function handleCopyLink() {
    if (!article) return
    setShareMenuOpen(false)
    await copyText(article.link)
  }

  async function handleNativeShare() {
    if (!article) return
    setShareMenuOpen(false)
    try {
      await navigator.share({ title: article.title, text: article.description, url: article.link })
    } catch (err) {
      if (err instanceof DOMException && err.name === 'AbortError') return
    }
  }

  const theme = THEME_STYLES[settings.readerTheme]

  return (
    <AnimatePresence>
      {article && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
          className={`fixed inset-0 z-[80] flex items-center justify-center bg-black/80 backdrop-blur-md ${
            isExpanded ? 'p-0' : 'p-3 sm:p-5 lg:p-7'
          }`}
          onClick={onClose}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.96, y: 15 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 15 }}
            transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
            onClick={(e) => e.stopPropagation()}
            style={{ backgroundColor: theme.bg, color: theme.text }}
            className={`relative flex flex-col overflow-hidden transition-all duration-300 ${
              isExpanded
                ? 'h-full w-full rounded-none border-none shadow-none'
                : 'h-[88vh] w-full max-w-5xl rounded-3xl border border-white/15 shadow-[0_30px_90px_rgba(0,0,0,0.9)]'
            }`}
          >
            {/* Header Toolbar */}
            <div
              className="flex shrink-0 items-center justify-between gap-2 border-b px-4 py-3 sm:px-6"
              style={{ borderColor: `${theme.text}1a` }}
            >
              <div className="flex items-center gap-1.5">
                <ToolbarButton onClick={onClose} label="Đóng cửa sổ" style={{ color: theme.subtle }}>
                  <XIcon width={17} height={17} />
                </ToolbarButton>
                <div className="mx-1 h-5 w-px" style={{ backgroundColor: `${theme.text}1a` }} />
                <ToolbarButton onClick={onPrev} disabled={!hasPrev} label="Bài trước" style={{ color: theme.subtle }}>
                  <ChevronLeftIcon width={17} height={17} />
                </ToolbarButton>
                <ToolbarButton onClick={onNext} disabled={!hasNext} label="Bài tiếp theo" style={{ color: theme.subtle }}>
                  <ChevronRightIcon width={17} height={17} />
                </ToolbarButton>
                <div className="mx-1 h-5 w-px" style={{ backgroundColor: `${theme.text}1a` }} />
                <ToolbarButton
                  onClick={() => setIsExpanded((v) => !v)}
                  label={isExpanded ? 'Thu nhỏ cửa sổ' : 'Mở rộng cửa sổ'}
                  style={{ color: theme.subtle }}
                >
                  {isExpanded ? <MinimizeIcon width={16} height={16} /> : <MaximizeIcon width={16} height={16} />}
                </ToolbarButton>
              </div>

              <div className="flex items-center gap-1">
                <ThemeDot
                  active={settings.readerTheme === 'light'}
                  onClick={() => onUpdateSettings({ readerTheme: 'light' })}
                  icon={<SunIcon width={14} height={14} />}
                  label="Chế độ sáng"
                />
                <ThemeDot
                  active={settings.readerTheme === 'sepia'}
                  onClick={() => onUpdateSettings({ readerTheme: 'sepia' })}
                  icon={<SepiaIcon width={14} height={14} />}
                  label="Chế độ sepia"
                />
                <ThemeDot
                  active={settings.readerTheme === 'dark'}
                  onClick={() => onUpdateSettings({ readerTheme: 'dark' })}
                  icon={<MoonIcon width={14} height={14} />}
                  label="Chế độ tối"
                />
                <div className="mx-1 h-5 w-px" style={{ backgroundColor: `${theme.text}1a` }} />
                <ToolbarButton
                  onClick={() => onUpdateSettings({ readerFontSize: Math.max(14, settings.readerFontSize - 1) })}
                  label="Chữ nhỏ hơn"
                  style={{ color: theme.subtle }}
                >
                  <span className="flex items-center gap-0.5">
                    <TextSizeIcon width={13} height={13} />
                    <span className="text-[11px] font-bold">-</span>
                  </span>
                </ToolbarButton>
                <ToolbarButton
                  onClick={() => onUpdateSettings({ readerFontSize: Math.min(26, settings.readerFontSize + 1) })}
                  label="Chữ lớn hơn"
                  style={{ color: theme.subtle }}
                >
                  <span className="flex items-center gap-0.5">
                    <TextSizeIcon width={17} height={17} />
                    <span className="text-[13px] font-bold">+</span>
                  </span>
                </ToolbarButton>
                <div className="mx-1 h-5 w-px" style={{ backgroundColor: `${theme.text}1a` }} />
                <div className="relative" ref={shareMenuRef}>
                  <ToolbarButton
                    onClick={() => setShareMenuOpen((v) => !v)}
                    label="Chia sẻ"
                    style={{ color: theme.subtle }}
                  >
                    <ShareIcon width={16} height={16} />
                  </ToolbarButton>
                  <AnimatePresence>
                    {shareMenuOpen && (
                      <motion.div
                        initial={{ opacity: 0, y: -6, scale: 0.97 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: -6, scale: 0.97 }}
                        transition={{ duration: 0.15, ease: [0.16, 1, 0.3, 1] }}
                        className="absolute right-0 top-full z-10 mt-2 w-56 overflow-hidden rounded-2xl p-1.5 shadow-[0_20px_50px_rgba(0,0,0,0.35)] border border-white/10"
                        style={{ backgroundColor: theme.card, color: theme.text }}
                        data-lenis-prevent
                      >
                        <ShareMenuItem label="Facebook" color="#1877F2" badge="f" onClick={shareToFacebook} />
                        <ShareMenuItem label="X (Twitter)" color="#000000" badge="X" onClick={shareToX} />
                        <ShareMenuItem
                          label="Telegram"
                          color="#26A5E4"
                          icon={<PlaneIcon width={13} height={13} style={{ color: '#fff' }} />}
                          onClick={shareToTelegram}
                        />
                        <ShareMenuItem label="Discord" color="#5865F2" badge="D" onClick={shareToDiscord} />
                        <div className="my-1.5 h-px" style={{ backgroundColor: `${theme.text}1a` }} />
                        <ShareMenuItem
                          label="Sao chép liên kết"
                          icon={<LinkIcon width={14} height={14} />}
                          onClick={handleCopyLink}
                        />
                        {typeof navigator.share === 'function' && (
                          <ShareMenuItem
                            label="Chia sẻ khác..."
                            icon={<ShareIcon width={14} height={14} />}
                            onClick={handleNativeShare}
                          />
                        )}
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
                <ToolbarButton
                  onClick={() => window.open(article.link, '_blank', 'noopener,noreferrer')}
                  label="Mở bản gốc"
                  style={{ color: theme.subtle }}
                >
                  <ExternalLinkIcon width={16} height={16} />
                </ToolbarButton>
              </div>
            </div>

            {/* Article Content Area - Safari Reader Layout */}
            <div className="flex-1 overflow-y-auto" data-lenis-prevent>
              <article className="mx-auto max-w-[780px] px-6 py-10 sm:px-10">
                <header className="mb-8 border-b pb-6" style={{ borderColor: `${theme.text}15` }}>
                  <div className="mb-3 flex items-center gap-2 text-[12px] font-semibold tracking-wide uppercase" style={{ color: theme.subtle }}>
                    <span className="rounded-md bg-white/10 px-2 py-0.5 text-white/90">{article.source}</span>
                    <span>·</span>
                    <span>{formatRelativeTime(article.pubDate)}</span>
                  </div>

                  <h1
                    className="font-bold leading-tight tracking-tight text-white"
                    style={{ fontSize: `${settings.readerFontSize * 1.5}px` }}
                  >
                    {article.title}
                  </h1>
                </header>

                {article.image && (
                  <div className="mb-8 overflow-hidden rounded-2xl border border-white/10 shadow-lg">
                    <img
                      src={article.image}
                      alt=""
                      className="w-full max-h-[480px] cursor-zoom-in object-cover transition hover:opacity-95"
                      onClick={() => setZoomedImage(article.image)}
                      onError={(e) => {
                        ;(e.currentTarget as HTMLImageElement).style.display = 'none'
                      }}
                    />
                  </div>
                )}

                <div style={{ fontSize: `${settings.readerFontSize}px` }}>
                  {state === 'loading' && <ReaderSkeleton color={theme.card} />}

                  {state === 'ok' && (
                    <div
                      className={`reader-content max-w-none ${settings.readerFont === 'sans' ? 'font-sans' : ''}`}
                      style={{ fontSize: `${settings.readerFontSize}px`, lineHeight: 1.8 }}
                      dangerouslySetInnerHTML={{ __html: html }}
                      onClick={(e) => {
                        const target = e.target as HTMLElement
                        if (target.tagName === 'IMG') {
                          e.preventDefault()
                          setZoomedImage((target as HTMLImageElement).src)
                        }
                      }}
                    />
                  )}

                  {state === 'error' && (
                    <div className="max-w-none">
                      {article.description && (
                        <p style={{ fontSize: `${settings.readerFontSize}px`, lineHeight: 1.8 }}>
                          {article.description}
                        </p>
                      )}
                      <div
                        className="mt-6 flex flex-col items-start gap-3 rounded-2xl border border-white/10 p-5 text-[13px]"
                        style={{ backgroundColor: theme.card, color: theme.subtle }}
                      >
                        <p className="font-semibold text-white/90">
                          {article.description
                            ? 'Không thể trích xuất toàn bộ nội dung bài viết. Đây là bản tóm tắt.'
                            : 'Không thể nạp bài viết này.'}
                        </p>
                        <div className="flex gap-2.5">
                          <button
                            type="button"
                            onClick={() => setRetryToken((t) => t + 1)}
                            className="flex items-center gap-1.5 rounded-xl px-4 py-2 text-[13px] font-bold shadow-md"
                            style={{ backgroundColor: theme.text, color: theme.bg }}
                          >
                            Thử lại
                            <RefreshIcon width={13} height={13} />
                          </button>
                          <a
                            href={article.link}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="flex items-center gap-1.5 rounded-xl border border-white/10 px-4 py-2 text-[13px] font-bold"
                            style={{ backgroundColor: `${theme.subtle}22`, color: theme.text }}
                          >
                            Mở bản gốc
                            <ExternalLinkIcon width={13} height={13} />
                          </a>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </article>
            </div>

            <ImageLightbox src={zoomedImage} onClose={() => setZoomedImage(null)} />
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

function ShareMenuItem({
  label,
  color,
  badge,
  icon,
  onClick,
}: {
  label: string
  color?: string
  badge?: string
  icon?: React.ReactNode
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-2.5 rounded-xl px-2.5 py-2 text-left text-[13px] font-medium transition hover:bg-black/[0.06] dark:hover:bg-white/10"
    >
      <span
        className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[11px] font-bold text-white"
        style={{ backgroundColor: color ?? '#8E8E93' }}
      >
        {icon ?? badge}
      </span>
      {label}
    </button>
  )
}

function ToolbarButton({
  children,
  onClick,
  disabled,
  label,
  style,
}: {
  children: React.ReactNode
  onClick: () => void
  disabled?: boolean
  label: string
  style?: React.CSSProperties
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      style={style}
      className="flex h-8.5 w-8.5 items-center justify-center rounded-xl bg-white/5 transition hover:bg-white/15 disabled:opacity-25 active:scale-95"
    >
      {children}
    </button>
  )
}

function ThemeDot({
  active,
  onClick,
  icon,
  label,
}: {
  active: boolean
  onClick: () => void
  icon: React.ReactNode
  label: string
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className={`flex h-8.5 w-8.5 items-center justify-center rounded-xl transition active:scale-95 ${
        active ? 'bg-[#0A84FF] text-white shadow-md' : 'text-current opacity-50 hover:bg-white/10 hover:opacity-100'
      }`}
    >
      {icon}
    </button>
  )
}

function ReaderSkeleton({ color }: { color: string }) {
  return (
    <div className="flex flex-col gap-4">
      {[100, 95, 88, 92, 60].map((w, i) => (
        <div key={i} className="h-4 rounded-full opacity-60" style={{ width: `${w}%`, backgroundColor: color }} />
      ))}
    </div>
  )
}
