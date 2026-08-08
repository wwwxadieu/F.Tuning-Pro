"use client";

import { useRef, useState } from "react";
import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import type { Article } from "@/lib/types";
import { tagGradientClass } from "@/lib/tagStyle";

function timeAgo(iso: string): string {
  if (!iso) return "mới đây";
  const diffMs = Date.now() - new Date(iso).getTime();
  if (isNaN(diffMs)) return "mới đây";
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return "vừa xong";
  if (mins < 60) return `${mins} phút trước`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} giờ trước`;
  const days = Math.floor(hours / 24);
  if (days > 365) return `${Math.floor(days / 365)} năm trước`;
  return `${days} ngày trước`;
}

export function NewsCard({
  article,
  index,
  onClick,
}: {
  article: Article;
  index: number;
  onClick?: (article: Article) => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [imageFailed, setImageFailed] = useState(false);
  const mouseX = useMotionValue(0.5);
  const mouseY = useMotionValue(0.5);

  const springConfig = { stiffness: 200, damping: 22 };
  const rotateX = useSpring(useTransform(mouseY, [0, 1], [6, -6]), springConfig);
  const rotateY = useSpring(useTransform(mouseX, [0, 1], [-6, 6]), springConfig);
  const glowX = useTransform(mouseX, [0, 1], ["0%", "100%"]);
  const glowY = useTransform(mouseY, [0, 1], ["0%", "100%"]);

  function handleMouseMove(e: React.MouseEvent<HTMLDivElement>) {
    const rect = ref.current?.getBoundingClientRect();
    if (!rect) return;
    mouseX.set((e.clientX - rect.left) / rect.width);
    mouseY.set((e.clientY - rect.top) / rect.height);
  }

  function handleMouseLeave() {
    mouseX.set(0.5);
    mouseY.set(0.5);
  }

  function handleClick(e: React.MouseEvent) {
    if (onClick) {
      e.preventDefault();
      onClick(article);
    }
  }

  const firstTag = article.tags[0] || "Big Tech";

  return (
    <motion.div
      ref={ref}
      onClick={handleClick}
      initial={{ opacity: 0, y: 40, rotateX: -8 }}
      whileInView={{ opacity: 1, y: 0, rotateX: 0 }}
      viewport={{ once: true, margin: "-60px" }}
      transition={{ duration: 0.5, delay: (index % 6) * 0.04, ease: [0.16, 1, 0.3, 1] }}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      style={{ rotateX, rotateY, transformStyle: "preserve-3d" }}
      className="glass group relative flex flex-col cursor-pointer overflow-hidden rounded-2xl border border-white/10 bg-[#12131a]/80 transition-all duration-300 hover:border-white/25 hover:shadow-2xl hover:shadow-accent/15"
    >
      <motion.div
        aria-hidden
        className="pointer-events-none absolute inset-0 z-10 opacity-0 transition-opacity duration-300 group-hover:opacity-100"
        style={{
          background: `radial-gradient(300px circle at ${glowX} ${glowY}, rgba(41,151,255,0.18), transparent 70%)`,
        }}
      />

      {/* Image Container with Fallback Apple Tech Graphic (Resolves Image 2 missing thumbnails) */}
      <div className="relative aspect-[16/10] w-full overflow-hidden bg-[#181a24]">
        {article.image && !imageFailed ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={article.image}
            alt=""
            loading="lazy"
            onError={() => setImageFailed(true)}
            className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
          />
        ) : (
          <div className="flex h-full w-full flex-col items-center justify-center relative overflow-hidden bg-gradient-to-br from-[#1a1c28] via-[#121420] to-[#0a0b12]">
            {/* Tech Vector Waveform / Grid Background */}
            <div className="absolute inset-0 opacity-15 bg-[radial-gradient(#2997ff_1px,transparent_1px)] [background-size:16px_16px]" />
            <div className="z-10 flex h-12 w-12 items-center justify-center rounded-2xl border border-white/15 bg-white/10 text-xl font-bold text-white shadow-inner backdrop-blur-md">
              {article.source.slice(0, 2).toUpperCase()}
            </div>
            <span className="z-10 mt-2.5 text-xs font-semibold tracking-wider text-white/50 uppercase">
              {article.source}
            </span>
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-[#12131a] via-transparent to-transparent opacity-80" />
      </div>

      {/* Card Content */}
      <div style={{ transform: "translateZ(25px)" }} className="flex flex-1 flex-col gap-3 p-5">
        <div className="flex flex-wrap items-center gap-1.5">
          {article.tags.slice(0, 2).map((tag) => (
            <span
              key={tag}
              className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${tagGradientClass(tag)}`}
            >
              {tag}
            </span>
          ))}
          {article.translated && (
            <span
              title={article.originalTitle}
              className="rounded-full border border-white/15 bg-white/5 px-2 py-0.5 text-[10px] font-medium text-white/60"
            >
              Đã dịch
            </span>
          )}
        </div>

        <h3
          title={article.translated ? article.originalTitle : undefined}
          className="text-balance text-[16px] font-bold leading-snug text-white/95 group-hover:text-blue-400 transition-colors line-clamp-2"
        >
          {article.title}
        </h3>

        {article.summary && (
          <p className="line-clamp-2 text-xs leading-relaxed text-white/55">
            {article.summary}
          </p>
        )}

        <div className="mt-auto flex items-center justify-between pt-3 text-xs text-white/40 border-t border-white/5">
          <span className="font-semibold text-white/70">{article.source}</span>
          <span>{timeAgo(article.publishedAt)}</span>
        </div>
      </div>
    </motion.div>
  );
}
