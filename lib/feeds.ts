import type { Tag } from "./types";

export interface FeedSource {
  name: string;
  url: string;
  baseTags: Tag[];
}

export const FEEDS: FeedSource[] = [
  { name: "TechCrunch", url: "https://techcrunch.com/feed/", baseTags: ["Startup", "Big Tech"] },
  { name: "The Verge", url: "https://www.theverge.com/rss/index.xml", baseTags: ["Big Tech"] },
  { name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index", baseTags: ["Phần mềm"] },
  { name: "Wired", url: "https://www.wired.com/feed/rss", baseTags: ["Big Tech"] },
  { name: "Engadget", url: "https://www.engadget.com/rss.xml", baseTags: ["Phần cứng"] },
  { name: "9to5Mac", url: "https://9to5mac.com/feed/", baseTags: ["Apple"] },
  { name: "The Hacker News", url: "https://feeds.feedburner.com/TheHackersNews", baseTags: ["Bảo mật"] },
  { name: "VentureBeat", url: "https://venturebeat.com/feed/", baseTags: ["AI", "Startup"] },
];

const KEYWORD_TAGS: Array<{ pattern: RegExp; tag: Tag }> = [
  { pattern: /\b(ai|artificial intelligence|chatgpt|openai|gpt-|llm|gemini|anthropic|claude)\b/i, tag: "AI" },
  { pattern: /\b(apple|iphone|ipad|macbook|ios |ipados|macos|airpods|apple watch|vision pro)\b/i, tag: "Apple" },
  { pattern: /\b(hack|breach|vulnerab|exploit|ransomware|malware|cyberattack|phishing|cve-)\b/i, tag: "Bảo mật" },
  { pattern: /\b(android|smartphone|iphone|galaxy|pixel|ipad|tablet)\b/i, tag: "Di động" },
  { pattern: /\b(app|software|update|os |operating system|firmware|api)\b/i, tag: "Phần mềm" },
  { pattern: /\b(chip|processor|gpu|cpu|hardware|silicon|nvidia|amd|intel|laptop|device)\b/i, tag: "Phần cứng" },
  { pattern: /\b(game|gaming|xbox|playstation|nintendo|steam|esports)\b/i, tag: "Gaming" },
  { pattern: /\b(startup|funding|raises|series [a-e]|venture capital|ipo)\b/i, tag: "Startup" },
  { pattern: /\b(google|meta|amazon|microsoft|facebook|tesla|apple)\b/i, tag: "Big Tech" },
];

export function inferTags(baseTags: Tag[], title: string, summary: string): Tag[] {
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
