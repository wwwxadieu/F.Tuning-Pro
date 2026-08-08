import { useCallback, useMemo, useState } from 'react'
import { AnimatePresence } from 'framer-motion'
import Header from './components/Header'
import Hero from './components/Hero'
import Sidebar from './components/Sidebar'
import NewsGrid from './components/NewsGrid'
import Footer from './components/Footer'
import SettingsModal from './components/SettingsModal'
import UpdateBanner from './components/UpdateBanner'
import AppUpdateToast from './components/AppUpdateToast'
import ReaderView from './components/ReaderView'
import Onboarding from './components/Onboarding'
import TodayDigest from './components/TodayDigest'
import QuickAddSourceButton from './components/QuickAddSourceButton'
import { useNews } from './hooks/useNews'
import { useSettings } from './hooks/useSettings'
import { useCustomSources } from './hooks/useCustomSources'
import { useSmoothScroll } from './hooks/useSmoothScroll'
import { useInterests } from './hooks/useInterests'
import { useAppUpdate } from './hooks/useAppUpdate'
import { useReadingHabits } from './hooks/useReadingHabits'
import { TagsProvider } from './context/TagsContext'
import { TAGS as BUILT_IN_TAGS } from './data/tags'
import { smoothScrollTo } from './lib/lenisInstance'
import type { Article, Notification, Tag } from './types/news'

const TOAST_DURATION_MS = 6500
const NOTIFICATION_HISTORY_LIMIT = 20

