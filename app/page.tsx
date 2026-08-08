"use client";

import { useMemo } from "react";
import { useNews } from "@/hooks/useNews";
import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { TagFilter } from "@/components/TagFilter";
import { SourceSidebar } from "@/components/SourceSidebar";
import { NewsGrid } from "@/components/NewsGrid";
import { AddSourceModal } from "@/components/AddSourceModal";
import { ArticleModal } from "@/components/ArticleModal";

export default function Home() {
  const news = useNews();

  // Counts are cross-filtered so each number answers "how many articles would I
  // get if I picked this?": tag counts respect the enabled sources, and source
  // counts respect the selected tag.
  const tagCounts = useMemo(() => {
    const visible = news.articles.filter((a) => !news.disabledSources.includes(a.source));
    const map: Record<string, number> = { __all__: visible.length };
    for (const article of visible) {
      for (const tag of article.tags) {
        map[tag] = (map[tag] ?? 0) + 1;
      }
    }
    return map;
  }, [news.articles, news.disabledSources]);

  const sourceCounts = useMemo(() => {
    const map: Record<string, number> = {};
    for (const article of news.articles) {
      if (news.selectedTag && !article.tags.includes(news.selectedTag)) continue;
      map[article.source] = (map[article.source] ?? 0) + 1;
    }
    return map;
  }, [news.articles, news.selectedTag]);

  return (
    <>
      <Header
        news={news}
        onOpenAddSource={() => news.setIsAddSourceOpen(true)}
      />

      <main className="min-h-screen pt-4">
        <Hero articleCount={news.articles.length} />

        <div className="mx-auto flex max-w-[1400px] gap-8 px-4 sm:px-6">
          <SourceSidebar
            allSources={news.allFeedSources}
            counts={sourceCounts}
            disabledSources={news.disabledSources}
            customSources={news.customSources}
            onToggleSource={news.toggleSource}
            onSetAll={news.setAllSourcesEnabled}
            onOpenAddSource={() => news.setIsAddSourceOpen(true)}
            onRemoveCustomSource={news.removeCustomSource}
          />

          {/* min-w-0 keeps the grid from overflowing this flex child */}
          <div className="min-w-0 flex-1">
            <TagFilter
              selectedTag={news.selectedTag}
              onSelect={news.setSelectedTag}
              counts={tagCounts}
            />

            {/* Below lg the sidebar is hidden, so sources move into a chip row */}
            <div className="flex gap-2 overflow-x-auto py-3 lg:hidden [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              <button
                onClick={() => news.setIsAddSourceOpen(true)}
                className="shrink-0 rounded-full border border-blue-500/40 bg-blue-500/15 px-3 py-1 text-xs font-bold text-blue-300 transition-colors"
              >
                + Thêm nguồn
              </button>
              {news.allFeedSources.map((feed) => {
                const enabled = !news.disabledSources.includes(feed.name);
                return (
                  <button
                    key={feed.name}
                    onClick={() => news.toggleSource(feed.name)}
                    className={`shrink-0 rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
                      enabled
                        ? "border-blue-500/40 bg-blue-500/15 text-white/90"
                        : "border-white/10 bg-white/5 text-white/35"
                    }`}
                  >
                    {feed.name}
                    <span className="ml-1.5 opacity-60">{sourceCounts[feed.name] ?? 0}</span>
                  </button>
                );
              })}
            </div>

            <NewsGrid
              articles={news.filteredArticles}
              loading={news.loading}
              error={news.error}
              onArticleClick={(article) => news.setSelectedArticle(article)}
            />
          </div>
        </div>
      </main>

      <footer className="border-t border-white/10 px-6 py-10 text-center text-xs text-white/40">
        <p>TechWave (F.VNN) — Hệ thống tổng hợp & phân tích tin tức công nghệ đa nguồn tự động.</p>
      </footer>

      {/* Add Source Modal (Soft Glass UI) */}
      <AddSourceModal
        isOpen={news.isAddSourceOpen}
        onClose={() => news.setIsAddSourceOpen(false)}
        onAddSource={(source) => news.addCustomSource(source)}
      />

      {/* Article Reader Modal */}
      <ArticleModal
        article={news.selectedArticle}
        onClose={() => news.setSelectedArticle(null)}
      />
    </>
  );
}
