import { useEffect, useState } from 'react'
import type { Tag } from '../types/news'

const KEY = 'luong:customSources'

function readInitial(): Tag[] {
  try {
    const raw = localStorage.getItem(KEY)
    return raw ? (JSON.parse(raw) as Tag[]) : []
  } catch {
    return []
  }
}

const DIACRITICS_RE = new RegExp('[̀-ͯ]', 'g')

function slugify(label: string): string {
  const base = label
    .normalize('NFD')
    .replace(DIACRITICS_RE, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
  return base || 'nguon'
}

export function useCustomSources() {
  const [sources, setSources] = useState<Tag[]>(readInitial)

  useEffect(() => {
    try {
      localStorage.setItem(KEY, JSON.stringify(sources))
    } catch {
      // storage unavailable — sources just won't persist
    }
  }, [sources])

  function addSource(input: { label: string; feedUrl: string; emoji?: string }): Tag {
    let hostname = 'Nguồn tuỳ chỉnh'
    try {
      hostname = new URL(input.feedUrl).hostname.replace(/^www\./, '')
    } catch {
      // keep default label
    }
    const tag: Tag = {
      id: `custom-${slugify(input.label)}-${Date.now().toString(36)}`,
      label: input.label.trim(),
      emoji: input.emoji?.trim() || '📰',
      feedUrl: input.feedUrl.trim(),
      source: hostname,
      custom: true,
    }
    setSources((prev) => [...prev, tag])
    return tag
  }

  function removeSource(id: string) {
    setSources((prev) => prev.filter((s) => s.id !== id))
  }

  return { sources, addSource, removeSource }
}
