'use client'

interface SeasonBannerProps {
  name: string
  endsAt: string
}

function daysLeft(endsAt: string): number {
  const end = new Date(endsAt)
  const now = new Date()
  return Math.max(0, Math.ceil((end.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)))
}

export function SeasonBanner({ name, endsAt }: SeasonBannerProps) {
  const days = daysLeft(endsAt)
  return (
    <div className="bg-gradient-to-r from-arcade-violet to-arcade-pink px-4 py-2 flex justify-between items-center font-mono text-xs">
      <span className="text-white font-bold tracking-wider">
        🏆 {name.toUpperCase()} — {days} DAY{days !== 1 ? 'S' : ''} LEFT
      </span>
      <button className="text-yellow-200 hover:text-white tracking-wider">
        JOIN EVENT
      </button>
    </div>
  )
}
