import type { ComponentType } from 'react'
import {
  BriefcaseIcon,
  CarIcon,
  ClapperboardIcon,
  CpuIcon,
  GamepadIcon,
  GlobeIcon,
  GraduationCapIcon,
  GridIcon,
  HeartPulseIcon,
  LandmarkIcon,
  LaptopIcon,
  PlaneIcon,
  RocketIcon,
  RssIcon,
  TrophyIcon,
} from '../components/categoryIcons'
import type { IconProps } from '../components/icons'

export interface CategoryStyle {
  icon: ComponentType<IconProps>
  color: string
}

// One curated vector glyph + accent color per built-in category, keyed by
// tag id. Custom (user-added) sources have no entry here and fall back to
// the emoji the user picked when adding them — see CategoryIcon.tsx.
export const CATEGORY_STYLES: Record<string, CategoryStyle> = {
  all: { icon: GridIcon, color: '#0A84FF' },
  'thoi-su': { icon: LandmarkIcon, color: '#5E5CE6' },
  'the-gioi': { icon: GlobeIcon, color: '#0A84FF' },
  'kinh-doanh': { icon: BriefcaseIcon, color: '#30D158' },
  'khoa-hoc-cong-nghe': { icon: RocketIcon, color: '#64D2FF' },
  'the-thao': { icon: TrophyIcon, color: '#FF9F0A' },
  'giai-tri': { icon: ClapperboardIcon, color: '#BF5AF2' },
  'giao-duc': { icon: GraduationCapIcon, color: '#FFD60A' },
  'suc-khoe': { icon: HeartPulseIcon, color: '#FF375F' },
  'du-lich': { icon: PlaneIcon, color: '#32ADE6' },
  xe: { icon: CarIcon, color: '#FF453A' },
  'may-tinh': { icon: LaptopIcon, color: '#8E8E93' },
  gaming: { icon: GamepadIcon, color: '#66D4CF' },
  'tech-quocte': { icon: CpuIcon, color: '#FFB340' },
}

export const DEFAULT_CATEGORY_STYLE: CategoryStyle = { icon: RssIcon, color: '#8E8E93' }

export function getCategoryStyle(tagId: string): CategoryStyle {
  return CATEGORY_STYLES[tagId] ?? DEFAULT_CATEGORY_STYLE
}
