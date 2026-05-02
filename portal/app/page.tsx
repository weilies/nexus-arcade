import { GameCard } from '@/components/GameCard'
import { getFeaturedGame } from '@/lib/data/games'
import Link from 'next/link'

export default async function HomePage() {
  const game = await getFeaturedGame()

  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <div className="card-panel w-full max-w-sm">
        {/* Hero */}
        <div className="text-center mb-5">
          <div className="text-5xl">🏰</div>
          <h1 className="font-pixel text-2xl font-bold text-meadow-dark mt-2">NEXUS ARCADE</h1>
          <p className="font-pixel text-base text-meadow-earth mt-1">🎮 Casual games. Compete. Conquer.</p>
        </div>

        {/* Featured game */}
        {game ? (
          <GameCard slug={game.slug} name={game.name} />
        ) : (
          <div className="bg-white rounded-card p-6 border-2 border-meadow-wheat shadow-card text-center">
            <div className="text-4xl mb-3">🎮</div>
            <div className="font-pixel text-lg text-ui-muted">No games live yet</div>
            <div className="text-sm text-meadow-earth mt-1">Check back soon!</div>
          </div>
        )}

        {/* More Games link */}
        <div className="text-center mt-4">
          <Link href="/games" className="btn-secondary inline-block">
            🕹️ MORE GAMES
          </Link>
        </div>
      </div>
    </div>
  )
}
