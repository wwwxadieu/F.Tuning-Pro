import { NextResponse } from "next/server";
import Parser from "rss-parser";

export const runtime = "nodejs";

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 TechWaveDiscover/1.0";

const parser = new Parser({
  timeout: 6000,
  headers: { "User-Agent": UA },
});

async function testRssUrl(url: string): Promise<{ name: string; url: string; title?: string } | null> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": UA, Accept: "application/rss+xml, application/xml, text/xml, */*" },
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return null;
    const text = await res.text();
    if (!text || (!text.includes("<rss") && !text.includes("<feed") && !text.includes("<xml"))) return null;

    const parsed = await parser.parseString(text);
    if (parsed && (parsed.items?.length || 0) >= 0) {
      const name = parsed.title ? parsed.title.replace(/rss|feed|offical|website/gi, "").trim() : "Custom Source";
      return {
        name: name || "Custom Source",
        url,
        title: parsed.title,
      };
    }
  } catch {
    // ignore
  }
  return null;
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const query = searchParams.get("query")?.trim();

  if (!query) {
    return NextResponse.json(
      { ok: false, error: "Vui lòng nhập đường dẫn hoặc tên miền." },
      { status: 400 }
    );
  }

  let candidates: string[] = [];

  // If query is already a full RSS link
  if (query.startsWith("http://") || query.startsWith("https://")) {
    candidates.push(query);
  } else {
    // Normalize domain
    let domain = query;
    if (!domain.includes(".")) {
      domain = `${domain}.com`;
    }
    candidates.push(`https://${domain}`);
    candidates.push(`http://${domain}`);
  }

  const urlsToTest = new Set<string>();

  for (const base of candidates) {
    const cleanBase = base.replace(/\/+$/, "");
    urlsToTest.add(cleanBase);
    urlsToTest.add(`${cleanBase}/feed`);
    urlsToTest.add(`${cleanBase}/feed/`);
    urlsToTest.add(`${cleanBase}/rss`);
    urlsToTest.add(`${cleanBase}/rss.xml`);
    urlsToTest.add(`${cleanBase}/feed.xml`);
    urlsToTest.add(`${cleanBase}/index.xml`);
    urlsToTest.add(`${cleanBase}/rss/home.rss`);
    urlsToTest.add(`${cleanBase}/rss/so-hoa.rss`);
    urlsToTest.add(`${cleanBase}/rss/cong-nghe.rss`);
  }

  // 1. Try direct RSS candidate URLs
  for (const url of Array.from(urlsToTest)) {
    const result = await testRssUrl(url);
    if (result) {
      return NextResponse.json({ ok: true, feed: result });
    }
  }

  // 2. Try HTML scraping for <link rel="alternate" type="application/rss+xml">
  for (const base of candidates) {
    try {
      const htmlRes = await fetch(base, {
        headers: { "User-Agent": UA },
        signal: AbortSignal.timeout(6000),
      });
      if (!htmlRes.ok) continue;
      const html = await htmlRes.text();

      const rssLinkMatch = html.match(
        /<link[^>]+type=["']application\/(rss|atom)\+xml["'][^>]+href=["']([^"']+)["']/i
      ) || html.match(
        /<link[^>]+href=["']([^"']+)["'][^>]+type=["']application\/(rss|atom)\+xml["']/i
      );

      if (rssLinkMatch && rssLinkMatch[2]) {
        let feedUrl = rssLinkMatch[2];
        if (feedUrl.startsWith("/")) {
          const origin = new URL(base).origin;
          feedUrl = `${origin}${feedUrl}`;
        }
        const result = await testRssUrl(feedUrl);
        if (result) {
          return NextResponse.json({ ok: true, feed: result });
        }
      }
    } catch {
      // ignore
    }
  }

  return NextResponse.json(
    {
      ok: false,
      error: `Không tìm thấy nguồn tin RSS từ '${query}'. Hãy thử nhập URL RSS trực tiếp (ví dụ: https://${query.includes(".") ? query : query + ".com"}/feed).`,
    },
    { status: 404 }
  );
}
