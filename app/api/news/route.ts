import { NextResponse } from "next/server";
import Parser from "rss-parser";
import { ProxyAgent, setGlobalDispatcher } from "undici";
import { FEEDS, inferTags, FeedSource } from "@/lib/feeds";
import { translateBatch } from "@/lib/translate";
import type { Article, CustomFeedSource, NewsResponse } from "@/lib/types";

export const runtime = "nodejs";
export const revalidate = 180;

const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;
if (proxyUrl) {
  setGlobalDispatcher(new ProxyAgent(proxyUrl));
}

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 TechWaveBot/1.0";

const parser = new Parser({
  timeout: 9000,
  headers: {
    "User-Agent": UA,
    Accept: "application/rss+xml, application/xml, text/xml, */*",
  },
  customFields: {
    item: [
      ["media:thumbnail", "media:thumbnail"],
      ["media:content", "media:content", { keepArray: true }],
      ["image", "image"],
      ["og:image", "ogImage"],
      ["content:encoded", "contentEncoded"],
    ],
  },
});

function stripHtml(html: string | undefined): string {
  if (!html) return "";
  return html
    .replace(/<script\b[^<]*>([\s\S]*?)<\/script>/gi, "")
    .replace(/<style\b[^<]*>([\s\S]*?)<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

function resolveUrl(baseUrl: string, relativeUrl: string | null): string | null {
  if (!relativeUrl) return null;
  const trimmed = relativeUrl.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith("data:")) return null;
  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed;
  try {
    const origin = new URL(baseUrl).origin;
    if (trimmed.startsWith("/")) return `${origin}${trimmed}`;
    return `${origin}/${trimmed}`;
  } catch {
    return trimmed;
  }
}

function extractImage(item: Parser.Item & Record<string, any>, feedUrl: string): string | null {
  if (item.enclosure?.url) return resolveUrl(feedUrl, item.enclosure.url);
  
  const mediaContent = item["media:content"];
  if (mediaContent?.$?.url) return resolveUrl(feedUrl, mediaContent.$.url);
  if (Array.isArray(mediaContent) && mediaContent[0]?.$?.url) {
    return resolveUrl(feedUrl, mediaContent[0].$.url);
  }

  const mediaThumb = item["media:thumbnail"];
  if (mediaThumb?.$?.url) return resolveUrl(feedUrl, mediaThumb.$.url);
  if (Array.isArray(mediaThumb) && mediaThumb[0]?.$?.url) {
    return resolveUrl(feedUrl, mediaThumb[0].$.url);
  }

  if (typeof item.ogImage === "string") return resolveUrl(feedUrl, item.ogImage);
  if (typeof item.image === "string" && item.image.trim()) return resolveUrl(feedUrl, item.image.trim());

  const html = item.contentEncoded || item["content:encoded"] || item.content || item.summary || item.description || "";
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  if (match && match[1]) return resolveUrl(feedUrl, match[1]);

  return null;
}

function parsePubDate(pubDateStr?: string): string {
  if (!pubDateStr) return new Date().toISOString();
  try {
    const date = new Date(pubDateStr);
    if (!isNaN(date.getTime())) return date.toISOString();
  } catch {
    // fallback
  }
  return new Date().toISOString();
}

async function fetchFeed(feed: FeedSource | CustomFeedSource): Promise<Article[]> {
  try {
    const res = await fetch(feed.url, {
      headers: {
        "User-Agent": UA,
        Accept: "application/rss+xml, application/xml, text/xml, */*",
      },
      next: { revalidate: 180 },
      signal: AbortSignal.timeout(9000),
    });
    if (!res.ok) return [];
    const xml = await res.text();
    const parsed = await parser.parseString(xml);
    const baseTags = feed.baseTags || ["Big Tech"];
    const isVi = feed.lang === "vi" || /[àáảãạâầấẩẫậăằắẳẵặèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]/i.test(xml);
    const lang = isVi ? "vi" : "en";

    return (parsed.items || []).slice(0, 25).map((item: any) => {
      const summary = stripHtml(item.contentSnippet || item.summary || item.content || item.description);
      const title = stripHtml(item.title) || "Untitled";
      const trimmedSummary = summary.length > 280 ? `${summary.slice(0, 280)}…` : summary;
      const publishedAt = parsePubDate(item.isoDate || item.pubDate);

      return {
        id: item.guid || item.link || `${feed.name}-${title}-${publishedAt}`,
        title,
        link: item.link || "#",
        source: feed.name,
        summary: trimmedSummary,
        image: extractImage(item as any, feed.url),
        tags: inferTags(baseTags, title, summary),
        publishedAt,
        lang,
        translated: false,
        isCustomSource: !!feed.isCustom,
      } satisfies Article;
    });
  } catch (err) {
    console.error(`[news] failed to fetch ${feed.name}:`, (err as Error).message);
    return [];
  }
}

async function processArticles(allFeeds: (FeedSource | CustomFeedSource)[]): Promise<Article[]> {
  const results = await Promise.allSettled(allFeeds.map(fetchFeed));
  const articlesMap = new Map<string, Article>();

  for (const r of results) {
    if (r.status === "fulfilled") {
      for (const article of r.value) {
        if (!articlesMap.has(article.id)) {
          articlesMap.set(article.id, article);
        }
      }
    }
  }

  const nowMs = Date.now();
  // Keep articles up to 14 days old to filter out ancient stale articles (e.g. from 2025)
  const fourteenDaysMs = 14 * 24 * 60 * 60 * 1000;

  const validArticles = Array.from(articlesMap.values()).filter((a) => {
    const pubTime = new Date(a.publishedAt).getTime();
    if (isNaN(pubTime)) return false;
    // Don't exclude if it's less than 14 days old, or if we have too few articles
    return nowMs - pubTime <= fourteenDaysMs;
  });

  const sorted = validArticles.sort(
    (a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime()
  );

  // Take top 250 articles for rich diversity across sources & tags
  const top = sorted.slice(0, 250);
  const toTranslate = top.filter((a) => a.lang === "en");
  const translations = await translateBatch(toTranslate);

  let cursor = 0;
  return top.map((article) => {
    if (article.lang !== "en") return article;
    const result = translations[cursor++];
    if (!result || !result.ok) return article;
    return {
      ...article,
      title: result.title,
      summary: result.summary,
      originalTitle: article.title,
      originalSummary: article.summary,
      translated: true,
    } satisfies Article;
  });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const customSourcesParam = searchParams.get("customSources");

  let customFeeds: CustomFeedSource[] = [];
  if (customSourcesParam) {
    try {
      const parsed = JSON.parse(customSourcesParam);
      if (Array.isArray(parsed)) {
        customFeeds = parsed.map((c) => ({
          name: String(c.name || "Custom Source"),
          url: String(c.url),
          baseTags: Array.isArray(c.baseTags) ? c.baseTags : ["Big Tech"],
          lang: c.lang || "vi",
          isCustom: true,
        }));
      }
    } catch {
      // ignore JSON parse error
    }
  }

  const allFeeds = [...FEEDS, ...customFeeds];
  const articles = await processArticles(allFeeds);

  const payload: NewsResponse = {
    articles,
    fetchedAt: new Date().toISOString(),
  };

  return NextResponse.json(payload, {
    headers: { "Cache-Control": "s-maxage=180, stale-while-revalidate=300" },
  });
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const customSources: CustomFeedSource[] = Array.isArray(body.customSources)
      ? body.customSources
      : [];

    const allFeeds = [...FEEDS, ...customSources];
    const articles = await processArticles(allFeeds);

    const payload: NewsResponse = {
      articles,
      fetchedAt: new Date().toISOString(),
    };

    return NextResponse.json(payload);
  } catch {
    const articles = await processArticles(FEEDS);
    return NextResponse.json({
      articles,
      fetchedAt: new Date().toISOString(),
    });
  }
}
