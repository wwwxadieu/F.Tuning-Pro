"use client";

import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import type { Article } from "@/lib/types";
import { NewsCard } from "./NewsCard";

function SkeletonCard() {
  return (
    <div className="glass shimmer-bg animate-shimmer flex aspect-[16/10] flex-col overflow-hidden rounded-2xl border border-white/10 bg-white/5" />
  );
}

const INITIAL_BATCH = 18;
const BATCH_SIZE = 12;

export function NewsGrid({
  articles,
  loading,
  error,
  onArticleClick,
}: {
  articles: Article[];
  loading: boolean;
  error: string | null;
  onArticleClick?: (article: Article) => void;
}) {
  const [visibleCount, setVisibleCount] = useState(INITIAL_BATCH);
  const observerTarget = useRef<HTMLDivElement>(null);

  // Reset pagination when articles array change (e.g. tag or source filter changed)
  useEffect(() => {
    setVisibleCount(INITIAL_BATCH);
  }, [articles]);

  // Infinite Scroll IntersectionObserver
  useEffect(() => {
    const target = observerTarget.current;
    if (!target) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          setVisibleCount((prev) => Math.min(prev + BATCH_SIZE, articles.length));
        }
      },
      { threshold: 0.1, rootMargin: "200px" }
    );

    observer.observe(target);
    return () => observer.disconnect();
  }, [articles.length]);

  if (error && articles.length === 0) {
    return (
      <div className="py-24 text-center text-white/50">
        <p className="text-base font-medium">Không thể tải tin tức: {error}</p>
      </div>
    );
  }

  if (loading && articles.length === 0) {
    return (
      <div className="grid grid-cols-1 gap-6 py-12 sm:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 9 }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </div>
    );
  }

  if (!loading && articles.length === 0) {
    return (
      <div className="py-24 text-center text-white/40">
        <p className="text-base font-semibold text-white/70">Không có tin tức phù hợp với bộ lọc hiện tại.</p>
        <p className="mt-2 text-xs text-white/40">
          Thử chọn thẻ khác hoặc bật lại nguồn tin ở cột bên trái.
        </p>
      </div>
    );
  }

  const visibleArticles = articles.slice(0, visibleCount);
  const hasMore = visibleCount < articles.length;

  return (
    <div className="perspective py-6 sm:py-10">
      {/* Grid Stats Bar */}
      <div className="mb-6 flex items-center justify-between text-xs text-white/50">
        <span>
          Đang hiển thị <strong className="text-white/90">{visibleArticles.length}</strong> / {articles.length} bài viết
        </span>
        {hasMore && (
          <span className="text-blue-400 font-medium">Cuộn xuống để xem thêm</span>
        )}
      </div>

      <AnimatePresence mode="popLayout">
        <motion.div
          layout
          className="grid grid-cols-1 gap-6 sm:grid-cols-2 xl:grid-cols-3"
        >
          {visibleArticles.map((article, i) => (
            <NewsCard
              key={article.id}
              article={article}
              index={i}
              onClick={onArticleClick}
            />
          ))}
        </motion.div>
      </AnimatePresence>

      {/* Infinite Scroll Trigger & Load More Button */}
      <div ref={observerTarget} className="mt-12 flex flex-col items-center justify-center py-6">
        {hasMore ? (
          <button
            onClick={() => setVisibleCount((prev) => Math.min(prev + BATCH_SIZE, articles.length))}
            className="flex items-center gap-2 rounded-2xl border border-white/20 bg-white/10 px-6 py-3 text-xs font-bold text-white transition-all hover:bg-white/20 active:scale-95 shadow-lg"
          >
            <span>Hiển thị thêm tin tức</span>
            <span className="rounded-full bg-white/15 px-2 py-0.5 text-[10px]">
              +{articles.length - visibleCount}
            </span>
          </button>
        ) : (
          <div className="text-center text-xs text-white/30">
            ✓ Đã tải toàn bộ {articles.length} bài viết.
          </div>
        )}
      </div>
    </div>
  );
}
