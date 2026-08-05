"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Article, NewsResponse, Tag } from "@/lib/types";

const POLL_INTERVAL_MS = 3 * 60 * 1000;
const SEEN_IDS_KEY = "techwave:seen-ids";
const NOTIF_PREF_KEY = "techwave:notifications-enabled";
// Stores the sources the user switched OFF, not the ones left on: that way a
// feed added in a later release shows up for existing users instead of being
// silently filtered out because it wasn't in their saved list.
const DISABLED_SOURCES_KEY = "techwave:disabled-sources";
const MAX_STORED_IDS = 400;

function loadSeenIds(): Set<string> {
  if (typeof window === "undefined") return new Set();
  try {
    const raw = window.localStorage.getItem(SEEN_IDS_KEY);
    return raw ? new Set(JSON.parse(raw)) : new Set();
  } catch {
    return new Set();
  }
}

function saveSeenIds(ids: Set<string>) {
  try {
    const trimmed = Array.from(ids).slice(-MAX_STORED_IDS);
    window.localStorage.setItem(SEEN_IDS_KEY, JSON.stringify(trimmed));
  } catch {
    // ignore quota errors
  }
}

function loadDisabledSources(): string[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(DISABLED_SOURCES_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed.filter((v) => typeof v === "string") : [];
  } catch {
    return [];
  }
}

function saveDisabledSources(sources: string[]) {
  try {
    window.localStorage.setItem(DISABLED_SOURCES_KEY, JSON.stringify(sources));
  } catch {
    // ignore quota errors
  }
}

export interface UseNewsResult {
  articles: Article[];
  filteredArticles: Article[];
  loading: boolean;
  error: string | null;
  selectedTag: Tag | null;
  setSelectedTag: (tag: Tag | null) => void;
  disabledSources: string[];
  toggleSource: (name: string) => void;
  setAllSourcesEnabled: (enabled: boolean, allSources: string[]) => void;
  lastFetchedAt: string | null;
  newCount: number;
  clearNewCount: () => void;
  notificationsEnabled: boolean;
  notificationPermission: NotificationPermission | "unsupported";
  toggleNotifications: () => Promise<void>;
  refresh: () => void;
}

export function useNews(): UseNewsResult {
  const [articles, setArticles] = useState<Article[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedTag, setSelectedTag] = useState<Tag | null>(null);
  const [disabledSources, setDisabledSources] = useState<string[]>([]);
  const [lastFetchedAt, setLastFetchedAt] = useState<string | null>(null);
  const [newCount, setNewCount] = useState(0);
  const [notificationsEnabled, setNotificationsEnabled] = useState(false);
  const [notificationPermission, setNotificationPermission] = useState<
    NotificationPermission | "unsupported"
  >("default");

  const seenIdsRef = useRef<Set<string>>(new Set());
  const isFirstLoadRef = useRef(true);

  useEffect(() => {
    seenIdsRef.current = loadSeenIds();
    isFirstLoadRef.current = seenIdsRef.current.size === 0;
    setDisabledSources(loadDisabledSources());

    if (typeof window !== "undefined" && "Notification" in window) {
      setNotificationPermission(Notification.permission);
      const pref = window.localStorage.getItem(NOTIF_PREF_KEY) === "true";
      setNotificationsEnabled(pref && Notification.permission === "granted");
    } else {
      setNotificationPermission("unsupported");
    }
  }, []);

  const fetchNews = useCallback(async () => {
    try {
      setError(null);
      const res = await fetch("/api/news", { cache: "no-store" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: NewsResponse = await res.json();

      const freshIds = data.articles
        .map((a) => a.id)
        .filter((id) => !seenIdsRef.current.has(id));

      if (!isFirstLoadRef.current && freshIds.length > 0) {
        setNewCount((n) => n + freshIds.length);

        if (
          notificationsEnabled &&
          typeof window !== "undefined" &&
          "Notification" in window &&
          Notification.permission === "granted"
        ) {
          const freshArticles = data.articles.filter((a) => freshIds.includes(a.id));
          const headline = freshArticles[0];
          const body =
            freshArticles.length === 1
              ? headline.title
              : `${headline.title} +${freshArticles.length - 1} tin khác`;
          const notif = new Notification("TechWave · Tin mới", {
            body,
            tag: "techwave-news",
          });
          notif.onclick = () => {
            window.focus();
            window.open(headline.link, "_blank");
          };
        }
      }

      data.articles.forEach((a) => seenIdsRef.current.add(a.id));
      saveSeenIds(seenIdsRef.current);
      isFirstLoadRef.current = false;

      setArticles(data.articles);
      setLastFetchedAt(data.fetchedAt);
    } catch (err) {
      setError((err as Error).message || "Không thể tải tin tức");
    } finally {
      setLoading(false);
    }
  }, [notificationsEnabled]);

  useEffect(() => {
    fetchNews();
    const interval = setInterval(fetchNews, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [fetchNews]);

  const toggleNotifications = useCallback(async () => {
    if (typeof window === "undefined" || !("Notification" in window)) return;

    if (notificationsEnabled) {
      setNotificationsEnabled(false);
      window.localStorage.setItem(NOTIF_PREF_KEY, "false");
      return;
    }

    let permission = Notification.permission;
    if (permission === "default") {
      permission = await Notification.requestPermission();
      setNotificationPermission(permission);
    }
    if (permission === "granted") {
      setNotificationsEnabled(true);
      window.localStorage.setItem(NOTIF_PREF_KEY, "true");
      new Notification("TechWave", {
        body: "Bạn sẽ nhận thông báo khi có tin công nghệ mới.",
        tag: "techwave-news",
      });
    }
  }, [notificationsEnabled]);

  const toggleSource = useCallback((name: string) => {
    setDisabledSources((prev) => {
      const next = prev.includes(name) ? prev.filter((s) => s !== name) : [...prev, name];
      saveDisabledSources(next);
      return next;
    });
  }, []);

  const setAllSourcesEnabled = useCallback((enabled: boolean, allSources: string[]) => {
    const next = enabled ? [] : [...allSources];
    saveDisabledSources(next);
    setDisabledSources(next);
  }, []);

  const filteredArticles = articles.filter(
    (a) =>
      (selectedTag === null || a.tags.includes(selectedTag)) &&
      !disabledSources.includes(a.source)
  );

  return {
    articles,
    filteredArticles,
    loading,
    error,
    selectedTag,
    setSelectedTag,
    disabledSources,
    toggleSource,
    setAllSourcesEnabled,
    lastFetchedAt,
    newCount,
    clearNewCount: () => setNewCount(0),
    notificationsEnabled,
    notificationPermission,
    toggleNotifications,
    refresh: fetchNews,
  };
}
