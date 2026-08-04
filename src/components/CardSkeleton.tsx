export default function CardSkeleton() {
  return (
    <div className="glass flex flex-col overflow-hidden rounded-2xl">
      <div className="shimmer-bg aspect-[16/10] w-full animate-shimmer" />
      <div className="flex flex-col gap-3 p-4">
        <div className="shimmer-bg h-4 w-4/5 animate-shimmer rounded-full" />
        <div className="shimmer-bg h-3 w-full animate-shimmer rounded-full" />
        <div className="shimmer-bg h-3 w-2/3 animate-shimmer rounded-full" />
      </div>
    </div>
  )
}
