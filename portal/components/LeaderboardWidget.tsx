import Link from 'next/link'
import type { LeaderboardEntry } from '@/lib/data/leaderboard'

interface LeaderboardWidgetProps {
  gameSlug: string
  scores: LeaderboardEntry[]
}

const RANK_COLORS = ['text-arcade-amber text-glow-amber', 'text-arcade-cyan text-glow-cyan', 'text-arcade-hot text-glow-hot']
const RANK_LABELS = ['1ST', '2ND', '3RD']

export function LeaderboardWidget({ gameSlug, scores }: LeaderboardWidgetProps) {
  return (
    <div className="crt-border-cyan bg-arcade-panel p-4 flex flex-col gap-3 relative overflow-hidden">
      {/* Corner decorations */}
      <div className="absolute top-0 left-0 w-3 h-3 border-t-2 border-l-2 border-arcade-cyan" />
      <div className="absolute top-0 right-0 w-3 h-3 border-t-2 border-r-2 border-arcade-cyan" />
      <div className="absolute bottom-0 left-0 w-3 h-3 border-b-2 border-l-2 border-arcade-cyan" />
      <div className="absolute bottom-0 right-0 w-3 h-3 border-b-2 border-r-2 border-arcade-cyan" />

      {/* Header */}
      <div className="font-pixel text-arcade-cyan text-[9px] tracking-widest text-glow-cyan pb-2 border-b border-arcade-border">
        ◈ HI-SCORE TABLE
      </div>

      {/* Scores */}
      {scores.length === 0 ? (
        <div className="font-mono text-arcade-dim text-xs text-center py-4">
          --- NO SCORES YET ---<br/>
          <span className="text-[10px]">BE THE FIRST</span>
        </div>
      ) : (
        <div className="flex flex-col gap-2">
          {scores.slice(0, 8).map((entry, i) => (
            <div key={entry.user_id}
                 className={`font-mono text-xs flex justify-between items-center pb-1 border-b border-arcade-border ${i < 3 ? RANK_COLORS[i] : 'text-arcade-amber opacity-70'}`}>
              <span className="font-pixel text-[7px] w-8 shrink-0">
                {i < 3 ? RANK_LABELS[i] : `${i + 1}.`}
              </span>
              <span className="flex-1 truncate mx-2 tracking-wider">{entry.username}</span>
              <span className="tabular-nums">{entry.score.toLocaleString('en-US')}</span>
            </div>
          ))}
        </div>
      )}

      <Link href={`/leaderboard/${gameSlug}`}
            className="font-mono text-arcade-hot text-[10px] text-right tracking-widest hover:text-glow-hot transition-all">
        FULL TABLE ▶
      </Link>
    </div>
  )
}
