"use client";

import { AnimatePresence, motion } from "framer-motion";
import type { Article } from "@/lib/types";
import { NewsCard } from "./NewsCard";

function SkeletonCard() {
  return (
    <div className="glass shimmer-bg animate-shimmer flex aspect-[16/10] flex-col overflow-hidden rounded-2xl" />
  );
}

export function NewsGrid({
  articles,
  loading,
  error,
}: {
  articles: Article[];
  loading: boolean;
  error: string | null;
}) {
  if (error && articles.length === 0) {
    return (
      <div className="mx-auto max-w-6xl px-6 py-24 text-center text-white/50">
        <p>Không thể tải tin tức: {error}</p>
      </div>
    );
  }

  if (loading && articles.length === 0) {
    return (
      <div className="mx-auto grid max-w-6xl grid-cols-1 gap-6 px-6 py-12 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <SkeletonCard key={i} />
        ))}
      </div>
    );
  }

  if (!loading && articles.length === 0) {
    return (
      <div className="mx-auto max-w-6xl px-6 py-24 text-center text-white/40">
        <p>Không có tin tức phù hợp với thẻ này.</p>
      </div>
    );
  }

  return (
    <div className="perspective mx-auto max-w-6xl px-6 py-12">
      <AnimatePresence mode="popLayout">
        <motion.div
          layout
          className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3"
        >
          {articles.map((article, i) => (
            <NewsCard key={article.id} article={article} index={i} />
          ))}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
