import { getAllLiveGames } from '@/lib/data/games'
import { GameCard } from '@/components/GameCard'

export default async function GamesPage() {
  const games = await getAllLiveGames()

  return (
    <div className="min-h-screen flex flex-col items-center px-4 py-8 bg-retro-glow">
      <div className="w-full max-w-2xl">
        <div className="text-center mb-6">
          <div className="text-4xl">🕹️</div>
          <h1 className="font-pixel text-2xl font-bold text-[#e8e8f0] mt-2">GAMES</h1>
          <p className="font-pixel text-sm text-[#8888aa] mt-1">Pick your adventure!</p>
        </div>

        {games.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {games.map((game) => (
              <GameCard
                key={game.id}
                slug={game.slug}
                name={game.name}
                description={game.description}
                thumbnailUrl={game.thumbnail_url}
                compact
              />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex items-center gap-4 bg-[#1a1a2e] rounded-xl p-4 border border-[#2a2a4a] opacity-60">
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
                   style={{ background: 'rgba(0,229,255,0.06)' }}>
                ❓
              </div>
              <div className="flex-1">
                <div className="font-pixel text-xl font-semibold text-[#666688]">Coming Soon</div>
                <div className="text-sm text-[#555577]">More games on the way</div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
