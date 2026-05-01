import Link from 'next/link'

export function Nav() {
  return (
    <nav className="bg-arcade-panel border-b-2 border-arcade-amber px-4 py-3 flex justify-between items-center"
         style={{ boxShadow: '0 2px 0 #7a5500, 0 4px 20px #ffb30033' }}>
      <Link href="/" className="font-pixel text-arcade-amber text-xs tracking-widest text-glow-amber hover:text-white transition-colors">
        NEXUS<span className="text-arcade-hot text-glow-hot mx-1">▓</span>ARCADE
      </Link>
      <div className="flex items-center gap-6 font-mono text-xs tracking-widest">
        <Link href="/leaderboard" className="text-arcade-cyan text-glow-cyan hover:text-white transition-colors">
          HI-SCORES
        </Link>
        <span className="text-arcade-dim">//</span>
        <Link href="/login" className="btn-pixel btn-pixel-hot py-1 px-3 text-[8px]">
          INSERT COIN
        </Link>
      </div>
    </nav>
  )
}
