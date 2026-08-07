import { AnimatePresence, motion, useMotionValue } from 'framer-motion'
import { useEffect, useState } from 'react'
import { MinusIcon, PlusIcon, XIcon } from './icons'

interface Props {
  src: string | null
  onClose: () => void
}

const MIN_SCALE = 1
const MAX_SCALE = 4
const ZOOM_STEP = 0.5

export default function ImageLightbox({ src, onClose }: Props) {
  const [scale, setScale] = useState(1)
  const x = useMotionValue(0)
  const y = useMotionValue(0)

  useEffect(() => {
    if (!src) return
    setScale(1)
    x.set(0)
    y.set(0)
  }, [src, x, y])

  useEffect(() => {
    if (!src) return
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
      else if (e.key === '+' || e.key === '=') zoomBy(ZOOM_STEP)
      else if (e.key === '-') zoomBy(-ZOOM_STEP)
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [src])

  function zoomBy(delta: number) {
    setScale((prev) => {
      const next = Math.min(MAX_SCALE, Math.max(MIN_SCALE, prev + delta))
      if (next === MIN_SCALE) {
        x.set(0)
        y.set(0)
      }
      return next
    })
  }

  function handleWheel(e: React.WheelEvent) {
    e.preventDefault()
    zoomBy(e.deltaY < 0 ? ZOOM_STEP : -ZOOM_STEP)
  }

  function handleDoubleClick() {
    setScale((prev) => {
      if (prev > MIN_SCALE) {
        x.set(0)
        y.set(0)
        return MIN_SCALE
      }
      return 2.5
    })
  }

  return (
    <AnimatePresence>
      {src && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[95] flex items-center justify-center bg-black/92 backdrop-blur-sm"
          onClick={onClose}
          onWheel={handleWheel}
        >
          <div className="absolute right-4 top-4 z-10 flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
            <button
              type="button"
              onClick={() => zoomBy(-ZOOM_STEP)}
              disabled={scale <= MIN_SCALE}
              aria-label="Thu nhỏ"
              className="flex h-9 w-9 items-center justify-center rounded-full bg-white/10 text-white transition hover:bg-white/20 disabled:opacity-30"
            >
              <MinusIcon width={15} height={15} />
            </button>
            <span className="w-12 text-center text-[12px] tabular-nums text-white/60">
              {Math.round(scale * 100)}%
            </span>
            <button
              type="button"
              onClick={() => zoomBy(ZOOM_STEP)}
              disabled={scale >= MAX_SCALE}
              aria-label="Phóng to"
              className="flex h-9 w-9 items-center justify-center rounded-full bg-white/10 text-white transition hover:bg-white/20 disabled:opacity-30"
            >
              <PlusIcon width={15} height={15} />
            </button>
            <div className="mx-1 h-5 w-px bg-white/15" />
            <button
              type="button"
              onClick={onClose}
              aria-label="Đóng"
              className="flex h-9 w-9 items-center justify-center rounded-full bg-white/10 text-white transition hover:bg-white/20"
            >
              <XIcon width={16} height={16} />
            </button>
          </div>

          <motion.img
            key={src}
            src={src}
            alt=""
            onClick={(e) => e.stopPropagation()}
            onDoubleClick={handleDoubleClick}
            drag={scale > 1}
            dragElastic={0.05}
            dragMomentum={false}
            style={{ x, y, cursor: scale > 1 ? 'grab' : 'zoom-in' }}
            animate={{ scale }}
            transition={{ duration: 0.2 }}
            className="max-h-[85vh] max-w-[90vw] select-none rounded-lg object-contain shadow-2xl"
            draggable={false}
          />

          <p className="absolute bottom-5 left-1/2 -translate-x-1/2 text-[11px] text-white/35">
            Cuộn để phóng to · Nhấp đôi để thu phóng nhanh · Kéo để di chuyển
          </p>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
