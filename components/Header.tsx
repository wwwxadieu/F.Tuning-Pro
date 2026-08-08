"use client";

import { useEffect, useState } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import type { UseNewsResult } from "@/hooks/useNews";

function BellIcon({ ringing }: { ringing: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className={`h-4.5 w-4.5 ${ringing ? "animate-bounce text-yellow-400" : ""}`}
    >
      <path
        d="M12 3a5 5 0 0 0-5 5v3.3c0 .7-.25 1.37-.7 1.9L5 15h14l-1.3-1.8a3 3 0 0 1-.7-1.9V8a5 5 0 0 0-5-5Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
      <path
        d="M9.5 18a2.5 2.5 0 0 0 5 0"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

function RefreshIcon({ refreshing }: { refreshing: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className={`h-4.5 w-4.5 ${refreshing ? "animate-spin text-blue-400" : ""}`}
    >
      <path
        d="M4 12a8 8 0 0114.93-4M20 12a8 8 0 01-14.93 4"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <path
        d="M20 4v4h-4M4 20v-4h4"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function Header({
  news,
  onOpenAddSource,
}: {
  news: UseNewsResult;
  onOpenAddSource?: () => void;
}) {
  const { scrollY } = useScroll();
  const bgOpacity = useTransform(scrollY, [0, 80], [0.85, 0.98]);
  const [formattedTime, setFormattedTime] = useState("");

  const {
    notificationsEnabled,
    notificationPermission,
    toggleNotifications,
    newCount,
    clearNewCount,
    lastFetchedAt,
    refresh,
    loading,
  } = news;

  useEffect(() => {
    function updateClock() {
      const now = new Date();
      const days = ["CN", "Th 2", "Th 3", "Th 4", "Th 5", "Th 6", "Th 7"];
      const dayName = days[now.getDay()];
      const dd = String(now.getDate()).padStart(2, "0");
      const mm = String(now.getMonth() + 1).padStart(2, "0");
      const hh = String(now.getHours()).padStart(2, "0");
      const min = String(now.getMinutes()).padStart(2, "0");
      setFormattedTime(`${dayName}, ${dd}/${mm} · ${hh}:${min}`);
    }

    updateClock();
    const timer = setInterval(updateClock, 30000);
    return () => clearInterval(timer);
  }, []);

  return (
    <motion.header className="fixed inset-x-0 top-0 z-50">
      {/* Dark Soft Glass Header Container */}
      <motion.div
        className="absolute inset-0 border-b border-white/10 bg-[#0a0a0c]/90 backdrop-blur-2xl shadow-lg"
        style={{ opacity: bgOpacity }}
      />

      <nav className="relative mx-auto flex max-w-[1400px] items-center justify-between px-4 sm:px-6 py-3.5">
        {/* Left Side: Brand Logo & Title */}
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-tr from-blue-600 via-indigo-500 to-purple-500 font-extrabold text-white text-base shadow-md shadow-blue-500/20">
            F
          </div>
          <div className="flex flex-col">
            <span className="text-base font-bold tracking-tight text-white drop-shadow-sm">
              F.VNN <span className="text-xs font-semibold text-blue-400">TechWave</span>
            </span>
          </div>
        </div>

        {/* Middle: Live Clock & Live Updates Badge */}
        <div className="hidden items-center gap-2.5 md:flex">
          <div className="flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3.5 py-1 text-xs font-semibold text-white/90 backdrop-blur-md">
            <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse" />
            <span>{formattedTime || "Đang cập nhật..."}</span>
          </div>

          <div className="flex items-center gap-1.5 rounded-full border border-blue-500/30 bg-blue-500/15 px-3 py-1 text-xs font-semibold text-blue-300">
            <span>Cập nhật trực tiếp</span>
          </div>
        </div>

        {/* Right Side: Action Buttons */}
        <div className="flex items-center gap-2.5">
          {onOpenAddSource && (
            <button
              onClick={onOpenAddSource}
              className="flex items-center gap-1.5 rounded-xl border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-semibold text-white transition-all hover:bg-white/20 active:scale-95"
            >
              <span>+ Thêm nguồn</span>
            </button>
          )}

          <button
            onClick={() => refresh()}
            disabled={loading}
            title="Làm mới tin tức"
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-white/15 bg-white/10 text-white transition-all hover:bg-white/20 active:scale-95 disabled:opacity-50"
          >
            <RefreshIcon refreshing={loading} />
          </button>

          <button
            onClick={() => {
              clearNewCount();
              void toggleNotifications();
            }}
            disabled={notificationPermission === "unsupported"}
            title={
              notificationPermission === "unsupported"
                ? "Trình duyệt không hỗ trợ thông báo"
                : notificationsEnabled
                ? "Tắt thông báo tin mới"
                : "Bật thông báo tin mới"
            }
            className={`relative flex h-9 w-9 items-center justify-center rounded-xl border transition-all ${
              notificationsEnabled
                ? "border-amber-400/40 bg-amber-400/20 text-amber-300"
                : "border-white/15 bg-white/10 text-white hover:bg-white/20"
            } active:scale-95 disabled:opacity-30`}
          >
            <BellIcon ringing={newCount > 0} />
            {newCount > 0 && (
              <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold text-white shadow-sm">
                {newCount > 9 ? "9+" : newCount}
              </span>
            )}
          </button>
        </div>
      </nav>
    </motion.header>
  );
}
