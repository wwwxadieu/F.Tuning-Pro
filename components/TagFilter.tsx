"use client";

import { motion } from "framer-motion";
import { ALL_TAGS } from "@/lib/feeds";
import { tagGradientClass } from "@/lib/tagStyle";
import type { Tag } from "@/lib/types";

export function TagFilter({
  selectedTag,
  onSelect,
  counts,
}: {
  selectedTag: Tag | null;
  onSelect: (tag: Tag | null) => void;
  counts: Record<string, number>;
}) {
  return (
    <div className="sticky top-[64px] z-40 border-b border-hair bg-ink/70 py-3 backdrop-blur-xl">
      <div className="flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        <Pill
          label="Tất cả"
          active={selectedTag === null}
          count={counts.__all__}
          onClick={() => onSelect(null)}
        />
        {ALL_TAGS.map((tag) => (
          <Pill
            key={tag}
            label={tag}
            active={selectedTag === tag}
            count={counts[tag] ?? 0}
            gradientClass={tagGradientClass(tag)}
            onClick={() => onSelect(tag)}
          />
        ))}
      </div>
    </div>
  );
}

function Pill({
  label,
  active,
  count,
  gradientClass,
  onClick,
}: {
  label: string;
  active: boolean;
  count?: number;
  gradientClass?: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="relative shrink-0 rounded-full border border-hair px-4 py-1.5 text-sm font-medium text-white/70 transition-colors hover:text-white"
    >
      {active && (
        <motion.span
          layoutId="tag-pill-active"
          transition={{ type: "spring", bounce: 0.2, duration: 0.5 }}
          className={`absolute inset-0 rounded-full ${gradientClass ?? "bg-white/15"}`}
        />
      )}
      <span className={`relative z-10 flex items-center gap-1.5 ${active ? "text-white" : ""}`}>
        {label}
        {typeof count === "number" && (
          <span className="text-xs opacity-60">{count}</span>
        )}
      </span>
    </button>
  );
}
