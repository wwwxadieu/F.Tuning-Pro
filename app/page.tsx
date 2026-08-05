"use client";

import { useMemo } from "react";
import { useNews } from "@/hooks/useNews";
import { FEEDS } from "@/lib/feeds";
import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { TagFilter } from "@/components/TagFilter";
import { SourceSidebar } from "@/components/SourceSidebar";
import { NewsGrid } from "@/components/NewsGrid";

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
      <Header news={news} />
      <main>
        <Hero articleCount={news.articles.length} />

        <div className="mx-auto flex max-w-[1400px] gap-8 px-6">
          <SourceSidebar
            counts={sourceCounts}
            disabledSources={news.disabledSources}
            onToggleSource={news.toggleSource}
            onSetAll={news.setAllSourcesEnabled}
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
              {FEEDS.map((feed) => {
                const enabled = !news.disabledSources.includes(feed.name);
                return (
                  <button
                    key={feed.name}
                    onClick={() => news.toggleSource(feed.name)}
                    className={`shrink-0 rounded-full border px-3 py-1 text-xs font-medium transition-colors ${
                      enabled
                        ? "border-accent/40 bg-accent/15 text-white/90"
                        : "border-hair bg-white/5 text-white/35"
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
            />
          </div>
        </div>
      </main>
      <footer className="border-t border-hair px-6 py-10 text-center text-sm text-white/30">
        <p>TechWave — tổng hợp tin tức công nghệ tự động từ nhiều nguồn RSS.</p>
      </footer>
    </>
  );
}
