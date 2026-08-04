import { useState } from 'react'
import Header from './components/Header'
import Hero from './components/Hero'
import TagFilter from './components/TagFilter'
import NewsGrid from './components/NewsGrid'
import Footer from './components/Footer'
import { useNews } from './hooks/useNews'

export default function App() {
  const { articles, statuses, retryTag } = useNews()
  const [selected, setSelected] = useState<Set<string>>(new Set())

  function toggleTag(tagId: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(tagId)) next.delete(tagId)
      else next.add(tagId)
      return next
    })
  }

  return (
    <div className="min-h-screen bg-black">
      <Header />
      <Hero />

      <main className="mx-auto max-w-6xl px-6 pb-10 pt-16 sm:px-8">
        <div className="mb-10">
          <TagFilter selected={selected} onToggle={toggleTag} onClear={() => setSelected(new Set())} />
        </div>
        <NewsGrid articles={articles} statuses={statuses} selected={selected} retryTag={retryTag} />
      </main>

      <Footer />
    </div>
  )
}
