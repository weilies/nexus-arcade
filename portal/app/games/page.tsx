import { getAllLiveGames } from '@/lib/data/games'
import { GameCard } from '@/components/GameCard'

const ACCENT_COLORS = ['#00e5ff', '#ff2d95', '#b366ff', '#ffd700', '#00ff88']

export default async function GamesPage() {
  const games = await getAllLiveGames()

  return (
    <div className="min-h-screen bg-retro-glow bg-retro-grid px-3 py-6 pb-24 md:px-4 md:py-10 md:pb-10">
      <div className="max-w-5xl mx-auto">

        {/* Header */}
        <div className="text-center mb-10">
          <div className="flex items-center justify-center gap-4 mb-3">
            <div style={{ flex: 1, maxWidth: '100px', height: '1px', background: 'linear-gradient(to right, transparent, #00e5ff66)' }} />
            <h1
              style={{
                fontFamily: 'Orbitron, sans-serif',
                fontSize: 'clamp(20px, 5vw, 32px)',
                fontWeight: '900',
                color: '#e8e8f0',
                letterSpacing: '0.18em',
                textShadow: '0 0 24px rgba(0,229,255,0.5), 0 0 48px rgba(0,229,255,0.2)',
                textTransform: 'uppercase',
              }}
            >
              GAME SELECT
            </h1>
            <div style={{ flex: 1, maxWidth: '100px', height: '1px', background: 'linear-gradient(to left, transparent, #00e5ff66)' }} />
          </div>
          <p
            style={{
              fontFamily: 'Orbitron, sans-serif',
              fontSize: '10px',
              color: '#444466',
              letterSpacing: '0.25em',
              textTransform: 'uppercase',
            }}
          >
            PLAYER 1 &mdash; CHOOSE YOUR STAGE
          </p>
        </div>

        {/* Grid */}
        {games.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {games.map((game, i) => (
              <GameCard
                key={game.id}
                slug={game.slug}
                name={game.name}
                description={game.description}
                thumbnailUrl={game.thumbnail_url}
                accentColor={ACCENT_COLORS[i % ACCENT_COLORS.length]}
                stageNum={i + 1}
              />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            {[1, 2, 3].map((n) => (
              <div
                key={n}
                style={{
                  borderTop: '3px solid #1a1a3a',
                  border: '1px solid #1a1a3a',
                  borderRadius: '2px',
                  overflow: 'hidden',
                  background: '#07071a',
                  opacity: 0.45,
                }}
              >
                <div style={{ padding: '5px 12px', background: '#0f0f22', borderBottom: '1px solid #1a1a3a' }}>
                  <span style={{ fontFamily: 'Orbitron, sans-serif', fontSize: '10px', color: '#333355', letterSpacing: '0.18em' }}>
                    STAGE {String(n).padStart(2, '0')}
                  </span>
                </div>
                <div style={{ aspectRatio: '16/9', background: '#040410', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span style={{ fontFamily: 'Orbitron, sans-serif', fontSize: '28px', color: '#222244' }}>?</span>
                </div>
                <div style={{ padding: '10px 14px 13px' }}>
                  <div style={{ fontFamily: 'Orbitron, sans-serif', fontSize: '13px', color: '#222244', letterSpacing: '0.05em' }}>
                    COMING SOON
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
