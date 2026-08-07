import { useState } from 'react'
import { CATEGORY_STYLES, DEFAULT_CATEGORY_STYLE } from '../data/categoryStyles'
import { RssIcon } from './categoryIcons'

interface Props {
  tagId: string
  /** Custom sources have no curated vector glyph — pass the user's chosen emoji as a fallback. */
  emoji?: string
  /** Hostname of a custom source, used to auto-detect its real site favicon. */
  faviconHost?: string
  size?: number
  /** Wrap the glyph in a soft rounded, tinted chip instead of a bare icon. */
  chip?: boolean
  /** Override the curated accent color, e.g. to stay white on a colored badge. */
  color?: string
  className?: string
}

function EmojiGlyph({ emoji, size, chip, className }: { emoji: string; size: number; chip: boolean; className: string }) {
  return chip ? (
    <span
      className={`inline-flex shrink-0 items-center justify-center rounded-lg bg-[var(--surface-2)] ${className}`}
      style={{ width: size * 1.75, height: size * 1.75, fontSize: size * 0.85, lineHeight: 1 }}
    >
      {emoji}
    </span>
  ) : (
    <span className={`inline-block ${className}`} style={{ fontSize: size, lineHeight: 1 }}>
      {emoji}
    </span>
  )
}

function RssGlyph({ size, chip, className }: { size: number; chip: boolean; className: string }) {
  const { color } = DEFAULT_CATEGORY_STYLE
  return chip ? (
    <span
      className={`inline-flex shrink-0 items-center justify-center rounded-lg ${className}`}
      style={{ width: size * 1.75, height: size * 1.75, background: `${color}22`, color }}
    >
      <RssIcon width={size} height={size} />
    </span>
  ) : (
    <RssIcon width={size} height={size} style={{ color }} className={className} />
  )
}

function FaviconGlyph({
  host,
  emoji,
  size,
  chip,
  className,
}: {
  host: string
  emoji?: string
  size: number
  chip: boolean
  className: string
}) {
  const [errored, setErrored] = useState(false)

  if (errored) {
    return emoji ? (
      <EmojiGlyph emoji={emoji} size={size} chip={chip} className={className} />
    ) : (
      <RssGlyph size={size} chip={chip} className={className} />
    )
  }

  const src = `https://www.google.com/s2/favicons?sz=64&domain=${encodeURIComponent(host)}`
  const img = (
    <img
      src={src}
      alt=""
      width={size}
      height={size}
      className="rounded-[3px] object-contain"
      onError={() => setErrored(true)}
    />
  )

  return chip ? (
    <span
      className={`inline-flex shrink-0 items-center justify-center rounded-lg bg-[var(--surface-2)] ${className}`}
      style={{ width: size * 1.75, height: size * 1.75 }}
    >
      {img}
    </span>
  ) : (
    <span className={`inline-block ${className}`}>{img}</span>
  )
}

export default function CategoryIcon({
  tagId,
  emoji,
  faviconHost,
  size = 16,
  chip = false,
  color: colorOverride,
  className = '',
}: Props) {
  const curated = CATEGORY_STYLES[tagId]

  if (!curated) {
    if (faviconHost) {
      return <FaviconGlyph host={faviconHost} emoji={emoji} size={size} chip={chip} className={className} />
    }
    if (emoji) {
      return <EmojiGlyph emoji={emoji} size={size} chip={chip} className={className} />
    }
  }

  const { icon: Icon, color: curatedColor } = curated ?? DEFAULT_CATEGORY_STYLE
  const color = colorOverride ?? curatedColor

  if (chip) {
    return (
      <span
        className={`inline-flex shrink-0 items-center justify-center rounded-lg ${className}`}
        style={{ width: size * 1.75, height: size * 1.75, background: colorOverride ? 'transparent' : `${color}22`, color }}
      >
        <Icon width={size} height={size} />
      </span>
    )
  }

  return <Icon width={size} height={size} style={{ color }} className={className} />
}
