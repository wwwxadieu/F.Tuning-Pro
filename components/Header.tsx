"use client";

import { motion, useScroll, useTransform } from "framer-motion";
import type { UseNewsResult } from "@/hooks/useNews";

function BellIcon({ ringing }: { ringing: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className={`h-5 w-5 ${ringing ? "animate-wiggle" : ""}`}
    >
      <path
        d="M12 3a5 5 0 0 0-5 5v3.3c0 .7-.25 1.37-.7 1.9L5 15h14l-1.3-1.8a3 3 0 0 1-.7-1.9V8a5 5 0 0 0-5-5Z"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinejoin="round"
      />
      <path
        d="M9.5 18a2.5 2.5 0 0 0 5 0"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function Header({ news }: { news: UseNewsResult }) {
  const { scrollY } = useScroll();
  const bgOpacity = useTransform(scrollY, [0, 120], [0, 1]);

  const {
    notificationsEnabled,
    notificationPermission,
    toggleNotifications,
    newCount,
    clearNewCount,
    lastFetchedAt,
  } = news;

  return (
    <motion.header className="fixed inset-x-0 top-0 z-50">
      <motion.div
        className="absolute inset-0 border-b border-hair"
        style={{ opacity: bgOpacity, backdropFilter: "blur(20px) saturate(180%)" }}
      />
      <motion.div
        className="absolute inset-0 -z-10"
        style={{ backgroundColor: "#0a0a0c", opacity: bgOpacity }}
      />
      <nav className="relative mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <div className="flex items-center gap-2">
          <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-gradient-to-br from-accent to-accent2 text-sm font-bold text-white">
            T
          </span>
          <span className="text-[15px] font-semibold tracking-tight">TechWave</span>
        </div>

        <div className="flex items-center gap-4">
          {lastFetchedAt && (
            <span className="hidden text-xs text-white/40 sm:block">
              Cập nhật{" "}
              {new Date(lastFetchedAt).toLocaleTimeString("vi-VN", {
                hour: "2-digit",
                minute: "2-digit",
              })}
            </span>
          )}

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
            className={`relative flex h-9 w-9 items-center justify-center rounded-full border transition-all ${
              notificationsEnabled
                ? "border-accent/40 bg-accent/15 text-accent"
                : "border-hair bg-white/5 text-white/70 hover:bg-white/10"
            } disabled:opacity-30`}
          >
            <BellIcon ringing={newCount > 0} />
            {newCount > 0 && (
              <span className="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-accent2 px-1 text-[10px] font-bold text-white">
                {newCount > 9 ? "9+" : newCount}
              </span>
            )}
          </button>
        </div>
      </nav>
    </motion.header>
  );
}
