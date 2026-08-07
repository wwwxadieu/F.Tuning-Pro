import { CATEGORY_STYLES, DEFAULT_CATEGORY_STYLE } from '../data/categoryStyles'

interface Props {
  tagId: string
  /** Custom sources have no curated vector glyph — pass the user's chosen emoji as a fallback. */
  emoji?: string
  size?: number
  /** Wrap the glyph in a soft rounded, tinted chip instead of a bare icon. */
  chip?: boolean
  /** Override the curated accent color, e.g. to stay white on a colored badge. */
  color?: string
  className?: string
}

export default function CategoryIcon({ tagId, emoji, size = 16, chip = false, color: colorOverride, className = '' }: Props) {
  const curated = CATEGORY_STYLES[tagId]

  if (!curated && emoji) {
    return chip ? (
      <span
        className={`inline-flex shrink-0 items-center justify-center rounded-lg bg-white/10 ${className}`}
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
