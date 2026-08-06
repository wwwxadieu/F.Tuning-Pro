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

      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-black/10 via-black/40 to-black" />

      <div className="relative z-10 flex h-full flex-col items-center justify-center px-6 text-center">
        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1 }}
          className="mb-4 text-sm font-medium uppercase tracking-[0.2em] text-white/50"
        >
          Tổng hợp tin tức
        </motion.p>
        <motion.h1
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
          className="text-gradient max-w-3xl font-semibold tracking-tight"
          style={{ fontSize: 'clamp(2.1rem, 7vw, 4.5rem)' }}
        >
          Mọi tin tức.
          <br />
          Một điểm đến.
        </motion.h1>
        <motion.p
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.35, ease: [0.16, 1, 0.3, 1] }}
          className="mt-6 max-w-xl text-lg text-white/60"
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
          className="mt-10 rounded-full bg-white px-7 py-3 text-[15px] font-semibold text-black shadow-[0_8px_30px_rgba(255,255,255,0.15)] transition hover:shadow-[0_8px_40px_rgba(255,255,255,0.25)]"
        >
          Khám phá tin tức
        </motion.button>
      </div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.2, duration: 1 }}
        className="absolute bottom-8 left-1/2 z-10 -translate-x-1/2 text-white/40"
      >
        <div className="flex h-8 w-5 items-start justify-center rounded-full border border-white/25 p-1">
          <motion.div
            animate={{ y: [0, 10, 0], opacity: [1, 0, 1] }}
            transition={{ duration: 1.8, repeat: Infinity, ease: 'easeInOut' }}
            className="h-1.5 w-1.5 rounded-full bg-white/60"
          />
        </div>
      </motion.div>
    </section>
  )
}
