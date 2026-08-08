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
    <span className="lock-select flex items-center gap-1.5 rounded-full border border-white/15 bg-white/10 px-3.5 py-1 text-xs font-semibold text-white/90 shadow-sm backdrop-blur-md">
      <span className="capitalize">{DATE_FORMATTER.format(now)}</span>
      <span className="text-white/40">·</span>
      <span className="tabular-nums">{TIME_FORMATTER.format(now)}</span>
    </span>
  )
}
