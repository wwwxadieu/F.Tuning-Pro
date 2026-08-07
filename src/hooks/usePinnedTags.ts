import { useEffect, useState } from 'react'
import type { Tag } from '../types/news'

const PINNED_KEY = 'luong:pinnedTags'

function readPinned(): string[] {
  try {
    const raw = localStorage.getItem(PINNED_KEY)
    return raw ? (JSON.parse(raw) as string[]) : []
  } catch {
    return []
  }
}

export function usePinnedTags(validTags?: Tag[]) {
  const [pinned, setPinned] = useState<string[]>(readPinned)

  useEffect(() => {
    try {
      localStorage.setItem(PINNED_KEY, JSON.stringify(pinned))
    } catch {
      // storage unavailable — pin selection just won't persist
    }
  }, [pinned])

  // Self-heal: drop pinned ids that no longer resolve to a real tag
  // (e.g. the custom source behind them was removed).
  useEffect(() => {
    if (!validTags) return
    const validIds = new Set(validTags.map((t) => t.id))
    setPinned((prev) => {
      const next = prev.filter((id) => validIds.has(id))
      return next.length === prev.length ? prev : next
    })
  }, [validTags])

  function isPinned(tagId: string) {
    return pinned.includes(tagId)
  }

  function togglePin(tagId: string) {
    setPinned((prev) => (prev.includes(tagId) ? prev.filter((id) => id !== tagId) : [...prev, tagId]))
  }

  return { pinned, isPinned, togglePin }
}
