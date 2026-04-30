import Link from 'next/link'
import type { LeaderboardEntry } from '@/lib/data/leaderboard'

interface LeaderboardWidgetProps {
  gameSlug: string
  scores: LeaderboardEntry[]
}

export function LeaderboardWidget({ gameSlug, scores }: LeaderboardWidgetProps) {
  return (
    <div className="bg-arcade-panel border-2 border-arcade-gold p-4 font-mono flex flex-col gap-2">
      <div className="text-arcade-gold text-sm font-bold tracking-wider mb-1">
        🏆 TOP PLAYERS
      </div>
      {scores.length === 0 && (
        <div className="text-arcade-dim text-xs">NO SCORES YET</div>
      )}
      {scores.map((entry, i) => (
        <div
          key={entry.user_id}
          className={`text-xs border-b border-arcade-border pb-1 flex justify-between ${
            i === 0 ? 'text-arcade-green' : 'text-arcade-purple'
          }`}
        >
          <span>
            #{entry.rank} {entry.username}
          </span>
          <span className="text-arcade-gold">{entry.score.toLocaleString('en-US')}</span>
        </div>
      ))}
      <Link
        href={`/leaderboard/${gameSlug}`}
        className="text-arcade-pink text-xs text-right mt-1 hover:text-pink-300"
      >
        VIEW FULL ►
      </Link>
    </div>
  )
}
