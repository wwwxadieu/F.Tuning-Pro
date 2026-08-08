import { motion } from 'framer-motion'
import { lazy, Suspense } from 'react'
import { smoothScrollTo } from '../lib/lenisInstance'

const HeroScene = lazy(() => import('./HeroScene'))

export default function Hero() {
  return (
    <section id="top" className="relative h-[92vh] min-h-[480px] w-full overflow-hidden">
      <div className="absolute inset-0">
        <Suspense fallback={null}>
          <HeroScene />
        </Suspense>
      </div>

      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-transparent via-[var(--bg)]/40 to-[var(--bg)]" />

      <div className="relative z-10 flex h-full flex-col items-center justify-center px-6 text-center">
        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1 }}
          className="mb-4 text-xs font-bold uppercase tracking-[0.25em] text-[var(--text-3)]"
        >
          Tổng hợp tin tức
        </motion.p>
        <motion.h1
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
          className="max-w-3xl font-extrabold tracking-tight text-[var(--text-1)] drop-shadow-sm"
          style={{ fontSize: 'clamp(2.2rem, 7vw, 4.6rem)' }}
        >
          Mọi tin tức.
          <br />
          Một điểm đến.
        </motion.h1>
        <motion.p
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.35, ease: [0.16, 1, 0.3, 1] }}
          className="mt-6 max-w-xl text-lg font-medium text-[var(--text-2)]"
        >
          F.VNN tổng hợp tin tức mới nhất từ nhiều nguồn, sắp xếp gọn gàng theo chủ đề bạn quan tâm.
        </motion.p>
        <motion.button
          type="button"
          onClick={() => smoothScrollTo('#tin-tuc')}
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.5, ease: [0.16, 1, 0.3, 1] }}
          whileHover={{ scale: 1.04 }}
          whileTap={{ scale: 0.97 }}
          className="mt-10 rounded-full bg-[var(--text-1)] px-8 py-3.5 text-[15px] font-bold text-[var(--bg)] shadow-xl transition hover:opacity-90"
        >
          Khám phá tin tức
        </motion.button>
      </div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.2, duration: 1 }}
        className="absolute bottom-8 left-1/2 z-10 -translate-x-1/2 text-[var(--text-4)]"
      >
        <div className="flex h-8 w-5 items-start justify-center rounded-full border border-[var(--border-1)] p-1">
          <motion.div
            animate={{ y: [0, 10, 0], opacity: [1, 0, 1] }}
            transition={{ duration: 1.8, repeat: Infinity, ease: 'easeInOut' }}
            className="h-1.5 w-1.5 rounded-full bg-[var(--text-3)]"
          />
        </div>
      </motion.div>
    </section>
  )
}
