"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import type { FeedSource } from "@/lib/feeds";
import type { CustomFeedSource } from "@/lib/types";

const COLLAPSED_KEY = "techwave:sidebar-collapsed";

function ChevronIcon({ pointsLeft }: { pointsLeft: boolean }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4">
      <path
        d={pointsLeft ? "M15 6l-6 6 6 6" : "M9 6l6 6-6 6"}
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-3 w-3">
      <path d="M5 12.5l4.5 4.5L19 7.5" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-3.5 w-3.5">
      <path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function SourceSidebar({
  allSources,
  counts,
  disabledSources,
  customSources,
  onToggleSource,
  onSetAll,
  onOpenAddSource,
  onRemoveCustomSource,
}: {
  allSources: (FeedSource | CustomFeedSource)[];
  counts: Record<string, number>;
  disabledSources: string[];
  customSources: CustomFeedSource[];
  onToggleSource: (name: string) => void;
  onSetAll: (enabled: boolean, allNames: string[]) => void;
  onOpenAddSource: () => void;
  onRemoveCustomSource: (name: string) => void;
}) {
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    try {
      setCollapsed(window.localStorage.getItem(COLLAPSED_KEY) === "true");
    } catch {
      // ignore
    }
  }, []);

  function toggleCollapsed() {
    setCollapsed((prev) => {
      const next = !prev;
      try {
        window.localStorage.setItem(COLLAPSED_KEY, String(next));
      } catch {
        // ignore
      }
      return next;
    });
  }

  const allNames = allSources.map((s) => s.name);
  const sorted = [...allSources].sort((a, b) => (counts[b.name] ?? 0) - (counts[a.name] ?? 0));
  const enabledCount = allNames.length - disabledSources.length;

  return (
    <motion.aside
      animate={{ width: collapsed ? 52 : 268 }}
      transition={{ type: "spring", bounce: 0.15, duration: 0.45 }}
      className="sticky top-[72px] hidden max-h-[calc(100vh-92px)] shrink-0 self-start pt-2 lg:block z-30"
    >
      <div className="soft-glass flex max-h-[calc(100vh-104px)] flex-col overflow-hidden rounded-2xl border border-white/10 bg-[#12131a]/95">
        {/* Header Section */}
        <div className="flex items-center justify-between gap-2 border-b border-white/10 px-3.5 py-3">
          {!collapsed && (
            <div className="min-w-0">
              <div className="truncate text-xs font-bold text-white/95">Nguồn tin tức</div>
              <div className="text-[11px] text-white/50">
                {enabledCount}/{allNames.length} đang hoạt động
              </div>
            </div>
          )}
          <button
            onClick={toggleCollapsed}
            title={collapsed ? "Mở rộng danh sách nguồn" : "Thu gọn danh sách nguồn"}
            className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border border-white/10 bg-white/5 text-white/70 transition-colors hover:bg-white/15 hover:text-white"
          >
            <ChevronIcon pointsLeft={!collapsed} />
          </button>
        </div>

        {!collapsed && (
          <>
            {/* Quick Actions Bar */}
            <div className="flex flex-col gap-2 border-b border-white/10 px-3 py-2.5">
              <button
                onClick={onOpenAddSource}
                className="flex w-full items-center justify-center gap-1.5 rounded-xl border border-blue-500/40 bg-blue-500/15 py-1.5 text-xs font-bold text-blue-300 transition-all hover:bg-blue-500/25 active:scale-98 shadow-sm"
              >
                <span>+ Thêm nguồn RSS</span>
              </button>

              <div className="flex justify-between px-1">
                <button
                  onClick={() => onSetAll(true, allNames)}
                  className="rounded-md px-2 py-0.5 text-[11px] font-medium text-white/60 hover:bg-white/10 hover:text-white"
                >
                  Chọn tất cả
                </button>
                <button
                  onClick={() => onSetAll(false, allNames)}
                  className="rounded-md px-2 py-0.5 text-[11px] font-medium text-white/60 hover:bg-white/10 hover:text-white"
                >
                  Bỏ chọn tất cả
                </button>
              </div>
            </div>

            {/* Source Items List */}
            <div className="flex-1 overflow-y-auto py-1.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              {sorted.map((feed) => {
                const enabled = !disabledSources.includes(feed.name);
                const isCustom = !!feed.isCustom;

                return (
                  <div
                    key={feed.name}
                    className="group flex w-full items-center gap-2 px-3 py-1.5 hover:bg-white/5 transition-colors"
                  >
                    <button
                      onClick={() => onToggleSource(feed.name)}
                      className="flex flex-1 items-center gap-2.5 min-w-0 text-left"
                    >
                      <span
                        className={`flex h-4 w-4 shrink-0 items-center justify-center rounded-[5px] border transition-colors ${
                          enabled
                            ? "border-blue-500 bg-blue-600 text-white"
                            : "border-white/20 text-transparent"
                        }`}
                      >
                        <CheckIcon />
                      </span>
                      <span
                        className={`min-w-0 flex-1 truncate text-xs transition-colors ${
                          enabled ? "text-white/90 font-medium" : "text-white/40"
                        }`}
                      >
                        {feed.name}
                        {isCustom && (
                          <span className="ml-1.5 rounded-full bg-blue-500/20 px-1.5 py-0.2 text-[9px] font-semibold text-blue-300">
                            Custom
                          </span>
                        )}
                      </span>
                      <span className={`text-[11px] tabular-nums ${enabled ? "text-white/50" : "text-white/20"}`}>
                        {counts[feed.name] ?? 0}
                      </span>
                    </button>

                    {isCustom && (
                      <button
                        onClick={() => onRemoveCustomSource(feed.name)}
                        title="Xóa nguồn tùy chỉnh"
                        className="opacity-0 group-hover:opacity-100 p-1 text-white/40 hover:text-red-400 transition-opacity"
                      >
                        <TrashIcon />
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          </>
        )}
      </div>
    </motion.aside>
  );
}
