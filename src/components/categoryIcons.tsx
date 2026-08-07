import { iconBase, type IconProps } from './icons'

// A dedicated glyph per news category, drawn in the same stroke language as
// icons.tsx, plus a few extras (flame, rss, grid) used for chrome elsewhere.

export function LandmarkIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <polygon points="12 2.5 21 8 3 8" />
      <line x1="5" y1="10" x2="5" y2="19" />
      <line x1="9.5" y1="10" x2="9.5" y2="19" />
      <line x1="14.5" y1="10" x2="14.5" y2="19" />
      <line x1="19" y1="10" x2="19" y2="19" />
      <line x1="3" y1="21" x2="21" y2="21" />
    </svg>
  )
}

export function GlobeIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <circle cx="12" cy="12" r="9" />
      <line x1="3" y1="12" x2="21" y2="12" />
      <path d="M12 3c2.6 2.4 4 5.6 4 9s-1.4 6.6-4 9c-2.6-2.4-4-5.6-4-9s1.4-6.6 4-9z" />
    </svg>
  )
}

export function BriefcaseIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <rect x="3" y="7.5" width="18" height="12" rx="2" />
      <path d="M8.5 7.5V5.5a2 2 0 0 1 2-2h3a2 2 0 0 1 2 2v2" />
      <line x1="3" y1="13" x2="21" y2="13" />
    </svg>
  )
}

export function RocketIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M12 2.5c2.8 1.8 4.5 5.2 4.5 8.8 0 2.2-.9 4.5-2 5.9L12 20l-2.5-2.8c-1.1-1.4-2-3.7-2-5.9 0-3.6 1.7-7 4.5-8.8z" />
      <circle cx="12" cy="10.5" r="1.9" />
      <path d="M8.7 15.3c-1.4.9-2 2.9-2.1 4.7 1.8-.1 3.7-.8 4.6-2.1" />
      <path d="M15.3 15.3c1.4.9 2 2.9 2.1 4.7-1.8-.1-3.7-.8-4.6-2.1" />
    </svg>
  )
}

export function TrophyIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M7.5 4h9v5a4.5 4.5 0 0 1-9 0V4z" />
      <path d="M7.5 5.5H4a3 3 0 0 0 3.5 3.5" />
      <path d="M16.5 5.5H20a3 3 0 0 1-3.5 3.5" />
      <line x1="12" y1="13" x2="12" y2="16.5" />
      <path d="M9 20.5h6" />
      <path d="M9.8 16.5h4.4l1 4H8.8l1-4z" />
    </svg>
  )
}

export function ClapperboardIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M3.5 8.3L4.8 4.6 20 6.4l-.7 2.8-15.8-.9z" />
      <rect x="3.3" y="8.3" width="17.4" height="11.2" rx="1.5" />
      <line x1="7.7" y1="5.2" x2="9.6" y2="8.2" />
      <line x1="13.2" y1="5.6" x2="14.7" y2="8.5" />
    </svg>
  )
}

export function GraduationCapIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M2 9.5L12 4.5l10 5-10 5-10-5z" />
      <path d="M6.2 11.7v5c0 1.4 2.6 3 5.8 3s5.8-1.6 5.8-3v-5" />
      <line x1="21.5" y1="9.5" x2="21.5" y2="15.5" />
    </svg>
  )
}

export function HeartPulseIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M12 20.5s-7.3-4.4-9.6-8.7C.7 8.4 2.3 4.7 6.1 4.5c2-.1 3.6 1.1 5.9 3.5 2.3-2.4 3.9-3.6 5.9-3.5 3.8.2 5.4 3.9 3.7 7.3-2.3 4.3-9.6 8.7-9.6 8.7z" />
      <polyline points="6 12 8.7 12 10.2 9 12.7 15 14.2 12 17.5 12" />
    </svg>
  )
}

export function PlaneIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M21 15.3v-1.9l-7.5-4.7V4.3a1.5 1.5 0 0 0-3 0v4.4L3 13.4v1.9l7.5-2.4v5.2L8.3 19.6v1.6L12 20.4l3.7 1v-1.6l-2.2-1.5v-5.2z" />
    </svg>
  )
}

export function CarIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M3.5 13.5l1.4-4.3A2 2 0 0 1 6.8 7.8h10.4a2 2 0 0 1 1.9 1.4l1.4 4.3" />
      <rect x="2.5" y="13.5" width="19" height="5.2" rx="1.6" />
      <circle cx="7.3" cy="19" r="1.6" />
      <circle cx="16.7" cy="19" r="1.6" />
      <line x1="4" y1="16" x2="7" y2="16" />
      <line x1="17" y1="16" x2="20" y2="16" />
    </svg>
  )
}

export function LaptopIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <rect x="4.5" y="4.5" width="15" height="10.2" rx="1.3" />
      <path d="M2.3 19.3l1.8-3h15.8l1.8 3a1 1 0 0 1-.9 1.5H3.2a1 1 0 0 1-.9-1.5z" />
    </svg>
  )
}

export function GamepadIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <rect x="2.5" y="7.5" width="19" height="10" rx="4.5" />
      <line x1="7" y1="10.3" x2="7" y2="14.3" />
      <line x1="5" y1="12.3" x2="9" y2="12.3" />
      <circle cx="16" cy="10.8" r="1" fill="currentColor" stroke="none" />
      <circle cx="18.3" cy="13.3" r="1" fill="currentColor" stroke="none" />
    </svg>
  )
}

export function FlameIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <path d="M12 2.5c1.7 2.6-.8 3.9-.8 6.5 0 1.3.9 2.3 1.9 2.3 1.3 0 2.2-1.3 1.7-2.7 2.7 1.6 4.2 4.5 4.2 7.2a7.2 7.2 0 0 1-14.4 0c0-3.4 1.7-5.4 2.6-7 .5 1.7 1.8 2.2 1.8 1.1-.4-3.1-1.3-5.3 3-7.4z" />
    </svg>
  )
}

export function RssIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <circle cx="5.5" cy="18.5" r="1.6" fill="currentColor" stroke="none" />
      <path d="M4.5 11.5a8 8 0 0 1 8 8" />
      <path d="M4.5 4.5a15 15 0 0 1 15 15" />
    </svg>
  )
}

export function GridIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <rect x="3" y="3" width="7.5" height="7.5" rx="1.8" />
      <rect x="13.5" y="3" width="7.5" height="7.5" rx="1.8" />
      <rect x="3" y="13.5" width="7.5" height="7.5" rx="1.8" />
      <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.8" />
    </svg>
  )
}

export function CpuIcon(props: IconProps) {
  return (
    <svg {...iconBase(props)}>
      <rect x="6" y="6" width="12" height="12" rx="2" />
      <rect x="9.5" y="9.5" width="5" height="5" rx="1" />
      <line x1="9" y1="2.5" x2="9" y2="6" />
      <line x1="12" y1="2.5" x2="12" y2="6" />
      <line x1="15" y1="2.5" x2="15" y2="6" />
      <line x1="9" y1="18" x2="9" y2="21.5" />
      <line x1="12" y1="18" x2="12" y2="21.5" />
      <line x1="15" y1="18" x2="15" y2="21.5" />
      <line x1="18" y1="9" x2="21.5" y2="9" />
      <line x1="18" y1="12" x2="21.5" y2="12" />
      <line x1="18" y1="15" x2="21.5" y2="15" />
      <line x1="2.5" y1="9" x2="6" y2="9" />
      <line x1="2.5" y1="12" x2="6" y2="12" />
      <line x1="2.5" y1="15" x2="6" y2="15" />
    </svg>
  )
}
