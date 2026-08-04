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

export interface Article {
  id: string;
  title: string;
  link: string;
  source: string;
  summary: string;
  image: string | null;
  tags: Tag[];
  publishedAt: string;
}

export interface NewsResponse {
  articles: Article[];
  fetchedAt: string;
}
