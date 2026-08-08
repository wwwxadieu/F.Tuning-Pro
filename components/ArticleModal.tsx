"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import type { Article } from "@/lib/types";

export function ArticleModal({
  article,
  onClose,
}: {
  article: Article | null;
  onClose: () => void;
}) {
  const [loading, setLoading] = useState(false);
  const [fullContent, setFullContent] = useState<string | null>(null);
  const [fetchError, setFetchError] = useState<string | null>(null);

  useEffect(() => {
    if (!article) {
      setFullContent(null);
      setFetchError(null);
      return;
    }

    let isMounted = true;
    async function loadArticle() {
      if (!article) return;
      setLoading(true);
      setFetchError(null);
      setFullContent(null);

      try {
        const res = await fetch(`/api/article?url=${encodeURIComponent(article.link)}`);
        const data = await res.json();

        if (isMounted) {
          if (res.ok && data.ok && data.content) {
            setFullContent(data.content);
          } else {
            setFetchError(data.error || "Không thể tải toàn bộ nội dung bài viết. Đây là bản tóm tắt.");
          }
        }
      } catch (err) {
        if (isMounted) {
          setFetchError("Lỗi kết nối mạng. Đây là bản tóm tắt.");
        }
      } finally {
        if (isMounted) setLoading(false);
      }
    }

    loadArticle();

    return () => {
      isMounted = false;
    };
  }, [article]);

  if (!article) return null;

  function handleRetry() {
    if (!article) return;
    setLoading(true);
    setFetchError(null);
    fetch(`/api/article?url=${encodeURIComponent(article.link)}`)
      .then((res) => res.json())
      .then((data) => {
        if (data.ok && data.content) {
          setFullContent(data.content);
        } else {
          setFetchError(data.error || "Không thể tải toàn bộ nội dung bài viết. Đây là bản tóm tắt.");
        }
      })
      .catch(() => setFetchError("Lỗi kết nối mạng. Đây là bản tóm tắt."))
      .finally(() => setLoading(false));
  }

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[100] flex items-center justify-center p-3 sm:p-6 overflow-y-auto">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
          className="fixed inset-0 bg-black/85 backdrop-blur-lg"
        />

        {/* Modal Container */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          className="soft-glass relative z-10 my-auto flex max-h-[90vh] w-full max-w-4xl flex-col overflow-hidden rounded-3xl border border-white/15 bg-[#0f1015] text-white shadow-2xl"
        >
          {/* Header Bar */}
          <div className="sticky top-0 z-20 flex items-center justify-between border-b border-white/10 bg-[#0f1015]/90 px-6 py-4 backdrop-blur-md">
            <div className="flex items-center gap-3">
              <span className="rounded-full bg-white/10 px-3 py-1 text-xs font-semibold text-white/80">
                {article.source}
              </span>
              {article.translated && (
                <span className="rounded-full border border-white/15 px-2.5 py-0.5 text-[11px] font-medium text-white/50">
                  Đã dịch sang Tiếng Việt
                </span>
              )}
            </div>
            <div className="flex items-center gap-2">
              <a
                href={article.link}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-1.5 rounded-xl border border-white/15 bg-white/5 px-3.5 py-1.5 text-xs font-semibold text-white/80 transition-colors hover:bg-white/15 hover:text-white"
              >
                Mở trang gốc ↗
              </a>
              <button
                onClick={onClose}
                className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 text-white/60 transition-colors hover:bg-white/20 hover:text-white"
              >
                ✕
              </button>
            </div>
          </div>

          {/* Content Body */}
          <div className="flex-1 overflow-y-auto px-6 py-6 sm:px-10 sm:py-8">
            {/* Article Image Header */}
            {article.image ? (
              <div className="mb-6 overflow-hidden rounded-2xl border border-white/10 bg-black/40 max-h-[380px]">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={article.image}
                  alt={article.title}
                  className="h-full w-full object-cover max-h-[380px]"
                />
              </div>
            ) : null}

            {/* Title */}
            <h1 className="text-2xl font-bold leading-tight text-white/95 sm:text-3xl">
              {article.title}
            </h1>

            {/* Date & Tags */}
            <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-white/50 border-b border-white/10 pb-5">
              <span>{article.source}</span>
              <span>•</span>
              <span>{new Date(article.publishedAt).toLocaleString("vi-VN")}</span>
              <div className="ml-auto flex gap-1.5">
                {article.tags.map((t) => (
                  <span key={t} className="rounded-full bg-white/10 px-2.5 py-0.5 text-[11px] text-white/70">
                    {t}
                  </span>
                ))}
              </div>
            </div>

            {/* Loading Indicator */}
            {loading && (
              <div className="my-10 flex flex-col items-center justify-center gap-3 text-white/50">
                <svg className="h-7 w-7 animate-spin text-accent" viewBox="0 0 24 24" fill="none">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                </svg>
                <p className="text-sm">Đang tải nội dung chi tiết bài viết...</p>
              </div>
            )}

            {/* Main Full Article Content */}
            {!loading && fullContent && (
              <div
                className="prose prose-invert max-w-none my-6 text-white/85 leading-relaxed [&>p]:mb-4 [&>p]:text-[15px] [&>h2]:text-xl [&>h2]:font-bold [&>h2]:mt-6 [&>h2]:mb-3 [&>img]:rounded-xl [&>img]:my-4"
                dangerouslySetInnerHTML={{ __html: fullContent }}
              />
            )}

            {/* Fallback Banner & Summary (Resolves Image 1 issue) */}
            {!loading && (!fullContent || fetchError) && (
              <div className="my-6 space-y-6">
                <div className="rounded-2xl border border-white/15 bg-white/5 p-5">
                  <p className="text-sm text-white/70">
                    Không thể tải toàn bộ nội dung bài viết. Đây là bản tóm tắt.
                  </p>
                  <div className="mt-4 flex flex-wrap gap-3">
                    <button
                      onClick={handleRetry}
                      className="flex items-center gap-1.5 rounded-xl border border-white/20 bg-white/10 px-4 py-2 text-xs font-semibold text-white transition-colors hover:bg-white/20"
                    >
                      Thử lại ↻
                    </button>
                    <a
                      href={article.link}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-1.5 rounded-xl bg-white px-4 py-2 text-xs font-bold text-black transition-colors hover:bg-white/90"
                    >
                      Mở bản gốc ↗
                    </a>
                  </div>
                </div>

                {article.summary && (
                  <div className="rounded-2xl border border-white/10 bg-black/40 p-6">
                    <h3 className="mb-3 text-sm font-semibold text-white/90">Tóm tắt nội dung:</h3>
                    <p className="text-base leading-relaxed text-white/80">{article.summary}</p>
                  </div>
                )}
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
