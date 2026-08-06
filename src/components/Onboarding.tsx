import { motion } from 'framer-motion'
import { useState } from 'react'
import { useTags } from '../context/TagsContext'
import InterestPicker from './InterestPicker'

interface Props {
  onComplete: (selected: string[]) => void
}

export default function Onboarding({ onComplete }: Props) {
  const { tags } = useTags()
  const [selected, setSelected] = useState<Set<string>>(new Set())

  function toggle(tagId: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(tagId)) next.delete(tagId)
      else next.add(tagId)
      return next
    })
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[100] flex items-center justify-center overflow-y-auto bg-black px-6 py-10"
    >
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        className="w-full max-w-2xl"
      >
        <div className="mb-8 text-center">
          <span className="mx-auto mb-5 flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2] text-xl font-bold shadow-lg shadow-blue-500/20">
            L
          </span>
          <h1 className="text-gradient text-3xl font-semibold tracking-tight sm:text-4xl">
            Bạn quan tâm điều gì?
          </h1>
          <p className="mx-auto mt-3 max-w-md text-[15px] text-white/50">
            Chọn một vài chủ đề để Luồng ưu tiên hiển thị tin tức phù hợp với bạn. Bạn có thể thay đổi
            bất cứ lúc nào trong phần Cài đặt.
          </p>
        </div>

        <InterestPicker tags={tags} selected={selected} onToggle={toggle} />

        <div className="mt-8 flex flex-col items-center gap-3">
          <motion.button
            type="button"
            onClick={() => onComplete([...selected])}
            disabled={selected.size === 0}
            whileHover={{ scale: selected.size > 0 ? 1.03 : 1 }}
            whileTap={{ scale: selected.size > 0 ? 0.97 : 1 }}
            className="w-full max-w-xs rounded-full bg-white px-7 py-3 text-[15px] font-semibold text-black shadow-[0_8px_30px_rgba(255,255,255,0.15)] transition disabled:cursor-not-allowed disabled:opacity-30 sm:w-auto"
          >
            {selected.size === 0 ? 'Chọn ít nhất 1 chủ đề' : `Bắt đầu với ${selected.size} chủ đề`}
          </motion.button>
          <button
            type="button"
            onClick={() => onComplete([])}
            className="text-[13px] font-medium text-white/40 transition hover:text-white/70"
          >
            Bỏ qua, hiển thị tất cả
          </button>
        </div>
      </motion.div>
    </motion.div>
  )
}
