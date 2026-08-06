import { useEffect, useState } from 'react'

const ONBOARDED_KEY = 'luong:onboarded'
const INTERESTS_KEY = 'luong:interests'

function readOnboarded(): boolean {
  try {
    return localStorage.getItem(ONBOARDED_KEY) === '1'
  } catch {
    return false
  }
}

function readInterests(): string[] {
  try {
    const raw = localStorage.getItem(INTERESTS_KEY)
    return raw ? (JSON.parse(raw) as string[]) : []
  } catch {
    return []
  }
}

export function useInterests() {
  const [onboarded, setOnboarded] = useState(readOnboarded)
  const [interests, setInterests] = useState<string[]>(readInterests)

  useEffect(() => {
    try {
      localStorage.setItem(INTERESTS_KEY, JSON.stringify(interests))
    } catch {
      // storage unavailable — selection just won't persist
    }
  }, [interests])

  function completeOnboarding(selected: string[]) {
    setInterests(selected)
    setOnboarded(true)
    try {
      localStorage.setItem(ONBOARDED_KEY, '1')
    } catch {
      // storage unavailable — will just re-show onboarding next launch
    }
  }

  return { onboarded, interests, setInterests, completeOnboarding }
}
