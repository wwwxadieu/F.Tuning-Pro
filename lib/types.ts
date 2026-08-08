export type Tag =
  | "AI"
  | "Apple"
  | "Bảo mật"
  | "Di động"
  | "Phần mềm"
  | "Phần cứng"
  | "Gaming"
  | "Startup"
  | "Big Tech";

export interface CustomFeedSource {
  name: string;
  url: string;
  baseTags?: Tag[];
  lang?: "vi" | "en";
  icon?: string;
  isCustom?: boolean;
}

export interface Article {
  id: string;
  title: string;
  link: string;
  source: string;
  summary: string;
  image: string | null;
  tags: Tag[];
  publishedAt: string;
  lang: "vi" | "en";
  translated: boolean;
  originalTitle?: string;
  originalSummary?: string;
  isCustomSource?: boolean;
}

export interface NewsResponse {
  articles: Article[];
  fetchedAt: string;
}

export interface ArticleDetailResponse {
  title: string;
  source: string;
  publishedAt: string;
  link: string;
  content: string;
  summary: string;
  image: string | null;
  author?: string;
  ok: boolean;
  error?: string;
}
