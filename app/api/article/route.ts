import { NextResponse } from "next/server";

export const runtime = "nodejs";

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 TechWaveReader/1.0";

function cleanHtml(html: string, baseUrl: string): string {
  if (!html) return "";

  // Remove scripts, styles, iframes, ads
  let cleaned = html
    .replace(/<script\b[^<]*>([\s\S]*?)<\/script>/gi, "")
    .replace(/<style\b[^<]*>([\s\S]*?)<\/style>/gi, "")
    .replace(/<nav\b[^<]*>([\s\S]*?)<\/nav>/gi, "")
    .replace(/<header\b[^<]*>([\s\S]*?)<\/header>/gi, "")
    .replace(/<footer\b[^<]*>([\s\S]*?)<\/footer>/gi, "")
    .replace(/<iframe\b[^<]*>([\s\S]*?)<\/iframe>/gi, "");

  // Convert relative images to absolute
  cleaned = cleaned.replace(/<img[^>]+src=["']([^"']+)["']/gi, (match, src) => {
    if (src.startsWith("http://") || src.startsWith("https://") || src.startsWith("data:")) {
      return match;
    }
    try {
      const origin = new URL(baseUrl).origin;
      const absoluteSrc = src.startsWith("/") ? `${origin}${src}` : `${origin}/${src}`;
      return match.replace(src, absoluteSrc);
    } catch {
      return match;
    }
  });

  return cleaned;
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const targetUrl = searchParams.get("url")?.trim();

  if (!targetUrl) {
    return NextResponse.json(
      { ok: false, error: "Thiếu địa chỉ URL bài viết." },
      { status: 400 }
    );
  }

  try {
    const res = await fetch(targetUrl, {
      headers: {
        "User-Agent": UA,
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
      signal: AbortSignal.timeout(8000),
    });

    if (!res.ok) {
      return NextResponse.json(
        { ok: false, error: `Máy chủ trang web gốc phản hồi mã lỗi HTTP ${res.status}.` },
        { status: res.status }
      );
    }

    const html = await res.text();

    // Extract title
    const titleMatch = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
    const title = titleMatch ? titleMatch[1].replace(/<[^>]+>/g, "").trim() : "";

    // Extract main image (og:image)
    const ogImageMatch = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i) ||
      html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
    let image = ogImageMatch ? ogImageMatch[1] : null;

    if (image && !image.startsWith("http")) {
      try {
        const origin = new URL(targetUrl).origin;
        image = image.startsWith("/") ? `${origin}${image}` : `${origin}/${image}`;
      } catch {
        // ignore
      }
    }

    // Attempt to extract main article body container
    let bodyContainer = "";

    // Match common article selectors in VnExpress, GenK, TechCrunch, The Verge, VietNamNet, etc.
    const articleMatch = html.match(/<article\b[^>]*>([\s\S]*?)<\/article>/i) ||
      html.match(/<div[^>]+class=["'][^"']*(fck_detail|detail-content|article-content|entry-content|post-content|content-detail)[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);

    if (articleMatch) {
      bodyContainer = articleMatch[1] || articleMatch[2];
    } else {
      // Fallback: collect paragraphs
      const paragraphs = html.match(/<p\b[^>]*>([\s\S]*?)<\/p>/gi);
      if (paragraphs && paragraphs.length > 0) {
        bodyContainer = paragraphs.slice(0, 15).join("\n");
      }
    }

    const cleanBody = cleanHtml(bodyContainer, targetUrl);

    if (!cleanBody || cleanBody.replace(/<[^>]+>/g, "").trim().length < 60) {
      return NextResponse.json({
        ok: false,
        error: "Không thể trích xuất toàn bộ nội dung tự động từ trang này.",
        title,
        image,
        link: targetUrl,
      });
    }

    return NextResponse.json({
      ok: true,
      title,
      link: targetUrl,
      image,
      content: cleanBody,
    });
  } catch (err) {
    return NextResponse.json(
      {
        ok: false,
        error: (err as Error).message || "Lỗi mạng hoặc hết thời gian chờ kết nối.",
      },
      { status: 500 }
    );
  }
}
