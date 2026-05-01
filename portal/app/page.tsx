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
    <div className="min-h-screen bg-arcade-bg text-arcade-amber flex flex-col">
      <Nav />
      {season && <SeasonBanner name={season.name} endsAt={season.ends_at} />}

      {/* Hero title */}
      <div className="text-center pt-10 pb-6 px-4 relative">
        <div className="font-pixel text-[9px] text-arcade-cyan text-glow-cyan tracking-[0.4em] mb-3">
          WELCOME TO
        </div>
        <h1 className="font-pixel text-arcade-amber text-glow-amber leading-relaxed"
            style={{ fontSize: 'clamp(18px, 4vw, 36px)', letterSpacing: '0.08em' }}>
          NEXUS<br/>
          <span className="text-arcade-hot text-glow-hot">ARCADE</span>
        </h1>
        <div className="font-mono text-arcade-dim text-xs tracking-widest mt-4">
          CASUAL GAMES &nbsp;•&nbsp; COMPETE &nbsp;•&nbsp; CONQUER
        </div>
        {/* Decorative scanline rule */}
        <div className="mt-6 mx-auto max-w-xs h-px"
             style={{ background: 'linear-gradient(90deg, transparent, #ffb300, transparent)' }} />
      </div>

      {/* Main content */}
      <main className="flex-1 max-w-4xl mx-auto w-full px-4 pb-16">
        {game ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <GameCard slug={game.slug} name={game.name} />
            <LeaderboardWidget gameSlug={game.slug} scores={scores} />
          </div>
        ) : (
          <div className="crt-border p-12 text-center dither-bg">
            <div className="font-pixel text-arcade-amber-dim text-[10px] leading-loose">
              NO GAMES LOADED<br/>
              <span className="cursor text-arcade-dim text-[8px]">STANDBY</span>
            </div>
          </div>
        )}
      </main>

      {/* Footer ticker */}
      <footer className="fixed bottom-0 left-0 right-0 border-t border-arcade-amber py-1 px-2"
              style={{ background: '#0a0800', boxShadow: '0 -2px 0 #7a5500, 0 -4px 16px #ffb30022' }}>
        <div className="marquee-wrap">
          <span className="marquee-inner font-mono text-arcade-amber-dim text-[9px] tracking-widest">
            NEXUS ARCADE v1.0 &nbsp;•&nbsp; INSERT COIN TO CONTINUE &nbsp;•&nbsp;
            HIGH SCORE RESETS EACH SEASON &nbsp;•&nbsp; PLAY FAIR OR GET BANNED &nbsp;•&nbsp;
            NEXUS ARCADE v1.0 &nbsp;•&nbsp; INSERT COIN TO CONTINUE &nbsp;•&nbsp;
            HIGH SCORE RESETS EACH SEASON &nbsp;•&nbsp; PLAY FAIR OR GET BANNED &nbsp;•&nbsp;
          </span>
        </div>
      </footer>
    </div>
  )
}
