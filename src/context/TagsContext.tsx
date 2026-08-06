import { createContext, useContext, useMemo } from 'react'
import type { ReactNode } from 'react'
import { TAGS as BUILT_IN_TAGS } from '../data/tags'
import type { Tag } from '../types/news'

interface TagsContextValue {
  tags: Tag[]
  tagMap: Map<string, Tag>
}

const TagsContext = createContext<TagsContextValue | null>(null)

export function TagsProvider({ customTags, children }: { customTags: Tag[]; children: ReactNode }) {
  const value = useMemo<TagsContextValue>(() => {
    const tags = [...BUILT_IN_TAGS, ...customTags]
    return { tags, tagMap: new Map(tags.map((t) => [t.id, t])) }
  }, [customTags])

  return <TagsContext.Provider value={value}>{children}</TagsContext.Provider>
}

export function useTags(): TagsContextValue {
  const ctx = useContext(TagsContext)
  if (!ctx) throw new Error('useTags must be used within TagsProvider')
  return ctx
}