export default function App() {
  useSmoothScroll()

  const { settings, update: updateSettings } = useSettings()
  const { sources: customSources, addSource, removeSource } = useCustomSources()
  const { onboarded, interests, setInterests, completeOnboarding } = useInterests()
  const { habits, trackArticleRead, getRecommendedArticles } = useReadingHabits()

  const allTags: Tag[] = useMemo(() => [...BUILT_IN_TAGS, ...customSources], [customSources])

  const appUpdate = useAppUpdate(settings.autoUpdateEnabled)
  const [dismissedUpdateVersion, setDismissedUpdateVersion] = useState<string | null>(null)

  const [notifications, setNotifications] = useState<Notification[]>([])
  const [toast, setToast] = useState<Notification | null>(null)

  const handleNewArticles = useCallback(
    (tag: Tag, newItems: Article[]) => {
      if (!settings.notificationsEnabled) return
      const notification: Notification = {
        id: `${tag.id}-${Date.now()}`,
        tagId: tag.id,
        tagLabel: tag.label,
        count: newItems.length,
        timestamp: Date.now(),
        read: false,
      }
      setNotifications((prev) => [notification, ...prev].slice(0, NOTIFICATION_HISTORY_LIMIT))
      setToast(notification)
      setTimeout(() => {
        setToast((current) => (current?.id === notification.id ? null : current))
      }, TOAST_DURATION_MS)
    },
    [settings.notificationsEnabled]
  )

  const { articles, statuses, revealCounts, retryTag, loadMore, refreshAll, refreshing, supplementing } = useNews(
    allTags,
    handleNewArticles,
    interests
  )

  const [selectedTag, setSelectedTag] = useState<string | null>(null)
  const [sidebarOpen, setSidebarOpen] = useState(() =>
    typeof window !== 'undefined' ? window.innerWidth >= 1024 : true
  )
  const [settingsOpen, setSettingsOpen] = useState(false)

  const [readerList, setReaderList] = useState<Article[] | null>(null)
  const [readerIndex, setReaderIndex] = useState(0)

  function selectTagAndScroll(tagId: string | null) {
    setSelectedTag(tagId)
    smoothScrollTo('#tin-tuc')
  }

  function handleReadNotifications() {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
  }

  function handleOpenArticle(article: Article, list: Article[]) {
    trackArticleRead(article)
    const index = list.findIndex((a) => a.id === article.id)
    setReaderList(list)
    setReaderIndex(index >= 0 ? index : 0)
  }

  function handleRemoveSource(tagId: string) {
    removeSource(tagId)
    setSelectedTag((prev) => (prev === tagId ? null : prev))
  }

  function handleClearCache() {
    const keys: string[] = []
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key?.startsWith('luong:feed:')) keys.push(key)
    }
    keys.forEach((k) => localStorage.removeItem(k))
    allTags.forEach((tag) => retryTag(tag.id))
  }

  const recommendedArticles = useMemo(() => {
    return getRecommendedArticles(articles, 5)
  }, [articles, habits, getRecommendedArticles])

  const unreadCount = notifications.filter((n) => !n.read).length
  const readerArticle = readerList ? readerList[readerIndex] : null
  const digestLoading = articles.length === 0 && Object.values(statuses).some((s) => s === 'loading')

  return (
    <TagsProvider customTags={customSources}>
      <div className="min-h-screen bg-[var(--bg)]">
        <AnimatePresence>{!onboarded && <Onboarding onComplete={completeOnboarding} />}</AnimatePresence>

        <Header
          onToggleSidebar={() => setSidebarOpen((v) => !v)}
          notifications={notifications}
          unreadCount={unreadCount}
          onReadNotifications={handleReadNotifications}
          onSelectNotification={selectTagAndScroll}
          onRefresh={refreshAll}
          refreshing={refreshing}
        />

        <Sidebar
          open={sidebarOpen}
          selected={selectedTag}
          onSelect={selectTagAndScroll}
          onOpenSettings={() => setSettingsOpen(true)}
          onRemoveSource={handleRemoveSource}
        />

        {sidebarOpen && (
          <div
            className="fixed inset-0 z-30 bg-black/50 lg:hidden"
            onClick={() => setSidebarOpen(false)}
          />
        )}

        <div className={`transition-[padding-left] duration-300 ease-out ${sidebarOpen ? 'lg:pl-64' : ''}`}>
          <Hero />

          <TodayDigest
            articles={articles}
            recommendedArticles={recommendedArticles}
            loading={digestLoading}
            onOpenArticle={handleOpenArticle}
          />

          <main className="mx-auto max-w-[1900px] px-6 pb-10 pt-16 sm:px-8">
            <NewsGrid
              articles={articles}
              statuses={statuses}
              revealCounts={revealCounts}
              supplementing={supplementing}
              selected={selectedTag}
              interests={interests}
              retryTag={retryTag}
              onLoadMore={loadMore}
              onOpenArticle={handleOpenArticle}
            />
          </main>

          <Footer />
        </div>

        <UpdateBanner toast={toast} onDismiss={() => setToast(null)} onClick={selectTagAndScroll} />

        <AppUpdateToast
          appUpdate={appUpdate}
          dismissed={dismissedUpdateVersion === appUpdate.latest?.version}
          onDismiss={() => setDismissedUpdateVersion(appUpdate.latest?.version ?? null)}
        />

        <QuickAddSourceButton onAddSource={addSource} />

        <SettingsModal
          open={settingsOpen}
          onClose={() => setSettingsOpen(false)}
          settings={settings}
          onUpdateSettings={updateSettings}
          customSources={customSources}
          onAddSource={addSource}
          onRemoveSource={handleRemoveSource}
          onClearCache={handleClearCache}
          interests={interests}
          onToggleInterest={(tagId) =>
            setInterests((prev) =>
              prev.includes(tagId) ? prev.filter((i) => i !== tagId) : [...prev, tagId]
            )
          }
          appUpdate={appUpdate}
        />

        <ReaderView
          article={readerArticle}
          hasPrev={readerIndex > 0}
          hasNext={!!readerList && readerIndex < readerList.length - 1}
          onPrev={() => setReaderIndex((i) => Math.max(0, i - 1))}
          onNext={() => setReaderIndex((i) => Math.min((readerList?.length ?? 1) - 1, i + 1))}
          onClose={() => setReaderList(null)}
          settings={settings}
          onUpdateSettings={updateSettings}
        />
      </div>
    </TagsProvider>
  )
}
