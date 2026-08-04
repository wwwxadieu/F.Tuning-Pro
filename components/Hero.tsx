"use client";

import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";

export function Hero({ articleCount }: { articleCount: number }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end start"],
  });

  const titleRotateX = useTransform(scrollYProgress, [0, 1], [0, 60]);
  const titleScale = useTransform(scrollYProgress, [0, 1], [1, 0.75]);
  const titleY = useTransform(scrollYProgress, [0, 1], [0, -60]);
  const titleOpacity = useTransform(scrollYProgress, [0, 0.75], [1, 0]);

  const orbAY = useTransform(scrollYProgress, [0, 1], [0, -180]);
  const orbARotate = useTransform(scrollYProgress, [0, 1], [0, 40]);
  const orbBY = useTransform(scrollYProgress, [0, 1], [0, 220]);
  const orbBRotate = useTransform(scrollYProgress, [0, 1], [0, -30]);

  return (
    <div ref={containerRef} className="relative h-[130vh]">
      <div className="perspective sticky top-0 flex h-screen flex-col items-center justify-center overflow-hidden">
        <motion.div
          aria-hidden
          className="pointer-events-none absolute -left-32 top-16 h-[420px] w-[420px] rounded-full bg-accent/25 blur-[110px]"
          style={{ y: orbAY, rotate: orbARotate }}
        />
        <motion.div
          aria-hidden
          className="pointer-events-none absolute -right-24 bottom-0 h-[380px] w-[380px] rounded-full bg-accent2/25 blur-[110px]"
          style={{ y: orbBY, rotate: orbBRotate }}
        />

        <motion.div
          style={{
            rotateX: titleRotateX,
            scale: titleScale,
            y: titleY,
            opacity: titleOpacity,
            transformStyle: "preserve-3d",
          }}
          className="relative z-10 flex flex-col items-center px-6 text-center"
        >
          <motion.span
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="mb-5 rounded-full border border-hair bg-white/5 px-4 py-1.5 text-xs font-medium tracking-wide text-white/60"
          >
            {articleCount > 0 ? `${articleCount} tin công nghệ mới nhất` : "Đang tải tin tức…"}
          </motion.span>
          <motion.h1
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, delay: 0.1 }}
            className="text-balance bg-gradient-to-b from-white via-white to-white/50 bg-clip-text text-[13vw] font-semibold leading-[0.95] tracking-tight text-transparent sm:text-[8vw] lg:text-[6.5vw]"
          >
            Công nghệ.
            <br />
            Cập nhật liên tục.
          </motion.h1>
          <motion.p
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.25 }}
            className="mt-6 max-w-xl text-balance text-lg text-white/50"
          >
            Tổng hợp tin tức từ TechCrunch, The Verge, Wired, Ars Technica và
            nhiều nguồn khác — sắp xếp theo thẻ, cập nhật theo thời gian thực.
          </motion.p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1, duration: 0.8 }}
          className="absolute bottom-10 flex flex-col items-center gap-2 text-white/30"
        >
          <span className="text-xs uppercase tracking-[0.2em]">Cuộn xuống</span>
          <motion.div
            animate={{ y: [0, 8, 0] }}
            transition={{ repeat: Infinity, duration: 1.6, ease: "easeInOut" }}
            className="h-8 w-5 rounded-full border border-white/20 p-1"
          >
            <div className="h-1.5 w-1.5 rounded-full bg-white/50" />
          </motion.div>
        </motion.div>
      </div>
    </div>
  );
}
