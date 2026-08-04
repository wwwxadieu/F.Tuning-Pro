import { motion } from 'framer-motion'

export default function Header() {
  return (
    <motion.header
      initial={{ y: -40, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
      className="fixed top-0 inset-x-0 z-50"
    >
      <div className="glass mx-auto mt-3 flex max-w-6xl items-center justify-between rounded-2xl px-5 py-3 shadow-[0_8px_32px_rgba(0,0,0,0.4)] sm:mx-4">
        <a href="#top" className="flex items-center gap-2.5">
          <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-gradient-to-br from-[#0A84FF] to-[#BF5AF2] text-sm font-bold shadow-lg shadow-blue-500/20">
            L
          </span>
          <span className="text-[15px] font-semibold tracking-tight">Luồng</span>
        </a>
        <nav className="hidden items-center gap-6 text-[13px] font-medium text-white/60 sm:flex">
          <a href="#tin-tuc" className="transition hover:text-white">
            Tin tức
          </a>
          <a href="#the" className="transition hover:text-white">
            Chủ đề
          </a>
        </nav>
        <span className="rounded-full border border-white/10 bg-white/5 px-3 py-1 text-[11px] font-medium text-white/50">
          Cập nhật trực tiếp
        </span>
      </div>
    </motion.header>
  )
}
