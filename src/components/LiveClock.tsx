import { useEffect, useState } from 'react'

const DATE_FORMATTER = new Intl.DateTimeFormat('vi-VN', {
  weekday: 'short',
  day: '2-digit',
  month: '2-digit',
})
const TIME_FORMATTER = new Intl.DateTimeFormat('vi-VN', {
  hour: '2-digit',
  minute: '2-digit',
})

export default function LiveClock() {
  const [now, setNow] = useState(() => new Date())

  useEffect(() => {
    const interval = setInterval(() => setNow(new Date()), 1000 * 15)
    return () => clearInterval(interval)
  }, [])

  return (
    <span className="lock-select flex items-center gap-1.5 rounded-full border border-[var(--border-1)] bg-[var(--surface-1)] px-3 py-1 text-[11px] font-medium text-[var(--text-3)]">
      <span className="capitalize">{DATE_FORMATTER.format(now)}</span>
      <span className="text-[var(--text-4)]">·</span>
      <span className="tabular-nums">{TIME_FORMATTER.format(now)}</span>
    </span>
  )
}
