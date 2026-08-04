"use client";

import { useMemo } from "react";
import { useNews } from "@/hooks/useNews";
import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { TagFilter } from "@/components/TagFilter";
import { NewsGrid } from "@/components/NewsGrid";

export default function Home() {
  const news = useNews();

  const counts = useMemo(() => {
    const map: Record<string, number> = { __all__: news.articles.length };
    for (const article of news.articles) {
      for (const tag of article.tags) {
        map[tag] = (map[tag] ?? 0) + 1;
      }
    }
    return map;
  }, [news.articles]);

  return (
    <>
      <Header news={news} />
      <main>
        <Hero articleCount={news.articles.length} />
        <TagFilter
          selectedTag={news.selectedTag}
          onSelect={news.setSelectedTag}
          counts={counts}
        />
        <NewsGrid
          articles={news.filteredArticles}
          loading={news.loading}
          error={news.error}
        />
      </main>
      <footer className="border-t border-hair px-6 py-10 text-center text-sm text-white/30">
        <p>TechWave — tổng hợp tin tức công nghệ tự động từ nhiều nguồn RSS.</p>
      </footer>
    </>
  );
}
