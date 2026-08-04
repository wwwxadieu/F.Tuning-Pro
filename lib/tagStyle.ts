import type { Tag } from "./types";

export const TAG_SLUGS: Record<Tag, string> = {
  AI: "AI",
  Apple: "Apple",
  "Bảo mật": "Security",
  "Di động": "Mobile",
  "Phần mềm": "Software",
  "Phần cứng": "Hardware",
  Gaming: "Gaming",
  Startup: "Startup",
  "Big Tech": "BigTech",
};

export function tagGradientClass(tag: Tag): string {
  return `tag-gradient-${TAG_SLUGS[tag]}`;
}
