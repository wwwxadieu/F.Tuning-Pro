import { NextResponse } from "next/server";
import Parser from "rss-parser";
import { ProxyAgent, setGlobalDispatcher } from "undici";
import { FEEDS, inferTags } from "@/lib/feeds";
import { translateBatch } from "@/lib/translate";
import type { Article, NewsResponse } from "@/lib/types";

export const runtime = "nodejs";
export const revalidate = 300;

const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;
if (proxyUrl) {
  setGlobalDispatcher(new ProxyAgent(proxyUrl));
}

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 TechWaveBot/1.0";

const parser = new Parser({
  timeout: 9000,
  headers: { "User-Agent": UA },
});

function stripHtml(html: string | undefined): string {
  if (!html) return "";
  return html
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function extractImage(item: Parser.Item & Record<string, any>): string | null {
  if (item.enclosure?.url) return item.enclosure.url;
  const mediaContent = item["media:content"];
  if (mediaContent?.$?.url) return mediaContent.$.url;
  if (Array.isArray(mediaContent) && mediaContent[0]?.$?.url) return mediaContent[0].$.url;
  const mediaThumb = item["media:thumbnail"];
  if (mediaThumb?.$?.url) return mediaThumb.$.url;
  const html = item["content:encoded"] || item.content || "";
  const match = html.match(/<img[^>]+src="([^"]+)"/i);
  return match ? match[1] : null;
}

async function fetchFeed(feed: (typeof FEEDS)[number]): Promise<Article[]> {
  try {
    const res = await fetch(feed.url, {
      headers: { "User-Agent": UA },
      next: { revalidate: 300 },
      signal: AbortSignal.timeout(9000),
    });
    if (!res.ok) return [];
    const xml = await res.text();
    const parsed = await parser.parseString(xml);
    return (parsed.items || []).slice(0, 15).map((item) => {
      const summary = stripHtml(item.contentSnippet || item.content || item.summary);
      const title = item.title || "Untitled";
      const trimmedSummary = summary.length > 200 ? `${summary.slice(0, 200)}…` : summary;
      return {
        id: item.guid || item.link || `${feed.name}-${title}`,
        title,
        link: item.link || "#",
        source: feed.name,
        summary: trimmedSummary,
        image: extractImage(item as any),
        tags: inferTags(feed.baseTags, title, summary),
        publishedAt: item.isoDate || item.pubDate || new Date().toISOString(),
        lang: feed.lang,
        translated: false,
      } satisfies Article;
    });
  } catch (err) {
    console.error(`[news] failed to fetch ${feed.name}:`, (err as Error).message);
    return [];
  }
}

export async function GET() {
  const results = await Promise.allSettled(FEEDS.map(fetchFeed));
  const articles = results
    .flatMap((r) => (r.status === "fulfilled" ? r.value : []))
    .reduce<Map<string, Article>>((map, article) => {
      if (!map.has(article.id)) map.set(article.id, article);
      return map;
    }, new Map())
    .values();

  const sorted = Array.from(articles).sort(
    (a, b) => new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime()
  );

  const top = sorted.slice(0, 80);
  const toTranslate = top.filter((a) => a.lang === "en");
  const translations = await translateBatch(toTranslate);

  let cursor = 0;
  const translated = top.map((article) => {
    if (article.lang !== "en") return article;
    const result = translations[cursor++];
    if (!result.ok) return article;
    return {
      ...article,
      title: result.title,
      summary: result.summary,
      originalTitle: article.title,
      originalSummary: article.summary,
      translated: true,
    } satisfies Article;
  });

  const payload: NewsResponse = {
    articles: translated,
    fetchedAt: new Date().toISOString(),
  };

  return NextResponse.json(payload, {
    headers: { "Cache-Control": "s-maxage=300, stale-while-revalidate=600" },
  });
}
