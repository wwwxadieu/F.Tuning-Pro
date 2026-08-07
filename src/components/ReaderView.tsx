import { AnimatePresence, motion } from 'framer-motion'
import { useEffect, useState } from 'react'
import type { Article, ReaderTheme, Settings } from '../types/news'
import { fetchReaderContent } from '../services/readerService'
import { formatRelativeTime } from '../utils/time'
import ImageLightbox from './ImageLightbox'
import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ExternalLinkIcon,
  MoonIcon,
  SepiaIcon,
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
  dark: { bg: '#000000', text: '#f2f2f2', subtle: '#9a9a9e', card: '#1c1c1e' },
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

  useEffect(() => {
    if (!article) return
    setState('loading')
    setHtml('')
    setZoomedImage(null)
    const controller = new AbortController()

    fetchReaderContent(article.link, controller.signal)
      .then((content) => {
        setHtml(content.html)
        setState('ok')
      })
      .catch(() => {
        if (controller.signal.aborted) return
        setState('error')
      })

    return () => controller.abort()
  }, [article])

  useEffect(() => {
    if (!article) return
    function onKeyDown(e: KeyboardEvent) {
      if (zoomedImage) return // let the lightbox handle its own Escape/zoom keys
      if (e.key === 'Escape') onClose()
      else if (e.key === 'ArrowLeft' && hasPrev) onPrev()
      else if (e.key === 'ArrowRight' && hasNext) onNext()
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [article, hasPrev, hasNext, onPrev, onNext, onClose, zoomedImage])

  const theme = THEME_STYLES[settings.readerTheme]

  return (
    <AnimatePresence>
      {article && (
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 24 }}
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed inset-0 z-[80] flex flex-col"
          style={{ backgroundColor: theme.bg, color: theme.text }}
        >
          <div
            className="flex shrink-0 items-center justify-between gap-2 border-b px-4 py-2.5 sm:px-6"
            style={{ borderColor: `${theme.text}1a` }}
          >
            <div className="flex items-center gap-1">
              <ToolbarButton onClick={onClose} label="Đóng" style={{ color: theme.subtle }}>
                <XIcon width={17} height={17} />
              </ToolbarButton>
              <div className="mx-1 h-5 w-px" style={{ backgroundColor: `${theme.text}1a` }} />
              <ToolbarButton onClick={onPrev} disabled={!hasPrev} label="Bài trước" style={{ color: theme.subtle }}>
                <ChevronLeftIcon width={17} height={17} />
              </ToolbarButton>
              <ToolbarButton onClick={onNext} disabled={!hasNext} label="Bài tiếp theo" style={{ color: theme.subtle }}>
                <ChevronRightIcon width={17} height={17} />
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
              <ToolbarButton
                onClick={() => window.open(article.link, '_blank', 'noopener,noreferrer')}
                label="Mở bản gốc"
                style={{ color: theme.subtle }}
              >
                <ExternalLinkIcon width={16} height={16} />
              </ToolbarButton>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto">
            <article className="mx-auto max-w-[680px] px-6 py-10 sm:px-8">
              {article.image && (
                <img
                  src={article.image}
                  alt=""
                  className="mb-6 aspect-video w-full cursor-zoom-in rounded-2xl object-cover transition hover:opacity-90"
                  onClick={() => setZoomedImage(article.image)}
                  onError={(e) => {
                    ;(e.currentTarget as HTMLImageElement).style.display = 'none'
                  }}
                />
              )}
              <h1 className="text-[1.7em] font-bold leading-tight tracking-tight" style={{ fontSize: `${settings.readerFontSize * 1.55}px` }}>
                {article.title}
              </h1>
              <p className="mb-8 mt-3 text-[13px]" style={{ color: theme.subtle }}>
                {article.source} · {formatRelativeTime(article.pubDate)}
              </p>

              {state === 'loading' && <ReaderSkeleton color={theme.card} />}

              {state === 'ok' && (
                <div
                  className={`reader-content ${settings.readerFont === 'sans' ? 'font-sans' : ''}`}
                  style={{ fontSize: `${settings.readerFontSize}px`, lineHeight: 1.7 }}
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
                <div>
                  <p style={{ fontSize: `${settings.readerFontSize}px`, lineHeight: 1.7 }}>{article.description}</p>
                  <p className="mt-6 rounded-xl px-4 py-3 text-[13px]" style={{ backgroundColor: theme.card, color: theme.subtle }}>
                    Không thể tải toàn bộ nội dung bài viết. Đây là bản tóm tắt — bấm biểu tượng{' '}
                    <ExternalLinkIcon width={12} height={12} style={{ display: 'inline' }} /> để mở bản đầy đủ.
                  </p>
                </div>
              )}
            </article>
          </div>

          <ImageLightbox src={zoomedImage} onClose={() => setZoomedImage(null)} />
        </motion.div>
      )}
    </AnimatePresence>
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
      className="flex h-8 w-8 items-center justify-center rounded-lg transition hover:bg-black/10 disabled:opacity-25 disabled:hover:bg-transparent dark:hover:bg-white/10"
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
      className={`flex h-8 w-8 items-center justify-center rounded-lg transition ${
        active ? 'bg-[#0A84FF] text-white' : 'text-current opacity-50 hover:opacity-100'
      }`}
    >
      {icon}
    </button>
  )
}

function ReaderSkeleton({ color }: { color: string }) {
  return (
    <div className="flex flex-col gap-3">
      {[100, 95, 88, 92, 60].map((w, i) => (
        <div key={i} className="h-4 rounded-full" style={{ width: `${w}%`, backgroundColor: color }} />
      ))}
    </div>
  )
}
