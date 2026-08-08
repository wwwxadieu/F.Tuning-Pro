import { AnimatePresence, motion } from 'framer-motion'
import type { Notification } from '../types/news'
import { useTags } from '../context/TagsContext'
import CategoryIcon from './CategoryIcon'

interface Props {
  toast: Notification | null
  onDismiss: () => void
  onClick: (tagId: string) => void
}

export default function UpdateBanner({ toast, onDismiss, onClick }: Props) {
  const { tagMap } = useTags()
  return (
    <div className="pointer-events-none fixed right-4 top-20 z-[60] flex w-full max-w-xs flex-col gap-2 sm:right-6">
      <AnimatePresence>
        {toast && (
          <motion.button
            key={toast.id}
            type="button"
            initial={{ opacity: 0, x: 60, scale: 0.95 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 60, scale: 0.95, transition: { duration: 0.2 } }}
            transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
            onClick={() => {
              onClick(toast.tagId)
              onDismiss()
            }}
            className="glass-panel pointer-events-auto flex items-start gap-3 rounded-2xl p-3.5 text-left shadow-[0_20px_60px_rgba(0,0,0,0.6)]"
          >
            <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2]">
              <CategoryIcon
                tagId={toast.tagId}
                emoji={tagMap.get(toast.tagId)?.emoji}
                faviconHost={tagMap.get(toast.tagId)?.source}
                size={15}
                color="#ffffff"
              />
            </span>
            <span className="flex-1">
              <span className="block text-[13px] font-semibold text-[var(--text-1)]">Có tin mới</span>
              <span className="mt-0.5 block text-[12px] text-[var(--text-2)]">
                {toast.count} bài viết mới trong {toast.tagLabel}
              </span>
            </span>
          </motion.button>
        )}
      </AnimatePresence>
    </div>
  )
}
