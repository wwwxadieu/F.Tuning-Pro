"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { FEEDS } from "@/lib/feeds";

const COLLAPSED_KEY = "techwave:sidebar-collapsed";

// Driven by FEEDS rather than by the articles themselves: the API returns only
// the 80 most recent items, so a quiet source can legitimately contribute zero
// articles right now and would otherwise vanish from the list entirely.
const ALL_SOURCE_NAMES = FEEDS.map((f) => f.name);

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

export function SourceSidebar({
  counts,
  disabledSources,
  onToggleSource,
  onSetAll,
}: {
  counts: Record<string, number>;
  disabledSources: string[];
  onToggleSource: (name: string) => void;
  onSetAll: (enabled: boolean, allSources: string[]) => void;
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

  const sorted = [...FEEDS].sort((a, b) => (counts[b.name] ?? 0) - (counts[a.name] ?? 0));
  const enabledCount = ALL_SOURCE_NAMES.length - disabledSources.length;

  return (
    <motion.aside
      animate={{ width: collapsed ? 48 : 256 }}
      transition={{ type: "spring", bounce: 0.15, duration: 0.45 }}
      className="sticky top-[64px] hidden max-h-[calc(100vh-88px)] shrink-0 self-start pt-3 lg:block"
    >
      <div className="glass flex max-h-[calc(100vh-100px)] flex-col overflow-hidden rounded-2xl">
        <div className="flex items-center justify-between gap-2 border-b border-hair px-3 py-3">
          {!collapsed && (
            <div className="min-w-0">
              <div className="truncate text-[13px] font-semibold text-white/90">Nguồn tin</div>
              <div className="text-[11px] text-white/40">
                {enabledCount}/{ALL_SOURCE_NAMES.length} đang bật
              </div>
            </div>
          )}
          <button
            onClick={toggleCollapsed}
            title={collapsed ? "Mở rộng danh sách nguồn" : "Thu gọn danh sách nguồn"}
            aria-label={collapsed ? "Mở rộng danh sách nguồn" : "Thu gọn danh sách nguồn"}
            className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border border-hair bg-white/5 text-white/60 transition-colors hover:bg-white/10 hover:text-white"
          >
            <ChevronIcon pointsLeft={!collapsed} />
          </button>
        </div>

        {!collapsed && (
          <>
            <div className="flex gap-1.5 border-b border-hair px-3 py-2">
              <button
                onClick={() => onSetAll(true, ALL_SOURCE_NAMES)}
                className="rounded-md px-2 py-1 text-[11px] font-medium text-white/50 transition-colors hover:bg-white/5 hover:text-white/90"
              >
                Chọn tất cả
              </button>
              <button
                onClick={() => onSetAll(false, ALL_SOURCE_NAMES)}
                className="rounded-md px-2 py-1 text-[11px] font-medium text-white/50 transition-colors hover:bg-white/5 hover:text-white/90"
              >
                Bỏ chọn tất cả
              </button>
            </div>

            <div className="flex-1 overflow-y-auto py-1.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
              {sorted.map((feed) => {
                const enabled = !disabledSources.includes(feed.name);
                return (
                  <button
                    key={feed.name}
                    onClick={() => onToggleSource(feed.name)}
                    className="group flex w-full items-center gap-2.5 px-3 py-1.5 text-left transition-colors hover:bg-white/5"
                  >
                    <span
                      className={`flex h-4 w-4 shrink-0 items-center justify-center rounded-[5px] border transition-colors ${
                        enabled
                          ? "border-accent bg-accent text-white"
                          : "border-white/20 text-transparent"
                      }`}
                    >
                      <CheckIcon />
                    </span>
                    <span
                      className={`min-w-0 flex-1 truncate text-[13px] transition-colors ${
                        enabled ? "text-white/85" : "text-white/35"
                      }`}
                    >
                      {feed.name}
                    </span>
                    <span className={`text-[11px] tabular-nums ${enabled ? "text-white/40" : "text-white/20"}`}>
                      {counts[feed.name] ?? 0}
                    </span>
                  </button>
                );
              })}
            </div>
          </>
        )}
      </div>
    </motion.aside>
  );
}
