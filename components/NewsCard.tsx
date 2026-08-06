"use client";

import { useRef, useState } from "react";
import { motion, useMotionValue, useSpring, useTransform } from "framer-motion";
import type { Article } from "@/lib/types";
import { tagGradientClass } from "@/lib/tagStyle";

function timeAgo(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return "vừa xong";
  if (mins < 60) return `${mins} phút trước`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} giờ trước`;
  const days = Math.floor(hours / 24);
  return `${days} ngày trước`;
}

export function NewsCard({ article, index }: { article: Article; index: number }) {
  const ref = useRef<HTMLAnchorElement>(null);
  const [imageFailed, setImageFailed] = useState(false);
  const mouseX = useMotionValue(0.5);
  const mouseY = useMotionValue(0.5);

  const springConfig = { stiffness: 200, damping: 22 };
  const rotateX = useSpring(useTransform(mouseY, [0, 1], [8, -8]), springConfig);
  const rotateY = useSpring(useTransform(mouseX, [0, 1], [-8, 8]), springConfig);
  const glowX = useTransform(mouseX, [0, 1], ["0%", "100%"]);
  const glowY = useTransform(mouseY, [0, 1], ["0%", "100%"]);

  function handleMouseMove(e: React.MouseEvent<HTMLAnchorElement>) {
    const rect = ref.current?.getBoundingClientRect();
    if (!rect) return;
    mouseX.set((e.clientX - rect.left) / rect.width);
    mouseY.set((e.clientY - rect.top) / rect.height);
  }

  function handleMouseLeave() {
    mouseX.set(0.5);
    mouseY.set(0.5);
  }

  return (
    <motion.a
      ref={ref}
      href={article.link}
      target="_blank"
      rel="noopener noreferrer"
      initial={{ opacity: 0, y: 60, rotateX: -12 }}
      whileInView={{ opacity: 1, y: 0, rotateX: 0 }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{ duration: 0.6, delay: (index % 6) * 0.05, ease: [0.16, 1, 0.3, 1] }}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      style={{ rotateX, rotateY, transformStyle: "preserve-3d" }}
      className="glass group relative flex flex-col overflow-hidden rounded-2xl transition-shadow hover:shadow-2xl hover:shadow-accent/10"
    >
      <motion.div
        aria-hidden
        className="pointer-events-none absolute inset-0 z-10 opacity-0 transition-opacity duration-300 group-hover:opacity-100"
        style={{
          background: `radial-gradient(280px circle at ${glowX} ${glowY}, rgba(41,151,255,0.15), transparent 70%)`,
        }}
      />

      <div className="relative aspect-[16/10] w-full overflow-hidden bg-white/5">
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
          <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-white/5 to-white/[0.02] text-3xl font-semibold text-white/15">
            {article.source.slice(0, 2).toUpperCase()}
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent" />
      </div>

      <div style={{ transform: "translateZ(30px)" }} className="flex flex-1 flex-col gap-3 p-5">
        <div className="flex flex-wrap items-center gap-1.5">
          {article.tags.slice(0, 2).map((tag) => (
            <span
              key={tag}
              className={`rounded-full px-2 py-0.5 text-[11px] font-medium text-white/90 ${tagGradientClass(tag)}`}
            >
              {tag}
            </span>
          ))}
          {article.translated && (
            <span
              title={article.originalTitle}
              className="rounded-full border border-hair px-2 py-0.5 text-[11px] font-medium text-white/50"
            >
              Đã dịch
            </span>
          )}
        </div>

        <h3
          title={article.translated ? article.originalTitle : undefined}
          className="text-balance text-[17px] font-semibold leading-snug text-white/95"
        >
          {article.title}
        </h3>

        {article.summary && (
          <p className="line-clamp-2 text-sm leading-relaxed text-white/50">
            {article.summary}
          </p>
        )}

        <div className="mt-auto flex items-center justify-between pt-2 text-xs text-white/40">
          <span className="font-medium text-white/60">{article.source}</span>
          <span>{timeAgo(article.publishedAt)}</span>
        </div>
      </div>
    </motion.a>
  );
}
