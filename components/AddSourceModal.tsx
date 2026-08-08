"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import type { CustomFeedSource } from "@/lib/types";

export function AddSourceModal({
  isOpen,
  onClose,
  onAddSource,
}: {
  isOpen: boolean;
  onClose: () => void;
  onAddSource: (source: CustomFeedSource) => void;
}) {
  const [urlInput, setUrlInput] = useState("");
  const [nameInput, setNameInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const query = urlInput.trim();
    if (!query) {
      setError("Vui lòng nhập tên miền hoặc địa chỉ RSS.");
      return;
    }

    setLoading(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const res = await fetch(`/api/feed-discover?query=${encodeURIComponent(query)}`);
      const data = await res.json();

      if (!res.ok || !data.ok) {
        throw new Error(data.error || "Không tìm thấy nguồn tin RSS từ đường dẫn này.");
      }

      const feed = data.feed;
      const customSource: CustomFeedSource = {
        name: nameInput.trim() || feed.name || query.replace(/^https?:\/\//, "").split("/")[0],
        url: feed.url,
        baseTags: ["Big Tech"],
        lang: "vi",
        isCustom: true,
      };

      onAddSource(customSource);
      setSuccessMsg(`Đã thêm nguồn "${customSource.name}" thành công!`);

      setTimeout(() => {
        setUrlInput("");
        setNameInput("");
        setSuccessMsg(null);
        onClose();
      }, 1000);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6">
        {/* Dim Overlay */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
          className="fixed inset-0 bg-black/80 backdrop-blur-md"
        />

        {/* Soft Glass Modal Box */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 15 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 15 }}
          className="soft-glass relative z-10 w-full max-w-md overflow-hidden rounded-3xl p-6 sm:p-7 text-white"
        >
          <div className="flex items-center justify-between border-b border-white/10 pb-4">
            <h3 className="text-lg font-bold tracking-tight text-white/95">Thêm nguồn tin nhanh</h3>
            <button
              onClick={onClose}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-white/60 transition-colors hover:bg-white/20 hover:text-white"
            >
              ✕
            </button>
          </div>

          <form onSubmit={handleSubmit} className="mt-5 space-y-4">
            <div>
              <label className="mb-1.5 block text-xs font-semibold text-white/70">
                Tên miền hoặc URL (Ví dụ: 9to5mac.com, vnexpress.net)
              </label>
              <input
                type="text"
                value={urlInput}
                onChange={(e) => setUrlInput(e.target.value)}
                placeholder="Ví dụ: 9to5mac.com"
                className="w-full rounded-xl border border-white/15 bg-black/60 px-4 py-3 text-sm text-white placeholder-white/35 outline-none transition-all focus:border-accent focus:ring-2 focus:ring-accent/30"
              />
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-semibold text-white/70">
                Tên nguồn hiển thị (Không bắt buộc)
              </label>
              <input
                type="text"
                value={nameInput}
                onChange={(e) => setNameInput(e.target.value)}
                placeholder="Tự động lấy nếu để trống"
                className="w-full rounded-xl border border-white/15 bg-black/60 px-4 py-3 text-sm text-white placeholder-white/35 outline-none transition-all focus:border-accent focus:ring-2 focus:ring-accent/30"
              />
            </div>

            {error && (
              <div className="flex items-center gap-2.5 rounded-xl border border-red-500/30 bg-red-500/15 p-3.5 text-xs font-medium text-red-300">
                <span className="shrink-0 text-base">⚠️</span>
                <span>{error}</span>
              </div>
            )}

            {successMsg && (
              <div className="flex items-center gap-2.5 rounded-xl border border-emerald-500/30 bg-emerald-500/15 p-3.5 text-xs font-medium text-emerald-300">
                <span className="shrink-0 text-base">✅</span>
                <span>{successMsg}</span>
              </div>
            )}

            <div className="pt-2">
              <button
                type="submit"
                disabled={loading}
                className="flex w-full items-center justify-center gap-2 rounded-xl bg-white px-5 py-3 text-sm font-bold text-black transition-all hover:bg-white/90 active:scale-[0.98] disabled:opacity-50"
              >
                {loading ? (
                  <>
                    <svg className="h-4 w-4 animate-spin text-black" viewBox="0 0 24 24" fill="none">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                    </svg>
                    Đang tìm nguồn RSS...
                  </>
                ) : (
                  <>+ Thêm nguồn</>
                )}
              </button>
            </div>
          </form>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
