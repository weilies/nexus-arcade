import { getAllLiveGames } from '@/lib/data/games'
import { GameCard } from '@/components/GameCard'

export default async function GamesPage() {
  const games = await getAllLiveGames()

  return (
    <div
      className="min-h-screen flex flex-col items-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <div className="card-panel w-full max-w-sm">
        <div className="text-center mb-5">
          <div className="text-4xl">🕹️</div>
          <h1 className="font-pixel text-2xl font-bold text-meadow-dark mt-2">GAMES</h1>
          <p className="font-pixel text-base text-meadow-earth mt-1">Pick your adventure!</p>
        </div>

        {games.length > 0 ? (
          <div className="flex flex-col gap-3">
            {games.map((game) => (
              <GameCard key={game.id} slug={game.slug} name={game.name} compact />
            ))}
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-4 bg-white rounded-card p-4 border-2 border-meadow-wheat shadow-card opacity-50">
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-3xl flex-shrink-0"
                   style={{ background: '#d4e7f7' }}>
                ❓
              </div>
              <div className="flex-1">
                <div className="font-pixel text-xl font-semibold" style={{ color: '#bbb' }}>Coming Soon</div>
                <div className="text-sm" style={{ color: '#bbb' }}>🕹️ More games on the way</div>
              </div>
              <span className="text-sm font-pixel" style={{ color: '#ccc' }}>SOON</span>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
