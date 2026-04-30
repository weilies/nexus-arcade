import { Nav } from '@/components/Nav'
import { GameCard } from '@/components/GameCard'
import { LeaderboardWidget } from '@/components/LeaderboardWidget'
import { SeasonBanner } from '@/components/SeasonBanner'
import { getFeaturedGame } from '@/lib/data/games'
import { getTopScores } from '@/lib/data/leaderboard'
import { getActiveSeason } from '@/lib/data/seasons'

export default async function HomePage() {
  const game = await getFeaturedGame()
  const scores = game ? await getTopScores(game.slug) : []
  const season = game ? await getActiveSeason(game.slug) : null

  return (
    <div className="min-h-screen bg-arcade-bg text-white">
      <Nav />
      {season && <SeasonBanner name={season.name} endsAt={season.ends_at} />}
      <main className="max-w-4xl mx-auto px-4 py-8">
        {game ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <GameCard slug={game.slug} name={game.name} />
            <LeaderboardWidget gameSlug={game.slug} scores={scores} />
          </div>
        ) : (
          <div className="text-center font-mono text-arcade-dim text-lg mt-16">
            NO GAMES LOADED
          </div>
        )}
      </main>
      <footer className="fixed bottom-0 left-0 right-0 bg-arcade-panel border-t border-arcade-border px-4 py-2 text-center font-mono text-arcade-dim text-xs">
        NEXUS ARCADE — JOIN OUR{' '}
        <a
          href="https://discord.gg/YOUR_INVITE"
          target="_blank"
          rel="noopener noreferrer"
          className="text-arcade-violet hover:text-arcade-purple"
        >
          DISCORD
        </a>
      </footer>
    </div>
  )
}
