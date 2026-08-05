const cache = new Map<string, string>();
const MAX_CACHE_SIZE = 2000;

async function translateText(text: string): Promise<string | null> {
  const trimmed = text.trim();
  if (!trimmed) return text;

  const cached = cache.get(trimmed);
  if (cached) return cached;

  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q=${encodeURIComponent(
      trimmed
    )}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(6000) });
    if (!res.ok) return null;

    const data = (await res.json()) as unknown;
    const chunks = Array.isArray(data) ? data[0] : null;
    if (!Array.isArray(chunks)) return null;

    const translated = chunks.map((chunk: unknown) => (Array.isArray(chunk) ? chunk[0] ?? "" : "")).join("");
    if (!translated) return null;

    if (cache.size >= MAX_CACHE_SIZE) cache.clear();
    cache.set(trimmed, translated);
    return translated;
  } catch {
    return null;
  }
}

async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let cursor = 0;

  async function worker() {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await fn(items[index]);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

export interface Translatable {
  title: string;
  summary: string;
}

export async function translateBatch<T extends Translatable>(
  items: T[],
  concurrency = 6
): Promise<Array<{ title: string; summary: string; ok: boolean }>> {
  return mapWithConcurrency(items, concurrency, async (item) => {
    const [title, summary] = await Promise.all([translateText(item.title), translateText(item.summary)]);
    if (title === null && summary === null) {
      return { title: item.title, summary: item.summary, ok: false };
    }
    return { title: title ?? item.title, summary: summary ?? item.summary, ok: true };
  });
}
