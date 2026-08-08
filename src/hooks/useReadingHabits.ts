import { useEffect, useState } from 'react'
import type { Article } from '../types/news'

const HABITS_KEY = 'fvnn:reading_habits'

export interface ReadingHabits {
  categoryCounts: Record<string, number>
  sourceCounts: Record<string, number>
  keywordCounts: Record<string, number>
  readArticleIds: string[]
  totalArticlesRead: number
}

const DEFAULT_HABITS: ReadingHabits = {
  categoryCounts: {},
  sourceCounts: {},
  keywordCounts: {},
  readArticleIds: [],
  totalArticlesRead: 0,
}

const STOP_WORDS = new Set([
  'và', 'hoặc', 'của', 'cho', 'với', 'trong', 'trên', 'tại', 'về', 'những', 'các', 'một',
  'này', 'đó', 'khi', 'đã', 'sẽ', 'là', 'được', 'ra', 'vào', 'đến', 'theo', 'từ', 'sau',
  'the', 'and', 'for', 'with', 'from', 'this', 'that', 'with', 'into', 'over'
])

function extractKeywords(text: string): string[] {
  const words = text
    .toLowerCase()
    .replace(/[^\w\sàáảãạăắằẳẵặâấầẩẫậđèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵ]/gi, ' ')
    .split(/\s+/)
  return words.filter((w) => w.length >= 3 && !STOP_WORDS.has(w))
}

export function useReadingHabits() {
  const [habits, setHabits] = useState<ReadingHabits>(() => {
    try {
      const raw = localStorage.getItem(HABITS_KEY)
      return raw ? { ...DEFAULT_HABITS, ...JSON.parse(raw) } : DEFAULT_HABITS
    } catch {
      return DEFAULT_HABITS
    }
  })

  useEffect(() => {
    try {
      localStorage.setItem(HABITS_KEY, JSON.stringify(habits))
    } catch {
      // storage quota
    }
  }, [habits])

  function trackArticleRead(article: Article) {
    setHabits((prev) => {
      const newCat = { ...prev.categoryCounts }
      newCat[article.tagId] = (newCat[article.tagId] || 0) + 1

      const newSrc = { ...prev.sourceCounts }
      newSrc[article.source] = (newSrc[article.source] || 0) + 1

      const newKw = { ...prev.keywordCounts }
      const keywords = extractKeywords(article.title)
      keywords.forEach((kw) => {
        newKw[kw] = (newKw[kw] || 0) + 1
      })

      const readSet = new Set([article.id, ...(prev.readArticleIds || []).slice(0, 100)])

      return {
        categoryCounts: newCat,
        sourceCounts: newSrc,
        keywordCounts: newKw,
        readArticleIds: Array.from(readSet),
        totalArticlesRead: (prev.totalArticlesRead || 0) + 1,
      }
    })
  }

  function getRecommendationScore(article: Article): number {
    if (habits.readArticleIds?.includes(article.id)) return -100 // Already read

    const catScore = (habits.categoryCounts[article.tagId] || 0) * 12
    const srcScore = (habits.sourceCounts[article.source] || 0) * 6

    let kwScore = 0
    const keywords = extractKeywords(article.title)
    keywords.forEach((kw) => {
      if (habits.keywordCounts[kw]) {
        kwScore += habits.keywordCounts[kw] * 4
      }
    })

    const ageHours = (Date.now() - new Date(article.pubDate).getTime()) / (1000 * 3600)
    const recencyBonus = Math.max(0, 24 - ageHours)

    return catScore + srcScore + kwScore + recencyBonus
  }

  function getRecommendedArticles(allArticles: Article[], limit = 6): Article[] {
    if (!habits.totalArticlesRead || habits.totalArticlesRead < 1) return []

    const scored = allArticles
      .map((a) => ({ article: a, score: getRecommendationScore(a) }))
      .filter((item) => item.score > 0)

    scored.sort((a, b) => b.score - a.score)
    return scored.slice(0, limit).map((item) => item.article)
  }

  return { habits, trackArticleRead, getRecommendedArticles }
}
