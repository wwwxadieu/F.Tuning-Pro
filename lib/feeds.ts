import type { CustomFeedSource, Tag } from "./types";

export interface FeedSource {
  name: string;
  url: string;
  baseTags: Tag[];
  lang: "en" | "vi";
  isCustom?: boolean;
}

export const FEEDS: FeedSource[] = [
  { name: "TechCrunch", url: "https://techcrunch.com/feed/", baseTags: ["Startup", "Big Tech"], lang: "en" },
  { name: "The Verge", url: "https://www.theverge.com/rss/index.xml", baseTags: ["Big Tech"], lang: "en" },
  { name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index", baseTags: ["Phần mềm"], lang: "en" },
  { name: "Wired", url: "https://www.wired.com/feed/rss", baseTags: ["Big Tech"], lang: "en" },
  { name: "Engadget", url: "https://www.engadget.com/rss.xml", baseTags: ["Phần cứng"], lang: "en" },
  { name: "9to5Mac", url: "https://9to5mac.com/feed/", baseTags: ["Apple"], lang: "en" },
  { name: "The Hacker News", url: "https://feeds.feedburner.com/TheHackersNews", baseTags: ["Bảo mật"], lang: "en" },
  { name: "VentureBeat", url: "https://venturebeat.com/feed/", baseTags: ["AI", "Startup"], lang: "en" },
  { name: "VnExpress Số hóa", url: "https://vnexpress.net/rss/so-hoa.rss", baseTags: ["Phần mềm"], lang: "vi" },
  { name: "VietNamNet Công nghệ", url: "https://vietnamnet.vn/rss/cong-nghe.rss", baseTags: ["Big Tech"], lang: "vi" },
  { name: "Genk", url: "https://genk.vn/rss/home.rss", baseTags: ["Big Tech"], lang: "vi" },
  { name: "Tinh Tế", url: "https://tinhte.vn/rss", baseTags: ["Phần cứng"], lang: "vi" },
  { name: "Thanh Niên Công nghệ", url: "https://thanhnien.vn/rss/cong-nghe.rss", baseTags: ["Big Tech"], lang: "vi" },
  { name: "Tuổi Trẻ Công nghệ", url: "https://tuoitre.vn/rss/nhip-song-so.rss", baseTags: ["Di động"], lang: "vi" },
  { name: "Dân Trí Sức mạnh số", url: "https://dantri.com.vn/rss/suc-manh-so.rss", baseTags: ["Phần cứng"], lang: "vi" },
  { name: "Sforum CellphoneS", url: "https://sforum.vn/feed", baseTags: ["Di động", "Phần cứng"], lang: "vi" },
];

const KEYWORD_TAGS: Array<{ pattern: RegExp; tag: Tag }> = [
  { pattern: /\b(ai|artificial intelligence|chatgpt|openai|gpt-|llm|gemini|anthropic|claude|deepseek|mistral|trí tuệ nhân tạo)\b/i, tag: "AI" },
  { pattern: /\b(apple|iphone|ipad|macbook|ios |ipados|macos|airpods|apple watch|vision pro|m1|m2|m3|m4|m5)\b/i, tag: "Apple" },
  { pattern: /\b(hack|breach|vulnerab|exploit|ransomware|malware|cyberattack|phishing|cve-|bảo mật|lỗ hổng|tấn công mạng|rò rỉ dữ liệu|mã độc|an ninh mạng)\b/i, tag: "Bảo mật" },
  { pattern: /\b(android|smartphone|iphone|galaxy|pixel|ipad|tablet|điện thoại|di động|mobile|xiaomi|oppo|vivo)\b/i, tag: "Di động" },
  { pattern: /\b(app|software|update|os |operating system|firmware|api|ứng dụng|phần mềm|cập nhật|hệ điều hành|window|windows)\b/i, tag: "Phần mềm" },
  { pattern: /\b(chip|processor|gpu|cpu|hardware|silicon|nvidia|amd|intel|laptop|device|con chip|máy tính|phần cứng|rtx|geforce|core ultra|ryzen|rog|strix|msi|asus|lenovo|dell|g.skill|ram|ssd)\b/i, tag: "Phần cứng" },
  { pattern: /\b(game|gaming|xbox|playstation|nintendo|steam|esports|trò chơi|gameplay|rog strix|chuột chơi game)\b/i, tag: "Gaming" },
  { pattern: /\b(startup|funding|raises|series [a-e]|venture capital|ipo|khởi nghiệp|gọi vốn|đầu tư)\b/i, tag: "Startup" },
  { pattern: /\b(google|meta|amazon|microsoft|facebook|tesla|apple|samsung|xiaomi|nvidia|tsmc|huawei)\b/i, tag: "Big Tech" },
];

export function inferTags(baseTags: Tag[] = [], title: string, summary: string): Tag[] {
  const haystack = `${title} ${summary}`;
  const tags = new Set<Tag>(baseTags);
  for (const { pattern, tag } of KEYWORD_TAGS) {
    if (pattern.test(haystack)) tags.add(tag);
  }
  if (tags.size === 0) tags.add("Big Tech");
  return Array.from(tags).slice(0, 4);
}

export const ALL_TAGS: Tag[] = [
  "AI",
  "Apple",
  "Bảo mật",
  "Di động",
  "Phần mềm",
  "Phần cứng",
  "Gaming",
  "Startup",
  "Big Tech",
];
